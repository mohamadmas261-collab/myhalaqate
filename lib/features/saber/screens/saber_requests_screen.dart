import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:myhalaqat/features/saber/services/saber_service.dart';

class SaberRequestsScreen extends StatefulWidget {
  const SaberRequestsScreen({Key? key}) : super(key: key);

  @override
  State<SaberRequestsScreen> createState() => _SaberRequestsScreenState();
}

class _SaberRequestsScreenState extends State<SaberRequestsScreen>
    with SingleTickerProviderStateMixin {
  final SaberService _saberService = SaberService();
  late TabController _tabController;

  bool _isLoading = true;
  List<dynamic> _allRequests = [];

  List<dynamic> get _pendingRequests =>
      _allRequests.where((r) => r['status'] == 'pending').toList();
  List<dynamic> get _completedRequests =>
      _allRequests.where((r) => r['status'] == 'completed').toList();
  List<dynamic> get _rejectedRequests =>
      _allRequests.where((r) => r['status'] == 'rejected').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final data = await _saberService.getMySaberRequests();
    if (mounted) {
      setState(() {
        _allRequests = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات السبر',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'الكل (${_allRequests.length})'),
            Tab(text: 'معلقة (${_pendingRequests.length})'),
            Tab(text: 'مكتملة (${_completedRequests.length})'),
            Tab(text: 'مرفوضة (${_rejectedRequests.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_allRequests),
                _buildList(_pendingRequests),
                _buildList(_completedRequests),
                _buildList(_rejectedRequests),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('لا توجد طلبات',
                style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(requests[index]);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final String studentName = req['student_name'] ?? 'بدون اسم';
    final String quizType = req['quiz_type'] == 'new' ? 'جديد' : 'مراجعة';
    final String content = req['part_name'] ?? 'غير محدد';
    final String date = req['requested_at']?.toString().split(' ')[0] ?? '';
    final String teacherNotes = req['teacher_notes'] ?? '';
    final String? adminNotes = req['admin_notes'];
    final bool isPending = req['status'] == 'pending';
    final bool isLocal = req['is_local'] == true;

    // --- لون وأيقونة الحالة ---
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (req['status']) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusText = 'مكتمل';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        statusText = 'مرفوض';
        break;
      default:
        statusColor = isLocal ? Colors.blue : Colors.orange;
        statusIcon = isLocal ? Icons.cloud_upload_outlined : Icons.hourglass_empty;
        statusText = isLocal ? 'بانتظار الرفع' : 'معلق (في الإدارة)';
    }

    // --- نتيجة السبر ---
    String? resultText;
    if (req['status'] == 'completed' && req['admin_score'] != null) {
      int score = double.tryParse(req['admin_score'].toString())?.toInt() ?? 0;
      int maxScore = double.tryParse(req['admin_max_score'].toString())?.toInt() ?? 100;
      resultText = '$score / $maxScore';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Column(
        children: [
          // --- هيدر الكارد ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- تفاصيل الطلب ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildDetailItem(Icons.bookmark_outline, 'نوع السبر', 'سبر $quizType'),
                    const SizedBox(width: 16),
                    _buildDetailItem(Icons.menu_book, 'الجزء', content),
                  ],
                ),
                if (teacherNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('ملاحظاتي: $teacherNotes', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (adminNotes != null && adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: req['status'] == 'rejected' ? Colors.red[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      req['status'] == 'rejected' ? 'سبب الرفض: $adminNotes' : 'ملاحظات الإدارة: $adminNotes',
                      style: TextStyle(color: req['status'] == 'rejected' ? Colors.red[900] : Colors.blue[900], fontSize: 13),
                    ),
                  ),
                ],
                if (resultText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grade, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('النتيجة: $resultText', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --- أزرار التعديل والحذف للمعلق فقط ---
          if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // تمرير isLocal للسيرفس لمعرفة هل يعدل محلياً أم في السيرفر
                      onPressed: () => _showEditDialog(req['id'], teacherNotes, req['is_local'] == true),
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('تعديل'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      // تمرير isLocal
                      onPressed: () => _showDeleteDialog(req['id'], req['is_local'] == true),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('حذف'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int requestId, String currentNotes, bool isLocal) {
    final TextEditingController notesController = TextEditingController(text: currentNotes);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل الملاحظات', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: notesController,
          decoration: InputDecoration(
            hintText: 'اكتب ملاحظاتك الجديدة هنا...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              bool success = await _saberService.updateSaberRequest(requestId, notesController.text.trim(), isLocal: isLocal);
              if (success) {
                _fetchRequests();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم تعديل الطلب بنجاح'), backgroundColor: Colors.green),
                  );
                }
              } else {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('حفظ التعديل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int requestId, bool isLocal) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: 'حذف الطلب',
      desc: 'هل أنت متأكد أنك تريد حذف طلب السبر هذا؟',
      btnCancelOnPress: () {},
      btnCancelText: 'إلغاء',
      btnOkOnPress: () async {
        setState(() => _isLoading = true);
        bool success = await _saberService.deleteSaberRequest(requestId, isLocal: isLocal);
        if (success) {
          _fetchRequests();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حذف الطلب'), backgroundColor: Colors.red),
            );
          }
        } else {
          setState(() => _isLoading = false);
        }
      },
      btnOkText: 'نعم، احذف',
      btnOkColor: Colors.red,
    ).show();
  }
}