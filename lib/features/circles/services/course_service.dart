import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';

class CourseService {
  final Dio _dio = ApiClient().dio;

  Future<List<dynamic>> getMyCourses() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _dio.get('/api/courses/');
      if (response.statusCode == 200) {
        final courses = response.data['results'] ?? [];
        await prefs.setString('cached_courses', jsonEncode(courses));
        return courses;
      }
      return [];
    } catch (e) {
      print('🚨 خطأ في جلب الدورات: $e');
      final cached = prefs.getString('cached_courses');
      if (cached != null && cached.isNotEmpty) return jsonDecode(cached);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCourseDetails(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'course_details_$courseId';
    try {
      final response = await _dio.get('/api/courses/$courseId/');
      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, jsonEncode(response.data));
        return response.data;
      }
      return null;
    } catch (e) {
      print('🚨 خطأ في جلب تفاصيل الدورة: $e');
      final cached = prefs.getString(cacheKey);
      if (cached != null) return jsonDecode(cached);
      return null;
    }
  }

  // خريطة أسماء الأيام العربية → رقم اليوم (الأحد=0 .. السبت=6)
  static const Map<String, int> arabicDayToNum = {
    'الأحد': 0, 'الإثنين': 1, 'الاثنين': 1, 'الثلاثاء': 2,
    'الأربعاء': 3, 'الاربعاء': 3, 'الخميس': 4,
    'الجمعة': 5, 'السبت': 6,
  };

  // أسماء الأيام بالأرقام (للعرض)
  static const Map<int, String> arabicDayNames = {
    0: 'الأحد', 1: 'الإثنين', 2: 'الثلاثاء', 3: 'الأربعاء',
    4: 'الخميس', 5: 'الجمعة', 6: 'السبت',
  };

  static String getArabicDayName(DateTime date) {
    return arabicDayNames[date.weekday % 7] ?? '';
  }

  // التحقق من أن التاريخ يقع ضمن أيام الدورة
  // الأيام تأتي من API كأسماء عربية: ["الأحد", "الثلاثاء", "الخميس"]
  Future<bool> isDateWithinCourse(int courseId, String dateStr) async {
    try {
      final course = await getCourseDetails(courseId);
      if (course == null) return true;

      final startDate = course['start_date']?.toString().substring(0, 10);

      // 1. منع الأيام المستقبلية فقط
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (dateStr.compareTo(today) > 0) return false;

      // 2. التحقق من يوم الأسبوع (إذا كانت الدورة تحدد أياماً)
      final daysRaw = course['days'];
      if (daysRaw == null) return true;

      List<int> dayInts = [];

      if (daysRaw is List) {
        for (final d in daysRaw) {
          if (d is int) {
            dayInts.add(d);
          } else if (d is String) {
            final trimmed = d.trim();
            final asInt = int.tryParse(trimmed);
            if (asInt != null) {
              dayInts.add(asInt);
            } else {
              final num = arabicDayToNum[trimmed];
              if (num != null) dayInts.add(num);
            }
          }
        }
      } else if (daysRaw is String && daysRaw.isNotEmpty) {
        for (final part in daysRaw.split(',')) {
          final trimmed = part.trim();
          final asInt = int.tryParse(trimmed);
          if (asInt != null) {
            dayInts.add(asInt);
          } else {
            final num = arabicDayToNum[trimmed];
            if (num != null) dayInts.add(num);
          }
        }
      }

      if (dayInts.any((d) => d >= 0 && d <= 6)) {
        final date = DateTime.parse(dateStr);
        final dayOfWeek = date.weekday % 7;
        if (!dayInts.contains(dayOfWeek)) return false;
      }

      return true;
    } catch (e) {
      print('⚠️ خطأ في التحقق من تاريخ الدورة: $e');
      return true;
    }
  }
}
