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
  static const int MAX_RETRIES = 5;

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
    if (_isSyncing) return result; // منع التداخل إذا كانت المزامنة تعمل بالفعل
    _isSyncing = true;
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

      // تحديث عداد المعلقات في الواجهة
      if (result.successCount > 0 || result.failCount > 0) {
        final pendingCount = await _countPending();
        pendingCountNotifier.value = pendingCount;
      }
    } catch (e) {
      print('🚨 خطأ عام في محرك المزامنة: $e');
    } finally {
      _isSyncing = false;
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

    for (final table in tables) {
      final failed = await _db.queryWhere(table, 'sync_status = ?', ['failed']);

      for (final item in failed) {
        final retryCount = item['retry_count'] as int;
        // استخدام last_attempt_at إن وُجد، وإلا fallback إلى created_at
        final lastAttempt =
            item['last_attempt_at'] as String? ?? item['created_at'] as String?;
        final lastAttemptTime =
            DateTime.tryParse(lastAttempt ?? '') ?? DateTime.now();
        final waitSeconds = _backoffSeconds(retryCount);
        final nextRetry = lastAttemptTime.add(Duration(seconds: waitSeconds));

        // إذا حان وقت إعادة المحاولة — نعيد تعيين retry_count
        if (DateTime.now().isAfter(nextRetry)) {
          await _db.update(
            table,
            {'sync_status': 'pending', 'retry_count': 0},
            'id = ?',
            [item['id']],
          );
        }
      }
    }
  }

  int _backoffSeconds(int retryCount) {
    // 5, 25, 125, 625, 3125 ثانية
    return (5 * _pow(5, retryCount)).clamp(5, 3125).toInt();
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
      'sync_status = ? AND retry_count < ?',
      ['pending', MAX_RETRIES],
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
        );

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
        final newRetryCount = (group.first['retry_count'] as int) + 1;
        final newStatus = newRetryCount >= MAX_RETRIES ? 'failed' : 'pending';
        await _db.update(
          'pending_attendance',
          {
            'sync_status': newStatus,
            'retry_count': newRetryCount,
            'last_attempt_at': now,
          },
          'id IN ($placeholders)',
          ids,
        );
        result.failCount += group.length;
      }
    }
  }

  // ==========================================
  // 2. مزامنة الحفظ المعلق (بنظام الدفعات Batch)
  // ==========================================
  Future<void> _syncMemorizations(SyncResult result) async {
    final pending = await _db.queryWhere(
      'pending_memorizations',
      'sync_status = ? AND retry_count < ?',
      ['pending', MAX_RETRIES],
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
        );
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
        print('❌ فشل إرسال الحفظ: $e');
        if (e is DioException) {
          print('   الحالة: ${e.response?.statusCode}');
          print('   الرد: ${e.response?.data}');
        }
        final newRetryCount = (group.first['retry_count'] as int) + 1;
        final newStatus = newRetryCount >= MAX_RETRIES ? 'failed' : 'pending';
        await _db.update(
          'pending_memorizations',
          {
            'sync_status': newStatus,
            'retry_count': newRetryCount,
            'last_attempt_at': now,
          },
          'id IN ($placeholders)',
          ids,
        );
        result.failCount += group.length;
      }
    }
  }

  // ==========================================
  // 3. مزامنة طلبات السبر (فردية)
  // ==========================================
  Future<void> _syncQuizRequests(SyncResult result) async {
    final pending = await _db.queryWhere(
      'pending_quiz_requests',
      'sync_status = ? AND retry_count < ?',
      ['pending', MAX_RETRIES],
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
        );

        await _db.update(
          'pending_quiz_requests',
          {'sync_status': 'synced'},
          'id = ?',
          [req['id']],
        );
        result.successCount += 1;
      } catch (e) {
        final newRetryCount = (req['retry_count'] as int) + 1;
        final newStatus = newRetryCount >= MAX_RETRIES ? 'failed' : 'pending';
        await _db.update(
          'pending_quiz_requests',
          {
            'sync_status': newStatus,
            'retry_count': newRetryCount,
            'last_attempt_at': now,
          },
          'id = ?',
          [req['id']],
        );
        result.failCount += 1;
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
