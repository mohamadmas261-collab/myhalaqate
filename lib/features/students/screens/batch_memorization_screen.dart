import 'package:flutter/material.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';
import 'package:myhalaqat/features/students/models/surahs_data.dart';
import 'package:myhalaqat/features/circles/services/course_service.dart';
import 'package:myhalaqat/features/students/screens/circle_memorization_record_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------- BatchMemorizationScreen (الصفحة الرئيسية) ----------------------
class BatchMemorizationScreen extends StatefulWidget {
  final int circleId;
  final String circleName;
  const BatchMemorizationScreen({Key? key, required this.circleId, required this.circleName}) : super(key: key);

  @override
  State<BatchMemorizationScreen> createState() => _BatchMemorizationScreenState();
}

class _BatchMemorizationScreenState extends State<BatchMemorizationScreen> with SingleTickerProviderStateMixin {
  final StudentService _studentService = StudentService();
  final CourseService _courseService = CourseService();
  late TabController _tabController;
  bool _isLoading = true, _isSaving = false;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _sortBy = 'name';
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];

  // عداد تسجيلات الحفظ لكل طالب: Map<studentId, count>
  final Map<int, int> _studentMemCount = {};

  String get _displayDate {
    final d = DateTime.tryParse(_selectedDate);
    if (d == null) return _selectedDate;
    return '${CourseService.getArabicDayName(d)} — $_selectedDate';
  }

  @override void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); _searchCtrl.addListener(_applyFilter); _fetchStudents(); }
  @override void dispose() { _tabController.dispose(); _searchCtrl.dispose(); super.dispose(); }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() { _filteredStudents = _students.where((s) => (s['student_name'] ?? '').toLowerCase().contains(q)).toList(); _sortStudents(); });
  }

  void _sortStudents() {
    if (_sortBy == 'name') _filteredStudents.sort((a, b) => (a['student_name'] ?? '').compareTo(b['student_name'] ?? ''));
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    final data = await _studentService.getStudentsByCircle(widget.circleId);
    if (mounted) setState(() { _students = data; _filteredStudents = List.from(data); _sortStudents(); _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('حفظ — ${widget.circleName}'),
      bottom: TabBar(controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70,
        tabs: const [Tab(icon: Icon(Icons.edit_note), text: 'تسجيل'), Tab(icon: Icon(Icons.history), text: 'السجل')],
      ),
    ),
    body: TabBarView(controller: _tabController, children: [
      _buildRegisterTab(),
      CircleMemorizationRecordScreen(circleId: widget.circleId, circleName: widget.circleName),
    ]),
    bottomNavigationBar: _isLoading || _studentMemCount.isEmpty ? null : _buildBottomBar(),
  );

  Widget _buildRegisterTab() {
    final totalCount = _studentMemCount.values.fold(0, (a, b) => a + b);
    return Column(
      children: [
        _buildTopBar(),
        if (_studentMemCount.isNotEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withOpacity(0.08),
            child: Text('إجمالي $totalCount تسجيل حفظ',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
          ),
        _buildSearchBar(),
        Expanded(
          child: _isLoading ? const Center(child: CircularProgressIndicator())
          : _filteredStudents.isEmpty ? const Center(child: Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 8, 12, 100), itemCount: _filteredStudents.length,
              itemBuilder: (_, i) => _buildStudentCard(i)),
        ),
      ],
    );
  }

  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
    child: Row(children: [
      const Icon(Icons.calendar_today, color: AppColors.primary, size: 18), const SizedBox(width: 8),
      const Text('التاريخ:', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(),
      OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.parse(_selectedDate),
            firstDate: DateTime(2020), lastDate: DateTime.now());
          if (picked != null) {
            final nd = picked.toIso8601String().split('T')[0];
            if (nd.compareTo(DateTime.now().toIso8601String().split('T')[0]) > 0) {
              CustomSnackbar.show(context, message: 'لا يمكن اختيار تاريخ مستقبلي', color: Colors.red, icon: Icons.block); return;
            }
            setState(() => _selectedDate = nd);
          }
        },
        icon: const Icon(Icons.edit_calendar, size: 16),
        label: Text(_displayDate, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]),
  );

  Widget _buildSearchBar() {
    final bgColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), color: bgColor,
      child: Row(children: [
        Expanded(child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'بحث عن طالب...', prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _searchCtrl.clear) : null,
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        )),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _sortBy, icon: const Icon(Icons.sort, size: 20),
          items: const [DropdownMenuItem(value: 'name', child: Text('أبجدي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))],
          onChanged: (v) { if (v != null) setState(() { _sortBy = v; _sortStudents(); }); },
        )),
      ]),
    );
  }

  Widget _buildStudentCard(int index) {
    final s = _filteredStudents[index]; final sId = s['id'];
    final mc = _studentMemCount[sId] ?? 0; final marked = mc > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: marked ? 3 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final cId = prefs.getInt('last_course_id') ?? 0;
          if (cId > 0) {
            final valid = await _courseService.isDateWithinCourse(cId, _selectedDate);
            if (!valid && mounted) {
              CustomSnackbar.show(context, message: 'هذا التاريخ خارج أيام الدورة!', color: Colors.red, icon: Icons.block); return;
            }
          }
          final count = await Navigator.push<int>(context, MaterialPageRoute(
            builder: (_) => _StudentMemorizationPage(student: s, selectedDate: _selectedDate)));
          if (count != null && count > 0 && mounted) {
            setState(() => _studentMemCount[sId] = (_studentMemCount[sId] ?? 0) + count);
          }
        },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            CircleAvatar(radius: 20,
              backgroundColor: marked ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade100,
              child: Icon(marked ? Icons.check_circle : Icons.person, color: marked ? AppColors.primary : Colors.grey, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['student_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: marked ? AppColors.primary : Colors.black87)),
              if (marked) Text('$mc تسجيل حفظ', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ])),
            Icon(marked ? Icons.check_circle : Icons.add_circle_outline, color: marked ? AppColors.primary : Colors.grey.shade400, size: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomBar() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.0 : 0.05),
        blurRadius: 10, offset: const Offset(0, -5))]),
    child: SafeArea(child: SizedBox(width: double.infinity, height: 48,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveAll,
        icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload),
        label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ الكل'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    )),
  );

  Future<void> _saveAll() async {
    if (_studentMemCount.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final cId = prefs.getInt('last_course_id') ?? 0;
    if (cId > 0) {
      final valid = await _courseService.isDateWithinCourse(cId, _selectedDate);
      if (!valid && mounted) { CustomSnackbar.show(context, message: 'هذا التاريخ خارج أيام الدورة!', color: Colors.red, icon: Icons.block); return; }
    }
    final total = _studentMemCount.values.fold(0, (a, b) => a + b);
    setState(() => _isSaving = true);
    final result = await SyncManager.instance.syncAll();
    pendingCountNotifier.value += total;
    if (mounted) {
      setState(() => _isSaving = false);
      CustomSnackbar.show(context,
        message: result.successCount > 0 ? 'تم حفظ وإرسال $total سجل ✅' : 'حفظ $total محلياً — المزامنة ⏳',
        color: result.successCount > 0 ? Colors.green : Colors.orange,
        icon: result.successCount > 0 ? Icons.check_circle : Icons.cloud_upload);
      setState(() => _studentMemCount.clear());
      _fetchStudents();
    }
  }
}

// ---------------------- صفحة حفظ الطالب (شاشة كاملة) ----------------------
class _StudentMemorizationPage extends StatefulWidget {
  final dynamic student;
  final String selectedDate;
  const _StudentMemorizationPage({required this.student, required this.selectedDate});
  @override State<_StudentMemorizationPage> createState() => _StudentMemorizationPageState();
}

class _StudentMemorizationPageState extends State<_StudentMemorizationPage> {
  final List<_MemForm> _forms = [];
  // السجلات المحفوظة مسبقاً (للقراءة فقط)
  List<Map<String, dynamic>> _savedRecords = [];

  @override void initState() {
    super.initState();
    _loadSavedRecords();
  }

  Future<void> _loadSavedRecords() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('pending_memorizations',
        where: 'enrollment_id = ? AND date = ?',
        whereArgs: [widget.student['id'], widget.selectedDate],
        orderBy: 'created_at DESC',
      );
      if (mounted) {
        setState(() {
          _savedRecords = rows;
          // دائماً نبدأ باستمارة واحدة جديدة (حتى لو في سجلات قديمة)
          _forms.add(_MemForm(surah: surahs[0]));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _forms.add(_MemForm(surah: surahs[0])));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.student['student_name'] ?? 'تسجيل حفظ'),
      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: Text('${_forms.length} تسجيل', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))))],
    ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.calendar_today, color: AppColors.primary, size: 20), const SizedBox(width: 10),
            Text(widget.selectedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // السجلات المحفوظة مسبقاً
      if (_savedRecords.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 18)),
            const SizedBox(width: 8),
            Text('${_savedRecords.length} تسجيلات محفوظة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success)),
          ]),
        ),
        ..._savedRecords.map((r) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.green.shade50,
          elevation: 0,
          child: Padding(padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['surah_name'] ?? 'سورة'} (${r['from_ayah']}-${r['to_ayah']})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${r['type'] == 'new' ? 'حفظ جديد' : 'مراجعة'} — ${_resultLabel(r['result']?.toString() ?? '')}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ])),
              const Icon(Icons.cloud_done, color: Colors.green, size: 18),
            ]),
          ),
        )),
        const Divider(height: 24),
      ],

      // تسجيلات جديدة
      ...List.generate(_forms.length, (i) => _buildFormCard(i)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => setState(() => _forms.add(_MemForm(surah: _forms.isNotEmpty ? _forms.last.surah : surahs[0]))),
        icon: const Icon(Icons.add_circle_outline), label: const Text('إضافة تسجيل حفظ آخر'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppColors.primary.withOpacity(0.3))),
      ),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          onPressed: _saveForms, icon: const Icon(Icons.cloud_upload), label: Text('حفظ الكل (${_forms.length})'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    ]),
  );

  Widget _buildFormCard(int index) {
    final f = _forms[index];
    return Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('تسجيل ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary))),
          if (index > 0) ...[const Spacer(),
            GestureDetector(onTap: () { f.notesCtrl?.dispose(); setState(() => _forms.removeAt(index)); },
              child: const Icon(Icons.close, color: Colors.red, size: 20))],
        ]),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(value: f.surah.id,
          items: surahs.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.number}. ${s.nameAr} (${s.totalAyahs})', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
          onChanged: (v) => setState(() { f.surah = surahs.firstWhere((s) => s.id == (v ?? 1)); f.fromAyah = 1; f.toAyah = f.surah.totalAyahs; }),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_stories), isDense: true),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ayahField('من', 1, f.surah.totalAyahs, f.fromAyah, (v) { setState(() { f.fromAyah = v; if (f.fromAyah > f.toAyah) f.toAyah = f.fromAyah; }); })),
          const SizedBox(width: 12),
          Expanded(child: _ayahField('إلى', f.fromAyah, f.surah.totalAyahs, f.toAyah, (v) { setState(() => f.toAyah = v); })),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _chip('⭐ جديد', 'new', f.type, AppColors.primary, (v) => setState(() => f.type = v)),
          const SizedBox(width: 12),
          _chip('📖 مراجعة', 'review', f.type, AppColors.info, (v) => setState(() => f.type = v)),
        ]),
        const SizedBox(height: 14),
        const Text('النتيجة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Row(children: ['excellent', 'good', 'redo'].map((r) {
          final sel = f.result == r;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => f.result = r),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 16), margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(color: sel ? _rCol(r).withOpacity(0.15) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? _rCol(r) : Colors.grey.shade300, width: 2)),
              child: Column(children: [
                Icon(_rIco(r), color: sel ? _rCol(r) : Colors.grey, size: 32),
                const SizedBox(height: 6),
                Text(_rLab(r), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: sel ? _rCol(r) : Colors.grey)),
              ]),
            ),
          ));
        }).toList()),
        const SizedBox(height: 14),
        // حقل ملاحظات خاص بكل تسجيل
        TextField(controller: f.notesCtrl, maxLines: 2, textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'ملاحظات (اختياري)...', prefixIcon: Icon(Icons.notes, size: 20), isDense: true)),
      ])),
    );
  }

  Widget _ayahField(String label, int min, int max, int value, void Function(int) onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 6),
    Container(padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: value.clamp(min, max),
        items: List.generate(max - min + 1, (i) => DropdownMenuItem(value: min + i, child: Text('الآية ${min + i}', style: const TextStyle(fontWeight: FontWeight.bold)))),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);

  Widget _chip(String l, String v, String c, Color co, void Function(String) cb) {
    final s = c == v;
    return Expanded(child: GestureDetector(
      onTap: () => cb(v),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: s ? co.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10), border: Border.all(color: s ? co : Colors.grey.shade300, width: s ? 2 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(l, style: TextStyle(fontWeight: FontWeight.bold, color: s ? co : Colors.grey))]),
      ),
    ));
  }

  Color _rCol(String r) => switch (r) { 'excellent' => AppColors.accent, 'good' => AppColors.success, _ => AppColors.warning };
  IconData _rIco(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _rLab(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };
  String _resultLabel(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };

  Future<void> _saveForms() async {
    final prefs = await SharedPreferences.getInstance();
    final courseId = prefs.getInt('last_course_id') ?? 0;
    if (courseId > 0) {
      final valid = await CourseService().isDateWithinCourse(courseId, widget.selectedDate);
      if (!valid && mounted) {
        CustomSnackbar.show(context, message: 'لا يمكن الحفظ في هذا التاريخ — اليوم خارج أيام الدورة أو تاريخ مستقبلي', color: Colors.red, icon: Icons.block);
        return;
      }
    }
    for (final f in _forms) {
      try {
        await DatabaseHelper.instance.insert('pending_memorizations', {
          'enrollment_id': widget.student['id'], 'surah_id': f.surah.id, 'surah_name': f.surah.nameAr,
          'from_ayah': f.fromAyah, 'to_ayah': f.toAyah, 'type': f.type, 'result': f.result,
          'date': widget.selectedDate, 'notes': f.notesCtrl?.text ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        if (e.toString().contains('notes')) {
          final d = await DatabaseHelper.instance.database;
          await d.execute('ALTER TABLE pending_memorizations ADD COLUMN notes TEXT');
          await DatabaseHelper.instance.insert('pending_memorizations', {
            'enrollment_id': widget.student['id'], 'surah_id': f.surah.id, 'surah_name': f.surah.nameAr,
            'from_ayah': f.fromAyah, 'to_ayah': f.toAyah, 'type': f.type, 'result': f.result,
            'date': widget.selectedDate, 'notes': f.notesCtrl?.text ?? '',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    if (mounted) {
      CustomSnackbar.show(context,
        message: 'تم حفظ ${_forms.length} سجل في قائمة الانتظار ✅',
        color: Colors.green, icon: Icons.check_circle);
      Navigator.pop(context, _forms.length);
    }
  }
}

// ---------------------- كلاس مساعد ----------------------
class _MemForm {
  Surah surah;
  int fromAyah;
  int toAyah;
  String type = 'new';
  String result = 'excellent';
  TextEditingController? notesCtrl;

  _MemForm({required this.surah, this.fromAyah = 1, this.toAyah = 1, this.notesCtrl}) {
    notesCtrl ??= TextEditingController();
  }
}
