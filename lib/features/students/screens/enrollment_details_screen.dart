import 'package:flutter/material.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';

class EnrollmentDetailsScreen extends StatefulWidget {
  final int enrollmentId;
  const EnrollmentDetailsScreen({Key? key, required this.enrollmentId}) : super(key: key);

  @override
  State<EnrollmentDetailsScreen> createState() => _EnrollmentDetailsScreenState();
}

class _EnrollmentDetailsScreenState extends State<EnrollmentDetailsScreen> {
  final StudentService _studentService = StudentService();
  Map<String, dynamic>? _enrollmentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final data = await _studentService.getEnrollmentDetails(widget.enrollmentId);
    if (mounted) {
      setState(() {
        _enrollmentData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التسجيل')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_enrollmentData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التسجيل')),
        body: const Center(child: Text('حدث خطأ في تحميل البيانات', style: TextStyle(color: Colors.red))),
      );
    }

    final bool isActive = _enrollmentData!['status'] == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('بطاقة التسجيل', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive 
                        ? [Theme.of(context).primaryColor, Colors.blue.shade700]
                        : [Colors.grey.shade600, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _enrollmentData!['student_name'] ?? 'بدون اسم',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'حالة التسجيل: نشط' : 'حالة التسجيل: غير نشط',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailTile(context, title: 'الدورة', value: _enrollmentData!['course_title'] ?? 'غير محدد', icon: Icons.school, color: Colors.purple),
            _buildDetailTile(context, title: 'الحلقة', value: _enrollmentData!['circle_name'] ?? 'غير محدد', icon: Icons.group_work, color: Colors.orange),
            const Divider(height: 32),
            _buildDetailTile(context, title: 'تاريخ التسجيل', value: _enrollmentData!['enrolled_at'] ?? 'غير محدد', icon: Icons.calendar_today, color: Colors.green),
            if (_enrollmentData!['archived_at'] != null)
              _buildDetailTile(context, title: 'تاريخ الأرشفة', value: _enrollmentData!['archived_at'], icon: Icons.archive, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}