import 'package:flutter/material.dart';
import 'package:myhalaqat/core/database/database_helper.dart';
import 'package:myhalaqat/core/services/background_sync_service.dart';

final ValueNotifier<int> pendingCountNotifier = ValueNotifier(0);
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// تحديث عداد المعلقات من قاعدة البيانات مباشرة — يُستدعى بعد أي إضافة/تعديل/حذف
Future<void> refreshPendingCount() async {
  int total = 0, failed = 0, pending = 0;
  try {
    final db = DatabaseHelper.instance;
    for (final table in ['pending_attendance', 'pending_memorizations', 'pending_quiz_requests']) {
      final items = await db.queryWhere(table,
          'sync_status = ? OR sync_status = ? OR sync_status = ?',
          ['pending', 'sending', 'failed']);
      total += items.length;
      final f = await db.queryWhere(table, 'sync_status = ?', ['failed']);
      failed += f.length;
      final p = await db.queryWhere(table, 'sync_status = ? OR sync_status = ?', ['pending', 'sending']);
      pending += p.length;
    }
    pendingCountNotifier.value = total;
  } catch (_) {}
  // تحديث إشعار الخدمة الخلفية فوراً
  _updateBackgroundNotification(pending, failed);
  // إذا في طلبات معلقة والخدمة موقوفة، شغّلها
  if (total > 0) {
    BackgroundSyncService.instance.start();
  }
}

void _updateBackgroundNotification(int pending, int failed) {
  try {
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
    BackgroundSyncService.updateNotification('مزامنة حلقات القرآن', '$status — $now');
  } catch (_) {}
}