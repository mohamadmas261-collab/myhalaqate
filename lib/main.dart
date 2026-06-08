import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:myhalaqat/core/network/sync_manager.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';
import 'package:myhalaqat/features/auth/screens/auth_wrapper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 1. تهيئة بيئة فلاتر الأساسية داخل العزل (Isolate)
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");

    try {
      // 2. استدعاء المزامنة
      // بما أن الـ ApiClient يقرأ التوكن بشكل غير متزامن داخل الـ Interceptor،
      // والـ DatabaseHelper يقوم بفتح القاعدة تلقائياً، فلن نواجه مشاكل هنا.
      await SyncManager.instance.syncAll();
      
      // إرجاع true يخبر النظام (Android/iOS) أن المهمة نجحت وانتهت بسلام
      return Future.value(true);
    } catch (e) {
      print('🚨 خطأ في المزامنة الخلفية: $e');
      
      // إرجاع false مهم جداً هنا! يخبر النظام أن المهمة فشلت بسبب مشكلة (مثل انقطاع النت)،
      // وبذلك سيقوم الـ WorkManager برمجياً بجدولة محاولة أخرى لاحقاً.
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تكييف مع أشرطة النظام في جميع الأجهزة
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  // تحميل ملف البيئة الأساسي
  await dotenv.load(fileName: ".env");

  // 1. نقرأ الذاكرة فقط
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // 2. تسجيل WorkManager للخلفية
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'myhalaqat-sync',
    'backgroundSync',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // 3. نشغل التطبيق ونرسم الشاشات فوراً
  runApp(const MyApp());

  // 4. الحل السحري: نأخر تشغيل المزامنة ثانيتين بين ما التطبيق يفتح ويرتاح
  Future.delayed(const Duration(seconds: 5), () {
    SyncManager.instance;
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'تطبيق حلقات القرآن',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', 'AE')],
          home: const AuthWrapper(),
        );
      },
    );
  }
}
