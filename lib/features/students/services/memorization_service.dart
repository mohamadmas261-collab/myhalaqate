import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';

class MemorizationService {
  final Dio _dio = ApiClient().dio;
  final DatabaseHelper _db = DatabaseHelper.instance;

  // جلب سجل الحفظ للحلقة كاملة مع الفلترة والتخزين المؤقت
  Future<List<dynamic>> getCircleMemorizationRecord(int circleId, {int? courseId, String? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final int resolvedCourseId = courseId ?? prefs.getInt('last_course_id') ?? 0;
    String cacheKey = 'cache_memo_record_circle_$circleId';
    if (date != null) cacheKey += '_$date';

    try {
      String url = resolvedCourseId > 0
          ? '/api/memorizations/?course=$resolvedCourseId'
          : '/api/memorizations/?circle=$circleId';
      if (date != null && date.isNotEmpty) url += '&date=$date';
      
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? [];
        await prefs.setString(cacheKey, jsonEncode(data));
        return data;
      }
    } catch (e) {
      print('⚠️ تعذر الاتصال بالسيرفر، سيتم عرض سجل الحفظ للحلقة من الكاش: $e');
    }

    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return jsonDecode(cached);
    }
    return [];
  }

  // جلب سجل الحفظ لطالب معين (التي عملناها سابقاً)
  Future<List<dynamic>> getStudentMemorizations(int enrollmentId) async {
    try {
      final response = await _dio.get('/api/memorizations/?enrollment=$enrollmentId');
      if (response.statusCode == 200) {
        final List<dynamic> records = response.data['results'] ?? [];
        
        await _db.delete('cached_memorizations', 'enrollment_id = ?', [enrollmentId]);
        for (var r in records) {
          await _db.insert('cached_memorizations', {
            'enrollment_id': enrollmentId,
            'student_name': r['student_name'] ?? '',
            'surah_name': r['surah_name'] ?? r['surah']?.toString() ?? '',
            'from_ayah': r['from_ayah'],
            'to_ayah': r['to_ayah'],
            'type': r['type'],
            'result': r['result'],
            'date': r['date'] ?? r['recorded_at']?.toString().split(' ')[0] ?? '',
            'recorded_by': r['recorded_by_name'] ?? '',
          });
        }
        return records;
      }
    } catch (e) {
      print('⚠️ تعذر الاتصال بالسيرفر، سيتم عرض سجل الحفظ الفردي من الكاش: $e');
    }

    final cached = await _db.queryWhere('cached_memorizations', 'enrollment_id = ?', [enrollmentId]);
    final pending = await _db.queryWhere('pending_memorizations', 'enrollment_id = ?', [enrollmentId]);
    
    final pendingList = pending.map((p) => {
      'surah_name': p['surah_name'] ?? 'سورة رقم ${p['surah_id']}',
      'from_ayah': p['from_ayah'],
      'to_ayah': p['to_ayah'],
      'type': p['type'],
      'result': p['result'],
      'date': p['date'],
      'recorded_by_name': 'قيد المزامنة ⏳',
      'recorded_at': p['created_at'],
    }).toList();

    final cachedList = cached.map((c) => {
      'surah_name': c['surah_name'],
      'from_ayah': c['from_ayah'],
      'to_ayah': c['to_ayah'],
      'type': c['type'],
      'result': c['result'],
      'date': c['date'],
      'recorded_by_name': c['recorded_by'],
      'recorded_at': c['date'],
    }).toList();

    return [...pendingList, ...cachedList];
  }

  Future<bool> submitMemorization({
    required int enrollmentId,
    required int surahId,
    required int fromAyah,
    required int toAyah,
    required String type,
    required String result,
    required int teacherId,
  }) async {
    try {
      await _db.insert('pending_memorizations', {
        "enrollment_id": enrollmentId,
        "surah_id": surahId,
        "surah_name": "سورة رقم $surahId",
        "from_ayah": fromAyah,
        "to_ayah": toAyah,
        "type": type,
        "result": result,
        "date": DateTime.now().toIso8601String().split('T')[0],
        "created_at": DateTime.now().toIso8601String(),
      });
      
      SyncManager.instance.syncAll();
      return true;
    } catch (e) {
      print('🚨 خطأ في حفظ التسميع محلياً: $e');
      return false;
    }
  }

  // تعديل سجل حفظ معلق
  Future<bool> updatePendingMemorization(int localId, Map<String, dynamic> newData) async {
    try {
      newData['action'] = 'update';
      await _db.update(
        'pending_memorizations',
        newData,
        'id = ?',
        [localId],
      );
      return true;
    } catch (e) {
      print('🚨 خطأ في تعديل الحفظ المعلق: $e');
      return false;
    }
  }

  // حذف سجل حفظ معلق
  Future<bool> deletePendingMemorization(int localId) async {
    try {
      await _db.delete('pending_memorizations', 'id = ?', [localId]);
      return true;
    } catch (e) {
      print('🚨 خطأ في حذف الحفظ المعلق: $e');
      return false;
    }
  }

  // جلب سجلات الحفظ المعلقة لتاريخ محدد
  Future<List<Map<String, dynamic>>> getPendingMemorizations(String date) async {
    return await _db.queryWhere(
      'pending_memorizations',
      'date = ? AND sync_status != ?',
      [date, 'synced'],
    );
  }
}