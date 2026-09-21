import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/widgets/sync_indicator.dart';
import 'package:myhalaqat/features/circles/services/course_service.dart';
import 'package:myhalaqat/features/circles/screens/circle_details_screen.dart';
import 'package:myhalaqat/features/pending/screens/pending_items_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CourseService _courseService = CourseService();

  bool _isLoading = true;
  bool _isOpeningCourse = false;
  List<dynamic> _courses = [];
  String _syncStatus = 'connected'; // connected, pending, syncing, error, offline
  bool _isSyncing = false;
  int _pendingCount = 0;
  int _failedCount = 0;
  int _justSyncedCount = 0;
  int _justFailedCount = 0;
  bool _showSyncDialog = false;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _listenToConnectivity();
    pendingCountNotifier.addListener(_onPendingChanged);
  }

  void _onPendingChanged() {
    _checkPendingCount();
    // تحديث الواجهة في الوقت الحقيقي عند تغيير عداد المعلقات
    if (_pendingCount == 0 && _failedCount == 0 && !_isSyncing) {
      setState(() => _syncStatus = 'connected');
    }
  }

  void _listenToConnectivity() {
    bool isFirstConnect = true;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (!isConnected) {
        setState(() { _syncStatus = 'offline'; _isSyncing = false; });
        return;
      }
      _runSync(isFirstConnect);
      if (isFirstConnect) isFirstConnect = false;
    });
    // أول اتصال عند فتح التطبيق
    Connectivity().checkConnectivity().then((results) {
      if (!results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other)) {
        _runSync(true);
      }
    });
    _checkPendingCount();
  }

  Future<void> _runSync(bool showNotification) async {
    _checkPendingCount();
    setState(() { _isSyncing = true; _syncStatus = 'syncing'; });
    final result = await SyncManager.instance.syncAll();
    if (!mounted) return;
    _checkPendingCount();
    setState(() { _isSyncing = false; });
    // تحديث الحالة بناءً على نتيجة المزامنة
    if (result.successCount > 0 || result.failCount > 0) {
      setState(() {
        if (result.failCount > 0) {
          _syncStatus = 'error';
          _justFailedCount = result.failCount;
        } else {
          _syncStatus = 'connected';
          _justSyncedCount = result.successCount;
        }
        if (result.successCount > 0 && showNotification) {
          _showSyncDialog = true;
              Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() { _showSyncDialog = false; _justFailedCount = 0; }); });
        }
      });
    } else {
      _checkPendingCount();
    }
  }

  Future<void> _checkPendingCount() async {
    final db = DatabaseHelper.instance;
    final att = await db.queryWhere('pending_attendance', 'sync_status = ? OR sync_status = ?', ['pending', 'sending']);
    final mem = await db.queryWhere('pending_memorizations', 'sync_status = ? OR sync_status = ?', ['pending', 'sending']);
    final quiz = await db.queryWhere('pending_quiz_requests', 'sync_status = ? OR sync_status = ?', ['pending', 'sending']);
    final failedAtt = await db.queryWhere('pending_attendance', 'sync_status = ?', ['failed']);
    final failedMem = await db.queryWhere('pending_memorizations', 'sync_status = ?', ['failed']);
    final failedQuiz = await db.queryWhere('pending_quiz_requests', 'sync_status = ?', ['failed']);
    final failedTotal = failedAtt.length + failedMem.length + failedQuiz.length;
    final total = att.length + mem.length + quiz.length;
    if (mounted) {
      setState(() {
        _pendingCount = total;
        _failedCount = failedTotal;
        // إذا كانت المزامنة قيد التشغيل، نكتفي بتحديث الأعداد فقط دون تغيير الحالة
        if (_isSyncing) return;
        // تحديث الحالة بناءً على الوضع الحالي
        if (_syncStatus == 'offline') return;
        if (failedTotal > 0) { _syncStatus = 'error'; }
        else if (total > 0) { _syncStatus = 'pending'; }
        else { _syncStatus = 'connected'; }
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    pendingCountNotifier.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _openPendingScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingItemsScreen()));
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    final data = await _courseService.getMyCourses();
    if (mounted) {
      setState(() {
        _courses = data;
        _isLoading = false;
      });
      final prefs = await SharedPreferences.getInstance();
      if (data.isNotEmpty) {
        await prefs.setInt('last_course_id', data[0]['id'] ?? 0);
      }
    }
  }

  Widget _buildSyncStatusBar() {
    Color bgColor; Color textColor; IconData icon; String message;
    switch (_syncStatus) {
      case 'offline':
        bgColor = Colors.red.withOpacity(0.1); textColor = Colors.red; icon = Icons.cloud_off;
        message = 'غير متصل — يعمل من الذاكرة المحلية'; break;
      case 'pending':
        bgColor = Colors.orange.withOpacity(0.1); textColor = Colors.orange.shade700; icon = Icons.cloud_upload;
        message = _failedCount > 0
            ? '$_pendingCount معلق — $_failedCount فاشل'
            : '$_pendingCount طلب بانتظار المزامنة';
        break;
      case 'syncing':
        bgColor = Colors.blue.withOpacity(0.1); textColor = Colors.blue; icon = Icons.sync;
        message = _pendingCount > 0 || _failedCount > 0
            ? 'جاري المزامنة... ($_pendingCount معلق)'
            : 'جاري المزامنة...';
        break;
      case 'error':
        bgColor = Colors.red.withOpacity(0.1); textColor = Colors.red; icon = Icons.error_outline;
        message = _failedCount > 0
            ? 'فشلت المزامنة لـ $_failedCount طلب — اضغط للتفاصيل'
            : 'فشلت المزامنة — $_pendingCount طلب لم يُرسل';
        break;
      default: // connected
        bgColor = Colors.green.withOpacity(0.1); textColor = Colors.green; icon = Icons.cloud_done;
        message = _pendingCount == 0 && _failedCount == 0
            ? 'جميع البيانات محدثة ✅'
            : 'مزامن — $_pendingCount معلق';
    }
    return GestureDetector(
      onTap: _openPendingScreen,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16), color: bgColor,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دوراتي', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          SyncAppBarAction(
            onViewPending: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingItemsScreen())),
          ),
          IconButton(
            icon: Icon(_syncStatus == 'syncing' ? Icons.sync : Icons.refresh),
            onPressed: () => _loadCourses(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildSyncStatusBar(),
              _buildPendingSummaryCard(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _courses.isEmpty
                        ? const Center(child: Text('لا توجد دورات مسندة إليك.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                        : RefreshIndicator(
                            onRefresh: _loadCourses,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _courses.length,
                              itemBuilder: (context, index) => _buildCourseCard(_courses[index]),
                            ),
                          ),
              ),
            ],
          ),
          if (_showSyncDialog && _justSyncedCount > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16, right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.green.shade50,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
              child: Row(children: [
                Icon(_justFailedCount > 0 ? Icons.warning : Icons.check_circle,
                    color: _justFailedCount > 0 ? Colors.orange.shade600 : Colors.green.shade600, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_justFailedCount > 0 ? 'تمت المزامنة مع أخطاء' : 'تمت المزامنة ✅',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  Text(_justFailedCount > 0
                      ? '$_justSyncedCount نجح — $_justFailedCount فشل'
                      : '$_justSyncedCount طلب',
                      style: TextStyle(color: _justFailedCount > 0 ? Colors.orange.shade700 : Colors.green.shade700, fontSize: 13)),
                ])),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  onPressed: () => setState(() { _showSyncDialog = false; _justSyncedCount = 0; _justFailedCount = 0; }),
                ),
              ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingSummaryCard() {
    final hasPending = _pendingCount > 0 || _failedCount > 0;
    final iconColor = hasPending ? AppColors.warning : Colors.green;
    final icon = hasPending ? Icons.cloud_upload : Icons.cloud_done;
    final title = hasPending ? 'طلبات المزامنة' : 'حالة المزامنة';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openPendingScreen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  hasPending
                      ? Row(children: [
                          if (_pendingCount > 0)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('$_pendingCount معلق', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold))),
                          if (_pendingCount > 0 && _failedCount > 0) const SizedBox(width: 6),
                          if (_failedCount > 0)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('$_failedCount فاشل', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                        ])
                      : Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('جميع البيانات محدثة', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))),
                        ]),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(dynamic course) {
    final title = course['title'] ?? 'بدون عنوان';
    final desc = course['description'] ?? '';
    final days = course['days'] ?? [];
    final startDate = course['start_date']?.toString().substring(0, 10) ?? '';
    final endDate = course['end_date']?.toString().substring(0, 10) ?? '';
    final isActive = course['is_active'] ?? true;
    // تحويل أيام الدورة إلى نص
    String daysText = '';
    if (days is List && days.isNotEmpty) {
      final names = days.map((d) {
        final trimmed = d.toString().trim();
        final num = CourseService.arabicDayToNum[trimmed];
        if (num != null) return CourseService.arabicDayNames[num] ?? trimmed;
        final asInt = int.tryParse(trimmed);
        if (asInt != null) return CourseService.arabicDayNames[asInt] ?? trimmed;
        return trimmed;
      }).toList();
      daysText = names.join(' - ');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCourseCircles(course),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [const Color(0xFF059669), const Color(0xFF047857)]
                  : [Colors.grey.shade400, Colors.grey.shade600],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.school, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(desc, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)), maxLines: 2),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.7), size: 18),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12, runSpacing: 8,
                children: [
                  if (startDate.isNotEmpty)
                    _buildInfoChip(Icons.calendar_today, startDate),
                  if (endDate.isNotEmpty)
                    _buildInfoChip(Icons.event, endDate),
                  if (daysText.isNotEmpty)
                    _buildInfoChip(Icons.repeat, daysText),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.greenAccent.withOpacity(0.2) : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'نشط' : 'منتهي',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.greenAccent : Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
      ],
    );
  }

  void _openCourseCircles(dynamic course) async {
    if (_isOpeningCourse) return; // منع الضغطات المتكررة
    setState(() => _isOpeningCourse = true);
    try {
      final courseId = course['id'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_course_id', courseId);
      final title = course['title'] ?? '';
      if (!mounted) return;
      // انتقال مباشر: شاشة الحلقات تعرض دائرة تحميل منعزلة على شاشة بيضاء
      // (بنفس أسلوب فتح الحلقة) بدلاً من النافذة المنبثقة
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _CirclesScreen(courseTitle: title, courseId: courseId),
      ));
    } finally {
      if (mounted) setState(() => _isOpeningCourse = false);
    }
  }
}

// شاشة عرض حلقات الدورة (بطاقات)
class _CirclesScreen extends StatefulWidget {
  final String courseTitle;
  final int courseId;

  const _CirclesScreen({
    required this.courseTitle,
    required this.courseId,
  });

  @override
  State<_CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<_CirclesScreen> {
  bool _isLoading = true;
  List<dynamic> _circles = [];

  @override
  void initState() {
    super.initState();
    _loadCircles();
  }

  Future<void> _loadCircles() async {
    final circles = await _getCirclesForCourse(widget.courseId);
    if (mounted) {
      setState(() { _circles = circles; _isLoading = false; });
    }
  }

  Future<List<dynamic>> _getCirclesForCourse(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_circles_$courseId';
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/api/circles/?course=$courseId');
      if (response.statusCode == 200) {
        final circles = response.data['results'] ?? [];
        await prefs.setString(cacheKey, jsonEncode(circles));
        return circles;
      }
    } catch (_) {}
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) return jsonDecode(cached);
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      // دائرة تحميل منعزلة على شاشة بيضاء أثناء الجلب (مثل فتح الحلقة)
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _circles.isEmpty
              ? const Center(
                  child: Text('لا توجد حلقات في هذه الدورة',
                      style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('${_circles.length} حلقات',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ),
                    ..._circles.map((circle) => _buildCircleCard(context, circle)),
                  ],
                ),
    );
  }

  Widget _buildCircleCard(BuildContext context, dynamic circle) {
    final name = circle['name'] ?? '';
    final teacher = circle['teacher_name'] ?? '';
    final circleId = circle['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CircleDetailsScreen(
              circleId: circleId,
              circleName: name,
              courseId: widget.courseId,
            ),
          ));
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF059669), const Color(0xFF047857)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.group_work, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(teacher, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),

                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

