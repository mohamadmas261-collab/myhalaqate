import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// حالة إرسال طلب السبر
enum SaberSendStatus {
  /// أُرسل بنجاح إلى السيرفر
  sent,

  /// لا يوجد اتصال — حُفظ محلياً وسيُرسل لاحقاً
  queued,

  /// رفض السيرفر الطلب أو خطأ منطقي — لم يُحفظ محلياً
  failed,
}

class SaberSendResult {
  final SaberSendStatus status;
  final String? errorMessage;
  const SaberSendResult(this.status, [this.errorMessage]);

  bool get isSent => status == SaberSendStatus.sent;
  bool get isQueued => status == SaberSendStatus.queued;
  bool get isFailed => status == SaberSendStatus.failed;
}

class SaberService {
  final Dio _dio = ApiClient().dio;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<dynamic>> getPendingLocalRequests() async {
    try {
      return await _db.queryWhere(
        'pending_quiz_requests',
        'sync_status IS NULL OR sync_status = ? OR sync_status = ? OR sync_status = ?',
        ['pending', 'sending', 'failed'],
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getMySaberRequests(int circleId, {int? courseId}) async {
    try {
      List<dynamic> serverRequests = [];
      String cacheKey = 'cache_saber_requests_circle_$circleId';
      try {
        final prefs = await SharedPreferences.getInstance();
        final int resolvedCourseId = courseId ?? prefs.getInt('last_course_id') ?? 0;

        String url = '/api/quiz-requests/?circle=$circleId';
        if (resolvedCourseId > 0) {
          url += '&course=$resolvedCourseId';
        }

        final response = await _dio.get(url);
        if (response.statusCode == 200) {
          serverRequests = response.data['results'] ?? [];
          await prefs.setString(cacheKey, jsonEncode(serverRequests));
        }
      } catch (e) {
        print('⚠️ تعذر جلب الطلبات من السيرفر (قد يكون غير متصل): $e');
        // فشل الاتصال — نحاول من الكاش
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString(cacheKey);
          if (cached != null && cached.isNotEmpty) {
            serverRequests = jsonDecode(cached);
          }
        } catch (_) {}
      }

      // دمج الطلبات المعلقة محلياً
      final pendingLocal = await _db.queryWhere(
        'pending_quiz_requests',
        'sync_status = ? OR sync_status = ? OR sync_status = ?',
        ['pending', 'sending', 'failed'],
      );

      final merged = <Map<String, dynamic>>[...serverRequests];
      for (final p in pendingLocal) {
        // جلب اسم الطالب من cached_students
        String studentName = 'طالب #${p['enrollment_id']}';
        try {
          final cached = await _db.queryWhere('cached_students', 'enrollment_id = ?', [p['enrollment_id']]);
          if (cached.isNotEmpty) {
            studentName = cached.first['name'] as String? ?? studentName;
          }
        } catch (_) {}
        merged.add({
          'id': p['id'],
          'enrollment_id': p['enrollment_id'],
          'student_name': studentName,
          'quiz_type': p['quiz_type'] ?? 'new',
          'quran_part': p['quran_part_id'],
          'teacher_notes': p['teacher_notes'] ?? '',
          'requested_at': p['created_at'] ?? '',
          'status': 'pending',
          'is_local': true,
          'sync_status': p['sync_status'],
          'last_error': p['last_error'],
        });
      }

      return merged;
    } catch (e) {
      print('🚨 خطأ في جلب طلبات السبر: $e');
      return [];
    }
  }

  Future<bool> createSaberRequest({
    required int enrollmentId,
    required int quranPart,
    required String quizType,
    required String teacherNotes,
  }) async {
    try {
      // 1. الحفظ المحلي فوراً
      await _db.insert('pending_quiz_requests', {
        'enrollment_id': enrollmentId,
        'quran_part_id': quranPart,
        'quiz_type': quizType,
        'teacher_notes': teacherNotes,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. تحديث العداد فوراً + استدعاء محرك المزامنة للعمل بالخلفية
      refreshPendingCount();
      SyncManager.instance.syncAll();
      return true;
    } catch (e) {
      print('🚨 خطأ في إنشاء طلب السبر محلياً: $e');
      return false;
    }
  }

  /// إرسال الطلب مباشرة للسيرفر مع تصنيف دقيق للأخطاء:
  /// - نجاح (2xx) → sent
  /// - فشل شبكة (لا يوجد اتصال) → حفظ محلي → queued (مع فحص التكرار أولاً)
  /// - رفض السيرفر (4xx/5xx) → failed بدون حفظ محلي (منعاً للتكرار)
  Future<SaberSendResult> createSaberRequestOnline({
    required int enrollmentId,
    required int quranPart,
    required String quizType,
    required String teacherNotes,
  }) async {
    try {
      final response = await _dio.post('/api/quiz-requests/', data: {
        'enrollment': enrollmentId,
        'quran_part': quranPart,
        'quiz_type': quizType,
        'teacher_notes': teacherNotes,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return const SaberSendResult(SaberSendStatus.sent);
      }
      return SaberSendResult(SaberSendStatus.failed, 'فشل الإرسال (${response.statusCode})');
    } on DioException catch (e) {
      // خطأ شبكة حقيقي (لا يوجد رد من السيرفر) → حفظ محلي
      if (e.response == null) {
        // فحص وقائي: ربما وصل الطلب فعلاً رغم انقطاع الرد (تجنب التكرار)
        final alreadyOnServer = await _checkRequestExistsOnServer(enrollmentId, quranPart, quizType);
        if (alreadyOnServer) return const SaberSendResult(SaberSendStatus.sent);

        await _queueLocally(enrollmentId, quranPart, quizType, teacherNotes);
        return const SaberSendResult(SaberSendStatus.queued);
      }
      // السيرفر ردّ بخطأ → لا نحفظ محلياً
      return SaberSendResult(SaberSendStatus.failed, _translateDioError(e));
    } catch (e) {
      print('🚨 خطأ غير متوقع في إرسال طلب السبر: $e');
      return SaberSendResult(SaberSendStatus.failed, 'حدث خطأ غير متوقع أثناء الإرسال');
    }
  }

  /// حفظ الطلب في قائمة الانتظار المحلية
  Future<void> _queueLocally(int enrollmentId, int quranPart, String quizType, String teacherNotes) async {
    try {
      await _db.insert('pending_quiz_requests', {
        'enrollment_id': enrollmentId,
        'quran_part_id': quranPart,
        'quiz_type': quizType,
        'teacher_notes': teacherNotes,
        'created_at': DateTime.now().toIso8601String(),
      });
      refreshPendingCount();
      SyncManager.instance.syncAll();
    } catch (e) {
      print('🚨 فشل الحفظ المحلي لطلب السبر: $e');
    }
  }

  /// فحص هل يوجد طلب مطابق معلق على السيرفر (لمنع التكرار عند انقطاع الرد)
  Future<bool> _checkRequestExistsOnServer(int enrollmentId, int quranPart, String quizType) async {
    try {
      final response = await _dio.get(
        '/api/quiz-requests/',
        queryParameters: {'enrollment': enrollmentId, 'status': 'pending'},
      ).timeout(const Duration(seconds: 5));
      final results = response.data is Map ? (response.data['results'] ?? []) : (response.data ?? []);
      if (results is List) {
        return results.any((r) =>
            r is Map &&
            r['quran_part'] == quranPart &&
            r['quiz_type'] == quizType);
      }
    } catch (_) {}
    return false;
  }

  /// ترجمة أخطاء Dio إلى رسائل عربية واضحة
  String _translateDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map) {
      for (final key in ['detail', 'non_field_errors', 'quran_part', 'enrollment', 'error']) {
        final val = data[key];
        if (val is List && val.isNotEmpty) { serverMsg = val.first.toString(); break; }
        if (val is String && val.isNotEmpty) { serverMsg = val; break; }
      }
    }
    if (serverMsg != null && serverMsg.isNotEmpty) {
      if (serverMsg.contains('already') || serverMsg.contains('موجود')) {
        return 'يوجد طلب سبر معلق مسبقاً لهذا الطالب';
      }
      return serverMsg;
    }
    switch (status) {
      case 400: return 'بيانات الطلب غير صحيحة';
      case 401:
      case 403: return 'غير مصرح — سجّل الدخول من جديد';
      case 404: return 'الطالب أو الجزء غير موجود';
      default: return 'فشل الإرسال${status != null ? ' ($status)' : ''}';
    }
  }

  Future<bool> updateSaberRequest(
    int requestId,
    String newNotes, {
    bool isLocal = false,
  }) async {
    try {
      if (isLocal) {
        // التعديل محلياً إذا لم يرفع بعد
        await _db.update(
          'pending_quiz_requests',
          {'teacher_notes': newNotes, 'action': 'update'},
          'id = ?',
          [requestId],
        );
        return true;
      } else {
        // التعديل على السيرفر
        final response = await _dio.patch(
          '/api/quiz-requests/$requestId/',
          data: {"teacher_notes": newNotes},
        );
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      print('🚨 خطأ في تعديل الطلب: $e');
      return false;
    }
  }

  Future<bool> deleteSaberRequest(int requestId, {bool isLocal = false}) async {
    try {
      if (isLocal) {
        // الحذف محلياً
        await _db.delete('pending_quiz_requests', 'id = ?', [requestId]);
        refreshPendingCount();
        return true;
      } else {
        // الحذف من السيرفر
        final response = await _dio.delete('/api/quiz-requests/$requestId/');
        return response.statusCode == 204 || response.statusCode == 200;
      }
    } catch (e) {
      print('🚨 خطأ في حذف الطلب: $e');
      return false;
    }
  }
}
