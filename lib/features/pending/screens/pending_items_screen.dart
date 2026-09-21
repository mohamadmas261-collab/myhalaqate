import 'package:flutter/material.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/features/pending/services/pending_service.dart';
import 'package:myhalaqat/features/students/models/surahs_data.dart';

class PendingItemsScreen extends StatefulWidget {
  const PendingItemsScreen({Key? key}) : super(key: key);

  @override
  State<PendingItemsScreen> createState() => _PendingItemsScreenState();
}

class _PendingItemsScreenState extends State<PendingItemsScreen> with SingleTickerProviderStateMixin {
  final PendingService _service = PendingService();
  late TabController _tabController;
  List<PendingItem> _allItems = [];
  bool _isLoading = true;
  bool _isSyncingNow = false;
  String _sortBy = 'date_desc';
  final Set<int> _selectedIds = {};
  bool _selectAll = false;
  String _searchQuery = '';
  String? _dateFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _loadItems();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final all = await _service.getAllPending(sortBy: _sortBy, includeSynced: true);
    if (mounted) setState(() { _allItems = all; _isLoading = false; _selectedIds.clear(); _selectAll = false; });
  }

  List<PendingItem> get _filteredItems {
    var items = _allItems.where((i) {
      // filter by tab
      final tab = _tabController.index;
      if (tab == 1 && i.syncStatus != 'pending' && i.syncStatus != 'sending') return false;
      if (tab == 2 && i.syncStatus != 'failed') return false;
      if (tab == 3 && i.syncStatus != 'synced') return false;
      // filter by search
      if (_searchQuery.isNotEmpty && !i.studentName.toLowerCase().contains(_searchQuery)) return false;
      // filter by date
      if (_dateFilter != null && i.date != _dateFilter) return false;
      return true;
    }).toList();
    return items;
  }

  int get _tabCount => _tabController.index == 0 ? _allItems.length
      : _tabController.index == 1 ? _allItems.where((i) => i.syncStatus == 'pending' || i.syncStatus == 'sending').length
      : _tabController.index == 2 ? _allItems.where((i) => i.syncStatus == 'failed').length
      : _allItems.where((i) => i.syncStatus == 'synced').length;

  void _toggleSelectAll() {
    final items = _filteredItems;
    if (_selectAll) {
      _selectedIds.clear();
      _selectAll = false;
    } else {
      _selectedIds.addAll(items.map((i) => i.localId));
      _selectAll = true;
    }
    setState(() {});
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف المحدد'), content: Text('سيتم حذف ${_selectedIds.length} عنصر.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    final byType = <String, List<int>>{};
    for (final id in _selectedIds) {
      final item = _allItems.firstWhere((i) => i.localId == id);
      byType.putIfAbsent(item.entityType, () => []).add(id);
    }
    int deleted = 0;
    for (final e in byType.entries) deleted += await _service.deleteItems(e.value, e.key);
    if (mounted) { CustomSnackbar.show(context, message: 'تم حذف $deleted عنصر', color: Colors.green, icon: Icons.check_circle); _selectedIds.clear(); _selectAll = false; _loadItems(); }
  }

  Future<void> _retryAllFailed() async {
    final failed = _allItems.where((i) => i.syncStatus == 'failed');
    int retried = 0;
    for (final item in failed) {
      if (await _service.retryItem(item.localId, item.entityType)) retried++;
    }
    if (mounted) {
      CustomSnackbar.show(context, message: 'تمت إعادة محاولة $retried طلب', color: Colors.orange, icon: Icons.cloud_upload);
      _loadItems();
    }
  }

  Future<void> _pickDateFilter() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _dateFilter = picked.toIso8601String().split('T')[0]);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final hasSelection = _selectedIds.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(hasSelection ? '${_selectedIds.length} محدد' : 'سجل المزامنة', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: hasSelection ? [
          if (_filteredItems.length > _selectedIds.length)
            IconButton(icon: const Icon(Icons.select_all), tooltip: _selectAll ? 'إلغاء الكل' : 'تحديد الكل', onPressed: _toggleSelectAll),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'حذف المحدد', onPressed: _deleteSelected),
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectedIds.clear(); _selectAll = false; })),
        ] : [
          if (_tabController.index == 2 && _allItems.any((i) => i.syncStatus == 'failed'))
            IconButton(icon: const Icon(Icons.refresh, color: Colors.orange), tooltip: 'إعادة محاولة الكل', onPressed: _retryAllFailed),
          IconButton(icon: Icon(Icons.calendar_today, color: _dateFilter != null ? AppColors.warning : null), tooltip: 'فلترة بالتاريخ', onPressed: _pickDateFilter),
          if (_dateFilter != null)
            IconButton(icon: const Icon(Icons.clear), tooltip: 'إلغاء الفلتر', onPressed: () => setState(() => _dateFilter = null)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort), tooltip: 'ترتيب',
            onSelected: (v) => setState(() { _sortBy = v; _loadItems(); }),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'date_desc', child: const Text('التاريخ (الأحدث)')),
              PopupMenuItem(value: 'date_asc', child: const Text('التاريخ (الأقدم)')),
              PopupMenuItem(value: 'type', child: const Text('النوع')),
              PopupMenuItem(value: 'status', child: const Text('الحالة')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadItems),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'الكل (${_allItems.length})'),
            Tab(text: 'معلق (${_allItems.where((i) => i.syncStatus == 'pending' || i.syncStatus == 'sending').length})'),
            Tab(text: 'فاشل (${_allItems.where((i) => i.syncStatus == 'failed').length})'),
            Tab(text: 'متزامن (${_allItems.where((i) => i.syncStatus == 'synced').length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_searchCtrl.text.isNotEmpty || _dateFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.grey.shade100,
              child: Row(children: [
                if (_dateFilter != null) ...[
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('📅 $_dateFilter', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                ],
                if (_searchQuery.isNotEmpty)
                  Text('🔍 $_searchQuery', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث باسم الطالب...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true,
                suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _searchCtrl.clear) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('لا توجد عناصر', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _loadItems,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildItemCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _allItems.any((i) => i.syncStatus == 'pending' || i.syncStatus == 'sending' || i.syncStatus == 'failed')
          ? FloatingActionButton.extended(
              onPressed: _isSyncingNow ? null : () async {
                setState(() => _isSyncingNow = true);
                try {
                  await SyncManager.instance.syncAll();
                  await _loadItems();
                  if (mounted) CustomSnackbar.show(context, message: 'تمت المزامنة', color: Colors.green, icon: Icons.check_circle);
                } finally {
                  if (mounted) setState(() => _isSyncingNow = false);
                }
              },
              icon: _isSyncingNow
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              label: Text(_isSyncingNow ? 'جارٍ المزامنة...' : 'مزامنة الآن'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  String _formatDateTime(String raw) {
    try {
      // تحويل ISO 8601 إلى YYYY-MM-DD HH:MM
      if (raw.length >= 16) return raw.substring(0, 16).replaceAll('T', ' ');
      return raw;
    } catch (_) {
      return raw;
    }
  }

  Widget _buildItemCard(PendingItem item) {
    final isFailed = item.syncStatus == 'failed';
    final isSending = item.syncStatus == 'sending';
    final isSynced = item.syncStatus == 'synced';
    final isSelected = _selectedIds.contains(item.localId);
    Color statusColor; String statusText; IconData statusIcon;
    if (isSynced) {
      statusColor = Colors.green; statusText = 'متزامن'; statusIcon = Icons.cloud_done;
    } else if (isFailed) {
      statusColor = Colors.red; statusText = 'فاشل'; statusIcon = Icons.error;
    } else if (isSending) {
      statusColor = Colors.blue; statusText = 'جارٍ'; statusIcon = Icons.sync;
    } else {
      statusColor = AppColors.warning; statusText = 'معلق'; statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : isFailed ? BorderSide(color: Colors.red.shade200) : BorderSide.none,
      ),
      elevation: isSelected ? 4 : (isFailed ? 3 : 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          if (_selectedIds.contains(item.localId)) { _selectedIds.remove(item.localId); _selectAll = false; }
          else _selectedIds.add(item.localId);
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Checkbox(value: isSelected, onChanged: (_) {
                setState(() {
                  if (_selectedIds.contains(item.localId)) { _selectedIds.remove(item.localId); _selectAll = false; }
                  else _selectedIds.add(item.localId);
                });
              }, visualDensity: VisualDensity.compact),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _typeColor(item.entityType).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(item.displayName, style: TextStyle(color: _typeColor(item.entityType), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (item.date.isNotEmpty) Text(_formatDateTime(item.date), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 3),
                  Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
            if (item.circleName.isNotEmpty || item.courseName.isNotEmpty)
              Padding(padding: const EdgeInsets.only(right: 44, top: 4),
                child: Text('${item.courseName.isNotEmpty ? '${item.courseName} / ' : ''}${item.circleName}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10))),
            const SizedBox(height: 4),
            _buildDetailContent(item),
            // عرض سبب الحالة بوضوح لكل العناصر
            if (isSynced) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  const Text('تمت المزامنة بنجاح', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ] else if (item.lastError != null && item.lastError!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFailed ? Colors.red.shade50 : (item.syncStatus == 'pending' ? Colors.orange.shade50 : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFailed ? Colors.red.shade100 : (item.syncStatus == 'pending' ? Colors.orange.shade200 : Colors.blue.shade100)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(isFailed ? Icons.error_outline : (item.syncStatus == 'pending' ? Icons.hourglass_empty : Icons.info_outline), size: 14,
                    color: isFailed ? Colors.red.shade400 : (item.syncStatus == 'pending' ? Colors.orange : Colors.blue.shade400)),
                  const SizedBox(width: 6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (item.syncStatus == 'pending')
                      const Text('بانتظار إعادة المحاولة...', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(_cleanError(item.lastError!), style: TextStyle(color: isFailed ? Colors.red.shade700 : (item.syncStatus == 'pending' ? Colors.orange.shade700 : Colors.blue.shade700), fontSize: 11)),
                  ])),
                ]),
              ),
            ] else if (item.syncStatus == 'pending') ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                child: Row(children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  const Text('بانتظار المزامنة — اضغط "مزامنة الآن" للإرسال', style: TextStyle(color: Colors.blue, fontSize: 11)),
                ]),
              ),
            ],
            if (!isSynced && !isSending) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (isFailed)
                  TextButton.icon(
                    onPressed: () => _retrySingle(item),
                    icon: const Icon(Icons.refresh, size: 16), label: const Text('إعادة محاولة', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                TextButton.icon(
                  onPressed: () => _editItem(item),
                  icon: const Icon(Icons.edit, size: 16), label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () => _deleteSingle(item),
                  icon: const Icon(Icons.delete, size: 16), label: const Text('حذف', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailContent(PendingItem item) {
    switch (item.entityType) {
      case 'attendance':
        return Container(margin: const EdgeInsets.only(right: 44), child: Row(children: [
          Icon(Icons.circle, size: 10, color: _attColor(item.data['status'] as String? ?? '')),
          const SizedBox(width: 6),
          Text(item.statusText, style: TextStyle(fontWeight: FontWeight.bold, color: _attColor(item.data['status'] as String? ?? ''), fontSize: 13)),
          const SizedBox(width: 16),
          Icon(Icons.label, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(item.actionLabel, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]));
      case 'memorization':
        return Container(margin: const EdgeInsets.only(right: 44), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.data['surah_name'] ?? 'سورة'} (${item.data['from_ayah']}-${item.data['to_ayah']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(item.typeText, style: const TextStyle(color: Colors.blue, fontSize: 10))),
            const SizedBox(width: 8),
            Text('النتيجة: ${item.resultText}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
          if ((item.data['notes'] as String? ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('ملاحظات: ${item.data['notes']}', style: TextStyle(color: Colors.grey[500], fontSize: 11))),
        ]));
      case 'quiz_request':
        return Container(margin: const EdgeInsets.only(right: 44), child: Row(children: [
          Icon(Icons.auto_stories, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text('الجزء ${item.data['quran_part_id'] ?? '?'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 16),
          Text(item.quizTypeText, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          if ((item.data['teacher_notes'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(child: Text('"${item.data['teacher_notes']}"', style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis)),
          ],
        ]));
      default: return const SizedBox.shrink();
    }
  }

  String _cleanError(String e) => e.replaceFirst('[CLIENT_ERROR] ', '');
  Color _attColor(String s) => switch (s) { 'present' => Colors.green, 'absent' => Colors.red, 'excused' => Colors.orange, _ => Colors.grey };
  Color _typeColor(String t) => switch (t) { 'attendance' => Colors.green, 'memorization' => Colors.orange, 'quiz_request' => Colors.blue, _ => Colors.grey };

  Future<void> _editItem(PendingItem item) async {
    switch (item.entityType) {
      case 'attendance': await _editAttendance(item); break;
      case 'memorization':
        if (!mounted) return;
        await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _EditPendingMemorizationPage(item: item, service: _service)));
        break;
      case 'quiz_request': await _editQuizRequest(item); break;
    }
    _loadItems();
  }

  Future<void> _editAttendance(PendingItem item) async {
    final current = item.data['status'] ?? 'present';
    final labels = {'present': 'حاضر ✅', 'absent': 'غائب ❌', 'excused': 'مستأذن ⏸'};
    final chosen = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('تعديل الحضور المعلق', style: TextStyle(fontWeight: FontWeight.bold)),
      children: ['present', 'absent', 'excused'].map((s) => RadioListTile<String>(title: Text(labels[s] ?? s), value: s, groupValue: current, onChanged: (v) => Navigator.pop(ctx, v))).toList(),
    ));
    if (chosen != null && chosen != current) {
      await _service.updateAttendance(item.localId, chosen);
      if (mounted) CustomSnackbar.show(context, message: 'تم التعديل ✅', color: Colors.green, icon: Icons.check_circle);
    }
  }

  Future<void> _editQuizRequest(PendingItem item) async {
    final data = item.data;
    int selectedPart = data['quran_part_id'] as int? ?? 1;
    String quizType = data['quiz_type'] as String? ?? 'new';
    final notesCtrl = TextEditingController(text: data['teacher_notes'] as String? ?? '');
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      content: StatefulBuilder(builder: (ctx, setD) => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الجزء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(value: selectedPart, isDense: true, items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('الجزء ${i + 1}'))),
          onChanged: (v) => setD(() => selectedPart = v ?? 1), decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_stories), isDense: true)),
        const SizedBox(height: 12), const Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _choiceChip('حفظ جديد', 'new', quizType, AppColors.primary, (v) => setD(() => quizType = v))),
          const SizedBox(width: 12),
          Expanded(child: _choiceChip('مراجعة', 'review', quizType, AppColors.info, (v) => setD(() => quizType = v))),
        ]), const SizedBox(height: 12),
        TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'ملاحظات', prefixIcon: Icon(Icons.notes), isDense: true)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white), child: const Text('حفظ التعديل'))),
      ]))),
    ));
    notesCtrl.dispose();
    if (saved == true) {
      await _service.updateQuizRequest(item.localId, {'quran_part_id': selectedPart, 'quiz_type': quizType, 'teacher_notes': notesCtrl.text});
      if (mounted) CustomSnackbar.show(context, message: 'تم التعديل ✅', color: Colors.green, icon: Icons.check_circle);
    }
  }

  Widget _choiceChip(String label, String value, String current, Color color, void Function(String) onChanged) {
    final sel = current == value;
    return GestureDetector(onTap: () => onChanged(value), child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: sel ? color.withOpacity(0.1) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel ? color : Colors.grey.shade300, width: sel ? 2 : 1)),
      child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? color : Colors.grey, fontSize: 13)))));
  }

  Future<void> _deleteSingle(PendingItem item) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف العنصر'), content: Text('سيتم حذف ${item.displayName}: ${item.studentName}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red)))],
    ));
    if (confirm == true) { await _service.deleteItem(item.localId, item.entityType); if (mounted) { CustomSnackbar.show(context, message: 'تم الحذف ✅', color: Colors.green, icon: Icons.check_circle); _loadItems(); } }
  }

  Future<void> _retrySingle(PendingItem item) async {
    final ok = await _service.retryItem(item.localId, item.entityType);
    if (mounted) { if (ok) CustomSnackbar.show(context, message: 'تمت إعادة المحاولة', color: Colors.orange, icon: Icons.cloud_upload); _loadItems(); }
  }
}

// صفحة تعديل حفظ معلق
class _EditPendingMemorizationPage extends StatefulWidget {
  final PendingItem item; final PendingService service;
  const _EditPendingMemorizationPage({required this.item, required this.service});
  @override State<_EditPendingMemorizationPage> createState() => _EditPendingMemorizationPageState();
}

class _EditPendingMemorizationPageState extends State<_EditPendingMemorizationPage> {
  late Surah _surah; late int _fromAyah; late int _toAyah; late String _type; late String _result;
  final _notesCtrl = TextEditingController();
  @override void initState() {
    super.initState();
    final d = widget.item.data;
    _surah = surahs.firstWhere((s) => s.id == (d['surah_id'] ?? 1), orElse: () => surahs[0]);
    _fromAyah = d['from_ayah'] ?? 1; _toAyah = d['to_ayah'] ?? 1; _type = d['type'] ?? 'new'; _result = d['result'] ?? 'excellent';
    _notesCtrl.text = d['notes'] ?? '';
  }
  @override void dispose() { _notesCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعديل سجل الحفظ المعلق')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('السورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(value: _surah.id, isDense: true,
        items: surahs.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.number}. ${s.nameAr} (${s.totalAyahs})', style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
        onChanged: (v) => setState(() { _surah = surahs.firstWhere((s) => s.id == (v ?? 1)); _fromAyah = 1; _toAyah = _surah.totalAyahs; }),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.auto_stories), isDense: true)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _ayahField('من', 1, _surah.totalAyahs, _fromAyah, (v) { setState(() { _fromAyah = v; if (_fromAyah > _toAyah) _toAyah = _fromAyah; }); })),
        const SizedBox(width: 12),
        Expanded(child: _ayahField('إلى', _fromAyah, _surah.totalAyahs, _toAyah, (v) => setState(() => _toAyah = v))),
      ]),
      const Text('النوع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _chip('جديد', _type == 'new', () => setState(() => _type = 'new'))),
        const SizedBox(width: 12),
        Expanded(child: _chip('مراجعة', _type == 'review', () => setState(() => _type = 'review'))),
      ]),
      const Text('النتيجة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 8),
      Row(children: ['excellent', 'good', 'redo'].map((r) {
        final sel = _result == r;
        return Expanded(child: GestureDetector(onTap: () => setState(() => _result = r),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 14), margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(color: sel ? _rCol(r).withOpacity(0.15) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? _rCol(r) : Colors.grey.shade300, width: 2)),
            child: Column(children: [Icon(_rIco(r), color: sel ? _rCol(r) : Colors.grey, size: 28), const SizedBox(height: 4),
              Text(_rLab(r), style: TextStyle(fontWeight: FontWeight.bold, color: sel ? _rCol(r) : Colors.grey))]))));
      }).toList()),
      const SizedBox(height: 16),
      TextField(controller: _notesCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'ملاحظات...', prefixIcon: Icon(Icons.notes))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('حفظ التعديل'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]),
  );
  Widget _ayahField(String label, int min, int max, int value, void Function(int) onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 6),
    Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: value.clamp(min, max),
        items: List.generate(max - min + 1, (i) => DropdownMenuItem(value: min + i, child: Text('الآية ${min + i}', style: const TextStyle(fontWeight: FontWeight.bold)))),
        onChanged: (v) { if (v != null) onChanged(v); }))),
  ]);
  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: selected ? Colors.green.withOpacity(0.1) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: selected ? Colors.green : Colors.grey.shade300, width: selected ? 2 : 1)),
    child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.green : Colors.grey)))));
  Color _rCol(String r) => switch (r) { 'excellent' => AppColors.success, 'good' => AppColors.accent, _ => AppColors.warning };
  IconData _rIco(String r) => switch (r) { 'excellent' => Icons.auto_awesome, 'good' => Icons.thumb_up, _ => Icons.refresh };
  String _rLab(String r) => switch (r) { 'excellent' => 'ممتاز', 'good' => 'جيد', _ => 'إعادة' };
  Future<void> _save() async {
    final ok = await widget.service.updateMemorization(widget.item.localId, {
      'surah_id': _surah.id, 'surah_name': _surah.nameAr, 'from_ayah': _fromAyah, 'to_ayah': _toAyah, 'type': _type, 'result': _result, 'notes': _notesCtrl.text,
    });
    if (mounted) { if (ok) { CustomSnackbar.show(context, message: 'تم التعديل', color: Colors.green, icon: Icons.check_circle); Navigator.pop(context, true); } else CustomSnackbar.show(context, message: 'فشل التعديل', color: Colors.red, icon: Icons.error); }
  }
}
