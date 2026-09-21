import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/features/attendance/services/attendance_service.dart';
import 'package:dio/dio.dart';

class CircleAttendanceRecordScreen extends StatefulWidget {
  final int circleId;
  final String circleName;

  const CircleAttendanceRecordScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
  }) : super(key: key);

  @override
  State<CircleAttendanceRecordScreen> createState() => _CircleAttendanceRecordScreenState();
}

class _CircleAttendanceRecordScreenState extends State<CircleAttendanceRecordScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final Dio _dio = ApiClient().dio;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _loadMoreFailed = false; // فشل تحميل الصفحة التالية (يمكن إعادة المحاولة)
  int _nextPage = 2;
  String? _nextUrl; // رابط الصفحة التالية الكامل من السيرفر
  List<Map<String, dynamic>> _records = [];
  String _selectedDate = '';
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, present, absent, excused

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
    _fetchRecords();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return; // المحتوى لا يحتاج تمرير
    if (_scrollController.position.pixels >= maxExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) _loadMoreRecords();
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    return _records.where((r) {
      if (_searchQuery.isNotEmpty) {
        final name = (r['student_name'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery)) return false;
      }
      if (_statusFilter != 'all' && r['status'] != _statusFilter) return false;
      return true;
    }).toList();
  }

  Future<String> _buildApiUrl({int? page}) async {
    final prefs = await SharedPreferences.getInstance();
    final courseId = prefs.getInt('last_course_id') ?? 0;
    String url = courseId > 0
        ? '/api/attendance/?course=$courseId'
        : '/api/attendance/?circle=${widget.circleId}';
    if (_selectedDate.isNotEmpty) url += '&date=$_selectedDate';
    if (page != null && page > 1) url += '&page=$page';
    return url;
  }

  /// استخراج رقم الصفحة التالية من رابط next
  int? _extractNextPage(dynamic nextUrl) {
    if (nextUrl == null) return null;
    try {
      final uri = Uri.parse(nextUrl.toString());
      final pageParam = uri.queryParameters['page'];
      if (pageParam != null) return int.tryParse(pageParam);
    } catch (_) {}
    return null;
  }

  /// تحويل رابط next المطلق إلى مسار نسبي (path + query)
  String _toRelativeUrl(String absoluteUrl) {
    try {
      final uri = Uri.parse(absoluteUrl);
      final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return '${uri.path}$query';
    } catch (_) {
      return absoluteUrl;
    }
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() { _isLoadingMore = true; _loadMoreFailed = false; });
    try {
      // الأولوية: رابط next من السيرفر مباشرة (مضمون من نفس مصدر البيانات)
      String url;
      if (_nextUrl != null && _nextUrl!.isNotEmpty) {
        url = _toRelativeUrl(_nextUrl!);
      } else {
        url = await _buildApiUrl(page: _nextPage);
      }

      final response = await _dio.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final List<dynamic> results = data['results'] ?? [];
          final nextUrl = data['next'];
          // تحديث رابط الصفحة التالية من استجابة السيرفر
          _nextUrl = nextUrl?.toString();
          _hasMore = _nextUrl != null;
          _nextPage = _extractNextPage(nextUrl) ?? (_nextPage + 1);
          if (results.isNotEmpty) {
            // تحويل إلى Map<String, dynamic> لتطابق نوع القائمة
            // تحويل صريح عنصر بعنصر لتفادي مشاكل الأنواع مع addAll
            for (final r in results) {
              if (r is Map) _records.add(Map<String, dynamic>.from(r));
            }
          } else if (_hasMore) {
            // نتائج فارغة لكن السيرفر يقول يوجد المزيد → توقف لتفادي الحلقة اللانهائية
            _hasMore = false;
          }
        } else {
          // استجابة غير مقسمة → نهاية البيانات
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404) {
        // 404 = لا توجد صفحة تالية (نهاية البيانات) — الحالة الطبيعية
        _hasMore = false;
      } else {
        // خطأ شبكة/سيرفر → إتاحة إعادة المحاولة للمستخدم
        _loadMoreFailed = true;
        print('⚠️ فشل تحميل الصفحة التالية ($code): ${e.message}');
      }
    } catch (e) {
      _loadMoreFailed = true;
      print('⚠️ فشل تحميل الصفحة التالية: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _fetchRecords() async {
    setState(() { _isLoading = true; _nextPage = 2; _nextUrl = null; _hasMore = true; _loadMoreFailed = false; });

    // جلب الصفحة الأولى مباشرة للحصول على معلومات الـ pagination
    List<dynamic> data = [];
    String cacheKey = 'cache_attendance_record_circle_${widget.circleId}';
    if (_selectedDate.isNotEmpty) cacheKey += '_$_selectedDate';
    try {
      final url = await _buildApiUrl(page: 1);
      final response = await _dio.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final respData = response.data;
        if (respData is Map) {
          data = respData['results'] ?? [];
          final nextUrl = respData['next'];
          _nextUrl = nextUrl?.toString();
          _hasMore = _nextUrl != null;
          _nextPage = _extractNextPage(nextUrl) ?? 2;
        } else {
          data = respData ?? [];
          _hasMore = false;
        }
        // حفظ في الكاش لدعم العمل دون اتصال
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, jsonEncode(data));
        } catch (_) {}
      }
    } catch (_) {
      // فشل الاتصال → استخدام الكاش عبر الخدمة
      data = await _attendanceService.getCircleAttendanceRecord(
        widget.circleId,
        date: _selectedDate.isEmpty ? null : _selectedDate,
      );
      _hasMore = false;
    }

    // دمج السجلات المعلقة محلياً
    final pending = await DatabaseHelper.instance.queryWhere(
      'pending_attendance',
      'circle_id = ? AND sync_status != ?',
      [widget.circleId, 'synced'],
    );
    if (_selectedDate.isNotEmpty) {
      pending.removeWhere((p) => p['date'] != _selectedDate);
    }

    final pendingRecords = <Map<String, dynamic>>[];
    for (final p in pending) {
      String studentName = 'طالب #${p['enrollment_id']}';
      try {
        final cached = await DatabaseHelper.instance.queryWhere(
          'cached_students', 'enrollment_id = ?', [p['enrollment_id']]);
        if (cached.isNotEmpty) {
          studentName = cached.first['name'] as String? ?? studentName;
        }
      } catch (_) {}
      pendingRecords.add({
        'id': p['id'],
        'enrollment': p['enrollment_id'],
        'student_name': studentName,
        'status': p['status'],
        'date': p['date'],
        'is_local': true,
        'sync_status': p['sync_status'],
        'last_error': p['last_error'],
      });
    }

    // دمج بدون تكرار
    final merged = <Map<String, dynamic>>[...pendingRecords];
    for (final r in data) {
      merged.add({...r as Map<String, dynamic>, 'is_local': false, 'sync_status': 'synced'});
    }

    if (mounted) setState(() { _records = merged; _isLoading = false; });
  }

  Future<bool> _isOnline() async {
    try {
      await _dio.get('/api/quran-parts/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    final currentStatus = record['status'] ?? 'present';
    final labels = {'present': 'حاضر ✅', 'absent': 'غائب ❌', 'excused': 'مستأذن ⏸'};
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('تعديل حالة الحضور', style: TextStyle(fontWeight: FontWeight.bold)),
        children: ['present', 'absent', 'excused'].map((s) => RadioListTile<String>(
          title: Text(labels[s] ?? s),
          value: s, groupValue: currentStatus,
          onChanged: (v) => Navigator.pop(ctx, v),
        )).toList(),
      ),
    );
    if (chosen == null || chosen == currentStatus) return;

    setState(() => _isLoading = true);
    final recordId = record['id'];
    final online = await _isOnline();

    if (online) {
      try {
        await _dio.patch('/api/attendance/$recordId/', data: {'status': chosen});
        if (mounted) CustomSnackbar.show(context, message: 'تم التعديل مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
      } catch (e) {
        if (mounted) CustomSnackbar.show(context, message: 'فشل التعديل — حفظ في قائمة الانتظار', color: Colors.orange, icon: Icons.warning);
        await DatabaseHelper.instance.insert('pending_attendance', {
          'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
          'status': chosen, 'circle_id': widget.circleId, 'action': 'update',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } else {
      await DatabaseHelper.instance.insert('pending_attendance', {
        'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
        'status': chosen, 'circle_id': widget.circleId, 'action': 'update',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) CustomSnackbar.show(context, message: 'حفظ التعديل محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
    }
    _fetchRecords();
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: Text('سيتم حذف سجل حضور "${record['student_name']}" في ${record['date']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final recordId = record['id'];
    final online = await _isOnline();

    if (online) {
      try {
        await _dio.delete('/api/attendance/$recordId/');
        if (mounted) CustomSnackbar.show(context, message: 'تم الحذف مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
      } catch (e) {
        if (mounted) CustomSnackbar.show(context, message: 'فشل الحذف — حفظ في قائمة الانتظار', color: Colors.orange, icon: Icons.warning);
        await DatabaseHelper.instance.insert('pending_attendance', {
          'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
          'status': record['status'], 'circle_id': widget.circleId, 'action': 'delete',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } else {
      await DatabaseHelper.instance.insert('pending_attendance', {
        'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
        'status': record['status'], 'circle_id': widget.circleId, 'action': 'delete',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) CustomSnackbar.show(context, message: 'حفظ الحذف محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
    }
    _fetchRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل حضور: ${widget.circleName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_selectedDate.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              tooltip: 'إلغاء الفلتر',
              onPressed: () { setState(() => _selectedDate = ''); _fetchRecords(); },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchRecords,
                    child: _filteredRecords.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
                            itemCount: _filteredRecords.length + (_isLoadingMore || _loadMoreFailed ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _filteredRecords.length) {
                                if (_loadMoreFailed) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: OutlinedButton.icon(
                                        onPressed: _loadMoreRecords,
                                        icon: const Icon(Icons.refresh, size: 18),
                                        label: const Text('تعذر التحميل — إعادة المحاولة'),
                                      ),
                                    ),
                                  );
                                }
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
                                );
                              }
                              return _buildRecordCard(_filteredRecords[i]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن طالب...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _searchCtrl.clear)
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context, initialDate: DateTime.now(),
                    firstDate: DateTime(2020), lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked.toIso8601String().split('T')[0]);
                    _fetchRecords();
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_selectedDate.isEmpty ? 'الكل' : _selectedDate, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _selectedDate.isEmpty ? Colors.grey.shade700 : AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('الحالة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusFilterChip('الكل', 'all', Colors.grey),
                      _statusFilterChip('حاضر', 'present', Colors.green),
                      _statusFilterChip('غائب', 'absent', Colors.red),
                      _statusFilterChip('مستأذن', 'excused', Colors.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusFilterChip(String label, String value, Color color) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Text(label, style: TextStyle(
            color: selected ? color : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          )),
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final bool isLocal = record['is_local'] == true;
    final bool isFailed = record['sync_status'] == 'failed';

    Color statusColor; String statusText; IconData statusIcon;
    switch (record['status']) {
      case 'present': statusColor = Colors.green; statusText = 'حاضر'; statusIcon = Icons.check_circle; break;
      case 'absent': statusColor = Colors.red; statusText = 'غائب'; statusIcon = Icons.cancel; break;
      case 'excused': statusColor = Colors.orange; statusText = 'مستأذن'; statusIcon = Icons.pause_circle_filled; break;
      default: statusColor = Colors.grey; statusText = 'غير محدد'; statusIcon = Icons.help; break;
    }

    // حالة المزامنة
    Color syncColor; IconData syncIcon; String syncText;
    if (isLocal && isFailed) {
      syncColor = Colors.red; syncIcon = Icons.error; syncText = 'فشل الإرسال';
    } else if (isLocal) {
      syncColor = Colors.blue; syncIcon = Icons.hourglass_empty; syncText = 'بانتظار المزامنة';
    } else {
      syncColor = Colors.green; syncIcon = Icons.check_circle; syncText = 'تم الإرسال';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLocal ? BorderSide(color: Colors.blue.shade200) : BorderSide.none,
      ),
      elevation: isLocal ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Icon(statusIcon, color: statusColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(record['student_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  if (isLocal && isFailed && record['last_error'] != null)
                    Flexible(child: Text(' ${record['last_error']}', style: TextStyle(color: Colors.red.shade400, fontSize: 9))),
                ]),
                Text('التاريخ: ${record['date']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: syncColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(syncIcon, color: syncColor, size: 10),
                  const SizedBox(width: 2),
                  Text(syncText, style: TextStyle(color: syncColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'edit') _editRecord(record);
                if (v == 'delete') _deleteRecord(record);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedDate.isEmpty ? 'لا توجد سجلات حضور لهذه الحلقة' : 'لا توجد سجلات في هذا التاريخ',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
