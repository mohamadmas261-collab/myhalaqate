import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';

class RecordsService {
  final Dio _dio = ApiClient().dio;

  // دالة مساعدة ذكية لحفظ وقراءة الكاش الخاص بالسجلات
  Future<List<dynamic>> _fetchWithCache(String endpoint, String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final response = await _dio.get(endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        // تحديث الكاش المحلي فور نجاح الجلب
        await prefs.setString(cacheKey, jsonEncode(data));
        return data;
      }
    } catch (e) {
      print('⚠️ تعذر الاتصال بالسيرفر، سيتم عرض البيانات من الكاش المحلي ($cacheKey): $e');
    }

    // جلب البيانات من الذاكرة في حال انقطاع الإنترنت
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null && cachedData.isNotEmpty) {
      return jsonDecode(cachedData);
    }
    
    return [];
  }

  Future<List<dynamic>> getStudentPoints(int enrollmentId) async {
    return await _fetchWithCache(
      '/api/student-points/?enrollment=$enrollmentId', 
      'cache_points_$enrollmentId'
    );
  }

  Future<List<dynamic>> getStudentQuizzes(int enrollmentId) async {
    return await _fetchWithCache(
      '/api/quizzes/?enrollment=$enrollmentId', 
      'cache_quizzes_$enrollmentId'
    );
  }

  Future<List<dynamic>> getStudentParts(int enrollmentId) async {
    return await _fetchWithCache(
      '/api/student-parts/?enrollment=$enrollmentId', 
      'cache_parts_$enrollmentId'
    );
  }

  Future<List<dynamic>> getPointEventTypes() async {
    return await _fetchWithCache(
      '/api/point-event-types/', 
      'cache_point_types'
    );
  }
}