import 'package:flutter/material.dart';
import 'package:myhalaqat/features/records/services/records_service.dart';

class StudentPartsScreen extends StatefulWidget {
  final int enrollmentId;
  const StudentPartsScreen({Key? key, required this.enrollmentId}) : super(key: key);

  @override
  State<StudentPartsScreen> createState() => _StudentPartsScreenState();
}

class _StudentPartsScreenState extends State<StudentPartsScreen> {
  final RecordsService _recordsService = RecordsService();
  bool _isLoading = true;
  List<dynamic> _parts = [];

  @override
  void initState() {
    super.initState();
    _fetchParts();
  }

  Future<void> _fetchParts() async {
    final data = await _recordsService.getStudentParts(widget.enrollmentId);
    if (mounted) {
      setState(() {
        _parts = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_parts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 70, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد أجزاء محفوظة حتى الآن', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchParts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _parts.length,
        itemBuilder: (context, index) {
          final part = _parts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.bookmark, color: Colors.green),
              ),
              title: Text(
                part['part_name'] ?? 'جزء غير معروف',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}