import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  late final Dio dio;
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:8000';

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('access_token');

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // إذا كان الخطأ 401 (غير مصرح)
        if (e.response?.statusCode == 401) {
          print('🚨 التوكن منتهي الصلاحية! جاري محاولة التجديد...');
          
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');

          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              // نستخدم نسخة Dio جديدة هنا عشان ما ندخل بدوامة (Infinite Loop) مع الـ Interceptor الحالي
              final refreshDio = Dio();
              final refreshResponse = await refreshDio.post(
                '${baseUrl}/api/token/refresh/',
                data: {'refresh': refreshToken},
              );

              if (refreshResponse.statusCode == 200) {
                // استلمنا توكن جديد، نحفظه!
                final newAccessToken = refreshResponse.data['access'];
                await prefs.setString('access_token', newAccessToken);

                print('✅ تم تجديد التوكن بنجاح! جاري إعادة إرسال الطلب...');

                // نحدث الـ Header للطلب الأصلي اللي فشل بالتوكن الجديد
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                // نعيد إرسال الطلب الأصلي
                final opts = Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                );
                
                final cloneReq = await dio.request(
                  e.requestOptions.path,
                  options: opts,
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                );

                // نرجع النتيجة وكأن الطلب الأول ما فشل أبداً
                return handler.resolve(cloneReq);
              }
            } catch (refreshError) {
              print('❌ فشل تجديد التوكن، يجب تسجيل الدخول من جديد: $refreshError');
              // هنا ممكن تمسح التوكنات وتجبر المستخدم يسجل دخول
              await prefs.remove('access_token');
              await prefs.remove('refresh_token');
            }
          } else {
             // ما في refresh_token من الأساس
             await prefs.remove('access_token');
          }
        }
        
        // إذا مشكلة ثانية أو فشل التجديد، نمرر الخطأ كما هو
        return handler.next(e);
      },
    ));
  }
}