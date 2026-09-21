import 'package:flutter/material.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/features/students/services/student_stats_service.dart';

/// صفحة تفاصيل الطالب: معلومات + جداول إحصائيات قابلة للتوسع
class StudentStatisticsDetailScreen extends StatefulWidget {
  final int enrollmentId;
  final String studentName;
  final int? studentId;
  final int courseId;

  const StudentStatisticsDetailScreen({
    Key? key,
    required this.enrollmentId,
    required this.studentName,
    this.studentId,
    required this.courseId,
  }) : super(key: key);

  @override
  State<StudentStatisticsDetailScreen> createState() => _StudentStatisticsDetailScreenState();
}

class _StudentStatisticsDetailScreenState extends State<StudentStatisticsDetailScreen> {
  final StudentStatsService _service = StudentStatsService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  // حالة التوسع لكل جدول
  final Map<String, bool> _expanded = {
    'attendance': false,
    'memorization': false,
    'quizzes': false,
    'points': false,
    'completedPages': false,
    'absenceAlerts': false,
    'completedParts': false,
  };

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _service.getStudentCourseReport(
      widget.enrollmentId,
      studentId: widget.studentId,
      courseId: widget.courseId,
    );
    if (mounted) setState(() { _data = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadReport,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStudentInfo(),
                      const SizedBox(height: 16),
                      _buildExpandableSection(
                        key: 'attendance', title: 'الحضور والغياب', icon: Icons.event_available, color: Colors.green,
                        count: _attendanceRecords.length,
                        summary: _attendanceSummary(),
                        child: _buildAttendanceTable(),
                      ),
                      _buildExpandableSection(
                        key: 'memorization', title: 'الحفظ والمراجعة', icon: Icons.menu_book, color: Colors.orange,
                        count: _memorizationRecords.length,
                        summary: '${_memorizationRecords.length} سجل',
                        child: _buildMemorizationTable(),
                      ),
                      _buildExpandableSection(
                        key: 'quizzes', title: 'السبر', icon: Icons.workspace_premium, color: Colors.blue,
                        count: _quizRecords.length,
                        summary: _quizzesSummary(),
                        child: _buildQuizzesTable(),
                      ),
                      _buildExpandableSection(
                        key: 'points', title: 'الأسهم', icon: Icons.star, color: Colors.amber,
                        count: _pointsRecords.length,
                        summary: _pointsSummary(),
                        child: _buildPointsTable(),
                      ),
                      _buildExpandableSection(
                        key: 'completedPages', title: 'الصفحات المكتملة', icon: Icons.description, color: Colors.teal,
                        count: _completedPages.length,
                        summary: '${_completedPages.length} صفحة',
                        child: _buildCompletedPagesTable(),
                      ),
                      _buildExpandableSection(
                        key: 'absenceAlerts', title: 'إنذارات الغياب', icon: Icons.warning_amber_rounded, color: Colors.red,
                        count: _absenceAlerts.length,
                        summary: '${_absenceAlerts.length} إنذار',
                        child: _buildAbsenceAlertsTable(),
                      ),
                      _buildExpandableSection(
                        key: 'completedParts', title: 'الأجزاء المكتملة', icon: Icons.auto_stories, color: Colors.purple,
                        count: _completedParts.length,
                        summary: '${_completedParts.length} جزء',
                        child: _buildCompletedPartsTable(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('تعذر جلب بيانات الطالب', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // البيانات المستخرجة من التقرير
  // ==========================================
  Map<String, dynamic> get _student => (_data?['student'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _attendance => (_data?['attendance'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _memorization => (_data?['memorization'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _quizzes => (_data?['quizzes'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get _points => (_data?['points'] as Map?)?.cast<String, dynamic>() ?? {};

  List<dynamic> get _attendanceRecords => (_attendance['records'] as List?) ?? [];
  List<dynamic> get _memorizationRecords => (_memorization['records'] as List?) ?? [];
  List<dynamic> get _quizRecords => (_quizzes['records'] as List?) ?? [];
  List<dynamic> get _pointsRecords => (_points['records'] as List?) ?? [];
  List<dynamic> get _completedPages => (_data?['completed_pages'] as List?) ?? [];
  List<dynamic> get _absenceAlerts => (_data?['absence_alerts'] as List?) ?? [];
  List<dynamic> get _completedParts => (_data?['general_parts'] as List?) ?? [];

  double get _pointsTotal {
    final t = _points['total'];
    if (t is num) return t.toDouble();
    return double.tryParse(t?.toString() ?? '') ?? 0;
  }

  String _attendanceSummary() {
    final p = _attendance['total_present'] ?? 0;
    final a = _attendance['total_absent'] ?? 0;
    final e = _attendance['total_excused'] ?? 0;
    final total = _attendanceRecords.length;
    return '$total سجل: $p حاضر، $a غائب، $e مستأذن';
  }

  int get _quizPassedCount {
    int passed = 0;
    for (final r in _quizRecords) {
      final score = (r['score'] is num) ? (r['score'] as num).toDouble() : double.tryParse(r['score']?.toString() ?? '') ?? 0;
      final maxScore = (r['max_score'] is num) ? (r['max_score'] as num).toDouble() : double.tryParse(r['max_score']?.toString() ?? '') ?? 100;
      if (maxScore > 0 && (score / maxScore) * 100 >= 50) passed++;
    }
    return passed;
  }

  String _quizzesSummary() {
    final total = _quizRecords.length;
    final passed = _quizPassedCount;
    final failed = total - passed;
    return '$total اختبارات سبر: $passed ناجح، $failed راسب';
  }

  String _pointsSummary() {
    final count = _pointsRecords.length;
    return '$count سجل أسهم: المجموع ${_pointsTotal.toStringAsFixed(0)} سهم';
  }

  /// تنسيق التاريخ بدون وقت (YYYY-MM-DD)
  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (s.isEmpty) return '';
    if (s.contains('T')) return s.split('T')[0];
    if (s.contains(' ')) return s.split(' ')[0];
    return s;
  }

  // ==========================================
  // معلومات الطالب
  // ==========================================
  Widget _buildStudentInfo() {
    final name = _student['name'] ?? widget.studentName;
    final phone = _student['phone'] ?? '';
    final birth = _student['date_of_birth'] ?? '';
    final courseTitle = (_data?['enrollment'] as Map?)?['course_title'] ?? '';
    final circleName = (_data?['enrollment'] as Map?)?['circle_name'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, const Color(0xFF047857)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text('$name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _infoChip(Icons.phone, phone.isNotEmpty ? '$phone' : '-', phone.isEmpty),
                _infoChip(Icons.calendar_today, birth.isNotEmpty ? '$birth' : '-', birth.isEmpty),
              ],
            ),
            if (courseTitle.toString().isNotEmpty || circleName.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('$circleName${circleName.toString().isNotEmpty && courseTitle.toString().isNotEmpty ? ' — ' : ''}$courseTitle',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 5),
                  Text('${_pointsTotal.toStringAsFixed(0)} سهم',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, bool isMissing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMissing ? Colors.orange.withOpacity(0.25) : Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isMissing ? Colors.orange.shade200 : Colors.white70),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(
            fontSize: 12,
            color: isMissing ? Colors.orange.shade100 : Colors.white,
            fontWeight: isMissing ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  // ==========================================
  // الأقسام القابلة للتوسع
  // ==========================================
  Widget _buildExpandableSection({
    required String key,
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required String summary,
    required Widget child,
  }) {
    final isExpanded = _expanded[key] ?? false;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded[key] = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(summary, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyTable(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(child: Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
    );
  }

  // ==========================================
  // جداول البيانات
  // ==========================================
  Widget _buildAttendanceTable() {
    if (_attendanceRecords.isEmpty) return _buildEmptyTable('لا توجد سجلات حضور');
    return Column(
      children: _attendanceRecords.map((r) {
        final status = r['status'] ?? '';
        Color c; String t; IconData ic;
        switch (status) {
          case 'present': c = Colors.green; t = 'حاضر'; ic = Icons.check_circle; break;
          case 'absent': c = Colors.red; t = 'غائب'; ic = Icons.cancel; break;
          case 'excused': c = Colors.orange; t = 'مستأذن'; ic = Icons.pause_circle; break;
          default: c = Colors.grey; t = 'غير محدد'; ic = Icons.help; break;
        }
        return _tableRow(
          leading: ic, leadingColor: c,
          title: _formatDate(r['date']),
          trailingText: t, trailingColor: c,
        );
      }).toList(),
    );
  }

  Widget _buildMemorizationTable() {
    if (_memorizationRecords.isEmpty) return _buildEmptyTable('لا توجد سجلات حفظ');
    return Column(
      children: _memorizationRecords.map((r) {
        final result = r['result'] ?? '';
        Color c; String t;
        switch (result) {
          case 'excellent': c = AppColors.success; t = 'ممتاز'; break;
          case 'good': c = Colors.orange; t = 'جيد'; break;
          case 'redo': c = Colors.red; t = 'إعادة'; break;
          default: c = Colors.grey; t = 'غير محدد';
        }
        final surah = r['surah'] ?? r['surah_name'] ?? '';
        final ayahs = r['ayahs'] ?? '${r['from_ayah'] ?? ''}-${r['to_ayah'] ?? ''}';
        final type = r['type'] == 'new' ? 'حفظ جديد' : 'مراجعة';
        return _tableRow(
          leading: Icons.menu_book, leadingColor: c,
          title: 'سورة $surah',
          subtitle: 'الآيات: $ayahs — $type',
          trailingText: t, trailingColor: c,
          trailingSub: _formatDate(r['date']),
        );
      }).toList(),
    );
  }

  Widget _buildQuizzesTable() {
    if (_quizRecords.isEmpty) return _buildEmptyTable('لا توجد سجلات سبر');
    return Column(
      children: _quizRecords.map((r) {
        final score = r['score'] ?? 0;
        final maxScore = r['max_score'] ?? 100;
        final percentage = (maxScore is num && maxScore > 0) ? ((score / maxScore) * 100) : 0.0;
        final passed = percentage >= 50;
        final c = passed ? Colors.green : Colors.red;
        final part = r['part'] ?? r['quran_part'] ?? '';
        final type = r['type'] == 'new' ? 'جديد' : 'مراجعة';
        return _tableRow(
          leading: passed ? Icons.check_circle : Icons.cancel, leadingColor: c,
          title: 'الجزء $part',
          subtitle: 'سبر $type',
          trailingText: '${percentage.toStringAsFixed(1)}%', trailingColor: c,
          trailingSub: _formatDate(r['date']),
        );
      }).toList(),
    );
  }

  Widget _buildPointsTable() {
    if (_pointsRecords.isEmpty) return _buildEmptyTable('لا توجد سجلات أسهم');
    return Column(
      children: [
        ..._pointsRecords.map((r) {
          final p = r['points'] ?? 0;
          final pNum = p is num ? p : (double.tryParse(p.toString()) ?? 0);
          final c = pNum >= 0 ? Colors.green : Colors.red;
          return _tableRow(
            leading: pNum >= 0 ? Icons.add_circle : Icons.remove_circle, leadingColor: c,
            title: '${r['event'] ?? 'حدث'}',
            subtitle: _formatDate(r['date']),
            trailingText: '${pNum >= 0 ? '+' : ''}${pNum.toStringAsFixed(0)}',
            trailingColor: c,
          );
        }),
        const Divider(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${_pointsTotal.toStringAsFixed(0)} سهم',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedPagesTable() {
    if (_completedPages.isEmpty) return _buildEmptyTable('لا توجد صفحات مكتملة');
    // ترتيب حسب تاريخ الإضافة (الأحدث أولاً) بدلاً من رقم الصفحة
    final sorted = List<dynamic>.from(_completedPages);
    sorted.sort((a, b) {
      final da = (a['completed_at'] ?? a['date'] ?? '').toString();
      final db = (b['completed_at'] ?? b['date'] ?? '').toString();
      return db.compareTo(da);
    });
    return Column(
      children: sorted.map((r) {
        final page = r['page'] ?? r['completed_pages'] ?? '';
        final date = r['completed_at'] ?? r['date'] ?? '';
        return _tableRow(
          leading: Icons.description, leadingColor: Colors.teal,
          title: 'صفحة $page',
          trailingText: '', trailingColor: Colors.teal,
          trailingSub: _formatDate(date),
        );
      }).toList(),
    );
  }

  Widget _buildAbsenceAlertsTable() {
    if (_absenceAlerts.isEmpty) return _buildEmptyTable('لا توجد إنذارات غياب');
    return Column(
      children: _absenceAlerts.map((r) {
        final isCleared = r['cleared_at'] != null;
        final c = isCleared ? Colors.green : Colors.red;
        return _tableRow(
          leading: isCleared ? Icons.check_circle : Icons.warning_amber_rounded, leadingColor: c,
          title: '${r['note'] ?? 'إنذار غياب'}',
          subtitle: _formatDate(r['created_at']),
          trailingText: isCleared ? 'تم الإغلاق' : 'مفتوح',
          trailingColor: c,
        );
      }).toList(),
    );
  }

  Widget _buildCompletedPartsTable() {
    if (_completedParts.isEmpty) return _buildEmptyTable('لا توجد أجزاء مكتملة');
    return Column(
      children: _completedParts.map((r) {
        final part = r['part'] ?? r['part_name'] ?? r['quran_part'] ?? '';
        final date = r['memorized_at'] ?? r['completed_at'] ?? r['date'] ?? '';
        return _tableRow(
          leading: Icons.auto_stories, leadingColor: Colors.purple,
          title: 'الجزء $part',
          trailingText: '', trailingColor: Colors.purple,
          trailingSub: _formatDate(date),
        );
      }).toList(),
    );
  }

  Widget _tableRow({
    required IconData leading,
    required Color leadingColor,
    required String title,
    String? subtitle,
    required String trailingText,
    required Color trailingColor,
    String? trailingSub,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(leading, size: 18, color: leadingColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
          if (trailingText.isNotEmpty)
            Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.bold, fontSize: 12)),
          if (trailingSub != null) ...[
            if (trailingText.isNotEmpty) const SizedBox(width: 8),
            Text(trailingSub, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
