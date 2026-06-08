import 'package:flutter/material.dart';
import 'package:myhalaqat/features/reports/services/reports_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final ReportsService _reportsService = ReportsService();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    final data = await _reportsService.getTeacherDashboard();
    if (mounted) setState(() { _dashboardData = data; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('لوحتي الخاصة')), body: const Center(child: CircularProgressIndicator()));
    }

    if (_dashboardData == null) {
      return Scaffold(appBar: AppBar(title: const Text('لوحتي الخاصة')), body: const Center(child: Text('عذراً، لم نتمكن من جلب بيانات اللوحة.')));
    }

    final teacher = _dashboardData!['teacher'] ?? {};
    final List<dynamic> circles = _dashboardData!['circles'] ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('لوحتي الخاصة', style: TextStyle(fontWeight: FontWeight.bold)), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTeacherProfileCard(teacher),
            const SizedBox(height: 24),
            const Text('حلقاتي وطلابي 📚', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            if (circles.isEmpty)
              const Center(child: Text('لا توجد حلقات مسندة إليك حالياً.'))
            else
              ...circles.map((circle) => _buildCircleSection(circle)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherProfileCard(Map<String, dynamic> teacher) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 35, backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.blue)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أهلاً بك،', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(teacher['name'] ?? 'أستاذنا الفاضل', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(children: [const Icon(Icons.phone, color: Colors.white70, size: 14), const SizedBox(width: 4), Text(teacher['phone'] ?? '---', style: const TextStyle(color: Colors.white70, fontSize: 13))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleSection(Map<String, dynamic> circle) {
    final List<dynamic> students = circle['students'] ?? [];
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(circle['circle_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    Text(circle['course_title'] ?? '', style: TextStyle(color: Colors.blue.shade700, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [const Icon(Icons.group, size: 16, color: Colors.blue), const SizedBox(width: 4), Text('${circle['total_students']} طلاب', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                ),
              ],
            ),
          ),
          
          if (students.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا يوجد طلاب في هذه الحلقة.')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = students[index];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade200, child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildMiniStat(Icons.stars, '${student['total_points'].toInt()}', Colors.amber),
                                const SizedBox(width: 12),
                                _buildMiniStat(Icons.library_books, '${student['completed_pages']}', Colors.green),
                                const SizedBox(width: 12),
                                _buildMiniStat(Icons.workspace_premium, '${student['quiz_count']}', Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
      ],
    );
  }
}