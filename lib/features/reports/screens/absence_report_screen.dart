import 'package:flutter/material.dart';
import 'package:myhalaqat/features/reports/services/reports_service.dart';

class AbsenceReportScreen extends StatefulWidget {
  const AbsenceReportScreen({Key? key}) : super(key: key);

  @override
  State<AbsenceReportScreen> createState() => _AbsenceReportScreenState();
}

class _AbsenceReportScreenState extends State<AbsenceReportScreen> {
  final ReportsService _reportsService = ReportsService();
  bool _isLoading = true;
  List<dynamic> _absenceList = [];

  @override
  void initState() {
    super.initState();
    _fetchAbsenceReport();
  }

  Future<void> _fetchAbsenceReport() async {
    final data = await _reportsService.getAbsenceReport(threshold: 3);
    if (mounted) {
      setState(() {
        _absenceList = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنذارات الغياب 🚨', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _absenceList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'ممتاز! لا يوجد طلاب تجاوزوا حد الغياب.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _absenceList.length,
                  itemBuilder: (context, index) {
                    final student = _absenceList[index];
                    final String phone = student['student_phone'] ?? 'غير متوفر';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200, width: 1),
                      ),
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  student['student_name'] ?? 'بدون اسم',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${student['absence_count']} غيابات',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Icon(Icons.group, size: 16, color: Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text('الحلقة: ${student['circle_name']}', style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                                    const SizedBox(width: 6),
                                    Text(phone, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.call, color: Colors.green),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('جاري الاتصال بـ $phone... 📞')),
                                    );
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}