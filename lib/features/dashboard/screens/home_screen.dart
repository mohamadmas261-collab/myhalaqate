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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CourseService _courseService = CourseService();

  bool _isLoading = true;
  List<dynamic> _courses = [];
  String _syncStatus = 'connected';
  int _pendingCount = 0;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _listenToConnectivity();
    pendingCountNotifier.addListener(_onPendingChanged);
  }

  void _onPendingChanged() => _checkPendingCount();

  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      setState(() => _syncStatus = isConnected ? 'connected' : 'offline');
      if (isConnected) {
        _checkPendingCount();
        setState(() => _syncStatus = 'syncing');
        SyncManager.instance.syncAll().then((result) {
          _checkPendingCount();
          if (mounted && result.hasFailed) setState(() => _syncStatus = 'error');
        });
      }
    });
    _checkPendingCount();
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
        if (_syncStatus == 'syncing') return;
        if (failedTotal > 0) { _syncStatus = 'error'; }
        else if (_syncStatus != 'offline') { _syncStatus = total > 0 ? 'pending' : 'connected'; }
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    pendingCountNotifier.removeListener(_onPendingChanged);
    super.dispose();
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
        message = 'جاري المزامنة...'; break;
      case 'syncing':
        bgColor = Colors.blue.withOpacity(0.1); textColor = Colors.blue; icon = Icons.sync;
        message = 'جاري المزامنة...'; break;
      case 'error':
        bgColor = Colors.orange.withOpacity(0.1); textColor = Colors.orange.shade700; icon = Icons.warning_amber_rounded;
        message = 'جاري إعادة المحاولة...'; break;
      default:
        bgColor = Colors.green.withOpacity(0.1); textColor = Colors.green; icon = Icons.cloud_done;
        message = 'جميع البيانات محفوظة';
    }
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16), color: bgColor,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: textColor, size: 16),
        const SizedBox(width: 8),
        Text(message, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دوراتي', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const SyncAppBarAction(),
          IconButton(
            icon: Icon(_syncStatus == 'syncing' ? Icons.sync : Icons.refresh),
            onPressed: () => _loadCourses(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSyncStatusBar(),
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
    final courseId = course['id'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_course_id', courseId);
    final title = course['title'] ?? '';

    final circles = await _getCirclesForCourse(courseId);
    if (!mounted) return;
    if (circles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد حلقات في هذه الدورة'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CirclesScreen(courseTitle: title, circles: circles, courseId: courseId),
    ));
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
}

// شاشة عرض حلقات الدورة (بطاقات)
class _CirclesScreen extends StatelessWidget {
  final String courseTitle;
  final List<dynamic> circles;
  final int courseId;

  const _CirclesScreen({
    required this.courseTitle,
    required this.circles,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(courseTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${circles.length} حلقات',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          ...circles.map((circle) => _buildCircleCard(context, circle)),
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
              courseId: courseId,
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

