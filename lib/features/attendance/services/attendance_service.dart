import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/database/database_helper.dart';

class AttendanceService {
  final Dio _dio = ApiClient().dio;
  final DatabaseHelper _db = DatabaseHelper.instance;

  // جلب سجل الحضور للحلقة مع الفلترة والتخزين المؤقت (Cache)
  Future<List<dynamic>> getCircleAttendanceRecord(int circleId, {int? courseId, String? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final int resolvedCourseId = courseId ?? prefs.getInt('last_course_id') ?? 0;
    String cacheKey = 'cache_attendance_record_circle_$circleId';
    if (date != null) cacheKey += '_$date';

    try {
      String url = resolvedCourseId > 0
          ? '/api/attendance/?course=$resolvedCourseId'
          : '/api/attendance/?circle=$circleId';
      if (date != null && date.isNotEmpty) url += '&date=$date';
      
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        await prefs.setString(cacheKey, jsonEncode(data));
        return data;
      }
    } catch (e) {
      print('⚠️ تعذر الاتصال بالسيرفر، سيتم عرض سجل الحضور من الكاش: $e');
    }

    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return jsonDecode(cached);
    }
    return [];
  }

  // تعديل سجل حضور معلق (لم يُزامن بعد)
  Future<bool> updatePendingAttendance(int localId, String newStatus) async {
    try {
      await _db.update(
        'pending_attendance',
        {'status': newStatus, 'action': 'update'},
        'id = ?',
        [localId],
      );
      return true;
    } catch (e) {
      print('🚨 خطأ في تعديل الحضور المعلق: $e');
      return false;
    }
  }

  // حذف سجل حضور معلق من قائمة الانتظار
  Future<bool> deletePendingAttendance(int localId) async {
    try {
      await _db.delete('pending_attendance', 'id = ?', [localId]);
      return true;
    } catch (e) {
      print('🚨 خطأ في حذف الحضور المعلق: $e');
      return false;
    }
  }

  // جلب سجلات الحضور المعلقة لحلقة وتاريخ محددين
  Future<List<Map<String, dynamic>>> getPendingAttendance(int circleId, String date) async {
    return await _db.queryWhere(
      'pending_attendance',
      'circle_id = ? AND date = ? AND sync_status != ?',
      [circleId, date, 'synced'],
    );
  }
}