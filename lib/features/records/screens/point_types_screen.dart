import 'package:flutter/material.dart';
import 'package:myhalaqat/features/records/services/records_service.dart';

class PointTypesScreen extends StatefulWidget {
  const PointTypesScreen({Key? key}) : super(key: key);

  @override
  State<PointTypesScreen> createState() => _PointTypesScreenState();
}

class _PointTypesScreenState extends State<PointTypesScreen> {
  final RecordsService _recordsService = RecordsService();
  bool _isLoading = true;
  List<dynamic> _pointTypes = [];

  @override
  void initState() {
    super.initState();
    _fetchPointTypes();
  }

  Future<void> _fetchPointTypes() async {
    final data = await _recordsService.getPointEventTypes();
    if (mounted) {
      setState(() {
        _pointTypes = data;
        _isLoading = false;
      });
    }
  }

  IconData _getIconForCode(String code) {
    if (code.contains('attendance')) return Icons.co_present;
    if (code.contains('memorization')) return Icons.menu_book;
    if (code.contains('quiz')) return Icons.workspace_premium;
    if (code.contains('page')) return Icons.library_books;
    return Icons.star_outline;
  }

  Color _getColorForCode(String code) {
    if (code.contains('absent') || code.contains('redo')) return Colors.red;
    if (code.contains('excellent') || code.contains('present') || code.contains('quiz') || code.contains('page')) return Colors.green;
    if (code.contains('good')) return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دليل أنواع النقاط', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pointTypes.length,
              itemBuilder: (context, index) {
                final item = _pointTypes[index];
                final String code = item['code'] ?? '';
                final IconData icon = _getIconForCode(code);
                final Color color = _getColorForCode(code);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                    title: Text(item['name_ar'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(item['description'] ?? 'لا يوجد وصف', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}