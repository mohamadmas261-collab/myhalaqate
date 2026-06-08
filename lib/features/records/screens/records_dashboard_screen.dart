import 'package:flutter/material.dart';
import 'package:myhalaqat/features/records/screens/student_parts_screen.dart';
import 'package:myhalaqat/features/records/screens/student_points_screen.dart';
import 'package:myhalaqat/features/records/screens/student_quizzes_screen.dart';
import 'package:myhalaqat/features/reports/screens/student_comprehensive_report_screen.dart';
import 'package:myhalaqat/features/reports/screens/student_weekly_report_screen.dart';

class RecordsDashboardScreen extends StatelessWidget {
  final int studentId;
  final String studentName;
  final int enrollmentId;
  final int courseId;

  const RecordsDashboardScreen({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.enrollmentId,
    required this.courseId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            studentName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'التقرير الشامل',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentComprehensiveReportScreen(
                      studentId: studentId,
                      courseId: courseId,
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.stars), text: 'النقاط'),
              Tab(icon: Icon(Icons.workspace_premium), text: 'السبرات'),
              Tab(icon: Icon(Icons.menu_book), text: 'الأجزاء'),
              Tab(icon: Icon(Icons.calendar_month), text: 'الأسبوعي'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StudentPointsScreen(enrollmentId: enrollmentId),
            StudentQuizzesScreen(enrollmentId: enrollmentId),
            StudentPartsScreen(enrollmentId: enrollmentId),
            StudentWeeklyReportScreen(enrollmentId: enrollmentId),
          ],
        ),
      ),
    );
  }
}