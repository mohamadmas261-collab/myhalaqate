import 'package:flutter/material.dart';
import 'package:myhalaqat/features/records/services/records_service.dart';

class StudentQuizzesScreen extends StatefulWidget {
  final int enrollmentId;
  const StudentQuizzesScreen({Key? key, required this.enrollmentId}) : super(key: key);

  @override
  State<StudentQuizzesScreen> createState() => _StudentQuizzesScreenState();
}

class _StudentQuizzesScreenState extends State<StudentQuizzesScreen> {
  final RecordsService _recordsService = RecordsService();
  bool _isLoading = true;
  List<dynamic> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    final data = await _recordsService.getStudentQuizzes(widget.enrollmentId);
    if (mounted) {
      setState(() {
        _quizzes = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_quizzes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد سبرات مسجلة بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchQuizzes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _quizzes.length,
        itemBuilder: (context, index) {
          final quiz = _quizzes[index];
          bool isPassed = quiz['passed'] == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPassed
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                child: Icon(
                  Icons.workspace_premium,
                  color: isPassed ? Colors.blue : Colors.red,
                ),
              ),
              title: Text(
                quiz['part_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                quiz['quiz_type'] == 'new' ? 'سبر جديد' : 'مراجعة',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${double.parse(quiz['score'].toString()).toInt()}%',
                    style: TextStyle(
                      color: isPassed ? Colors.blue : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isPassed ? 'ناجح' : 'لم يجتز',
                    style: TextStyle(
                      fontSize: 11,
                      color: isPassed ? Colors.blue : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}