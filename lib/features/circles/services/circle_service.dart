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
}