import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';

/// خدمة إحصائيات الطلاب: جلب الترتيب والتقارير الشاملة
class StudentStatsService {
  final Dio _dio = ApiClient().dio;
  final StudentService _studentService = StudentService();

  // كاش في الذاكرة للتقارير (يُستخدم لنسخ الأرقام + صفحة التفاصيل)
  final Map<int, Map<String, dynamic>> _reportCache = {};

  /// جلب قائمة الطلاب مرتبة حسب النقاط
  /// يعتمد على student-ranking مع fallback إلى enrollments
  /// إنترنت شغّال → جلب مباشر + تحديث الكاش | لا إنترنت → آخر نسخة محفوظة
  Future<List<Map<String, dynamic>>> getStudentStatsList(int courseId, int circleId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_student_stats_${courseId}_$circleId';
    List<Map<String, dynamic>> ranking = [];
    bool rankingFetched = false;

    // 1. جلب الترتيب من API
    try {
      String url = '/api/dashboard/student-ranking/';
      final params = <String>[];
      if (courseId > 0) params.add('course=$courseId');
      if (circleId > 0) params.add('circle=$circleId');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> results = data is Map ? (data['results'] ?? []) : (data ?? []);
        ranking = results.map((r) => Map<String, dynamic>.from(r)).toList();
        rankingFetched = true;
      }
    } catch (_) {}

    // فشل جلب الترتيب → عرض آخر نسخة محفوظة كاملة (تشمل الهواتف والترتيب)
    if (!rankingFetched) {
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final list = jsonDecode(cached) as List;
          return list.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    // 2. جلب التسجيلات (للحصول على enrollment_id)
    List<dynamic> enrollments = [];
    try {
      enrollments = await _studentService.getStudentsByCircle(circleId);
    } catch (_) {}

    // 3. الدمج
    final merged = <Map<String, dynamic>>[];
    for (final r in ranking) {
      int? enrollmentId = r['enrollment_id'] as int?;
      final String name = (r['student_name'] ?? '').toString();

      // fallback: مطابقة بالاسم
      if (enrollmentId == null && enrollments.isNotEmpty) {
        for (final e in enrollments) {
          if ((e['student_name'] ?? '') == name) {
            enrollmentId = e['id'] as int?;
            break;
          }
        }
      }

      merged.add({
        'rank': r['rank'] ?? 0,
        'student_name': name,
        'total_points': r['total_points'] ?? 0,
        'enrollment_id': enrollmentId,
        'student_id': r['student_id'],
        'student_phone': r['student_phone'] ?? '',
        'student_date_of_birth': r['student_date_of_birth'] ?? '',
        'circle_name': r['circle_name'] ?? '',
      });
    }

    // 4. إذا الترتيب فارغ → fallback للتسجيلات مرتبة بالنقاط
    if (merged.isEmpty && enrollments.isNotEmpty) {
      final sorted = List<dynamic>.from(enrollments)
        ..sort((a, b) => ((b['total_points'] ?? 0) as num).compareTo((a['total_points'] ?? 0) as num));
      int rank = 1;
      for (final e in sorted) {
        merged.add({
          'rank': rank++,
          'student_name': e['student_name'] ?? '',
          'total_points': e['total_points'] ?? 0,
          'enrollment_id': e['id'],
          'student_id': null,
          'student_phone': '',
          'student_date_of_birth': '',
          'circle_name': e['circle_name'] ?? '',
        });
      }
    }

    // 5. تحديث الكاش بالبيانات المحدثة من الشبكة
    if (rankingFetched && merged.isNotEmpty) {
      try {
        await prefs.setString(cacheKey, jsonEncode(merged));
      } catch (_) {}
    }

    return merged;
  }

  /// جلب تقرير الطالب الشامل (كاش في الذاكرة + كاش دائم للعمل دون اتصال)
  Future<Map<String, dynamic>?> getStudentCourseReport(
    int enrollmentId, {
    int? studentId,
    int? courseId,
  }) async {
    // من كاش الذاكرة
    if (_reportCache.containsKey(enrollmentId)) return _reportCache[enrollmentId];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_course_report_$enrollmentId';

    // حفظ النتيجة في الذاكرة + الكاش الدائم
    Future<Map<String, dynamic>> saveResult(Map<String, dynamic> result) async {
      _reportCache[enrollmentId] = result;
      try {
        await prefs.setString(cacheKey, jsonEncode(result));
      } catch (_) {}
      return result;
    }

    // 1. محاولة بـ enrollment
    try {
      final response = await _dio.get(
        '/api/dashboard/student-course-report/?enrollment=$enrollmentId',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && (data['student'] != null || data['attendance'] != null)) {
          return await saveResult(Map<String, dynamic>.from(data));
        }
      }
    } catch (_) {}

    // 2. fallback: student + course
    if (studentId != null && courseId != null && studentId > 0 && courseId > 0) {
      try {
        final response = await _dio.get(
          '/api/dashboard/student-course-report/?student=$studentId&course=$courseId',
        );
        if (response.statusCode == 200) {
          final data = response.data;
          if (data is Map) {
            return await saveResult(Map<String, dynamic>.from(data));
          }
        }
      } catch (_) {}
    }

    // 3. لا يوجد اتصال → آخر نسخة محفوظة
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final result = Map<String, dynamic>.from(jsonDecode(cached));
        _reportCache[enrollmentId] = result;
        return result;
      } catch (_) {}
    }

    return null;
  }

  void clearCache() => _reportCache.clear();
}
