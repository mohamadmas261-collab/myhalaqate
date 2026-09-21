import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';

/// Modal لعرض تفاصيل الطالب: معلوماته + إحصائيات الحضور + سجل الحضور
class StudentAttendanceModal extends StatefulWidget {
  final int enrollmentId;
  final String studentName;
  final int? studentId;

  const StudentAttendanceModal({
    Key? key,
    required this.enrollmentId,
    required this.studentName,
    this.studentId,
  }) : super(key: key);

  @override
  State<StudentAttendanceModal> createState() => _StudentAttendanceModalState();
}

class _StudentAttendanceModalState extends State<StudentAttendanceModal> {
  final Dio _dio = ApiClient().dio;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _studentInfo;
  int _totalPresent = 0;
  int _totalAbsent = 0;
  int _totalExcused = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
    _loadStudentInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreRecords();
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_student_attendance_${widget.enrollmentId}';
    bool fetched = false;
    try {
      final response = await _dio.get(
        '/api/attendance/?enrollment=${widget.enrollmentId}&ordering=-date',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> results = data is Map ? (data['results'] ?? []) : (data ?? []);
        _hasMore = data is Map && data['next'] != null;
        _records = results.map((r) => Map<String, dynamic>.from(r)).toList();
        _computeStats();
        fetched = true;
        // تحديث الكاش بالصفحة الأولى
        try {
          await prefs.setString(cacheKey, jsonEncode(_records));
        } catch (_) {}
      }
    } catch (_) {
      // فشل الاتصال — نعرض آخر نسخة محفوظة
    }
    if (!fetched) {
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        try {
          final list = jsonDecode(cached) as List;
          _records = list.map((r) => Map<String, dynamic>.from(r)).toList();
          _hasMore = false; // بلا اتصال لا يوجد تحميل صفحات إضافية
          _computeStats();
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final response = await _dio.get(
        '/api/attendance/?enrollment=${widget.enrollmentId}&ordering=-date&page=${_currentPage + 1}',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> results = data is Map ? (data['results'] ?? []) : (data ?? []);
        _hasMore = data is Map && data['next'] != null;
        _currentPage++;
        _records.addAll(results.map((r) => Map<String, dynamic>.from(r)).toList());
        _computeStats();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _loadStudentInfo() async {
    if (widget.studentId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_student_info_${widget.studentId}';
    try {
      final response = await _dio.get('/api/students/${widget.studentId}/');
      if (response.statusCode == 200) {
        final info = Map<String, dynamic>.from(response.data);
        if (mounted) setState(() => _studentInfo = info);
        try {
          await prefs.setString(cacheKey, jsonEncode(info));
        } catch (_) {}
        return;
      }
    } catch (_) {
      // فشل الاتصال — نعرض آخر نسخة محفوظة
    }
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final info = Map<String, dynamic>.from(jsonDecode(cached));
        if (mounted) setState(() => _studentInfo = info);
      } catch (_) {}
    }
  }

  void _computeStats() {
    _totalPresent = 0;
    _totalAbsent = 0;
    _totalExcused = 0;
    for (final r in _records) {
      switch (r['status']) {
        case 'present': _totalPresent++; break;
        case 'absent': _totalAbsent++; break;
        case 'excused': _totalExcused++; break;
      }
    }
  }

  double get _attendancePercentage {
    final total = _totalPresent + _totalAbsent + _totalExcused;
    if (total == 0) return 0;
    return (_totalPresent / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // مقبض السحب
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // الرأس
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // المعلومات الشخصية
                      if (_studentInfo != null) _buildPersonalInfo(),
                      // الإحصائيات
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      // سجل الحضور
                      const Text('سجل الحضور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text('لا توجد سجلات حضور',
                            style: TextStyle(color: Colors.grey.shade500))),
                        )
                      else
                        ..._records.map((r) => _buildRecordTile(r)),
                      if (_isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!_hasMore && _records.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(child: Text('— نهاية السجل —',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    final phone = _studentInfo?['phone'] ?? '';
    final birth = _studentInfo?['date_of_birth'] ?? '';
    if (phone.toString().isEmpty && birth.toString().isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المعلومات الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (phone.toString().isNotEmpty)
              Row(children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('$phone', style: const TextStyle(fontSize: 13)),
              ]),
            if (birth.toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('$birth', style: const TextStyle(fontSize: 13)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final total = _totalPresent + _totalAbsent + _totalExcused;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: AppColors.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('إحصائيات الحضور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('حاضر', _totalPresent, Colors.green, Icons.check_circle),
                _statItem('غائب', _totalAbsent, Colors.red, Icons.cancel),
                _statItem('مستأذن', _totalExcused, Colors.orange, Icons.pause_circle),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text('${_attendancePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                      color: _attendancePercentage >= 75 ? Colors.green : Colors.orange)),
                  const Text('نسبة الحضور', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
                Column(children: [
                  Text('$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text('إجمالي السجلات', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int count, Color color, IconData icon) {
    return Column(children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 4),
      Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }

  Widget _buildRecordTile(Map<String, dynamic> record) {
    Color color; String text; IconData icon;
    switch (record['status']) {
      case 'present': color = Colors.green; text = 'حاضر'; icon = Icons.check_circle; break;
      case 'absent': color = Colors.red; text = 'غائب'; icon = Icons.cancel; break;
      case 'excused': color = Colors.orange; text = 'مستأذن'; icon = Icons.pause_circle; break;
      default: color = Colors.grey; text = 'غير محدد'; icon = Icons.help; break;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text('${record['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// عرض الـ Modal
void showStudentAttendanceModal(BuildContext context, {
  required int enrollmentId,
  required String studentName,
  int? studentId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StudentAttendanceModal(
      enrollmentId: enrollmentId,
      studentName: studentName,
      studentId: studentId,
    ),
  );
}
