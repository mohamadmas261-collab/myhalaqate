import 'package:flutter/material.dart';
import 'package:myhalaqat/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/features/auth/screens/login_screen.dart';
import 'package:myhalaqat/core/widgets/custom_snackbar.dart';
import 'package:myhalaqat/core/theme/app_theme.dart';
import 'package:myhalaqat/core/notifiers/app_notifiers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _teacherName = 'جاري التحميل...';
  String _teacherPhone = '---';
  String _appVersion = '1.1.2';
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadProfileData();
    SharedPreferences.getInstance().then((p) => _appVersion = p.getString('app_version') ?? '1.1.2');
  }

 Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. محاولة جلب أحدث بيانات للبروفايل من الباك إند
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/api/profile/');
      
      if (response.statusCode == 200) {
        final data = response.data;

        // تحديث الذاكرة المحلية بالبيانات الجديدة من السيرفر
        await prefs.setString('teacher_phone', data['phone'] ?? '');
        await prefs.setString('teacher_email', data['email'] ?? '');

        String fetchedName = data['teacher_name'] ?? data['first_name'] ?? '';
        if (fetchedName.trim().isNotEmpty) {
          await prefs.setString('teacher_name', fetchedName);
        }
      }
    } catch (e) {
      print('⚠️ تعذر جلب البروفايل من الباك إند، سيتم عرض البيانات المحلية: $e');
    }

    // 2. تحديث الواجهة بالبيانات (سواء كانت محدثة من السيرفر أو من الكاش في حال عدم وجود نت)
    if (mounted) {
      setState(() {
        _teacherName = prefs.getString('teacher_name') ?? 'أستاذنا الفاضل';
        _teacherPhone = prefs.getString('teacher_phone') ?? 'رقم غير مسجل';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- 1. بطاقة التعريف ---
                  _buildProfileHeader(),
                  const SizedBox(height: 24),

                  // --- 2. إعدادات المظهر ---
                  _buildSectionLabel('المظهر والتخصيص'),
                  _buildSettingsGroup(
                    children: [
                      // زر الوضع الليلي هنا 🌙
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeNotifier,
                        builder: (context, currentMode, child) {
                          final isDark = currentMode == ThemeMode.dark;
                          return SwitchListTile(
                            title: const Text('الوضع الليلي', style: TextStyle(fontWeight: FontWeight.w600)),
                            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.amber : Colors.orange),
                            value: isDark,
                            activeColor: Theme.of(context).primaryColor,
                            onChanged: (val) async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('isDarkMode', val);
                              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- 4. تسجيل الخروج ---
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('تسجيل خروج', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('الإصدار $_appVersion', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
    );
  }

  // --- دوال بناء الواجهة المساعدة ---

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.primary.withOpacity(0.2)
              : Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, size: 50, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(_teacherName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(_teacherPhone, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
      ),
    );
  }

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }
}
