import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';

class ReportsService {
  final Dio _dio = ApiClient().dio;

  // دالة مساعدة لحفظ وقراءة الكاش
  Future<dynamic> _fetchWithCache(String endpoint, String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _dio.get(endpoint);
      if (response.statusCode == 200) {
        final data = response.data['results'] ?? response.data;
        await prefs.setString(cacheKey, jsonEncode(data));
        return data;
      }
    } catch (e) {
      print('⚠️ تعذر جلب $cacheKey من السيرفر، سيتم استخدام الكاش: $e');
    }

    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      return jsonDecode(cachedData);
    }
    return null;
  }

  Future<List<dynamic>> getStudentRanking() async {
    final data = await _fetchWithCache('/api/dashboard/student-ranking/', 'cache_student_ranking');
    return data != null ? (data as List) : [];
  }

  Future<Map<String, dynamic>?> getMemorizationStats() async {
    final data = await _fetchWithCache('/api/dashboard/memorization-stats/', 'cache_memo_stats');
    return data as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getCircleStats(int circleId) async {
    final data = await _fetchWithCache('/api/dashboard/circle-stats/?circle=$circleId', 'cache_circle_stats_$circleId');
    return data as Map<String, dynamic>?;
  }

  Future<List<dynamic>> getAbsenceReport({int threshold = 3}) async {
    final data = await _fetchWithCache('/api/dashboard/absence-report/?threshold=$threshold', 'cache_absence_report');
    return data != null ? (data as List) : [];
  }

  Future<Map<String, dynamic>?> getWeeklyReport(int enrollmentId) async {
    final data = await _fetchWithCache('/api/dashboard/weekly-report/?enrollment=$enrollmentId', 'cache_weekly_report_$enrollmentId');
    return data as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getTeacherDashboard({int? teacherId}) async {
    final prefs = await SharedPreferences.getInstance();
    final int resolvedTeacherId = teacherId ?? prefs.getInt('teacher_id') ?? 0;
    final String endpoint = resolvedTeacherId > 0
        ? '/api/dashboard/teacher-dashboard/?teacher=$resolvedTeacherId'
        : '/api/dashboard/teacher-dashboard/';
    final data = await _fetchWithCache(endpoint, 'cache_teacher_dashboard');
    return data as Map<String, dynamic>?;
  }
  
  Future<Map<String, dynamic>?> getStudentComprehensiveReport(int studentId, int courseId) async {
    final data = await _fetchWithCache('/api/dashboard/student-course-report/?student=$studentId&course=$courseId', 'cache_comprehensive_${studentId}_$courseId');
    return data as Map<String, dynamic>?;
  }
}