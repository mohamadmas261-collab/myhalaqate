import 'package:flutter/material.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/features/attendance/services/attendance_service.dart';
import 'package:dio/dio.dart';

class CircleAttendanceRecordScreen extends StatefulWidget {
  final int circleId;
  final String circleName;

  const CircleAttendanceRecordScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
  }) : super(key: key);

  @override
  State<CircleAttendanceRecordScreen> createState() => _CircleAttendanceRecordScreenState();
}

class _CircleAttendanceRecordScreenState extends State<CircleAttendanceRecordScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final Dio _dio = ApiClient().dio;
  bool _isLoading = true;
  List<dynamic> _records = [];
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    final data = await _attendanceService.getCircleAttendanceRecord(
      widget.circleId,
      date: _selectedDate.isEmpty ? null : _selectedDate,
    );
    if (mounted) setState(() { _records = data; _isLoading = false; });
  }

  Future<bool> _isOnline() async {
    try {
      await _dio.get('/api/quran-parts/');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _editRecord(Map<String, dynamic> record) async {
    final currentStatus = record['status'] ?? 'present';
    final labels = {'present': 'حاضر ✅', 'absent': 'غائب ❌', 'excused': 'مستأذن ⏸'};
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('تعديل حالة الحضور', style: TextStyle(fontWeight: FontWeight.bold)),
        children: ['present', 'absent', 'excused'].map((s) => RadioListTile<String>(
          title: Text(labels[s] ?? s),
          value: s, groupValue: currentStatus,
          onChanged: (v) => Navigator.pop(ctx, v),
        )).toList(),
      ),
    );
    if (chosen == null || chosen == currentStatus) return;

    final recordId = record['id'];
    final online = await _isOnline();

    if (online) {
      try {
        await _dio.patch('/api/attendance/$recordId/', data: {'status': chosen});
        CustomSnackbar.show(context, message: 'تم التعديل مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
      } catch (e) {
        CustomSnackbar.show(context, message: 'فشل التعديل — حفظ في قائمة الانتظار', color: Colors.orange, icon: Icons.warning);
        await DatabaseHelper.instance.insert('pending_attendance', {
          'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
          'status': chosen, 'circle_id': widget.circleId, 'action': 'update',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } else {
      await DatabaseHelper.instance.insert('pending_attendance', {
        'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
        'status': chosen, 'circle_id': widget.circleId, 'action': 'update',
        'created_at': DateTime.now().toIso8601String(),
      });
      CustomSnackbar.show(context, message: 'حفظ التعديل محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
    }
    _fetchRecords();
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: Text('سيتم حذف سجل حضور "${record['student_name']}" في ${record['date']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final recordId = record['id'];
    final online = await _isOnline();

    if (online) {
      try {
        await _dio.delete('/api/attendance/$recordId/');
        CustomSnackbar.show(context, message: 'تم الحذف مباشرة ✅', color: Colors.green, icon: Icons.check_circle);
      } catch (e) {
        CustomSnackbar.show(context, message: 'فشل الحذف — حفظ في قائمة الانتظار', color: Colors.orange, icon: Icons.warning);
        await DatabaseHelper.instance.insert('pending_attendance', {
          'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
          'status': record['status'], 'circle_id': widget.circleId, 'action': 'delete',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } else {
      await DatabaseHelper.instance.insert('pending_attendance', {
        'server_id': recordId, 'enrollment_id': record['enrollment'], 'date': record['date'],
        'status': record['status'], 'circle_id': widget.circleId, 'action': 'delete',
        'created_at': DateTime.now().toIso8601String(),
      });
      CustomSnackbar.show(context, message: 'حفظ الحذف محلياً — سيتم المزامنة لاحقاً', color: Colors.orange, icon: Icons.cloud_upload);
    }
    _fetchRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('سجل حضور: ${widget.circleName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_selectedDate.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              tooltip: 'إلغاء الفلتر',
              onPressed: () { setState(() => _selectedDate = ''); _fetchRecords(); },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchRecords,
                    child: _records.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _records.length,
                            itemBuilder: (_, i) => _buildRecordCard(_records[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('فلترة:', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context, initialDate: DateTime.now(),
                firstDate: DateTime(2020), lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked.toIso8601String().split('T')[0]);
                _fetchRecords();
              }
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_selectedDate.isEmpty ? 'عرض الكل' : _selectedDate),
            style: OutlinedButton.styleFrom(
              foregroundColor: _selectedDate.isEmpty ? Colors.grey.shade700 : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    Color statusColor; String statusText; IconData statusIcon;
    switch (record['status']) {
      case 'present': statusColor = Colors.green; statusText = 'حاضر'; statusIcon = Icons.check_circle; break;
      case 'absent': statusColor = Colors.red; statusText = 'غائب'; statusIcon = Icons.cancel; break;
      case 'excused': statusColor = Colors.orange; statusText = 'مستأذن'; statusIcon = Icons.pause_circle_filled; break;
      default: statusColor = Colors.grey; statusText = 'غير محدد'; statusIcon = Icons.help; break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record['student_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('التاريخ: ${record['date']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'edit') _editRecord(record);
                if (v == 'delete') _deleteRecord(record);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('تعديل')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('حذف', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _selectedDate.isEmpty ? 'لا توجد سجلات حضور لهذه الحلقة' : 'لا توجد سجلات في هذا التاريخ',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
