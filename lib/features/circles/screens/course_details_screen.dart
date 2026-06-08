import 'package:flutter/material.dart';
import 'package:myhalaqat/features/circles/services/course_service.dart';

class CourseDetailsScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailsScreen({Key? key, required this.courseId}) : super(key: key);

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final CourseService _courseService = CourseService();
  Map<String, dynamic>? _courseData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    final data = await _courseService.getCourseDetails(widget.courseId);
    if (mounted) {
      setState(() {
        _courseData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الدورة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_courseData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الدورة')),
        body: const Center(child: Text('حدث خطأ في تحميل بيانات الدورة', style: TextStyle(color: Colors.red, fontSize: 16))),
      );
    }

    final bool isActive = _courseData!['is_active'] ?? false;
    final List<dynamic> daysList = _courseData!['days'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الدورة', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive ? [Theme.of(context).primaryColor, Colors.teal] : [Colors.grey.shade600, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(isActive ? Icons.school : Icons.school_outlined, size: 60, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(_courseData!['title'] ?? 'بدون اسم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text(isActive ? 'دورة نشطة' : 'دورة مغلقة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_courseData!['description'] != null && _courseData!['description'].toString().isNotEmpty) ...[
              const Text('وصف الدورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_courseData!['description'], style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5)),
              const SizedBox(height: 24),
            ],
            const Text('أيام الدوام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: daysList.map((day) {
                return Chip(
                  label: Text(day.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  avatar: Icon(Icons.calendar_today, size: 16, color: Theme.of(context).primaryColor),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('معلومات إضافية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildInfoTile(context, title: 'تاريخ البداية', value: _courseData!['start_date'] ?? 'غير محدد', icon: Icons.play_circle_fill, color: Colors.green),
            _buildInfoTile(context, title: 'تاريخ النهاية', value: _courseData!['end_date'] ?? 'غير محدد', icon: Icons.stop_circle, color: Colors.red),
            _buildInfoTile(context, title: 'مجموع النقاط', value: _courseData!['total_points']?.toString() ?? '0', icon: Icons.stars, color: Colors.amber.shade700),
            _buildInfoTile(context, title: 'تاريخ الإنشاء', value: _courseData!['created_at']?.toString().substring(0, 10) ?? 'غير محدد', icon: Icons.history, color: Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
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