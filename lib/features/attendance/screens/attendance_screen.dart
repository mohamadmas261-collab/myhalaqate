import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';
import 'package:myhalaqat/features/attendance/services/attendance_service.dart';
import 'package:myhalaqat/features/attendance/screens/circle_attendance_record_screen.dart';
import 'package:myhalaqat/features/circles/services/course_service.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  final int circleId;
  final String circleName;

  const AttendanceScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
  }) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  final StudentService _studentService = StudentService();
  final AttendanceService _attendanceService = AttendanceService();
  final CourseService _courseService = CourseService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _sortBy = 'name'; // name, points, attendance, absence
  final Map<int, String> _statuses = {};
  final Map<int, Map<String, dynamic>> _pendingMap = {};
  List<dynamic> _existingRecords = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  bool _dateInvalid = false;
  String _dateError = '';
  bool _showHistory = false;

  String get _displayDate {
    final date = DateTime.tryParse(_selectedDate);
    if (date == null) return _selectedDate;
    final dayName = CourseService.getArabicDayName(date);
    return '$dayName — $_selectedDate';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(_applyFilter);
    _fetchStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) =>
        (s['student_name'] ?? '').toLowerCase().contains(q)).toList();
      _sortStudents();
    });
  }

  void _sortStudents() {
    switch (_sortBy) {
      case 'name':
        _filteredStudents.sort((a, b) => (a['student_name'] ?? '').compareTo(b['student_name'] ?? ''));
        break;
    }
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    final data = await _studentService.getStudentsByCircle(widget.circleId);
    final pendingRecords = await _attendanceService.getPendingAttendance(widget.circleId, _selectedDate);

    // جلب السجلات المتزامنة من الكاش (إن وجدت)
    List<dynamic> syncedRecords = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final courseId = prefs.getInt('last_course_id') ?? 0;
      final cached = prefs.getString('cache_attendance_record_circle_${widget.circleId}_$_selectedDate');
      if (cached != null) syncedRecords = jsonDecode(cached);
      // إذا لا يوجد كاش نحاول من API
      if (syncedRecords.isEmpty && courseId > 0) {
        final dio = ApiClient().dio;
        final res = await dio.get('/api/attendance/?course=$courseId&date=$_selectedDate');
        if (res.statusCode == 200) syncedRecords = res.data['results'] ?? [];
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _students = data;
        _filteredStudents = List.from(data);
        _sortStudents();
        _pendingMap.clear();
        for (var p in pendingRecords) {
          _pendingMap[p['enrollment_id']] = {
            'local_id': p['id'],
            'status': p['status'],
            'sync_status': p['sync_status'],
          };
        }
        // دمج السجلات المتزامنة (إذا لم يكن هناك pending)
        for (var sr in syncedRecords) {
          final eId = sr['enrollment'];
          if (!_pendingMap.containsKey(eId)) {
            _pendingMap[eId] = {
              'local_id': null,
              'status': sr['status'],
              'sync_status': 'synced',
            };
          }
        }
        for (var student in _students) {
          final sId = student['id'];
          final pending = _pendingMap[sId];
          _statuses[sId] = pending != null ? pending['status'] as String : '';
        }
        // بناء قائمة السجلات الموجودة للعرض
        _existingRecords = [];
        for (var p in pendingRecords) {
          _existingRecords.add({
            'student_name': _students.firstWhere(
              (s) => s['id'] == p['enrollment_id'],
              orElse: () => {'student_name': 'طالب', 'id': 0},
            )['student_name'] ?? 'طالب',
            'status': p['status'],
            'date': p['date'],
            'sync_status': p['sync_status'],
          });
        }
        for (var sr in syncedRecords) {
          if (!_existingRecords.any((r) => r['student_name'] == sr['student_name'])) {
            _existingRecords.add(sr);
          }
        }
        _isLoading = false;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present': return 'حاضر';
      case 'absent': return 'غائب';
      case 'excused': return 'مستأذن';
      default: return '';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'excused': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle;
      case 'absent': return Icons.cancel;
      case 'excused': return Icons.pause_circle;
      default: return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حضور/غياب', style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'تسجيل'),
            Tab(icon: Icon(Icons.history), text: 'السجل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // التبويب الأول: تسجيل الحضور
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildDateBar(),
                    if (_dateInvalid) _buildDateError(),
                    _buildBulkActions(),
                    _buildSearchBar(),
                    Expanded(
                      child: _filteredStudents.isEmpty
                          ? const Center(child: Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey, fontSize: 16)))
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              children: [
                                ...List.generate(_filteredStudents.length, (i) => _buildStudentCard(i)),
                                if (_existingRecords.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildHistoryHeader(),
                                  ..._existingRecords.map((r) => _buildExistingRecordCard(r)),
                                ],
                              ],
                              ),
                            ),
                          ],
                ),
          // التبويب الثاني: سجل الحضور
          CircleAttendanceRecordScreen(
            circleId: widget.circleId,
            circleName: widget.circleName,
          ),
        ],
      ),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
    );
  }

  Widget _buildDateBar() {
    final bgColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          const Text('التاريخ:', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.edit_calendar, size: 16),
            label: Text(_displayDate, style: const TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _dateError.isNotEmpty ? _dateError : 'هذا التاريخ غير مسموح به',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          const Text('تحديد الكل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          _bulkBtn(Icons.check_circle, Colors.green, 'present'),
          const SizedBox(width: 8),
          _bulkBtn(Icons.cancel, Colors.red, 'absent'),
          const SizedBox(width: 8),
          _bulkBtn(Icons.pause_circle, Colors.orange, 'excused'),
          const SizedBox(width: 8),
          Container(height: 20, width: 1, color: Colors.grey.shade300),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _statuses.clear()),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.clear_all, color: Colors.grey, size: 18),
            ),
          ),
          const Spacer(),
          Text('${_statuses.values.where((s) => s.isNotEmpty).length}/${_students.length}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _bulkBtn(IconData icon, Color color, String status) {
    return InkWell(
      onTap: () => setState(() => _students.forEach((s) => _statuses[s['id']] = status)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    final bgColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: bgColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث عن طالب...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); })
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              icon: const Icon(Icons.sort, size: 20),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('أبجدي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
              onChanged: (v) { if (v != null) setState(() { _sortBy = v; _sortStudents(); }); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.history, color: AppColors.info, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('السجلات المسجلة لهذا التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Text('${_existingRecords.length}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExistingRecordCard(Map<String, dynamic> record) {
    Color statusColor; String statusText; IconData statusIcon;
    switch (record['status']) {
      case 'present': statusColor = Colors.green; statusText = 'حاضر'; statusIcon = Icons.check_circle; break;
      case 'absent': statusColor = Colors.red; statusText = 'غائب'; statusIcon = Icons.cancel; break;
      case 'excused': statusColor = Colors.orange; statusText = 'مستأذن'; statusIcon = Icons.pause_circle; break;
      default: statusColor = Colors.grey; statusText = 'غير محدد'; statusIcon = Icons.help; break;
    }
    final isPending = record['sync_status'] != 'synced';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(record['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            if (isPending) ...[
              const SizedBox(width: 6),
              const Text('⏳', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(int index) {
    final student = _filteredStudents[index];
    final sId = student['id'];
    final currentStatus = _statuses[sId] ?? '';
    final isPending = _pendingMap.containsKey(sId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: currentStatus.isEmpty ? Colors.grey.shade100 : _statusColor(currentStatus).withOpacity(0.15),
              child: currentStatus.isEmpty
                  ? Text('${index + 1}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14))
                  : Icon(_statusIcon(currentStatus), color: _statusColor(currentStatus), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(student['student_name'] ?? 'بدون اسم',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isPending ? Colors.orange.shade700 : Colors.black87)),
                      if (isPending) ...[
                        const SizedBox(width: 6),
                        const Text('⏳', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_statusLabel(currentStatus),
                      style: TextStyle(color: _statusColor(currentStatus), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusToggle(sId, 'present', Icons.check_circle, Colors.green),
                const SizedBox(width: 2),
                _statusToggle(sId, 'absent', Icons.cancel, Colors.red),
                const SizedBox(width: 2),
                _statusToggle(sId, 'excused', Icons.pause_circle, Colors.orange),
                if (isPending) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _editPending(sId),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.edit, color: Colors.amber, size: 16),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusToggle(int studentId, String status, IconData icon, Color color) {
    final isSelected = _statuses[studentId] == status;
    return GestureDetector(
      onTap: () => setState(() => _statuses[studentId] = isSelected ? '' : status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade400, size: 20),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final newDate = picked.toIso8601String().split('T')[0];
      if (newDate.compareTo(DateTime.now().toIso8601String().split('T')[0]) > 0) {
        CustomSnackbar.show(context, message: 'لا يمكن اختيار تاريخ مستقبلي', color: Colors.red, icon: Icons.block);
        return;
      }
      setState(() {
        _selectedDate = newDate;
        _dateInvalid = false;
        _statuses.clear();
        _pendingMap.clear();
      });
      _fetchStudents();
    }
  }

  Future<void> _editPending(int studentId) async {
    final pending = _pendingMap[studentId];
    if (pending == null) return;
    final localId = pending['local_id'] as int;
    final currentStatus = pending['status'] as String;

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('تعديل السجل المعلق', style: TextStyle(fontWeight: FontWeight.bold)),
        children: ['present', 'absent', 'excused'].map((s) {
          return RadioListTile<String>(
            title: Text(_statusLabel(s)),
            value: s,
            groupValue: currentStatus,
            onChanged: (val) => Navigator.pop(ctx, val),
          );
        }).toList(),
      ),
    );

    if (chosen != null && chosen != currentStatus) {
      final ok = await _attendanceService.updatePendingAttendance(localId, chosen);
      if (ok && mounted) {
        setState(() { _statuses[studentId] = chosen; _pendingMap[studentId] = {...pending, 'status': chosen}; });
        CustomSnackbar.show(context, message: 'تم التعديل', color: Colors.green, icon: Icons.check_circle);
      }
    } else if (chosen == null) {
      final delete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حذف السجل؟'),
          content: const Text('سيتم حذف سجل الحضور من قائمة الانتظار.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (delete == true) {
        final ok = await _attendanceService.deletePendingAttendance(localId);
        if (ok && mounted) {
          setState(() { _pendingMap.remove(studentId); _statuses[studentId] = ''; });
          CustomSnackbar.show(context, message: 'تم الحذف', color: Colors.orange, icon: Icons.delete);
        }
      }
    }
  }

  Widget _buildBottomBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(isDark ? 0.0 : 0.05), blurRadius: 10, offset: const Offset(0, -5)),
      ]),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAttendance,
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload),
            label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ الحضور'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    final marked = _statuses.values.where((s) => s.isNotEmpty);
    if (marked.isEmpty) {
      CustomSnackbar.show(context, message: 'لم يتم تحديد أي طالب', color: Colors.orange, icon: Icons.warning_amber_rounded);
      return;
    }

    // التحقق من أن التاريخ ضمن أيام الدورة
    final prefs = await SharedPreferences.getInstance();
    final courseId = prefs.getInt('last_course_id') ?? 0;
    if (courseId > 0) {
      final valid = await _courseService.isDateWithinCourse(courseId, _selectedDate);
      if (!valid && mounted) {
        setState(() {
          _dateInvalid = true;
          _dateError = 'لا يمكن الحفظ في هذا التاريخ — اليوم خارج أيام الدورة أو تاريخ مستقبلي';
        });
        CustomSnackbar.show(context, message: _dateError, color: Colors.red, icon: Icons.block);
        return;
      }
    }

    setState(() => _isSaving = true);
    final db = DatabaseHelper.instance;
    int savedCount = 0;

    for (var entry in _statuses.entries) {
      if (entry.value.isNotEmpty) {
        final existing = _pendingMap[entry.key];
        if (existing != null && existing['local_id'] != null) {
          await db.update('pending_attendance', {'status': entry.value, 'action': 'update'}, 'id = ?', [existing['local_id']]);
        } else if (existing != null) {
          // synced record → insert كسجل تعديل
          await db.insert('pending_attendance', {
            'enrollment_id': entry.key, 'date': _selectedDate, 'status': entry.value,
            'circle_id': widget.circleId, 'action': 'update',
            'created_at': DateTime.now().toIso8601String(),
          });
        } else {
          await db.insert('pending_attendance', {
            'enrollment_id': entry.key, 'date': _selectedDate, 'status': entry.value,
            'circle_id': widget.circleId, 'created_at': DateTime.now().toIso8601String(),
          });
        }
        savedCount++;
      }
    }

    final result = await SyncManager.instance.syncAll();
    pendingCountNotifier.value = (pendingCountNotifier.value + savedCount).clamp(0, 999999);

    if (mounted) {
      setState(() {
        _isSaving = false;
        // تحديث _existingRecords لعكس التغييرات الجديدة
        _existingRecords = [];
        for (var entry in _statuses.entries) {
          if (entry.value.isNotEmpty) {
            _pendingMap[entry.key] = {
              'local_id': _pendingMap[entry.key]?['local_id'],
              'status': entry.value,
              'sync_status': 'pending',
            };
            // إضافة للسجلات المعروضة
            _existingRecords.add({
              'student_name': _students.firstWhere(
                (s) => s['id'] == entry.key,
                orElse: () => {'student_name': 'طالب', 'id': 0},
              )['student_name'] ?? 'طالب',
              'status': entry.value,
              'date': _selectedDate,
              'sync_status': 'pending',
            });
          }
        }
      });
      if (result.successCount > 0) {
        CustomSnackbar.show(context, message: 'تم حفظ وإرسال $savedCount سجل ✅', color: Colors.green, icon: Icons.check_circle);
      } else if (result.failCount > 0) {
        CustomSnackbar.show(context, message: 'حفظ $savedCount محلياً — المزامنة قيد الانتظار ⏳', color: Colors.orange, icon: Icons.cloud_upload);
      } else {
        CustomSnackbar.show(context, message: 'تم حفظ $savedCount سجل محلياً', color: Colors.green, icon: Icons.check_circle);
      }
    }
  }
}


