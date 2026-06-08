import 'package:flutter/material.dart';
import 'package:myhalaqat/features/records/services/records_service.dart';

class StudentPointsScreen extends StatefulWidget {
  final int enrollmentId;
  const StudentPointsScreen({Key? key, required this.enrollmentId}) : super(key: key);

  @override
  State<StudentPointsScreen> createState() => _StudentPointsScreenState();
}

class _StudentPointsScreenState extends State<StudentPointsScreen> {
  final RecordsService _recordsService = RecordsService();
  bool _isLoading = true;
  List<dynamic> _points = [];

  @override
  void initState() {
    super.initState();
    _fetchPoints();
  }

  Future<void> _fetchPoints() async {
    final data = await _recordsService.getStudentPoints(widget.enrollmentId);
    if (mounted) {
      setState(() {
        _points = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_points.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_outlined, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد نقاط مسجلة بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPoints,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _points.length,
        itemBuilder: (context, index) {
          final point = _points[index];
          double val = double.tryParse(point['total_points'].toString()) ?? 0;
          bool isPositive = val >= 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPositive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                child: Icon(
                  isPositive ? Icons.add : Icons.remove,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              title: Text(
                point['event_type_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(point['awarded_at'] ?? ''),
              trailing: Text(
                '${val > 0 ? '+' : ''}$val',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}