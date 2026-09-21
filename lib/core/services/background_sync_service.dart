import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart' show AndroidServiceInstance;
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/utils/app_state_helper.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/network/api_client.dart';

class BackgroundSyncService {
  static final BackgroundSyncService instance = BackgroundSyncService._();
  BackgroundSyncService._();

  static const int syncIntervalMinutes = 5;

  Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'myhalaqat_sync_channel',
        initialNotificationTitle: 'مزامنة حلقات القرآن',
        initialNotificationContent: 'جاري التشغيل...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> start() async {
    try {
      await AppStateHelper.setForeground(true);
      final service = FlutterBackgroundService();
      await service.startService();
    } catch (e) {
      print('⚠️ الخدمة الخلفية لم تبدأ: $e');
    }
  }

  /// تحديث الإشعار مباشرة من التطبيق (فقط إذا الخدمة شغالة)
  static void updateNotification(String title, String content) {
    try {
      final service = FlutterBackgroundService();
      service.invoke('setNotificationInfo', {
        'title': title,
        'content': content,
      });
    } catch (_) {}
  }

  /// إيقاف الخدمة نهائياً (يخفي الإشعار)
  static void stop() {
    try {
      final service = FlutterBackgroundService();
      service.invoke('setForegroundMode', {'value': false});
      service.invoke('stopService');
    } catch (_) {}
  }

  /// إيقاف الخدمة إذا لا توجد طلبات معلقة (يُستدعى عند طي التطبيق)
  static Future<void> stopIfIdle() async {
    try {
      int pending = 0;
      final db = DatabaseHelper.instance;
      for (final table in ['pending_attendance', 'pending_memorizations', 'pending_quiz_requests']) {
        final items = await db.queryWhere(table,
            'sync_status = ? OR sync_status = ? OR sync_status = ?',
            ['pending', 'sending', 'failed']);
        pending += items.length;
      }
      if (pending == 0) {
        FlutterBackgroundService().invoke('setForegroundMode', {'value': false});
        await Future.delayed(const Duration(milliseconds: 200));
        FlutterBackgroundService().invoke('stopService');
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  try { WidgetsFlutterBinding.ensureInitialized(); } catch (_) {}
  _initBaseUrlAsync().then((_) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none) && !results.contains(ConnectivityResult.other)) {
        _runSync(service);
      }
    });

    _runSync(service);

    Timer.periodic(const Duration(seconds: 30), (_) {
      _updateNotificationFromDb(service);
    });

    Timer.periodic(const Duration(minutes: BackgroundSyncService.syncIntervalMinutes), (_) {
      _runSync(service);
    });
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  try { WidgetsFlutterBinding.ensureInitialized(); } catch (_) {}
  await _initBaseUrlAsync();
  try { await SyncManager.instance.syncAll(); } catch (_) {}
  return true;
}

Future<void> _initBaseUrlAsync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('cached_base_url');
    ApiClient.forceBaseUrl((url != null && url.isNotEmpty) ? url : 'http://10.0.2.2:8000');
  } catch (_) {
    ApiClient.forceBaseUrl('http://10.0.2.2:8000');
  }
}

Future<void> _runSync(ServiceInstance service) async {
  _updateNotification(service, 'مزامنة حلقات القرآن', '🔄 جاري المزامنة...');
  try {
    final result = await SyncManager.instance.syncAll();
    final now = DateTime.now().toString().substring(0, 19);

    int pendingAfter = 0, failedAfter = 0;
    try {
      pendingAfter = await _countStatus('pending', 'sending');
      failedAfter = await _countStatus('failed');
    } catch (_) {}

    String status;
    if (result.successCount > 0 && result.failCount == 0 && pendingAfter == 0 && failedAfter == 0) {
      status = '✅ تمت مزامنة ${result.successCount} طلب';
    } else if (result.successCount > 0 && result.failCount > 0) {
      status = '✅ ${result.successCount} نجح ⚠️ ${result.failCount} فشل';
    } else if (result.successCount > 0 && pendingAfter > 0) {
      status = '✅ ${result.successCount} أُرسل — $pendingAfter متبقي';
    } else if (failedAfter > 0) {
      status = '⚠️ $failedAfter فشل — $pendingAfter معلق';
    } else if (pendingAfter > 0) {
      status = '⏳ $pendingAfter بانتظار الإرسال';
    } else {
      status = '✅ محدثة';
    }
    _updateNotification(service, 'مزامنة حلقات القرآن', '$status — $now');

    // نوقف الخدمة فقط إذا التطبيق في الخلفية ولا توجد طلبات
    if (pendingAfter == 0 && failedAfter == 0 && !await AppStateHelper.isForeground()) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (service is AndroidServiceInstance) {
        service.setAsBackgroundService();
        await Future.delayed(const Duration(milliseconds: 200));
      }
      service.stopSelf();
    }
  } catch (e) {
    final now = DateTime.now().toString().substring(0, 19);
    String brief = e.toString();
    if (brief.length > 40) brief = brief.substring(0, 40);
    brief = brief.replaceAll(RegExp(r'Exception: |DioException: |Http status error \[|\]'), '');
    _updateNotification(service, 'مزامنة حلقات القرآن', '⚠️ $brief — $now');
  }
}

Future<int> _countStatus(String s1, [String? s2]) async {
  final db = DatabaseHelper.instance;
  int total = 0;
  for (final table in ['pending_attendance', 'pending_memorizations', 'pending_quiz_requests']) {
    if (s2 != null) {
      final items = await db.queryWhere(table, 'sync_status = ? OR sync_status = ?', [s1, s2]);
      total += items.length;
    } else {
      final items = await db.queryWhere(table, 'sync_status = ?', [s1]);
      total += items.length;
    }
  }
  return total;
}

void _updateNotification(ServiceInstance service, String title, String content) {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(title: title, content: content);
  }
}

Future<void> _updateNotificationFromDb(ServiceInstance service) async {
  try {
    int pending = 0, failed = 0;
    try {
      pending = await _countStatus('pending', 'sending');
      failed = await _countStatus('failed');
    } catch (_) {}
    final now = DateTime.now().toString().substring(0, 19);
    String status;
    if (pending == 0 && failed == 0) {
      status = '✅ محدثة';
    } else if (failed > 0) {
      status = '⚠️ $failed فشل — $pending معلق';
    } else if (pending > 0) {
      status = '⏳ $pending بانتظار الإرسال';
    } else {
      status = '✅ محدثة';
    }
    _updateNotification(service, 'مزامنة حلقات القرآن', '$status — $now');
    // إذا لا توجد طلبات والتطبيق في الخلفية: أوقف الخدمة → يختفي الإشعار
    if (pending == 0 && failed == 0 && service is AndroidServiceInstance && !await AppStateHelper.isForeground()) {
      service.setAsBackgroundService();
      await Future.delayed(const Duration(milliseconds: 200));
      service.stopSelf();
    }
  } catch (_) {}
}
