import 'package:flutter/material.dart';
import 'package:myhalaqat/features/reports/services/reports_service.dart';

class StudentComprehensiveReportScreen extends StatefulWidget {
  final int studentId;
  final int courseId;

  const StudentComprehensiveReportScreen({
    Key? key, required this.studentId, required this.courseId,
  }) : super(key: key);

  @override
  State<StudentComprehensiveReportScreen> createState() => _StudentComprehensiveReportScreenState();
}

class _StudentComprehensiveReportScreenState extends State<StudentComprehensiveReportScreen> {
  final ReportsService _reportsService = ReportsService();
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    final data = await _reportsService.getStudentComprehensiveReport(widget.studentId, widget.courseId);
    if (mounted) setState(() { _reportData = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('التقرير الشامل')), body: const Center(child: CircularProgressIndicator()));
    }

    if (_reportData == null) {
      return Scaffold(appBar: AppBar(title: const Text('التقرير الشامل')), body: const Center(child: Text('حدث خطأ في جلب بيانات التقرير.')));
    }

    final student = _reportData!['student'] ?? {};
    final enrollment = _reportData!['enrollment'] ?? {};
    final attendance = _reportData!['attendance'] ?? {};
    final memorization = _reportData!['memorization'] ?? {};
    final quizzes = _reportData!['quizzes'] ?? {};
    final points = _reportData!['points'] ?? {};
    final pagesCount = _reportData!['completed_pages_count'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('التقرير الشامل: ${student['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ميزة الطباعة ستتوفر قريباً!')));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(radius: 40, backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1), child: Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor)),
                    const SizedBox(height: 16),
                    Text(student['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(enrollment['course_title'] ?? '', style: TextStyle(fontSize: 16, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn('الحلقة', enrollment['circle_name']),
                        _buildInfoColumn('المعلم', enrollment['teacher_name']),
                        _buildInfoColumn('رقم الهاتف', student['phone']),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildCircleStat('إجمالي النقاط', '${points['total'] ?? 0}', Colors.amber),
                const SizedBox(width: 12),
                _buildCircleStat('سبر مجتاز', '${quizzes['passed'] ?? 0}/${quizzes['total'] ?? 0}', Colors.purple),
                const SizedBox(width: 12),
                _buildCircleStat('صفحات', '$pagesCount', Colors.green),
              ],
            ),
            const SizedBox(height: 20),

            _buildSectionCard(
              title: 'إحصائيات الحضور',
              icon: Icons.access_time,
              color: Colors.blue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('حاضر', '${attendance['total_present'] ?? 0}', Colors.green),
                  _buildMiniStat('غائب', '${attendance['total_absent'] ?? 0}', Colors.red),
                  _buildMiniStat('مستأذن', '${attendance['total_excused'] ?? 0}', Colors.orange),
                ],
              ),
            ),

            _buildSectionCard(
              title: 'إنجاز التسميع (${memorization['total_sessions']} جلسات)',
              icon: Icons.menu_book,
              color: Colors.teal,
              child: Column(
                children: (memorization['records'] as List? ?? []).take(5).map((m) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
                    title: Text('سورة ${m['surah']} (آيات ${m['ayahs']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(m['result'] == 'excellent' ? 'ممتاز' : (m['result'] == 'good' ? 'جيد' : 'إعادة'), 
                      style: TextStyle(color: m['result'] == 'excellent' ? Colors.green : (m['result'] == 'good' ? Colors.orange : Colors.red), fontWeight: FontWeight.bold)),
                  );
                }).toList()..add(const ListTile(title: Text('...المزيد في السجل المفصل', style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center))),
              ),
            ),

            if ((quizzes['records'] as List? ?? []).isNotEmpty)
              _buildSectionCard(
                title: 'الاختبارات والسبر',
                icon: Icons.workspace_premium,
                color: Colors.purple,
                child: Column(
                  children: (quizzes['records'] as List).map((q) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stars, color: Colors.purple),
                      title: Text(q['part'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(q['type'] == 'new' ? 'سبر جديد' : 'مراجعة'),
                      trailing: Text('${q['score']} / ${q['max_score']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String title, String? value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value ?? '---', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildCircleStat(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)]),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}