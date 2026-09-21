import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/features/students/services/student_stats_service.dart';
import 'package:myhalaqat/features/students/screens/student_statistics_detail_screen.dart';

/// صفحة إحصائيات الطلاب: جدول مرتب بالنقاط + نسخ الأرقام
class StudentStatisticsScreen extends StatefulWidget {
  final int circleId;
  final String circleName;
  final int courseId;

  const StudentStatisticsScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
    required this.courseId,
  }) : super(key: key);

  @override
  State<StudentStatisticsScreen> createState() => _StudentStatisticsScreenState();
}

class _StudentStatisticsScreenState extends State<StudentStatisticsScreen> {
  final StudentStatsService _service = StudentStatsService();
  bool _isLoading = true;
  bool _isCopying = false;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final data = await _service.getStudentStatsList(widget.courseId, widget.circleId);
    if (mounted) {
      setState(() { _students = data; _isLoading = false; });
    }
  }

  bool _isDataComplete(Map<String, dynamic> s) {
    final phone = (s['student_phone'] ?? '').toString();
    final birth = (s['student_date_of_birth'] ?? '').toString();
    return phone.isNotEmpty && birth.isNotEmpty;
  }

  /// نسخ جميع الأسماء وأرقام الهاتف إلى قائمة (فوري — من بيانات الترتيب)
  Future<void> _copyAllNumbers() async {
    if (_students.isEmpty || _isCopying) return;
    setState(() => _isCopying = true);
    try {
      final buffer = StringBuffer();
      for (final s in _students) {
        buffer.writeln(s['student_name'] ?? '');
        final phone = (s['student_phone'] ?? '').toString();
        buffer.writeln(phone.isNotEmpty ? phone : '-');
        buffer.writeln('-------------------');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        CustomSnackbar.show(context,
          message: 'تم نسخ ${_students.length} اسم ورقم هاتف إلى الحافظة',
          color: Colors.green, icon: Icons.check_circle);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, message: 'فشل النسخ', color: Colors.red, icon: Icons.error);
      }
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات الطلاب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildHeader(),
                    _buildCopyButton(),
                    // مفتاح الألوان قريب من الجدول مباشرة
                    _buildLegendRow(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadStudents,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                          itemCount: _students.length,
                          itemBuilder: (_, i) => _buildStudentRow(_students[i]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: AppColors.primary.withOpacity(0.15))),
      ),
      child: Text(
        '${widget.circleName} — ${_students.length} طالب',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// مفتاح الألوان: الأخضر = الترتيب، الأصفر = الأسهم — ملاصق للجدول
  Widget _buildLegendRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        children: [
          _legendBadge(
            color: AppColors.primary,
            label: 'الترتيب على الحلقة',
            sample: '1',
          ),
          const Spacer(),
          _legendBadge(
            color: Colors.orange,
            label: 'الأسهم',
            icon: Icons.star,
          ),
        ],
      ),
    );
  }

  /// شارة توضيحية ثابتة أعلى القائمة
  Widget _legendBadge({required Color color, required String label, String? sample, IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: icon != null
              ? Icon(icon, size: 12, color: color)
              : Text(sample ?? '',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  /// زر نسخ الأسماء وأرقام الهاتف — فوق قائمة الطلاب مباشرة
  Widget _buildCopyButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _students.isEmpty || _isCopying ? null : _copyAllNumbers,
          icon: _isCopying
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.copy, size: 20),
          label: const Text(
            'نسخ اسماء الطلاب وارقام هواتفهم الى قائمة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('لا يوجد طلاب في هذه الحلقة', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> s) {
    final complete = _isDataComplete(s);
    final phone = (s['student_phone'] ?? '').toString();
    final birth = (s['student_date_of_birth'] ?? '').toString();
    final points = s['total_points'] ?? 0;
    final rank = s['rank'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: complete ? null : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: complete ? BorderSide.none : BorderSide(color: Colors.orange.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final enrollmentId = s['enrollment_id'] as int?;
          if (enrollmentId == null) {
            CustomSnackbar.show(context,
              message: 'لا يمكن فتح التفاصيل — معرف التسجيل غير متوفر',
              color: Colors.orange, icon: Icons.warning);
            return;
          }
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => StudentStatisticsDetailScreen(
              enrollmentId: enrollmentId,
              studentName: s['student_name'] ?? '',
              studentId: int.tryParse((s['student_id'] ?? '').toString()),
              courseId: widget.courseId,
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // شارة الترتيب (الأخضر — موضح في الترويسة)
              Container(
                width: 34, height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$rank', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              // الاسم والبيانات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(s['student_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (!complete)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(birth.isNotEmpty ? birth : '-',
                          style: TextStyle(fontSize: 11, color: birth.isNotEmpty ? Colors.grey.shade600 : Colors.orange.shade700)),
                        const SizedBox(width: 10),
                        Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(phone.isNotEmpty ? phone : '-',
                          style: TextStyle(fontSize: 11, color: phone.isNotEmpty ? Colors.grey.shade600 : Colors.orange.shade700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // شارة الأسهم (الأصفر — موضح في الترويسة)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 13, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text('$points', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
