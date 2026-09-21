import 'package:flutter/material.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/api_client.dart';
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
  bool _isLoading = true;
  List<dynamic> _records = [];
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      String url = '/api/memorizations/?circle=${widget.circleId}';
      if (_selectedDate.isNotEmpty) url += '&date=$_selectedDate';
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        if (mounted) setState(() { _records = response.data['results'] ?? []; _isLoading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<bool> _isOnline() async {
    try { await _dio.get('/api/quran-parts/'); return true; } catch (_) { return false; }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
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
    final online = await _isOnline();
    if (online) {
      try {
        await _dio.delete('/api/memorizations/$id/');
        CustomSnackbar.show(context, message: 'تم الحذف مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
      } catch (e) {
        await DatabaseHelper.instance.insert('pending_memorizations', {
          'enrollment_id': record['enrollment'], 'surah_id': record['surah'], 'surah_name': record['surah_name'],
          'from_ayah': record['from_ayah'], 'to_ayah': record['to_ayah'], 'type': record['type'],
          'result': record['result'], 'date': record['date'], 'action': 'delete',
          'server_id': id, 'created_at': DateTime.now().toIso8601String(),
        });
        CustomSnackbar.show(context, message: 'حفظ الحذف محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
      }
    } else {
      await DatabaseHelper.instance.insert('pending_memorizations', {
        'enrollment_id': record['enrollment'], 'surah_id': record['surah'], 'surah_name': record['surah_name'],
        'from_ayah': record['from_ayah'], 'to_ayah': record['to_ayah'], 'type': record['type'],
        'result': record['result'], 'date': record['date'], 'action': 'delete',
        'server_id': id, 'created_at': DateTime.now().toIso8601String(),
      });
      CustomSnackbar.show(context, message: 'حفظ الحذف محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
    }
    _fetchRecords();
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('سجل حفظ: ${widget.circleName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_selectedDate.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { setState(() => _selectedDate = ''); _fetchRecords(); }),
        ],
      ),
      body: Column(
        children: [
          Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('فلترة بالتاريخ:', style: TextStyle(fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_selectedDate.isEmpty ? 'عرض الكل' : _selectedDate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _selectedDate.isEmpty ? Colors.grey.shade700 : Theme.of(context).primaryColor),
              ),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchRecords,
                    child: _records.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _records.length,
                            itemBuilder: (_, i) => _buildRecordCard(_records[i])),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    Color rc; String rt;
    switch (record['result']) {
      case 'excellent': rc = Colors.green; rt = 'ممتاز'; break;
      case 'good': rc = Colors.orange; rt = 'جيد'; break;
      case 'redo': rc = Colors.red; rt = 'إعادة'; break;
      default: rc = Colors.grey; rt = 'غير محدد';
    }
    final tt = record['type'] == 'new' ? 'حفظ جديد' : 'مراجعة';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: rc.withOpacity(0.3), width: 1)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(record['student_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(rt, style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
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

  Color _color(String r) => switch (r) { 'excellent' => const Color(0xFFD4AF37), 'good' => Colors.green, _ => Colors.orange };
  IconData _icon(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _label(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };

  Future<void> _save() async {
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
