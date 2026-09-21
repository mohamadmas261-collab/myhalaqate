import 'package:dio/dio.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/features/students/models/student_model.dart';

class StudentService {
  final Dio _dio = ApiClient().dio;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<dynamic>> getStudentsByCircle(int circleId) async {
    try {
      // 1. محاولة جلب الطلاب من السيرفر
      final response = await _dio.get('/api/enrollments/?circle=$circleId');
      if (response.statusCode == 200) {
        final List<dynamic> students = response.data['results'] ?? [];
        
        // 2. تحديث الكاش المحلي: مسح القديم للحلقة وإضافة الجديد
        await _db.delete('cached_students', 'circle_id = ?', [circleId]);
        for (var s in students) {
          await _db.insert('cached_students', {
            'enrollment_id': s['id'],
            'name': s['student_name'] ?? 'بدون اسم',
            'circle_id': circleId,
            'course_id': s['course_id'] ?? 0,
            'circle_name': s['circle_name'] ?? '',
            'status': s['status'] ?? 'active'
          });
        }
        return students;
      }
    } catch (e) {
      print('⚠️ لا يوجد اتصال، سيتم عرض الطلاب من قاعدة البيانات المحلية: $e');
    }

    // 3. في حال انقطاع الإنترنت، جلب البيانات من SQLite
    final cached = await _db.queryWhere('cached_students', 'circle_id = ?', [circleId]);
    return cached.map((c) => {
      'id': c['enrollment_id'],
      'student_name': c['name'],
      'course_id': c['course_id'],
      'circle_name': c['circle_name'],
      'status': c['status'],
      'total_points': c['total_points'] ?? 0,
      'attendance_count': c['attendance_count'] ?? 0,
      'total_sessions': c['total_sessions'] ?? 0,
    }).toList();
  }

  Future<List<dynamic>> searchStudents(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _dio.get('/api/students/?search=${Uri.encodeComponent(query)}');
      if (response.statusCode == 200) {
        return response.data['results'] ?? [];
      }
      return [];
    } catch (e) {
      print('🚨 خطأ في البحث عن الطلاب: $e');
      final cached = await _db.queryAll('cached_students');
      return cached
          .where((s) => (s['name'] as String).contains(query))
          .map((c) => {
                'id': c['enrollment_id'],
                'student_name': c['name'],
                'course_id': c['course_id'],
                'status': c['status'],
              })
          .toList();
    }
  }

  Future<List<Student>> getMyStudents() async {
    try {
      final response = await _dio.get('/api/students');
      if (response.statusCode == 200) {
        List data = response.data['results'];
        return data.map((json) => Student.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('🚨 خطأ في جلب الطلاب: $e');
      return [];
    }
  }

  Future<Student?> getStudentById(int studentId) async {
    try {
      final response = await _dio.get('/api/students/$studentId');
      if (response.statusCode == 200) {
        return Student.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('🚨 خطأ في جلب تفاصيل الطالب: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getEnrollmentDetails(int enrollmentId) async {
    try {
      final response = await _dio.get('/api/enrollments/$enrollmentId/');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('🚨 خطأ في جلب تفاصيل التسجيل: $e');
      return null;
    }
  }
}