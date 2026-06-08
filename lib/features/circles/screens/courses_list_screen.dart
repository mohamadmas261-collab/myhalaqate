import 'package:flutter/material.dart';
import 'package:myhalaqat/features/circles/screens/course_details_screen.dart';
import 'package:myhalaqat/features/circles/services/course_service.dart';

class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({Key? key}) : super(key: key);

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  final CourseService _courseService = CourseService();
  bool _isLoading = true;
  List<dynamic> _courses = [];

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final data = await _courseService.getMyCourses();
    if (mounted) {
      setState(() {
        _courses = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دوراتي', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? const Center(child: Text('لا يوجد دورات مسندة إليك حالياً.', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    final bool isActive = course['is_active'] ?? false;
                    final List<dynamic> daysList = course['days'] ?? [];
                    final String daysText = daysList.join(' - ');

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CourseDetailsScreen(courseId: course['id'])),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      course['title'] ?? 'دورة بدون اسم',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isActive ? 'نشطة' : 'مغلقة',
                                      style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(course['description'] ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.date_range, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('من ${course['start_date']} إلى ${course['end_date']}', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(daysText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.stars, size: 16, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Text('إجمالي النقاط: ${course['total_points']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}