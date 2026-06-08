import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';

class AuthService {
  final Dio _dio = ApiClient().dio;

  Future<bool> login({required String username, required String password}) async {
    try {
      final response = await _dio.post(
        '/api/token/',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final String accessToken = response.data['access'];
        final String refreshToken = response.data['refresh'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);

        try {
          final profileResponse = await _dio.get(
            '/api/profile/',
            options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
          );

          if (profileResponse.statusCode == 200) {
            final Map<String, dynamic> profileData = profileResponse.data;
            print('✅ استجابة السيرفر للبروفايل: $profileData');
            
            await prefs.setString('role', profileData['role'] ?? '');
            
            // ✅ التعديل الأول: سحب الاسم من teacher_name وإذا كان فارغ يسحب first_name
            String fetchedName = profileData['teacher_name'] ?? profileData['first_name'] ?? '';
            
            // إذا كان الاسم لا يزال فارغاً، استخدم اسم المستخدم
            if (fetchedName.trim().isEmpty) {
              fetchedName = username;
            }
            
            await prefs.setString('teacher_name', fetchedName);
            
            // ✅ التعديل الثاني: سحب teacher_id بشكل مباشر بناءً على استجابة السيرفر
            if (profileData['role'] == 'teacher' && profileData['teacher_id'] != null) {
              await prefs.setInt('teacher_id', profileData['teacher_id']);
            }
          }
        } catch (e) {
          print('⚠️ تم تسجيل الدخول لكن فشل جلب البروفايل: $e');
        }

        return true; 
      }
      return false;
    } on DioException catch (e) {
      print('❌ خطأ في تسجيل الدخول: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      print('❌ خطأ غير متوقع: $e');
      return false;
    }
  }
}