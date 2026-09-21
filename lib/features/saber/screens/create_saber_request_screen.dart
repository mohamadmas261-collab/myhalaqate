import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';
import 'package:myhalaqat/features/saber/services/saber_service.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';

class CreateSaberRequestScreen extends StatefulWidget {
  final int circleId;
  const CreateSaberRequestScreen({Key? key, required this.circleId}) : super(key: key);

  @override
  State<CreateSaberRequestScreen> createState() => _CreateSaberRequestScreenState();
}

class _CreateSaberRequestScreenState extends State<CreateSaberRequestScreen> with SingleTickerProviderStateMixin {
  final StudentService _studentService = StudentService();
  final SaberService _saberService = SaberService();
  final TextEditingController _searchCtrl = TextEditingController();
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  List<dynamic> _previousRequests = [];
  List<dynamic> _pendingLocal = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _searchCtrl.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterStudents() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredStudents = query.isEmpty
          ? List.from(_students)
          : _students.where((s) => (s['student_name'] ?? '').toString().toLowerCase().contains(query)).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _studentService.getStudentsByCircle(widget.circleId),
      _saberService.getMySaberRequests(),
      _saberService.getPendingLocalRequests(),
    ]);
    if (mounted) {
      setState(() {
        _students = results[0];
        _filteredStudents = List.from(_students);
        _previousRequests = results[1];
        _pendingLocal = results[2];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب سبر'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'طلب سبر (${_filteredStudents.length})'),
            Tab(text: 'سجل الطلبات (${_previousRequests.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildRequestTab() {
    if (_students.isEmpty) {
      return const Center(child: Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'بحث عن طالب...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); })
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 12 + MediaQuery.of(context).padding.bottom + 16),
            children: _filteredStudents.map((s) => _buildStudentCard(s)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_previousRequests.isEmpty && _pendingLocal.isEmpty) {
      return const Center(child: Text('لا توجد طلبات سابقة', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_pendingLocal.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.hourglass_empty, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Text('بانتظار المزامنة (${_pendingLocal.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          ..._pendingLocal.map((r) => _buildPendingCard(r)),
          const SizedBox(height: 12),
        ],
        if (_previousRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.history, color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 10),
              Text('الطلبات السابقة (${_previousRequests.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          ..._previousRequests.map((r) => _buildRequestCard(r)),
        ],
      ],
    );
  }

  Widget _buildStudentCard(dynamic student) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showSaberForm(student),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(student['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> req) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          const Icon(Icons.hourglass_empty, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('طلب قيد المزامنة ⏳', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('الجزء ${req['quran_part_id'] ?? '?'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 22),
            tooltip: 'حذف الطلب',
            onPressed: () => _deletePendingRequest(req['id']),
          ),
        ]),
      ),
    );
  }

  Future<void> _deletePendingRequest(int localId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلب'),
        content: const Text('هل أنت متأكد من حذف هذا الطلب المعلق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _saberService.deleteSaberRequest(localId, isLocal: true);
    if (ok && mounted) {
      setState(() => _pendingLocal.removeWhere((r) => r['id'] == localId));
      CustomSnackbar.show(context, message: 'تم حذف الطلب', color: Colors.green, icon: Icons.check_circle);
    }
  }

  Future<void> _deleteServerRequest(int requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلب'),
        content: const Text('هل أنت متأكد من حذف هذا الطلب المعلق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await _saberService.deleteSaberRequest(requestId, isLocal: false);
    if (ok && mounted) {
      setState(() => _previousRequests.removeWhere((r) => r['id'] == requestId));
      CustomSnackbar.show(context, message: 'تم حذف الطلب', color: Colors.green, icon: Icons.check_circle);
    }
  }

  Future<void> _showSaberForm(dynamic student) async {
    int selectedPart = 1;
    String quizType = 'new';
    final notesCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.quiz, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(student['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                const SizedBox(height: 20),

                const Text('الجزء *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedPart,
                  items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('الجزء ${i + 1}'))),
                  onChanged: (v) => setDialogState(() => selectedPart = v ?? 1),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_stories)),
                ),
                const SizedBox(height: 16),

                const Text('النوع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _choiceChip('حفظ جديد', 'new', quizType, Icons.star, AppColors.primary, (v) => setDialogState(() => quizType = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _choiceChip('مراجعة', 'review', quizType, Icons.menu_book, AppColors.info, (v) => setDialogState(() => quizType = v))),
                ]),
                const SizedBox(height: 16),

                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'ملاحظات للمشرف (اختياري)...',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('إرسال الطلب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    notesCtrl.dispose();
    if (saved == true) {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = !connectivity.contains(ConnectivityResult.none) && !connectivity.contains(ConnectivityResult.other);

      if (isOnline) {
        final ok = await _saberService.createSaberRequestOnline(
          enrollmentId: student['id'],
          quranPart: selectedPart,
          quizType: quizType,
          teacherNotes: notesCtrl.text,
        );
        if (mounted) {
          if (ok) {
            CustomSnackbar.show(context, message: 'تم إرسال طلب السبر بنجاح ✅', color: Colors.green, icon: Icons.check_circle);
          } else {
            CustomSnackbar.show(context, message: 'فشل الإرسال، حفظ محلياً', color: Colors.orange, icon: Icons.warning);
          }
          _loadData();
        }
      } else {
        await _saberService.createSaberRequest(
          enrollmentId: student['id'],
          quranPart: selectedPart,
          quizType: quizType,
          teacherNotes: notesCtrl.text,
        );
        if (mounted) {
          CustomSnackbar.show(context, message: 'حفظ محلياً — سيرسل فور توفر الإنترنت', color: Colors.orange, icon: Icons.cloud_upload);
          _loadData();
        }
      }
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'pending';
    final score = double.tryParse((req['admin_score'] ?? '').toString()) ?? 0;
    final maxScore = double.tryParse((req['admin_max_score'] ?? '').toString()) ?? 100;
    final percentage = maxScore > 0 ? (score / maxScore * 100) : 0.0;
    final isFailed = status == 'completed' && percentage < 50;
    final bool isPending = status == 'pending';
    Color statusColor; String statusText; IconData statusIcon;
    if (isFailed) {
      statusColor = Colors.red; statusText = 'راسب'; statusIcon = Icons.cancel;
    } else switch (status) {
      case 'completed': statusColor = Colors.green; statusText = 'ناجح'; statusIcon = Icons.check_circle; break;
      case 'rejected': statusColor = Colors.red; statusText = 'مرفوض'; statusIcon = Icons.cancel; break;
      default: statusColor = Colors.orange; statusText = 'معلق'; statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(req['student_name'] ?? 'طالب', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            if (isPending)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                tooltip: 'حذف الطلب',
                onPressed: () => _deleteServerRequest(req['id']),
              ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.auto_stories, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('الجزء ${req['quran_part'] ?? '?'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(width: 16),
            Text(req['quiz_type'] == 'new' ? 'حفظ جديد' : 'مراجعة', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const Spacer(),
            if (status == 'completed')
              Text('$score/$maxScore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isFailed ? Colors.red : Colors.green)),
          ]),
          if (req['admin_notes'] != null && (req['admin_notes'] as String).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('ملاحظة: ${req['admin_notes']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ),
        ]),
      ),
    );
  }

  Widget _choiceChip(String label, String value, String current, IconData icon, Color color, void Function(String) onChanged) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
