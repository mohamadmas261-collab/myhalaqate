import 'package:dio/dio.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';


class SaberService {
  final Dio _dio = ApiClient().dio;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<dynamic>> getPendingLocalRequests() async {
    try {
      return await _db.queryWhere(
        'pending_quiz_requests',
        'sync_status IS NULL OR sync_status = ? OR sync_status = ?',
        ['pending', 'sending'],
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getMySaberRequests() async {
    try {
      List<dynamic> serverRequests = [];
      try {
        final response = await _dio.get('/api/quiz-requests/');
        if (response.statusCode == 200) {
          serverRequests = response.data['results'] ?? [];
        }
      } catch (e) {
        print('⚠️ تعذر جلب الطلبات من السيرفر (قد يكون غير متصل): $e');
      }

      // جلب الطلبات المعلقة محلياً لدمجها وعرضها
      final pendingLocal = await _db.queryWhere(
        'pending_quiz_requests',
        'sync_status = ? OR sync_status = ?',
        ['pending', 'sending'],
      );

      // إرجاع طلبات السيرفر فقط (الطلبات المعلقة محلياً تظهر في قسم منفصل)
      return serverRequests;
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

      // 2. استدعاء محرك المزامنة للعمل بالخلفية
      SyncManager.instance.syncAll();
      pendingCountNotifier.value += 1;
      return true;
    } catch (e) {
      print('🚨 خطأ في إنشاء طلب السبر محلياً: $e');
      return false;
    }
  }

  Future<bool> createSaberRequestOnline({
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
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('🚨 خطأ في إرسال طلب السبر: $e');
      return false;
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
