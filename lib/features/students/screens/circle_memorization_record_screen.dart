import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/features/students/models/surahs_data.dart';
import 'package:dio/dio.dart';

class CircleMemorizationRecordScreen extends StatefulWidget {
  final int circleId;
  final String circleName;

  const CircleMemorizationRecordScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
  }) : super(key: key);

  @override
  State<CircleMemorizationRecordScreen> createState() => _CircleMemorizationRecordScreenState();
}

class _CircleMemorizationRecordScreenState extends State<CircleMemorizationRecordScreen> {
  final Dio _dio = ApiClient().dio;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _loadMoreFailed = false;
  int _nextPage = 2;
  String? _nextUrl;
  List<dynamic> _records = [];
  String _selectedDate = '';
  String _searchQuery = '';
  String _surahFilter = ''; // '' = الكل
  String _resultFilter = ''; // '' = الكل

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
    if (maxExtent <= 0) return;
    if (_scrollController.position.pixels >= maxExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) _loadMoreRecords();
    }
  }

  /// استخراج رقم الصفحة من رابط next
  int? _extractNextPage(dynamic nextUrl) {
    if (nextUrl == null) return null;
    try {
      final uri = Uri.parse(nextUrl.toString());
      final pageParam = uri.queryParameters['page'];
      if (pageParam != null) return int.tryParse(pageParam);
    } catch (_) {}
    return null;
  }

  /// تحويل رابط next المطلق إلى مسار نسبي
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
      String url;
      if (_nextUrl != null && _nextUrl!.isNotEmpty) {
        url = _toRelativeUrl(_nextUrl!);
      } else {
        url = '/api/memorizations/?circle=${widget.circleId}&page=$_nextPage';
      }

      final response = await _dio.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final List<dynamic> results = data['results'] ?? [];
          final nextUrl = data['next'];
          _nextUrl = nextUrl?.toString();
          _hasMore = _nextUrl != null;
          _nextPage = _extractNextPage(nextUrl) ?? (_nextPage + 1);
          if (results.isNotEmpty) {
            // تحويل صريح عنصر بعنصر لتفادي مشاكل الأنواع مع addAll
            for (final r in results) {
              if (r is Map) _records.add(Map<String, dynamic>.from(r));
            }
          } else if (_hasMore) {
            _hasMore = false;
          }
        } else {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404) {
        _hasMore = false; // نهاية البيانات
      } else {
        _loadMoreFailed = true;
        print('⚠️ فشل تحميل الصفحة التالية (حفظ) [$code]: ${e.message}');
      }
    } catch (e) {
      _loadMoreFailed = true;
      print('⚠️ فشل تحميل الصفحة التالية (حفظ): $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// قائمة السور المتوفرة في السجلات (للفلتر)
  List<String> get _availableSurahs {
    final set = <String>{};
    for (final r in _records) {
      final s = (r['surah_name'] ?? r['surah'] ?? '').toString();
      if (s.isNotEmpty) set.add(s);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  /// السجلات بعد تطبيق الفلاتر محلياً
  List<Map<String, dynamic>> get _filteredRecords {
    return _records.where((r) {
      final rec = r as Map<String, dynamic>;
      // فلتر الاسم
      if (_searchQuery.isNotEmpty) {
        final name = (rec['student_name'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery)) return false;
      }
      // فلتر السورة
      if (_surahFilter.isNotEmpty) {
        final s = (rec['surah_name'] ?? rec['surah'] ?? '').toString();
        if (!s.contains(_surahFilter)) return false;
      }
      // فلتر النتيجة
      if (_resultFilter.isNotEmpty && rec['result'] != _resultFilter) return false;
      return true;
    }).map((r) => r as Map<String, dynamic>).toList();
  }

  Future<void> _fetchRecords() async {
    setState(() { _isLoading = true; _nextPage = 2; _nextUrl = null; _hasMore = true; _loadMoreFailed = false; });
    // 1. جلب الصفحة الأولى من سجلات الحفظ للحلقة مع معلومات الـ pagination
    List<dynamic> apiRecords = [];
    String cacheKey = 'cache_memo_record_circle_${widget.circleId}';
    try {
      final response = await _dio.get('/api/memorizations/?circle=${widget.circleId}')
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final respData = response.data;
        if (respData is Map) {
          apiRecords = respData['results'] ?? [];
          final nextUrl = respData['next'];
          _nextUrl = nextUrl?.toString();
          _hasMore = _nextUrl != null;
          _nextPage = _extractNextPage(nextUrl) ?? 2;
        } else {
          apiRecords = respData ?? [];
          _hasMore = false;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(apiRecords));
      }
    } catch (_) {
      _hasMore = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          apiRecords = jsonDecode(cached);
        }
      } catch (_) {}
    }

    // 2. فلترة حسب التاريخ محلياً (بدون الاعتماد على API)
    if (_selectedDate.isNotEmpty) {
      apiRecords = apiRecords.where((r) {
        final rDate = r['date']?.toString().split(' ')[0] ?? '';
        return rDate == _selectedDate;
      }).toList();
    }

    // 3. جلب السجلات المعلقة من قاعدة البيانات المحلية
    List<Map<String, dynamic>> pending = [];
    try {
      pending = await DatabaseHelper.instance.queryWhere(
        'pending_memorizations',
        'sync_status != ?',
        ['synced'],
      );
    } catch (_) {}

    // 4. تحويل المعلقة إلى تنسيق موحد + فلترة حسب التاريخ محلياً
    final pendingRecords = <Map<String, dynamic>>[];
    for (final p in pending) {
      // فلترة حسب التاريخ محلياً
      if (_selectedDate.isNotEmpty) {
        final pDate = p['date']?.toString().split(' ')[0] ?? '';
        if (pDate != _selectedDate) continue;
      }
      String studentName = 'طالب #${p['enrollment_id']}';
      try {
        final cached = await DatabaseHelper.instance.queryWhere(
          'cached_students',
          'enrollment_id = ?',
          [p['enrollment_id']],
        );
        if (cached.isNotEmpty) {
          studentName = cached.first['name'] as String? ?? studentName;
        }
      } catch (_) {}
      pendingRecords.add({
        'id': p['id'],
        'enrollment': p['enrollment_id'],
        'student_name': studentName,
        'surah_name': p['surah_name'] ?? 'سورة رقم ${p['surah_id']}',
        'surah': p['surah_id'],
        'from_ayah': p['from_ayah'],
        'to_ayah': p['to_ayah'],
        'type': p['type'],
        'result': p['result'],
        'notes': p['notes'] ?? '',
        'date': p['date'],
        'is_local': true,
        'sync_status': p['sync_status'],
        'last_error': p['last_error'],
      });
    }

    // 4. دمج بدون تكرار
    final merged = <Map<String, dynamic>>[...pendingRecords];
    for (final r in apiRecords) {
      merged.add({...r as Map<String, dynamic>, 'is_local': false, 'sync_status': 'synced'});
    }

    if (mounted) setState(() { _records = merged; _isLoading = false; });
  }

  Future<bool> _isOnline() async {
    try { await _dio.get('/api/quran-parts/'); return true; } catch (_) { return false; }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final isLocal = record['is_local'] == true;
    final isFailed = record['sync_status'] == 'failed';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: Text('سيتم حذف سجل حفظ "${record['student_name']}" — ${record['surah_name']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final id = record['id'];

    setState(() => _isLoading = true);

    if (isLocal) {
      await DatabaseHelper.instance.delete('pending_memorizations', 'id = ?', [id]);
      await refreshPendingCount();
      if (mounted) CustomSnackbar.show(context, message: 'تم الحذف ✅', color: Colors.green, icon: Icons.check_circle);
      _fetchRecords();
      return;
    }

    final online = await _isOnline();
    if (online) {
      try {
        await _dio.delete('/api/memorizations/$id/');
        if (mounted) CustomSnackbar.show(context, message: 'تم الحذف مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
      } catch (e) {
        await DatabaseHelper.instance.insert('pending_memorizations', {
          'enrollment_id': record['enrollment'], 'surah_id': record['surah'], 'surah_name': record['surah_name'],
          'from_ayah': record['from_ayah'], 'to_ayah': record['to_ayah'], 'type': record['type'],
          'result': record['result'], 'date': record['date'], 'action': 'delete',
          'server_id': id, 'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) CustomSnackbar.show(context, message: 'حفظ الحذف محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
      }
    } else {
      await DatabaseHelper.instance.insert('pending_memorizations', {
        'enrollment_id': record['enrollment'], 'surah_id': record['surah'], 'surah_name': record['surah_name'],
        'from_ayah': record['from_ayah'], 'to_ayah': record['to_ayah'], 'type': record['type'],
        'result': record['result'], 'date': record['date'], 'action': 'delete',
        'server_id': id, 'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) CustomSnackbar.show(context, message: 'حفظ الحذف محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
    }
    _fetchRecords();
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    final isLocal = record['is_local'] == true;
    if (isLocal) {
      // تعديل سجل معلق — نفتح صفحة تعديل تحفظ في جدول الانتظار
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _EditPendingMemorizationPage(record: record),
        ),
      );
      if (saved == true) _fetchRecords();
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditMemorizationPage(record: record),
      ),
    );
    if (saved == true) _fetchRecords();
  }

  // دوال مساعدة للتعديل
  Widget _buildAyahEdit(String label, int min, int max, int value, void Function(int) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: DropdownButtonHideUnderline(child: DropdownButton<int>(
          isExpanded: true, value: value.clamp(min, max),
          items: List.generate(max - min + 1, (i) => DropdownMenuItem(value: min + i,
            child: Text('الآية ${min + i}', style: const TextStyle(fontWeight: FontWeight.bold)))),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      ),
    ]);
  }

  Widget _editChip(String label, String value, String current, void Function(String) onChanged) {
    final sel = current == value;
    return Expanded(child: GestureDetector(
      onTap: () => onChanged(value),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? Colors.green.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? Colors.green : Colors.grey.shade300, width: sel ? 2 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.green : Colors.grey)),
        ]),
      ),
    ));
  }

  Color _colorFor(String r) => switch (r) { 'excellent' => const Color(0xFFD4AF37), 'good' => Colors.green, _ => Colors.orange };
  IconData _iconFor(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _labelFor(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null) { setState(() => _selectedDate = picked.toIso8601String().split('T')[0]); _fetchRecords(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سجل حفظ: ${widget.circleName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_selectedDate.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { setState(() => _selectedDate = ''); _fetchRecords(); }),
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
      child: Column(children: [
        Row(children: [
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
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_selectedDate.isEmpty ? 'الكل' : _selectedDate, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _selectedDate.isEmpty ? Colors.grey.shade700 : AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Text('السورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _surahFilter.isEmpty ? null : _surahFilter,
              hint: const Text('الكل', style: TextStyle(fontSize: 12)),
              isDense: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: _availableSurahs.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _surahFilter = v ?? ''),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _resultFilter.isEmpty ? null : _resultFilter,
              hint: const Text('كل النتائج', style: TextStyle(fontSize: 12)),
              isDense: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 'excellent', child: Text('ممتاز', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'good', child: Text('جيد', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'redo', child: Text('إعادة', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) => setState(() => _resultFilter = v ?? ''),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final isLocal = record['is_local'] == true;
    final isFailed = record['sync_status'] == 'failed';
    Color rc; String rt;
    switch (record['result']) {
      case 'excellent': rc = Colors.green; rt = 'ممتاز'; break;
      case 'good': rc = Colors.orange; rt = 'جيد'; break;
      case 'redo': rc = Colors.red; rt = 'إعادة'; break;
      default: rc = Colors.grey; rt = 'غير محدد';
    }
    final tt = record['type'] == 'new' ? 'حفظ جديد' : 'مراجعة';

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
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLocal ? BorderSide(color: Colors.blue.shade200) : BorderSide(color: rc.withOpacity(0.3), width: 1),
      ),
      elevation: isLocal ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(record['student_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
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
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(rt, style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            // زر القائمة
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
          ]),
          if (isFailed && record['last_error'] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(record['last_error'] as String, style: TextStyle(color: Colors.red.shade700, fontSize: 10)),
            ),
          const Divider(height: 16),
          Row(children: [
            Icon(Icons.menu_book, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text('سورة ${record['surah_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Text('الآيات: ${record['from_ayah']} - ${record['to_ayah']}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(tt, style: const TextStyle(color: Colors.blue, fontSize: 11)),
            ),
            Text(record['date'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ]),
          // الملاحظة إن وُجدت
          if ((record['notes'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notes, size: 14, color: Colors.amber.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(record['notes'].toString().trim(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(_selectedDate.isEmpty ? 'لا توجد سجلات حفظ لهذه الحلقة' : 'لا توجد سجلات في هذا التاريخ',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
    ]));
  }
}

// صفحة تعديل حفظ كاملة (بدلاً من BottomSheet لتجنب Crash)
class _EditMemorizationPage extends StatefulWidget {
  final Map<String, dynamic> record;
  const _EditMemorizationPage({required this.record});
  @override State<_EditMemorizationPage> createState() => _EditMemorizationPageState();
}

class _EditMemorizationPageState extends State<_EditMemorizationPage> {
  late Surah _surah;
  late int _fromAyah;
  late int _toAyah;
  late String _type;
  late String _result;
  bool _isSaving = false;
  final _notesCtrl = TextEditingController();
  final _dio = ApiClient().dio;

  @override void initState() {
    super.initState();
    final r = widget.record;
    _surah = surahs.firstWhere((s) => s.id == (r['surah'] ?? 1), orElse: () => surahs[0]);
    _fromAyah = r['from_ayah'] ?? 1;
    _toAyah = r['to_ayah'] ?? 1;
    _type = r['type'] ?? 'new';
    _result = r['result'] ?? 'excellent';
    _notesCtrl.text = r['notes'] ?? '';
  }

  @override void dispose() { _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعديل سجل الحفظ')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('السورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value: _surah.id,
        items: surahs.map((s) => DropdownMenuItem(value: s.id,
          child: Text('${s.number}. ${s.nameAr} (${s.totalAyahs})', style: const TextStyle(fontWeight: FontWeight.bold)),
        )).toList(),
        onChanged: (v) => setState(() { _surah = surahs.firstWhere((s) => s.id == (v ?? 1)); _fromAyah = 1; _toAyah = _surah.totalAyahs; }),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_stories), isDense: true),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _ayahField('من', 1, _surah.totalAyahs, _fromAyah, (v) { setState(() { _fromAyah = v; if (_fromAyah > _toAyah) _toAyah = _fromAyah; }); })),
        const SizedBox(width: 12),
        Expanded(child: _ayahField('إلى', _fromAyah, _surah.totalAyahs, _toAyah, (v) => setState(() => _toAyah = v))),
      ]),
      const SizedBox(height: 16),
      const Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _chip('⭐ جديد', _type == 'new', () => setState(() => _type = 'new'))),
        const SizedBox(width: 12),
        Expanded(child: _chip('📖 مراجعة', _type == 'review', () => setState(() => _type = 'review'))),
      ]),
      const SizedBox(height: 16),
      const Text('النتيجة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: ['excellent', 'good', 'redo'].map((r) {
        final sel = _result == r;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _result = r),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 14), margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: sel ? _color(r).withOpacity(0.15) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? _color(r) : Colors.grey.shade300, width: 2),
            ),
            child: Column(children: [
              Icon(_icon(r), color: sel ? _color(r) : Colors.grey, size: 28),
              const SizedBox(height: 4),
              Text(_label(r), style: TextStyle(fontWeight: FontWeight.bold, color: sel ? _color(r) : Colors.grey)),
            ]),
          ),
        ));
      }).toList()),
      const SizedBox(height: 16),
      TextField(controller: _notesCtrl, maxLines: 3, textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'ملاحظات...', prefixIcon: Icon(Icons.notes))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديل'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]),
  );

  Widget _ayahField(String label, int min, int max, int value, void Function(int) onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 6),
    Container(padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: value.clamp(min, max),
        items: List.generate(max - min + 1, (i) => DropdownMenuItem(value: min + i, child: Text('الآية ${min + i}', style: const TextStyle(fontWeight: FontWeight.bold)))),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? Colors.green.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? Colors.green : Colors.grey.shade300, width: selected ? 2 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.green : Colors.grey)),
      ]),
    ),
  );

  Color _color(String r) => switch (r) { 'excellent' => const Color(0xFFD4AF37), 'good' => Colors.green, _ => Colors.orange };
  IconData _icon(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _label(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final r = widget.record;
      final id = r['id'];
      final notes = _notesCtrl.text;
      final online = await _isOnline();

      if (online) {
        try {
          await _dio.patch('/api/memorizations/$id/', data: {
            'surah': _surah.id, 'from_ayah': _fromAyah, 'to_ayah': _toAyah,
            'type': _type, 'result': _result, 'notes': notes,
          });
          if (mounted) {
            CustomSnackbar.show(context, message: 'تم التعديل مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
            Navigator.pop(context, true);
          }
        } catch (e) {
          await _saveLocal(id, r, notes, 'update');
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        await _saveLocal(id, r, notes, 'update');
        if (mounted) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveLocal(int id, Map<String, dynamic> r, String notes, String action) async {
    await DatabaseHelper.instance.insert('pending_memorizations', {
      'enrollment_id': r['enrollment'], 'surah_id': _surah.id, 'surah_name': _surah.nameAr,
      'from_ayah': _fromAyah, 'to_ayah': _toAyah, 'type': _type, 'result': _result,
      'date': r['date'], 'notes': notes, 'action': action,
      'server_id': id, 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> _isOnline() async {
    try { await _dio.get('/api/quran-parts/'); return true; } catch (_) { return false; }
  }
}

// صفحة تعديل حفظ معلق (تحفظ في جدول الانتظار بدلاً من API)
class _EditPendingMemorizationPage extends StatefulWidget {
  final Map<String, dynamic> record;
  const _EditPendingMemorizationPage({required this.record});
  @override State<_EditPendingMemorizationPage> createState() => _EditPendingMemorizationPageState();
}

class _EditPendingMemorizationPageState extends State<_EditPendingMemorizationPage> {
  late Surah _surah;
  late int _fromAyah;
  late int _toAyah;
  late String _type;
  late String _result;
  final _notesCtrl = TextEditingController();

  @override void initState() {
    super.initState();
    final r = widget.record;
    _surah = surahs.firstWhere((s) => s.id == (r['surah'] ?? 1), orElse: () => surahs[0]);
    _fromAyah = r['from_ayah'] ?? 1;
    _toAyah = r['to_ayah'] ?? 1;
    _type = r['type'] ?? 'new';
    _result = r['result'] ?? 'excellent';
    _notesCtrl.text = r['notes'] ?? '';
  }

  @override void dispose() { _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعديل سجل الحفظ المعلق')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('السورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value: _surah.id,
        items: surahs.map((s) => DropdownMenuItem(value: s.id,
          child: Text('${s.number}. ${s.nameAr} (${s.totalAyahs})', style: const TextStyle(fontWeight: FontWeight.bold)),
        )).toList(),
        onChanged: (v) => setState(() { _surah = surahs.firstWhere((s) => s.id == (v ?? 1)); _fromAyah = 1; _toAyah = _surah.totalAyahs; }),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_stories), isDense: true),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _ayahField('من', 1, _surah.totalAyahs, _fromAyah, (v) { setState(() { _fromAyah = v; if (_fromAyah > _toAyah) _toAyah = _fromAyah; }); })),
        const SizedBox(width: 12),
        Expanded(child: _ayahField('إلى', _fromAyah, _surah.totalAyahs, _toAyah, (v) => setState(() => _toAyah = v))),
      ]),
      const SizedBox(height: 16),
      const Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _chip('⭐ جديد', _type == 'new', () => setState(() => _type = 'new'))),
        const SizedBox(width: 12),
        Expanded(child: _chip('📖 مراجعة', _type == 'review', () => setState(() => _type = 'review'))),
      ]),
      const SizedBox(height: 16),
      const Text('النتيجة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      Row(children: ['excellent', 'good', 'redo'].map((r) {
        final sel = _result == r;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _result = r),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 14), margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: sel ? _rCol(r).withOpacity(0.15) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? _rCol(r) : Colors.grey.shade300, width: 2),
            ),
            child: Column(children: [
              Icon(_rIco(r), color: sel ? _rCol(r) : Colors.grey, size: 28),
              const SizedBox(height: 4),
              Text(_rLab(r), style: TextStyle(fontWeight: FontWeight.bold, color: sel ? _rCol(r) : Colors.grey)),
            ]),
          ),
        ));
      }).toList()),
      const SizedBox(height: 16),
      TextField(controller: _notesCtrl, maxLines: 3, textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'ملاحظات...', prefixIcon: Icon(Icons.notes))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check), label: const Text('حفظ التعديل'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]),
  );

  Widget _ayahField(String label, int min, int max, int value, void Function(int) onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    const SizedBox(height: 6),
    Container(padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: value.clamp(min, max),
        items: List.generate(max - min + 1, (i) => DropdownMenuItem(value: min + i, child: Text('الآية ${min + i}', style: const TextStyle(fontWeight: FontWeight.bold)))),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? Colors.green.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? Colors.green : Colors.grey.shade300, width: selected ? 2 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.green : Colors.grey)),
      ]),
    ),
  );

  Color _rCol(String r) => switch (r) { 'excellent' => const Color(0xFFD4AF37), 'good' => Colors.green, _ => Colors.orange };
  IconData _rIco(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _rLab(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };

  Future<void> _save() async {
    final r = widget.record;
    final localId = r['id'];
    try {
      await DatabaseHelper.instance.update(
        'pending_memorizations',
        {
          'surah_id': _surah.id,
          'surah_name': _surah.nameAr,
          'from_ayah': _fromAyah,
          'to_ayah': _toAyah,
          'type': _type,
          'result': _result,
          'notes': _notesCtrl.text,
          'action': 'update',
        },
        'id = ?',
        [localId],
      );
      await refreshPendingCount();
      if (mounted) {
        CustomSnackbar.show(context, message: 'تم التعديل ✅', color: Colors.green, icon: Icons.check_circle);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, message: 'فشل التعديل', color: Colors.red, icon: Icons.error);
      }
    }
  }
}
