import 'package:flutter/material.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/sync_indicator.dart';
import 'package:myhalaqat/features/circles/services/circle_service.dart';
import 'package:myhalaqat/features/attendance/screens/attendance_screen.dart';
import 'package:myhalaqat/features/students/screens/batch_memorization_screen.dart';
import 'package:myhalaqat/features/saber/screens/create_saber_request_screen.dart';
import 'package:myhalaqat/features/students/screens/students_list_screen.dart';
import 'package:myhalaqat/features/attendance/screens/circle_attendance_record_screen.dart';
import 'package:myhalaqat/features/students/screens/circle_memorization_record_screen.dart';
import 'package:myhalaqat/features/pending/screens/pending_items_screen.dart';
import 'package:myhalaqat/features/students/screens/student_statistics_screen.dart';

class CircleDetailsScreen extends StatefulWidget {
  final int circleId;
  final String circleName;
  final int courseId;

  const CircleDetailsScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
    required this.courseId,
  }) : super(key: key);

  @override
  State<CircleDetailsScreen> createState() => _CircleDetailsScreenState();
}

class _CircleDetailsScreenState extends State<CircleDetailsScreen> {
  final CircleService _circleService = CircleService();
  Map<String, dynamic>? _circleData;
  bool _isLoading = true;
  List<dynamic> _archivedStudents = [];
  bool _isLoadingArchived = true;
  bool _archivedExpanded = true;

  @override
  void initState() {
    super.initState();
    _fetchCircleDetails();
    _fetchArchivedStudents();
  }

  Future<void> _fetchCircleDetails() async {
    final data = await _circleService.getCircleDetails(widget.circleId);
    if (mounted) {
      setState(() { _circleData = data; _isLoading = false; });
    }
  }

  Future<void> _fetchArchivedStudents() async {
    final data = await _circleService.getArchivedStudents(
      courseId: widget.courseId,
      circleId: widget.circleId,
    );
    if (mounted) {
      setState(() { _archivedStudents = data; _isLoadingArchived = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.circleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          SyncAppBarAction(
            onViewPending: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingItemsScreen())),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة الحلقة
                    _buildCircleHeader(),
                    const SizedBox(height: 24),

                    // الإجراءات الرئيسية
                    const Text('الإجراءات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildActionGrid(),
                    const SizedBox(height: 24),

                    // الطلاب المؤرشفون
                    _buildArchivedSection(),
                    // هامش سفلي آمن حتى لا يلتصق المحتوى بحافة الشاشة
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// قسم قابل للتوسع: الطلاب المؤرشفون في هذه الحلقة
  Widget _buildArchivedSection() {
    final count = _archivedStudents.length;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _archivedExpanded = !_archivedExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.archive, color: Colors.grey.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('الطلاب المفصولين من الحلقة ($count)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Icon(_archivedExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          if (_archivedExpanded) ...[
            const Divider(height: 1),
            if (_isLoadingArchived)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_archivedStudents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('لا يوجد طلاب مؤرشفون',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              )
            else
              ..._archivedStudents.map((s) => _buildArchivedStudentTile(s)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// بطاقة طالب مؤرشف: الاسم + الهاتف + تاريخ التسجيل + تاريخ الأرشفة
  Widget _buildArchivedStudentTile(dynamic s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = (s['student_phone'] ?? '').toString();
    final enrolledAt = _formatDate(s['enrolled_at']);
    final archivedAt = _formatDate(s['archived_at']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.withOpacity(0.15),
            child: Icon(Icons.person_off, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['student_name'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.phone, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(phone, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  ]),
                ],
                const SizedBox(height: 3),
                Wrap(spacing: 12, runSpacing: 2, children: [
                  Text('تاريخ التسجيل: $enrolledAt', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text('تاريخ الأرشفة: $archivedAt', style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// تنسيق التاريخ للعرض (بدون وقت)
  String _formatDate(dynamic raw) {
    final s = (raw ?? '').toString();
    if (s.isEmpty) return '-';
    return s.split(' ')[0].split('T')[0];
  }

  Widget _buildCircleHeader() {
    final name = _circleData?['name'] ?? widget.circleName;
    final courseTitle = _circleData?['course_title'] ?? '';
    final teacherName = _circleData?['teacher_name'] ?? '';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF059669), const Color(0xFF047857)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.group_work, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            if (courseTitle.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text(courseTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            if (teacherName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(teacherName, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionCard(
              title: 'حضور/غياب', icon: Icons.fact_check, color: Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AttendanceScreen(circleId: widget.circleId, circleName: widget.circleName),
              )),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(
              title: 'تسجيل حفظ', icon: Icons.menu_book, color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BatchMemorizationScreen(circleId: widget.circleId, circleName: widget.circleName),
              )),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionCard(
              title: 'طلب سبر', icon: Icons.quiz, color: Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CreateSaberRequestScreen(circleId: widget.circleId),
              )),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(
              title: 'إحصائيات الطلاب', icon: Icons.insights, color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => StudentStatisticsScreen(
                  circleId: widget.circleId,
                  circleName: widget.circleName,
                  courseId: widget.courseId,
                ),
              )),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordLinks() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CircleAttendanceRecordScreen(
                circleId: widget.circleId,
                circleName: widget.circleName,
              ),
            )),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('سجل الحضور'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CircleMemorizationRecordScreen(
                circleId: widget.circleId,
                circleName: widget.circleName,
              ),
            )),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('سجل الحفظ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    final notes = _circleData!['notes']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ملاحظات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notes.isNotEmpty ? notes : 'لا توجد ملاحظات.',
                  style: TextStyle(color: Colors.grey.shade800, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
