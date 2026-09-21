import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// تخزين متزامن لحالة التطبيق (foreground/background) باستخدام ملف
/// (SharedPreferences غير موثوق عبر العزلات لأنه async)
class AppStateHelper {
  static Future<bool> _ensureDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return Directory(dir.path).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<String> _stateFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/app_foreground.txt';
  }

  /// كتابة متزامنة — مضمونة لتكون متاحة فوراً للعزل الخلفي
  static Future<void> setForeground(bool value) async {
    try {
      final path = await _stateFilePath();
      final file = File(path);
      file.writeAsStringSync(value ? '1' : '0');
    } catch (_) {}
  }

  /// قراءة متزامنة — من نفس الملف
  static Future<bool> isForeground() async {
    try {
      final path = await _stateFilePath();
      final file = File(path);
      if (file.existsSync()) {
        return file.readAsStringSync() == '1';
      }
      return true; // افتراضياً التطبيق أمامي
    } catch (_) {
      return true;
    }
  }
}
