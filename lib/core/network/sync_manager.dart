import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import '../database/database_helper.dart';
import 'api_client.dart';

// كلاس مساعد لمعرفة نتيجة المزامنة
class SyncResult {
  int successCount = 0;
  int failCount = 0;
  bool get hasPending => failCount > 0;
  bool get hasFailed => failCount > 0;
}

class SyncManager {
  static final SyncManager instance = SyncManager._init();
  final Dio _dio = ApiClient().dio;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _needsResync = false;

  SyncManager._init() {
    // 1. الاستماع لتغيرات الشبكة الفورية
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (!results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other)) {
        _retryFailedWithBackoff();
        syncAll();
      }
    });

    // 2. مزامنة دورية صامتة كل 30 ثانية
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other)) {
        await _retryFailedWithBackoff();
        syncAll();
      }
    });
  }

  // الدالة الرئيسية التي تشغل كل عمليات المزامنة
  Future<SyncResult> syncAll() async {
    final result = SyncResult();

    // إذا كان الجهاز غير متصل بالشبكة نهائياً، لا نقوم بالمزامنة (نمنع تحول المعلقات إلى فاشل)
    try {
      final netResult = await Connectivity().checkConnectivity();
      if (netResult.contains(ConnectivityResult.none)) {
        final pendingCount = await _countPending();
        pendingCountNotifier.value = pendingCount;
        return result;
      }
    } catch (_) {}

    if (_isSyncing) {
      _needsResync = true;
      return result; // تسجيل طلب مزامنة بدلاً من إسقاطه
    }
    _isSyncing = true;
    _needsResync = false;
    final startedAt = DateTime.now().toIso8601String();

    try {
      await _syncAttendance(result);
      await _syncMemorizations(result);
      await _syncQuizRequests(result);

      // إذا نجحت أي مزامنة، نسحب أحدث البيانات من السيرفر لتحديث الكاش المحلي
      if (result.successCount > 0) {
        await fetchLatestData();
        // تنظيف السجلات المتزامنة بعد 7 أيام
        _cleanupSyncedItems();
      }

      // تحديث عداد المعلقات في الواجهة دائماً (وليس فقط عند وجود نجاح/فشل)
      final pendingCount = await _countPending();
      pendingCountNotifier.value = pendingCount;
    } catch (e) {
      print('🚨 خطأ عام في محرك المزامنة: $e');
    } finally {
      _isSyncing = false;
      if (_needsResync) {
        syncAll();
      }
    }

    // تسجيل عملية المزامنة في sync_log
    try {
      final finishedAt = DateTime.now().toIso8601String();
      final status = result.failCount > 0 ? (result.successCount > 0 ? 'partial' : 'failed') : 'success';
      await _db.insert('sync_log', {
        'started_at': startedAt,
        'finished_at': finishedAt,
        'success_count': result.successCount,
        'fail_count': result.failCount,
        'status': status,
      });
    } catch (_) {}

    return result;
  }

  // حذف السجلات المتزامنة القديمة (أقدم من 7 أيام)
  Future<void> _cleanupSyncedItems() async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      for (final table in ['pending_attendance', 'pending_memorizations', 'pending_quiz_requests']) {
        await _db.delete(table, 'sync_status = ? AND created_at < ?', ['synced', weekAgo]);
      }
    } catch (_) {}
  }

  Future<void> _retryFailedWithBackoff() async {
    final tables = [
      'pending_attendance',
      'pending_memorizations',
      'pending_quiz_requests',
    ];
    final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();

    for (final table in tables) {
      // استعادة العناصر العالقة في حالة 'sending' لأكثر من 5 دقائق
      try {
        final stuck = await _db.queryWhere(table, 'sync_status = ? AND last_attempt_at < ?', ['sending', fiveMinAgo]);
        for (final s in stuck) {
          await _db.update(table, {'sync_status': 'pending', 'last_error': '[CLIENT_ERROR] تم قطع الاتصال أثناء الإرسال، حاول مرة أخرى'}, 'id = ?', [s['id']]);
        }
      } catch (_) {}

      final failed = await _db.queryWhere(table, 'sync_status = ?', ['failed']);

      for (final item in failed) {
        final lastError = item['last_error'] as String? ?? '';
        // لا نعيد محاولة أخطاء العميل (4xx) — تخطيها
        if (lastError.startsWith('[CLIENT_ERROR]')) continue;

        final retryCount = item['retry_count'] as int;
        // استخدام last_attempt_at إن وُجد، وإلا fallback إلى created_at
        final lastAttempt =
            item['last_attempt_at'] as String? ?? item['created_at'] as String?;
        final lastAttemptTime =
            DateTime.tryParse(lastAttempt ?? '') ?? DateTime.now();
        final waitSeconds = _backoffSeconds(retryCount);
        final nextRetry = lastAttemptTime.add(Duration(seconds: waitSeconds));

        // إذا حان وقت إعادة المحاولة — نعيد تعيين إلى pending ونبقي الخطأ ليعلم المستخدم سبب المشكلة
        if (DateTime.now().isAfter(nextRetry)) {
          await _db.update(
            table,
            {'sync_status': 'pending', 'retry_count': 0, 'last_attempt_at': DateTime.now().toIso8601String()},
            'id = ?',
            [item['id']],
          );
        }
      }
    }
  }

  int _backoffSeconds(int retryCount) {
    // 30, 60, 120, 240, 480 ثانية (نصف دقيقة، دقيقة، 2، 4، 8 دقائق)
    return (30 * _pow(2, retryCount)).clamp(30, 1800).toInt();
  }

  double _pow(int base, int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }

  // ==========================================
  // 1. مزامنة الحضور المعلق (بنظام الدفعات Batch)
  // ==========================================
  Future<void> _syncAttendance(SyncResult result) async {
    final pending = await _db.queryWhere(
      'pending_attendance',
      '(sync_status = ? OR sync_status = ?)',
      ['pending', 'sending'],
    );

    if (pending.isEmpty) return;

    final groups = _groupBy(pending, (e) => '${e['date']}_${e['circle_id']}');

    for (final group in groups.values) {
      final ids = group.map((e) => e['id']).toList();
      final placeholders = List.filled(ids.length, '?').join(',');

      final now = DateTime.now().toIso8601String();
      await _db.update(
        'pending_attendance',
        {'sync_status': 'sending', 'last_attempt_at': now},
        'id IN ($placeholders)',
        ids,
      );

      try {
        final records = group
            .map(
              (e) => {'enrollment': e['enrollment_id'].toString(), 'status': e['status']},
            )
            .toList();

        final response = await _dio.post(
          '/api/attendance/batch/',
          data: {
            'circle': group.first['circle_id'],
            'date': group.first['date'],
            'records': records,
          },
        ).timeout(const Duration(seconds: 15));

        // استخراج server_id من الاستجابة إن وُجد
        final serverIds = <int>{};
        if (response.data is List) {
          for (var rec in response.data) {
            if (rec['id'] != null) serverIds.add(rec['id'] as int);
          }
        }
        final sid = serverIds.isNotEmpty ? serverIds.first : null;

        await _db.update(
          'pending_attendance',
          {
            'sync_status': 'synced',
            if (sid != null) 'server_id': sid,
          },
          'id IN ($placeholders)',
          ids,
        );
        result.successCount += group.length;
      } catch (e) {
        final errorMsg = _translateError(e);
        // إذا كان الخطأ "موجود مسبقاً"، نعتبر المزامنة ناجحة (السجل موجود فعلاً في السيرفر)
        final isDuplicate = errorMsg.contains('موجود مسبقاً') || errorMsg.contains('already exists');
        await _db.update(
          'pending_attendance',
          {
            'sync_status': isDuplicate ? 'synced' : 'failed',
            'last_attempt_at': now,
            'last_error': isDuplicate ? null : errorMsg,
          },
          'id IN ($placeholders)',
          ids,
        );
        if (isDuplicate) {
          result.successCount += group.length;
        } else {
          result.failCount += group.length;
        }
      }
    }
  }

  // ==========================================
  // 2. مزامنة الحفظ المعلق (بنظام الدفعات Batch)
  // ==========================================
  Future<void> _syncMemorizations(SyncResult result) async {
    final pending = await _db.queryWhere(
      'pending_memorizations',
      '(sync_status = ? OR sync_status = ?)',
      ['pending', 'sending'],
    );

    if (pending.isEmpty) return;

    // التجميع حسب التاريخ لتكوين الدفعة
    final groups = _groupBy(pending, (e) => '${e['date']}');

    for (final group in groups.values) {
      final ids = group.map((e) => e['id']).toList();
      final placeholders = List.filled(ids.length, '?').join(',');

      final now = DateTime.now().toIso8601String();
      await _db.update(
        'pending_memorizations',
        {'sync_status': 'sending', 'last_attempt_at': now},
        'id IN ($placeholders)',
        ids,
      );

      try {
        final records = group
            .map(
              (e) => {
                'enrollment': e['enrollment_id'].toString(),
                'surah': e['surah_id'],
                'from_ayah': e['from_ayah'],
                'to_ayah': e['to_ayah'],
                'type': e['type'],
                'result': e['result'],
                'date': e['date'],
                'notes': e['notes'] ?? '',
              },
            )
            .toList();

        final body = jsonEncode({'records': records});
        print('📤 إرسال حفظ: $body');
        final response = await _dio.post(
          '/api/memorizations/batch/',
          data: {'records': records},
        ).timeout(const Duration(seconds: 15));
        print('📥 استجابة الحفظ: ${response.statusCode} ${response.data}');

        // استخراج server_id من الاستجابة إن وُجد
        final serverIds = <int>{};
        if (response.data is List) {
          for (var rec in response.data) {
            if (rec['id'] != null) serverIds.add(rec['id'] as int);
          }
        }
        final sid = serverIds.isNotEmpty ? serverIds.first : null;

        await _db.update(
          'pending_memorizations',
          {
            'sync_status': 'synced',
            if (sid != null) 'server_id': sid,
          },
          'id IN ($placeholders)',
          ids,
        );
        result.successCount += group.length;
      } catch (e) {
        final errorMsg = _translateError(e);
        final isDuplicate = errorMsg.contains('موجود مسبقاً') || errorMsg.contains('already exists');
        await _db.update(
          'pending_memorizations',
          {
            'sync_status': isDuplicate ? 'synced' : 'failed',
            'last_attempt_at': now,
            'last_error': isDuplicate ? null : errorMsg,
          },
          'id IN ($placeholders)',
          ids,
        );
        if (isDuplicate) {
          result.successCount += group.length;
        } else {
          result.failCount += group.length;
        }
      }
    }
  }

  // ==========================================
  // 3. مزامنة طلبات السبر (فردية)
  // ==========================================
  Future<void> _syncQuizRequests(SyncResult result) async {
    final pending = await _db.queryWhere(
      'pending_quiz_requests',
      '(sync_status = ? OR sync_status = ?)',
      ['pending', 'sending'],
    );

    if (pending.isEmpty) return;

    for (final req in pending) {
      final now = DateTime.now().toIso8601String();
      await _db.update(
        'pending_quiz_requests',
        {'sync_status': 'sending', 'last_attempt_at': now},
        'id = ?',
        [req['id']],
      );

      try {
        await _dio.post(
          '/api/quiz-requests/',
          data: {
            "enrollment": req['enrollment_id'],
            "quran_part": req['quran_part_id'],
            "quiz_type": req['quiz_type'],
            "teacher_notes": req['teacher_notes'],
          },
        ).timeout(const Duration(seconds: 15));

        await _db.update(
          'pending_quiz_requests',
          {'sync_status': 'synced'},
          'id = ?',
          [req['id']],
        );
        result.successCount += 1;
      } catch (e) {
        final errorMsg = _translateError(e);
        final isDuplicate = errorMsg.contains('موجود مسبقاً') || errorMsg.contains('already exists');
        await _db.update(
          'pending_quiz_requests',
          {
            'sync_status': isDuplicate ? 'synced' : 'failed',
            'last_attempt_at': now,
            'last_error': isDuplicate ? null : errorMsg,
          },
          'id = ?',
          [req['id']],
        );
        if (isDuplicate) {
          result.successCount += 1;
        } else {
          result.failCount += 1;
        }
      }
    }
  }

  // ==========================================
  // 4. تحديث الجداول المحلية (الكاش) بعد الرفع
  // ==========================================
  Future<void> fetchLatestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int circleId = prefs.getInt('last_circle_id') ?? 0;
      if (circleId == 0) return;

      // 1. تحديث الطلاب + استخراج course_id
      final studentsRes = await _dio.get('/api/enrollments/?circle=$circleId');
      int courseId = 0;
      if (studentsRes.statusCode == 200) {
        final List<dynamic> students = studentsRes.data['results'] ?? [];
        if (students.isNotEmpty) {
          courseId = students.first['course_id'] ?? 0;
          if (courseId > 0) await prefs.setInt('last_course_id', courseId);
        }

        // 1a. جلب cached_students الحاليين للمقارنة
        final cachedBefore = await _db.queryWhere('cached_students', 'circle_id = ?', [circleId]);
        final serverIds = students.map((s) => s['id'] as int).toSet();

        // 1b. تحديث/إضافة الطلاب الموجودين في السيرفر مع بيانات الترتيب
        for (var s in students) {
          await _db.insert('cached_students', {
            'id': s['id'],
            'enrollment_id': s['id'],
            'name': s['student_name'] ?? '',
            'circle_id': circleId,
            'course_id': s['course_id'] ?? courseId,
            'circle_name': s['circle_name'] ?? '',
            'status': s['status'] ?? 'active',
            'sync_status': 'synced',
            'total_points': s['total_points'] ?? 0,
            'attendance_count': s['attendance_count'] ?? 0,
            'total_sessions': s['total_sessions'] ?? 0,
          });
        }

        // 1c. وضع علامة deleted_on_server للطلاب المحذوفين
        final now = DateTime.now().toIso8601String();
        for (var cached in cachedBefore) {
          final cachedId = cached['id'] as int;
          if (!serverIds.contains(cachedId) && cached['sync_status'] != 'deleted_on_server') {
            await _db.update(
              'cached_students',
              {'sync_status': 'deleted_on_server', 'deleted_at': now},
              'id = ?',
              [cachedId],
            );
          }
        }

        // 1d. حذف الطلاب المحذوفين منذ أكثر من 30 يوماً
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
        await _db.delete(
          'cached_students',
          'sync_status = ? AND deleted_at IS NOT NULL AND deleted_at < ?',
          ['deleted_on_server', thirtyDaysAgo],
        );
      }

      if (courseId == 0) {
        courseId = prefs.getInt('last_course_id') ?? 0;
        if (courseId == 0) return;
      }

      // 2. تحديث الحضور (باستخدام course_id حسب API)
      final attRes = await _dio.get(
        '/api/attendance/?course=$courseId&ordering=-date',
      );
      if (attRes.statusCode == 200) {
        final List<dynamic> records = attRes.data['results'] ?? [];
        await prefs.setString(
          'cache_attendance_record_course_$courseId',
          jsonEncode(records),
        );
      }

      // 3. تحديث الحفظ (باستخدام course_id حسب API)
      final memoRes = await _dio.get(
        '/api/memorizations/?course=$courseId&ordering=-date',
      );
      if (memoRes.statusCode == 200) {
        final List<dynamic> records = memoRes.data['results'] ?? [];
        await prefs.setString(
          'cache_memo_record_course_$courseId',
          jsonEncode(records),
        );
      }

      // 4. تحديث كاش التقارير (للعمل دون اتصال)
      try {
        final rankRes = await _dio.get('/api/dashboard/student-ranking/?course=$courseId');
        if (rankRes.statusCode == 200) {
          await prefs.setString('cache_student_ranking', jsonEncode(rankRes.data['results'] ?? rankRes.data));
        }
      } catch (_) {}

      try {
        final memoStatsRes = await _dio.get('/api/dashboard/memorization-stats/?course=$courseId');
        if (memoStatsRes.statusCode == 200) {
          await prefs.setString('cache_memo_stats', jsonEncode(memoStatsRes.data['results'] ?? memoStatsRes.data));
        }
      } catch (_) {}

      try {
        final teacherId = prefs.getInt('teacher_id') ?? 0;
        final dashEndpoint = teacherId > 0
            ? '/api/dashboard/teacher-dashboard/?teacher=$teacherId'
            : '/api/dashboard/teacher-dashboard/';
        final dashRes = await _dio.get(dashEndpoint);
        if (dashRes.statusCode == 200) {
          await prefs.setString('cache_teacher_dashboard', jsonEncode(dashRes.data['results'] ?? dashRes.data));
        }
      } catch (_) {}

      print('✅ تم تحديث الكاش المحلي بنجاح');
    } catch (e) {
      print('❌ خطأ أثناء جلب أحدث البيانات للكاش: $e');
    }
  }

  // حساب عدد العناصر المعلقة في جميع الجداول
  Future<int> _countPending() async {
    int total = 0;
    for (final table in ['pending_attendance', 'pending_memorizations', 'pending_quiz_requests']) {
      final items = await _db.queryWhere(
        table,
        'sync_status = ? OR sync_status = ? OR sync_status = ?',
        ['pending', 'sending', 'failed'],
      );
      total += items.length;
    }
    return total;
  }

  // ترجمة أخطاء السيرفر إلى رسائل مفهومة للمستخدم
  String _translateError(dynamic e) {
    // 1. Timeout
    if (e is TimeoutException) {
      return 'انتهت مهلة الاتصال — تحقق من اتصالك بالإنترنت وحاول مرة أخرى';
    }

    // 2. DioException
    if (e is DioException) {
      final statusCode = e.response?.statusCode ?? 0;
      final data = e.response?.data;

      // رسائل حسب حالة HTTP
      switch (statusCode) {
        case 400: return '[CLIENT_ERROR] ${_extractFieldErrors(data, 'البيانات المرسلة غير صالحة — راجع الحقول الملونة')}';
        case 401: return '[CLIENT_ERROR] انتهت صلاحية الجلسة — يرجى تسجيل الدخول مرة أخرى';
        case 403: return '[CLIENT_ERROR] لا تملك صلاحية تنفيذ هذا الإجراء';
        case 404: return '[CLIENT_ERROR] العنصر المطلوب غير موجود على السيرفر';
        case 409: return '[CLIENT_ERROR] تعارض في البيانات — السجل موجود مسبقاً';
        case 429: return 'تم تجاوز عدد الطلبات المسموح بها — حاول لاحقاً';
        case 500: return 'خطأ داخلي في السيرفر — حاول مرة أخرى لاحقاً';
        case 502: return 'السيرفر غير متاح مؤقتاً — حاول مرة أخرى';
        case 503: return 'خدمة السيرفر غير متاحة حالياً';
      }

      // رسائل حسب نوع الخطأ
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return 'انتهت مهلة الاتصال — تحقق من اتصالك بالإنترنت وحاول مرة أخرى';
        case DioExceptionType.receiveTimeout:
          return 'السيرفر لم يستجب — تحقق من اتصالك وحاول مرة أخرى';
        case DioExceptionType.connectionError:
          return 'تعذر الاتصال بالسيرفر — تحقق من اتصالك بالإنترنت';
        case DioExceptionType.badResponse:
          return '[CLIENT_ERROR] ${_extractFieldErrors(data, 'خطأ $statusCode من السيرفر')}';
        default:
          return 'خطأ في الاتصال — تحقق من اتصالك بالإنترنت';
      }
    }

    // 3. أي خطأ آخر
    final msg = e.toString();
    if (msg.length > 150) return msg.substring(0, 150);
    return msg;
  }

  // استخراج رسائل الخطأ من حقول الاستجابة (Django REST Framework format)
  String _extractFieldErrors(dynamic data, String fallback) {
    if (data == null) return fallback;
    try {
      if (data is String) return _translateDjangoMessage(data);
      if (data is List) return data.map((e) => _translateDjangoMessage(e.toString())).join(' | ');
      if (data is Map) {
        if (data['detail'] != null) return _translateDjangoMessage(data['detail'].toString());
        if (data['message'] != null) return _translateDjangoMessage(data['message'].toString());
        if (data['non_field_errors'] != null) {
          final errors = data['non_field_errors'] as List;
          if (errors.isNotEmpty) return _translateDjangoMessage(errors.first.toString());
        }
        final messages = <String>[];
        for (final entry in data.entries) {
          final fieldName = _fieldNameArabic(entry.key);
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            final translated = value.map((e) => _translateDjangoMessage(e.toString())).join(', ');
            messages.add('$fieldName: $translated');
          } else if (value is String) {
            messages.add('$fieldName: ${_translateDjangoMessage(value)}');
          }
        }
        if (messages.isNotEmpty) return messages.join(' | ');
      }
    } catch (_) {}
    return fallback;
  }

  // ترجمة رسائل Django المعروفة إلى العربية
  String _translateDjangoMessage(String msg) {
    if (msg.contains('Invalid pk') || msg.contains('object does not exist')) {
      return 'الطالب غير موجود في النظام';
    }
    if (msg.contains('is not a valid choice')) {
      final start = msg.indexOf('"') + 1;
      final end = msg.indexOf('"', start);
      if (start > 0 && end > start) {
        final val = msg.substring(start, end);
        return '"$val" ليس اختياراً صالحاً';
      }
      return 'قيمة غير صالحة';
    }
    if (msg.contains('This field is required') || msg.contains('may not be blank') || msg.contains('may not be null')) {
      return 'هذا الحقل مطلوب';
    }
    if (msg.contains('already exists') || msg.contains('must make a unique set') || msg.contains('unique set') || msg.contains('مجموعة فريدة')) {
      return 'السجل موجود مسبقاً';
    }
    if (msg.contains('Ensure this field has at least')) {
      return 'القيمة قصيرة جداً';
    }
    if (msg.contains('Ensure this field has no more than')) {
      return 'القيمة طويلة جداً';
    }
    if (msg.contains('Enter a valid')) {
      return 'القيمة المدخلة غير صالحة';
    }
    if (msg.contains('No')) {
      return 'لا يوجد عنصر مطابق';
    }
    if (msg.contains('not found')) {
      return 'العنصر غير موجود';
    }
    if (msg.contains('is not a valid') || msg.contains('invalid')) {
      return 'قيمة غير صالحة';
    }
    return msg;
  }

  // ترجمة أسماء الحقول إلى العربية
  String _fieldNameArabic(String field) {
    switch (field) {
      case 'enrollment': return 'الطالب';
      case 'enrollment_id': return 'الطالب';
      case 'student_name': return 'اسم الطالب';
      case 'status': return 'حالة الحضور';
      case 'date': return 'التاريخ';
      case 'circle': return 'الحلقة';
      case 'circle_id': return 'الحلقة';
      case 'course': return 'الدورة';
      case 'surah': return 'السورة';
      case 'surah_id': return 'السورة';
      case 'from_ayah': return 'من الآية';
      case 'to_ayah': return 'إلى الآية';
      case 'type': return 'النوع';
      case 'result': return 'النتيجة';
      case 'notes': return 'الملاحظات';
      case 'quiz_type': return 'نوع السبر';
      case 'quran_part': return 'الجزء';
      case 'quran_part_id': return 'الجزء';
      case 'teacher_notes': return 'ملاحظات المعلم';
      case 'records': return 'سجلات الحضور';
      default: return field;
    }
  }

  // دالة مساعدة لتجميع البيانات (Grouping)
  Map<String, List<Map<String, dynamic>>> _groupBy(
    List<Map<String, dynamic>> list,
    String Function(Map<String, dynamic>) key,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in list) {
      final k = key(item);
      map.putIfAbsent(k, () => []).add(item);
    }
    return map;
  }
}
