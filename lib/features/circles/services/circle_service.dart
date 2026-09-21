import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';

class CircleService {
  final Dio _dio = ApiClient().dio;

  Future<List<dynamic>> getMyCircles() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // 1. محاولة جلب الحلقات من السيرفر
      final response = await _dio.get('/api/circles/');
      if (response.statusCode == 200) {
        final List<dynamic> circles = response.data['results'] ?? [];
        // 2. تحديث الكاش المحلي فور نجاح الجلب
        await prefs.setString('cached_circles', jsonEncode(circles));
        return circles;
      }
    } catch (e) {
      print('⚠️ تعذر الاتصال بالسيرفر، سيتم عرض الحلقات من الكاش المحلي: $e');
    }

    // 3. في حال عدم وجود إنترنت، عرض البيانات من الكاش
    final cachedString = prefs.getString('cached_circles');
    if (cachedString != null && cachedString.isNotEmpty) {
      return jsonDecode(cachedString);
    }
    
    return [];
  }

  Future<Map<String, dynamic>?> getCircleDetails(int circleId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'circle_details_$circleId';
    try {
      final response = await _dio.get('/api/circles/$circleId/');
      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, jsonEncode(response.data));
        return response.data;
      }
      return null;
    } catch (e) {
      print('🚨 خطأ في جلب تفاصيل الحلقة: $e');
      final cached = prefs.getString(cacheKey);
      if (cached != null) return jsonDecode(cached);
      return null;
    }
  }

  /// جلب الطلاب المؤرشفين في الدورة (مع فلترة الحلقة محلياً)
  /// ملاحظة: API لا يدعم فلتر circle — يدعم course و status فقط
  Future<List<dynamic>> getArchivedStudents({required int courseId, int? circleId}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_archived_enrollments_${courseId}_${circleId ?? 'all'}';
    List<dynamic> result = [];
    try {
      final response = await _dio.get('/api/enrollments/', queryParameters: {
        'course': courseId,
        'status': 'archived',
      });
      if (response.statusCode == 200) {
        result = response.data['results'] ?? [];
        await prefs.setString(cacheKey, jsonEncode(result));
      }
    } catch (e) {
      print('⚠️ تعذر جلب الطلاب المؤرشفين، سيتم العرض من الكاش: $e');
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          result = jsonDecode(cached);
        } catch (_) {}
      }
    }
    // فلترة حسب الحلقة الحالية (الـ API لا يدعم فلتر circle)
    if (circleId != null) {
      result = result.where((e) => e is Map && e['circle'] == circleId).toList();
    }
    return result;
  }
}