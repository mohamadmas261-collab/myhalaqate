import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';

class PendingItem {
  final int localId;
  final String entityType;
  final Map<String, dynamic> data;
  final String syncStatus;
  final int retryCount;
  final String? lastError;
  final String createdAt;
  final String date;
  final String studentName;
  final String circleName;
  final String courseName;

  PendingItem({
    required this.localId,
    required this.entityType,
    required this.data,
    required this.syncStatus,
    required this.retryCount,
    this.lastError,
    required this.createdAt,
    this.date = '',
    this.studentName = '',
    this.circleName = '',
    this.courseName = '',
  });

  String get displayName {
    switch (entityType) {
      case 'attendance':
        return 'حضور/غياب';
      case 'memorization':
        return 'تسجيل حفظ';
      case 'quiz_request':
        return 'طلب سبر';
      default:
        return entityType;
    }
  }

  String get actionLabel {
    final a = data['action'] as String? ?? 'create';
    switch (a) {
      case 'create': return 'إضافة';
      case 'update': return 'تعديل';
      case 'delete': return 'حذف';
      default: return a;
    }
  }

  String get statusText {
    final s = data['status'] as String? ?? '';
    final m = {'present': 'حاضر', 'absent': 'غائب', 'excused': 'مستأذن'};
    return m[s] ?? s;
  }

  String get resultText {
    final r = data['result'] as String? ?? '';
    final m = {'excellent': 'ممتاز', 'good': 'جيد', 'redo': 'إعادة'};
    return m[r] ?? r;
  }

  String get typeText {
    final t = data['type'] as String?;
    if (t == 'new') return 'حفظ جديد';
    return 'مراجعة';
  }

  String get quizTypeText {
    final t = data['quiz_type'] as String?;
    if (t == 'new') return 'جديد';
    return 'مراجعة';
  }
}

class PendingService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // جلب جميع العناصر المعلقة (pending, sending, failed) + المتزامنة حديثاً (synced)
  Future<List<PendingItem>> getAllPending({String sortBy = 'date_desc', bool includeSynced = false}) async {
    final items = <PendingItem>[];

    // 1. attendance
    String attWhere = includeSynced
        ? 'sync_status != ?'
        : 'sync_status = ? OR sync_status = ? OR sync_status = ?';
    List<dynamic> attArgs = includeSynced ? ['deleted'] : ['pending', 'sending', 'failed'];
    final attRows = await _db.queryWhere('pending_attendance', attWhere, attArgs);
    for (final r in attRows) {
      final info = await _enrich(r['enrollment_id'] as int? ?? 0);
      items.add(PendingItem(
        localId: r['id'] as int,
        entityType: 'attendance',
        data: Map<String, dynamic>.from(r),
        syncStatus: r['sync_status'] as String? ?? 'pending',
        retryCount: r['retry_count'] as int? ?? 0,
        lastError: r['last_error'] as String?,
        createdAt: (r['created_at'] as String?) ?? '',
        date: (r['date'] as String?) ?? '',
        studentName: info['student_name'] ?? 'طالب',
        circleName: info['circle_name'] ?? '',
        courseName: info['course_name'] ?? '',
      ));
    }

    // 2. memorizations
    String memWhere = includeSynced
        ? 'sync_status != ?'
        : 'sync_status = ? OR sync_status = ? OR sync_status = ?';
    List<dynamic> memArgs = includeSynced ? ['deleted'] : ['pending', 'sending', 'failed'];
    final memRows = await _db.queryWhere('pending_memorizations', memWhere, memArgs);
    for (final r in memRows) {
      final info = await _enrich(r['enrollment_id'] as int? ?? 0);
      items.add(PendingItem(
        localId: r['id'] as int,
        entityType: 'memorization',
        data: Map<String, dynamic>.from(r),
        syncStatus: r['sync_status'] as String? ?? 'pending',
        retryCount: r['retry_count'] as int? ?? 0,
        lastError: r['last_error'] as String?,
        createdAt: (r['created_at'] as String?) ?? '',
        date: (r['date'] as String?) ?? '',
        studentName: info['student_name'] ?? 'طالب',
        circleName: info['circle_name'] ?? '',
        courseName: info['course_name'] ?? '',
      ));
    }

    // 3. quiz requests
    String quizWhere = includeSynced
        ? 'sync_status != ?'
        : 'sync_status = ? OR sync_status = ? OR sync_status = ?';
    List<dynamic> quizArgs = includeSynced ? ['deleted'] : ['pending', 'sending', 'failed'];
    final quizRows = await _db.queryWhere('pending_quiz_requests', quizWhere, quizArgs);
    for (final r in quizRows) {
      final info = await _enrich(r['enrollment_id'] as int? ?? 0);
      items.add(PendingItem(
        localId: r['id'] as int,
        entityType: 'quiz_request',
        data: Map<String, dynamic>.from(r),
        syncStatus: r['sync_status'] as String? ?? 'pending',
        retryCount: r['retry_count'] as int? ?? 0,
        lastError: r['last_error'] as String?,
        createdAt: (r['created_at'] as String?) ?? '',
        date: (r['created_at'] as String?) ?? '',
        studentName: info['student_name'] ?? 'طالب',
        circleName: info['circle_name'] ?? '',
        courseName: info['course_name'] ?? '',
      ));
    }

    // ترتيب
    _sortItems(items, sortBy);
    return items;
  }

  void _sortItems(List<PendingItem> items, String sortBy) {
    switch (sortBy) {
      case 'date_desc':
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'date_asc':
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'type':
        items.sort((a, b) => a.entityType.compareTo(b.entityType));
        break;
      case 'status':
        items.sort((a, b) => a.syncStatus.compareTo(b.syncStatus));
        break;
      default:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  // إثراء بيانات الطالب والحلقة والدورة من cached_students و SharedPreferences
  Future<Map<String, String>> _enrich(int enrollmentId) async {
    final result = <String, String>{'student_name': '', 'circle_name': '', 'course_name': ''};
    try {
      final cached = await _db.queryWhere('cached_students', 'enrollment_id = ?', [enrollmentId]);
      if (cached.isNotEmpty) {
        final c = cached.first;
        result['student_name'] = (c['name'] as String?) ?? '';
        result['circle_name'] = (c['circle_name'] as String?) ?? '';
        final courseId = c['course_id'] as int? ?? 0;
        if (courseId > 0) {
          result['course_name'] = await _getCourseName(courseId);
        }
      }
    } catch (_) {}
    return result;
  }

  Future<String> _getCourseName(int courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_courses');
      if (cached != null) {
        final List<dynamic> courses = jsonDecode(cached);
        for (final c in courses) {
          if (c['id'] == courseId) return c['title'] as String? ?? 'دورة $courseId';
        }
      }
    } catch (_) {}
    return 'دورة $courseId';
  }

  Future<int> countPending() async {
    int total = 0;
    for (final table in ['pending_attendance', 'pending_memorizations', 'pending_quiz_requests']) {
      final items = await _db.queryWhere(table, 'sync_status = ? OR sync_status = ? OR sync_status = ?', ['pending', 'sending', 'failed']);
      total += items.length;
    }
    return total;
  }

  Future<bool> deleteItem(int localId, String entityType) async {
    try {
      await _db.delete(_tableFor(entityType), 'id = ?', [localId]);
      final count = await countPending();
      pendingCountNotifier.value = count;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> deleteItems(List<int> localIds, String entityType) async {
    if (localIds.isEmpty) return 0;
    try {
      final placeholders = localIds.map((_) => '?').join(',');
      await _db.delete(_tableFor(entityType), 'id IN ($placeholders)', localIds);
      final count = await countPending();
      pendingCountNotifier.value = count;
      return localIds.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> retryItem(int localId, String entityType) async {
    try {
      await _db.update(
        _tableFor(entityType),
        {'sync_status': 'pending', 'retry_count': 0, 'last_error': null},
        'id = ?',
        [localId],
      );
      SyncManager.instance.syncAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateAttendance(int localId, String newStatus) async {
    try {
      await _db.update('pending_attendance', {'status': newStatus, 'action': 'update'}, 'id = ?', [localId]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMemorization(int localId, Map<String, dynamic> data) async {
    try {
      data['action'] = 'update';
      await _db.update('pending_memorizations', data, 'id = ?', [localId]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateQuizRequest(int localId, Map<String, dynamic> data) async {
    try {
      data['action'] = 'update';
      await _db.update('pending_quiz_requests', data, 'id = ?', [localId]);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _tableFor(String entityType) {
    switch (entityType) {
      case 'attendance': return 'pending_attendance';
      case 'memorization': return 'pending_memorizations';
      case 'quiz_request': return 'pending_quiz_requests';
      default: return '';
    }
  }
}
