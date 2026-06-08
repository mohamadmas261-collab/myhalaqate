import 'package:flutter/material.dart';
import 'package:myhalaqat/features/reports/services/reports_service.dart';
import 'package:myhalaqat/features/reports/screens/absence_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  final int circleId;
  const ReportsScreen({Key? key, this.circleId = 0}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsService _reportsService = ReportsService();

  bool _isLoading = true;
  int _absentStudentsCount = 0;
  List<dynamic> _rankingList = [];
  Map<String, dynamic>? _memoStats;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchRankingData(),
      _fetchStatsData(),
      _fetchAbsenceCount(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchRankingData() async {
    final data = await _reportsService.getStudentRanking();
    if (mounted) setState(() => _rankingList = data);
  }

  Future<void> _fetchStatsData() async {
    final data = await _reportsService.getMemorizationStats();
    if (mounted) setState(() => _memoStats = data);
  }

  Future<void> _fetchAbsenceCount() async {
    final data = await _reportsService.getAbsenceReport(threshold: 3);
    if (mounted) setState(() => _absentStudentsCount = data.length);
  }

  Color _getMedalColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return Colors.brown.shade300;
    return Colors.blue.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات والتقارير', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // --- تنبيه الغياب ---
                    if (_absentStudentsCount > 0) ...[
                      _buildAbsenceAlert(),
                      const SizedBox(height: 20),
                    ],

                    // --- صدارة الإنجاز ---
                    if (_memoStats != null) ...[
                      _buildSectionTitle('صدارة الإنجاز 🏅'),
                      const SizedBox(height: 12),
                      _buildAchievementRow(),
                      const SizedBox(height: 24),
                    ],

                    // --- لوحة الشرف ---
                    _buildSectionTitle('ترتيب الطلاب (لوحة الشرف) 🏆'),
                    const SizedBox(height: 12),
                    _buildHonorRoll(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAbsenceAlert() {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
        title: const Text('تنبيه: طلاب تجاوزوا حد الغياب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        subtitle: Text('يوجد $_absentStudentsCount طالب يحتاجون متابعة.'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AbsenceReportScreen()),
        ),
      ),
    );
  }

  Widget _buildAchievementRow() {
    final mostPages = _memoStats!['most_completed_pages'];
    final mostReviews = _memoStats!['most_reviews'];

    if (mostPages == null || mostPages.isEmpty || mostReviews == null || mostReviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Text('لا توجد بيانات كافية لإظهار صدارة الإنجاز.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return Row(
      children: [
        _buildAchievementCard(
          'الأعلى صفحات',
          '${mostPages[0]['completed_pages']}',
          mostPages[0]['student_name'],
          Icons.insert_drive_file,
          Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildAchievementCard(
          'الأكثر مراجعة',
          '${mostReviews[0]['review_count']}',
          mostReviews[0]['student_name'],
          Icons.published_with_changes,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildAchievementCard(String title, String value, String name, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHonorRoll() {
    if (_rankingList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Text('لا توجد بيانات للترتيب حالياً.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    final topStudents = _rankingList.length > 10 ? _rankingList.sublist(0, 10) : _rankingList;

    return Column(
      children: topStudents.map((student) {
        final int rank = student['rank'];
        final Color medalColor = _getMedalColor(rank);
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: medalColor,
              child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            title: Text(student['student_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('حلقة: ${student['circle_name']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(student['total_points'] as num).toInt()}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.stars, color: Colors.amber, size: 16),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}