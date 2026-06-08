import 'package:flutter/material.dart';
import 'package:myhalaqat/features/reports/services/reports_service.dart';

class StudentWeeklyReportScreen extends StatefulWidget {
  final int enrollmentId;
  const StudentWeeklyReportScreen({Key? key, required this.enrollmentId}) : super(key: key);

  @override
  State<StudentWeeklyReportScreen> createState() => _StudentWeeklyReportScreenState();
}

class _StudentWeeklyReportScreenState extends State<StudentWeeklyReportScreen> {
  final ReportsService _reportsService = ReportsService();
  bool _isLoading = true;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    final data = await _reportsService.getWeeklyReport(widget.enrollmentId);
    if (mounted) setState(() { _reportData = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_reportData == null) return const Center(child: Text('لا توجد بيانات للتقرير الأسبوعي.'));

    final attendance = _reportData!['attendance'] as List<dynamic>? ?? [];
    final memorization = _reportData!['memorization'] as List<dynamic>? ?? [];
    final pages = _reportData!['completed_pages'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildStatCard('الحضور', '${_reportData!['attendance_total']} أيام', Icons.co_present, Colors.blue),
              _buildStatCard('التسميع', '${_reportData!['memorization_total']} مرات', Icons.mic, Colors.teal),
              _buildStatCard('السبر', '${_reportData!['quiz_total']} اختبارات', Icons.workspace_premium, Colors.amber),
              _buildStatCard('الصفحات', '${_reportData!['completed_pages_total']} صفحة', Icons.library_books, Colors.green),
            ],
          ),
          const Divider(height: 32, thickness: 1),

          _buildSectionTitle('سجل الحضور الأخير 📅'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attendance.map((a) {
              Color color = a['status'] == 'present' ? Colors.green : (a['status'] == 'absent' ? Colors.red : Colors.orange);
              String text = a['status'] == 'present' ? 'حاضر' : (a['status'] == 'absent' ? 'غائب' : 'مستأذن');
              return Chip(label: Text('${a['date']} ($text)', style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: color);
            }).toList(),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('الحفظ والمراجعة 📖'),
          const SizedBox(height: 8),
          ...memorization.map((m) {
            Color resColor = m['result'] == 'excellent' ? Colors.green : (m['result'] == 'redo' ? Colors.red : Colors.orange);
            String resText = m['result'] == 'excellent' ? 'ممتاز' : (m['result'] == 'redo' ? 'إعادة' : 'جيد');
            String typeText = m['type'] == 'new' ? 'حفظ جديد' : 'مراجعة';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: resColor.withOpacity(0.2), child: Icon(Icons.menu_book, color: resColor)),
                title: Text('سورة ${m['surah']} (آيات ${m['ayahs']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$typeText • ${m['date']}'),
                trailing: Text(resText, style: TextStyle(color: resColor, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),

          _buildSectionTitle('الصفحات المنجزة 📄'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pages.map((p) {
              return Chip(
                label: Text('صفحة ${p['page']}'),
                backgroundColor: Colors.green.shade50,
                side: BorderSide(color: Colors.green.shade200),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
              Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}