import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';
import 'package:myhalaqat/features/students/models/surahs_data.dart';
import 'package:myhalaqat/features/circles/services/course_service.dart';
import 'package:myhalaqat/features/students/screens/circle_memorization_record_screen.dart';

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
  bool _isLoading = true;
  bool _isOpeningStudent = false;
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

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _filteredStudents[index]; final sId = s['id'];
    final mc = _studentMemCount[sId] ?? 0; final marked = mc > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: marked ? 3 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (_isOpeningStudent) return;
          setState(() => _isOpeningStudent = true);
          // إظهار Loading فوري أثناء التحقق من التاريخ
          _showLoadingDialog('جاري فتح سجل الطالب...');
          try {
            final prefs = await SharedPreferences.getInstance();
            final cId = prefs.getInt('last_course_id') ?? 0;
            if (cId > 0) {
              final valid = await _courseService.isDateWithinCourse(cId, _selectedDate);
              if (!valid && mounted) {
                Navigator.pop(context); // إغلاق Loading
                CustomSnackbar.show(context, message: 'هذا التاريخ خارج أيام الدورة!', color: Colors.red, icon: Icons.block); return;
              }
            }
            if (!mounted) return;
            Navigator.pop(context); // إغلاق Loading قبل فتح الصفحة
            final count = await Navigator.push<int>(context, MaterialPageRoute(
              builder: (_) => _StudentMemorizationPage(student: s, selectedDate: _selectedDate)));
            if (count != null && count > 0 && mounted) {
              setState(() => _studentMemCount[sId] = (_studentMemCount[sId] ?? 0) + count);
            }
          } finally {
            if (mounted) setState(() => _isOpeningStudent = false);
          }
        },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            CircleAvatar(radius: 20,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(marked ? Icons.check_circle : Icons.person, color: AppColors.primary, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s['student_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: marked ? AppColors.primary :  isDark ? Colors.white : Colors.black87)),
              if (marked) Text('$mc تسجيل حفظ', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ])),
            Icon(marked ? Icons.check_circle : Icons.add_circle_outline, color: marked ? AppColors.primary : Colors.grey.shade400, size: 24),
          ]),
        ),
      ),
    );
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
  bool _isSaving = false;
  bool _isLoadingRecords = true;
  bool _recordsExpanded = false;
  List<Map<String, dynamic>> _lastRecords = [];

  // للتعبئة التلقائية من آخر سجل حفظ
  bool _autoFillApplied = false;
  int? _initialSurahId;
  int? _initialFrom;
  int? _initialTo;

  @override void initState() {
    super.initState();
    _loadLastMemo();
    _loadLastRecords();
  }

  Future<void> _loadLastMemo() async {
    final studentId = widget.student['id'] as int? ?? 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_memo_$studentId');
      if (saved != null) {
        final data = jsonDecode(saved);
        final surahId = data['surah_id'] as int? ?? 1;
        final fromAyah = data['from_ayah'] as int? ?? 1;
        final toAyah = data['to_ayah'] as int? ?? 1;
        final surah = surahs.firstWhere((s) => s.id == surahId, orElse: () => surahs[0]);
        if (mounted) {
          setState(() => _forms.add(_MemForm(surah: surah, fromAyah: fromAyah, toAyah: toAyah)));
          _rememberInitialValues();
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _forms.add(_MemForm(surah: surahs.last)));
      _rememberInitialValues();
    }
  }

  /// تذكّر قيم النموذج الأولى لكشف ما إذا عدّلها المستخدم
  void _rememberInitialValues() {
    if (_forms.isEmpty) return;
    _initialSurahId = _forms.first.surah.id;
    _initialFrom = _forms.first.fromAyah;
    _initialTo = _forms.first.toAyah;
  }

  /// بناء نموذج من سجل حفظ قادم من السيرفر أو الكاش
  _MemForm? _formFromRecord(Map<String, dynamic> r) {
    Surah? surah;
    final surahId = int.tryParse((r['surah'] ?? '').toString());
    if (surahId != null) {
      for (final s in surahs) {
        if (s.id == surahId) { surah = s; break; }
      }
    }
    // fallback: المطابقة باسم السورة
    if (surah == null) {
      final name = (r['surah_name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        for (final s in surahs) {
          if (s.nameAr == name || s.nameAr.contains(name) || name.contains(s.nameAr)) {
            surah = s;
            break;
          }
        }
      }
    }
    if (surah == null) return null;

    int? from = int.tryParse((r['from_ayah'] ?? '').toString());
    int? to = int.tryParse((r['to_ayah'] ?? '').toString());
    // fallback: حقل ayahs بصيغة "1-7"
    if (from == null || to == null) {
      final parts = (r['ayahs'] ?? '').toString().split('-');
      if (parts.length == 2) {
        from ??= int.tryParse(parts[0].trim());
        to ??= int.tryParse(parts[1].trim());
      }
    }
    from ??= 1;
    to ??= from;
    // ضبط الحدود داخل عدد آيات السورة
    if (from < 1) from = 1;
    if (from > surah.totalAyahs) from = surah.totalAyahs;
    if (to < from) to = from;
    if (to > surah.totalAyahs) to = surah.totalAyahs;
    return _MemForm(surah: surah, fromAyah: from, toAyah: to);
  }

  /// تعبئة تلقائية للنموذج من آخر سجل حفظ — إن لم يكن المستخدم قد عدّله
  void _applyServerAutoFill(List<Map<String, dynamic>> records) {
    if (_autoFillApplied || records.isEmpty) return;
    if (_forms.length != 1) return;
    final form = _forms.first;
    final untouched = form.surah.id == _initialSurahId &&
        form.fromAyah == _initialFrom &&
        form.toAyah == _initialTo;
    if (!untouched) return;
    final autoForm = _formFromRecord(records.first);
    if (autoForm == null) return;
    _autoFillApplied = true;
    if (mounted) {
      setState(() {
        form.surah = autoForm.surah;
        form.fromAyah = autoForm.fromAyah;
        form.toAyah = autoForm.toAyah;
      });
    }
    // تنظيف controller النموذج المؤقت
    autoForm.notesCtrl?.dispose();
  }

  /// جلب آخر سجلات الحفظ للطالب من API
  /// إنترنت شغّال → جلب مباشر + تحديث الكاش | لا إنترنت → آخر نسخة محفوظة
  Future<void> _loadLastRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_last_memos_${widget.student['id']}';
    try {
      final dio = ApiClient().dio;
      final response = await dio.get(
        '/api/memorizations/?enrollment=${widget.student['id']}&ordering=-date',
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = response.data;
        final results = data is Map ? (data['results'] ?? []) : (data ?? []);
        final parsed = <Map<String, dynamic>>[];
        if (results is List) {
          for (final r in results) {
            if (r is Map) parsed.add(Map<String, dynamic>.from(r));
          }
        }
        // تحديث الكاش
        try {
          await prefs.setString(cacheKey, jsonEncode(parsed));
        } catch (_) {}
        if (mounted) {
          setState(() {
            _lastRecords = parsed;
            _isLoadingRecords = false;
          });
        }
        // تعبئة تلقائية من آخر سجل حفظ (يعمل عند تغيير الجهاز)
        _applyServerAutoFill(parsed);
        return;
      }
    } catch (e) {
      print('🚨 فشل جلب سجلات الحفظ: $e');
    }
    // لا يوجد اتصال → آخر نسخة محفوظة
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = jsonDecode(cached) as List;
        final parsed = list.map((r) => Map<String, dynamic>.from(r)).toList();
        if (mounted) {
          setState(() {
            _lastRecords = parsed;
            _isLoadingRecords = false;
          });
        }
        // تعبئة تلقائية من الكاش
        _applyServerAutoFill(parsed);
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoadingRecords = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.student['student_name'] ?? 'تسجيل حفظ'),
      actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(child: Text('${_forms.length} تسجيل', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))))],
    ),
     
     bottomNavigationBar: SafeArea( // SafeArea هنا تمنع الزر ينقطش من تحت
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity, 
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveForms,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload),
            label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ الكل (${_forms.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
            ),
          ),
        ),
      ),
    ),
     
     
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.calendar_today, color: AppColors.primary, size: 20), const SizedBox(width: 10),
            Text(widget.selectedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // جدول السجلات السابقة (قابل للتوسع)
      _buildRecordsCard(),

      const SizedBox(height: 16),

      // تسجيلات جديدة
      ...List.generate(_forms.length, (i) => _buildFormCard(i)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => setState(() => _forms.add(_MemForm(surah: _forms.isNotEmpty ? _forms.last.surah : surahs.last))),
        icon: const Icon(Icons.add_circle_outline), label: const Text('إضافة تسجيل حفظ آخر'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: AppColors.primary.withOpacity(0.3))),
      ),
    ]),
  );

  /// بطاقة سجلات الحفظ السابقة (قابلة للتوسع - آخر 5 سجلات)
  Widget _buildRecordsCard() {
    if (_isLoadingRecords) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('جاري تحميل السجلات...', style: TextStyle(fontSize: 13)),
          ]),
        ),
      );
    }
    if (_lastRecords.isEmpty) return const SizedBox.shrink();

    // آخر 3 سجلات ظاهرة افتراضياً، وعند التوسيع تظهر 10 ثم زر عرض الكل
    const collapsedCount = 3;
    const expandedCount = 10;
    final showCount = _recordsExpanded ? expandedCount : collapsedCount;
    final initialRecords = _lastRecords.take(showCount).toList();
    final hiddenCount = _lastRecords.length - initialRecords.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _recordsExpanded = !_recordsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.menu_book, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('سجلات الحفظ الأخيرة (${_lastRecords.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Icon(_recordsExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500),
            ]),
          ),
        ),
        const Divider(height: 1),
        // آخر 3 سجلات تظهر دائماً بدون الحاجة للضغط
        ...initialRecords.map((r) => _buildRecordTile(r)),
        if (!_recordsExpanded && hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: () => setState(() => _recordsExpanded = true),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text('عرض المزيد ($hiddenCount سجل)'),
            ),
          ),
        if (_recordsExpanded && hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              Text('وهناك $hiddenCount سجلات إضافية',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _showAllRecords,
                icon: const Icon(Icons.list, size: 18),
                label: const Text('عرض الكل'),
              ),
            ]),
          ),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildRecordTile(Map<String, dynamic> r) {
    final result = r['result'] ?? '';
    Color rc; String rt; IconData ri;
    switch (result) {
      case 'excellent': rc = AppColors.success; rt = 'ممتاز'; ri = Icons.auto_awesome; break;
      case 'good': rc = AppColors.accent; rt = 'جيد'; ri = Icons.thumb_up; break;
      default: rc = AppColors.warning; rt = 'إعادة'; ri = Icons.refresh;
    }
    final surahName = r['surah_name'] ?? r['surah'] ?? '';
    final ayahs = r['ayahs'] ?? '${r['from_ayah'] ?? ''}-${r['to_ayah'] ?? ''}';
    final date = (r['date'] ?? '').toString().split('T')[0];
    final notes = (r['notes'] ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ri, color: rc, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('سورة $surahName ($ayahs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          // الملاحظة إن وُجدت
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notes, size: 12, color: Colors.amber.shade800),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(notes,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: rc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(rt, style: TextStyle(color: rc, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  /// عرض جميع السجلات في Modal
  void _showAllRecords() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.menu_book, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('جميع السجلات (${_lastRecords.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _lastRecords.length,
              itemBuilder: (_, i) => _buildRecordTile(_lastRecords[i]),
            ),
          ),
        ]),
      ),
    );
  }

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
        // حقل السورة — يفتح نافذة بحث
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectSurah(f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.auto_stories, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(f.surah.nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Icon(Icons.search, color: Colors.grey.shade500, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ayahField('من', 1, f.surah.totalAyahs, f.fromAyah, (v) { setState(() { f.fromAyah = v; if (f.fromAyah > f.toAyah) f.toAyah = f.fromAyah; }); })),
          const SizedBox(width: 12),
          Expanded(child: _ayahField('إلى', f.fromAyah, f.surah.totalAyahs, f.toAyah, (v) { setState(() => f.toAyah = v); })),
        ]),
        const SizedBox(height: 14),
        const Text('النوع *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          _chip('⭐ جديد', 'new', f.type, AppColors.primary, (v) => setState(() => f.type = v)),
          const SizedBox(width: 12),
          _chip('📖 مراجعة', 'review', f.type, AppColors.info, (v) => setState(() => f.type = v)),
        ]),
        const SizedBox(height: 14),
        const Text('النتيجة *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
        // حقل ملاحظات خاص بكل تسجيل (إجباري)
        TextField(controller: f.notesCtrl, maxLines: 2, textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'ملاحظات (إجباري)...',
            prefixIcon: Icon(Icons.notes, size: 20),
            suffixText: '*',
            suffixStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            isDense: true,
          )),
      ])),
    );
  }

  /// نافذة اختيار السورة مع البحث بالاسم
  Future<void> _selectSurah(_MemForm f) async {
    final selected = await showDialog<Surah>(
      context: context,
      builder: (_) => const _SurahSearchDialog(),
    );
    if (selected != null) {
      setState(() {
        f.surah = selected;
        f.fromAyah = 1;
        f.toAyah = 1; // افتراضي: الآية الأولى فقط
      });
    }
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

  Widget _chip(String l, String v, String? c, Color co, void Function(String) cb) {
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

  Color _rCol(String r) => switch (r) { 'excellent' => AppColors.success, 'good' => AppColors.accent, _ => AppColors.warning };
  IconData _rIco(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _rLab(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };
  Future<void> _saveForms() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _saveFormsInternal();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveFormsInternal() async {
    // التحقق من الحقول الإجبارية (النوع، النتيجة، الملاحظات)
    for (int i = 0; i < _forms.length; i++) {
      final f = _forms[i];
      if (f.type == null) {
        CustomSnackbar.show(context,
          message: 'التسجيل ${i + 1}: اختر النوع (جديد أو مراجعة)',
          color: Colors.red, icon: Icons.warning_amber_rounded);
        return;
      }
      if (f.result == null) {
        CustomSnackbar.show(context,
          message: 'التسجيل ${i + 1}: اختر النتيجة',
          color: Colors.red, icon: Icons.warning_amber_rounded);
        return;
      }
      if ((f.notesCtrl?.text.trim() ?? '').isEmpty) {
        CustomSnackbar.show(context,
          message: 'التسجيل ${i + 1}: الملاحظات إجبارية',
          color: Colors.red, icon: Icons.warning_amber_rounded);
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final courseId = prefs.getInt('last_course_id') ?? 0;
    if (courseId > 0) {
      final valid = await CourseService().isDateWithinCourse(courseId, widget.selectedDate);
      if (!valid && mounted) {
        CustomSnackbar.show(context, message: 'لا يمكن الحفظ في هذا التاريخ — اليوم خارج أيام الدورة أو تاريخ مستقبلي', color: Colors.red, icon: Icons.block);
        return;
      }
    }

    // حفظ آخر سورة وآيات للطالب في SharedPreferences (قبل أي return)
    if (_forms.isNotEmpty) {
      final last = _forms.last;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString('last_memo_${widget.student['id'] as int? ?? 0}', jsonEncode({
          'surah_id': last.surah.id, 'from_ayah': last.fromAyah, 'to_ayah': last.toAyah,
        }));
      } catch (_) {}
    }

    // محاولة الإرسال المباشر أولاً
    try {
      final dio = ApiClient().dio;
      final records = _forms.map((f) => {
        'enrollment': widget.student['id'],
        'surah': f.surah.id,
        'from_ayah': f.fromAyah,
        'to_ayah': f.toAyah,
        'type': f.type!,
        'result': f.result!,
        'date': widget.selectedDate,
        'notes': f.notesCtrl?.text.trim() ?? '',
      }).toList();

      final response = await dio.post('/api/memorizations/batch/', data: {'records': records})
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        CustomSnackbar.show(context,
          message: 'تم حفظ وإرسال ${_forms.length} سجل ✅',
          color: Colors.green, icon: Icons.check_circle);
        Navigator.pop(context, _forms.length);
      }
      return;
    } catch (e) {
      print('⚠️ فشل الإرسال المباشر، حفظ محلياً: $e');
    }

    // حفظ محلياً (offline أو فشل الإرسال)
    for (final f in _forms) {
      try {
        await DatabaseHelper.instance.insert('pending_memorizations', {
          'enrollment_id': widget.student['id'], 'surah_id': f.surah.id, 'surah_name': f.surah.nameAr,
          'from_ayah': f.fromAyah, 'to_ayah': f.toAyah, 'type': f.type!, 'result': f.result!,
          'date': widget.selectedDate, 'notes': f.notesCtrl?.text.trim() ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        if (e.toString().contains('notes')) {
          final d = await DatabaseHelper.instance.database;
          await d.execute('ALTER TABLE pending_memorizations ADD COLUMN notes TEXT');
          await DatabaseHelper.instance.insert('pending_memorizations', {
            'enrollment_id': widget.student['id'], 'surah_id': f.surah.id, 'surah_name': f.surah.nameAr,
            'from_ayah': f.fromAyah, 'to_ayah': f.toAyah, 'type': f.type!, 'result': f.result!,
            'date': widget.selectedDate, 'notes': f.notesCtrl?.text.trim() ?? '',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    await refreshPendingCount();
    if (mounted) {
      CustomSnackbar.show(context,
        message: 'تم حفظ ${_forms.length} سجل في قائمة الانتظار ✅',
        color: Colors.green, icon: Icons.check_circle);
      Navigator.pop(context, _forms.length);
    }
  }
}

// ---------------------- كلاسات مساعدة ----------------------
class _MemForm {
  Surah surah;
  int fromAyah;
  int toAyah;
  String? type;    // بدون قيمة افتراضية — المستخدم يختار
  String? result;  // بدون قيمة افتراضية — المستخدم يختار
  TextEditingController? notesCtrl;

  _MemForm({required this.surah, this.fromAyah = 1, this.toAyah = 1, this.notesCtrl}) {
    notesCtrl ??= TextEditingController();
  }
}

/// نافذة اختيار السورة مع البحث الفوري بالاسم
class _SurahSearchDialog extends StatefulWidget {
  const _SurahSearchDialog();
  @override State<_SurahSearchDialog> createState() => _SurahSearchDialogState();
}

class _SurahSearchDialogState extends State<_SurahSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Surah> _filtered = surahs;

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _filter(String q) {
    final query = q.trim();
    setState(() {
      _filtered = query.isEmpty
          ? surahs
          : surahs.where((s) => s.nameAr.contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text('اختر السورة', style: TextStyle(fontWeight: FontWeight.bold)),
    content: SizedBox(
      width: double.maxFinite,
      height: 400,
      child: Column(children: [
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ابحث عن السورة... (مثال: الفيل)',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _filter(''); })
                : null,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: _filter,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _filtered.isEmpty
              ? Center(child: Text('لا توجد سور مطابقة', style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(_filtered[i].nameAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onTap: () => Navigator.pop(context, _filtered[i]),
                  ),
                ),
        ),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
    ],
  );
}
