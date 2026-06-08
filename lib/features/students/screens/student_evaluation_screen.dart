import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myhalaqat/core/widgets/custom_button.dart';
import 'package:myhalaqat/core/widgets/custom_text_field.dart';
import 'package:myhalaqat/features/students/models/student_model.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';
import 'package:myhalaqat/features/students/services/memorization_service.dart';
import 'package:myhalaqat/features/saber/services/saber_service.dart';
import 'package:myhalaqat/features/records/screens/records_dashboard_screen.dart';

class StudentEvaluationScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final int enrollmentId; 
  final int courseId;

  const StudentEvaluationScreen({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.enrollmentId, 
    required this.courseId,
  }) : super(key: key);

  @override
  State<StudentEvaluationScreen> createState() => _StudentEvaluationScreenState();
}

class _StudentEvaluationScreenState extends State<StudentEvaluationScreen> {
  final TextEditingController _fromAyahController = TextEditingController();
  final TextEditingController _toAyahController = TextEditingController();

  final List<String> _quranSurahs = [
    "الفاتحة", "البقرة", "آل عمران", "النساء", "المائدة", "الأنعام", "الأعراف", "الأنفال", "التوبة", "يونس",
    "هود", "يوسف", "الرعد", "إبراهيم", "الحجر", "النحل", "الإسراء", "الكهف", "مريم", "طه",
    "الأنبياء", "الحج", "المؤمنون", "النور", "الفرقان", "الشعراء", "النمل", "القصص", "العنكبوت", "الروم",
    "لقمان", "السجدة", "الأحزاب", "سبأ", "فاطر", "يس", "الصافات", "ص", "الزمر", "غافر",
    "فصلت", "الشورى", "الزخرف", "الدخان", "الجاثية", "الأحقاف", "محمد", "الفتح", "الحجرات", "ق",
    "الذاريات", "الطور", "النجم", "القمر", "الرحمن", "الواقعة", "الحديد", "المجادلة", "الحشر", "الممتحنة",
    "الصف", "الجمعة", "المنافقون", "التغابن", "الطلاق", "التحريم", "الملك", "القلم", "الحاقة", "المعارج",
    "نوح", "الجن", "المزمل", "المدثر", "القيامة", "الإنسان", "المرسلات", "النبأ", "النازعات", "عبس",
    "التكوير", "الانفطار", "المطففين", "الانشقاق", "البروج", "الطارق", "الأعلى", "الغاشية", "الفجر", "البلد",
    "الشمس", "الليل", "الضحى", "الشرح", "التين", "العلق", "القدر", "البينة", "الزلزلة", "العاديات",
    "القارعة", "التكاثر", "العصر", "الهمزة", "الفيل", "قريش", "الماعون", "الكوثر", "الكافرون", "النصر",
    "المسد", "الإخلاص", "الفلق", "الناس"
  ];

  int? _selectedSurahId; 

  @override
  void dispose() {
    _fromAyahController.dispose();
    _toAyahController.dispose();
    super.dispose();
  }

  String _selectedType = 'جديد';
  String _selectedGrade = 'ممتاز';

  final StudentService _studentService = StudentService();
  final MemorizationService _memorizationService = MemorizationService(); 
  final SaberService _saberService = SaberService();
  
  late Future<Student?> _studentDetailsFuture;
  late Future<List<dynamic>> _memorizationsFuture; 

  @override
  void initState() {
    super.initState();
    _studentDetailsFuture = _studentService.getStudentById(widget.studentId);
    _memorizationsFuture = _memorizationService.getStudentMemorizations(widget.enrollmentId);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'الملف الشخصي'),
              Tab(icon: Icon(Icons.assignment_turned_in_outlined), text: 'التسميع'),
              Tab(icon: Icon(Icons.history_edu), text: 'السجل'),
            ],
          ),
        ),
        body: FutureBuilder<Student?>(
          future: _studentDetailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text('حدث خطأ في تحميل بيانات الطالب.'),
              );
            }

            final student = snapshot.data!;

            return TabBarView(
              children: [
                _buildTabStudentProfile(student),
                _buildTabDailyRecitation(),
                _buildTabHistoryAndNotes(), 
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabDailyRecitation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('نوع التسميع اليومي'),
          Row(
            children: [
              _buildSelectableCard(
                'حفظ جديد',
                Icons.star,
                _selectedType == 'جديد',
                () => setState(() => _selectedType = 'جديد'),
              ),
              const SizedBox(width: 12),
              _buildSelectableCard(
                'مراجعة قديم',
                Icons.menu_book,
                _selectedType == 'مراجعة',
                () => setState(() => _selectedType = 'مراجعة'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('تفاصيل التسميع'),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _selectedSurahId,
                hint: Row(
                  children: [
                    Icon(Icons.auto_stories, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    const Text('اختر السورة'),
                  ],
                ),
                icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).primaryColor),
                items: List.generate(_quranSurahs.length, (index) {
                  return DropdownMenuItem<int>(
                    value: index + 1, 
                    child: Text('${index + 1}. سورة ${_quranSurahs[index]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }),
                onChanged: (value) => setState(() => _selectedSurahId = value),
              ),
            ),
          ),
          const SizedBox(height: 12), 
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _fromAyahController,
                  hintText: 'من آية', 
                  icon: Icons.arrow_back
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _toAyahController,
                  hintText: 'إلى آية', 
                  icon: Icons.arrow_forward
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('التقييم (بناءً على الأخطاء)'),
          Row(
            children: [
              _buildSelectableCard(
                'ممتاز',
                Icons.check_circle,
                _selectedGrade == 'ممتاز',
                () => setState(() => _selectedGrade = 'ممتاز'),
                activeColor: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildSelectableCard(
                'جيد',
                Icons.error_outline,
                _selectedGrade == 'جيد',
                () => setState(() => _selectedGrade = 'جيد'),
                activeColor: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildSelectableCard(
                'إعادة',
                Icons.cancel_outlined,
                _selectedGrade == 'إعادة',
                () => setState(() => _selectedGrade = 'إعادة'),
                activeColor: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),

          CustomButton(
            text: 'حفظ التسميع ($_selectedType - $_selectedGrade)',
            onPressed: () async {
              if (_selectedSurahId == null || _fromAyahController.text.isEmpty || _toAyahController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء اختيار السورة وإدخال أرقام الآيات'), backgroundColor: Colors.red),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري الحفظ المحلي والمزامنة... ⏳')),
              );

              String typeCode = _selectedType == 'جديد' ? 'new' : 'review';
              String resultCode = 'excellent';
              if (_selectedGrade == 'جيد') resultCode = 'good';
              if (_selectedGrade == 'إعادة') resultCode = 'redo';

              final prefs = await SharedPreferences.getInstance();
              final teacherId = prefs.getInt('teacher_id') ?? 0;

              bool isSuccess = await _memorizationService.submitMemorization(
                enrollmentId: widget.enrollmentId,
                surahId: _selectedSurahId!,
                fromAyah: int.parse(_fromAyahController.text.trim()),
                toAyah: int.parse(_toAyahController.text.trim()),
                type: typeCode,
                result: resultCode,
                teacherId: teacherId,
              );

              if (!context.mounted) return;

              if (isSuccess) {
                setState(() => _selectedSurahId = null);
                _fromAyahController.clear();
                _toAyahController.clear();
                setState(() => _memorizationsFuture = _memorizationService.getStudentMemorizations(widget.enrollmentId));

                AwesomeDialog(
                  context: context,
                  dialogType: _selectedGrade == 'ممتاز' ? DialogType.success : DialogType.info,
                  animType: AnimType.scale,
                  title: _selectedGrade == 'ممتاز' ? 'إنجاز رائع! 🎉' : 'تم الحفظ',
                  desc: 'تم حفظ التسميع محلياً وجاري المزامنة في الخلفية بصمت.',
                  btnOkText: 'حسناً',
                  btnOkColor: Theme.of(context).primaryColor,
                  btnOkOnPress: () {},
                ).show();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فشل الحفظ المحلي. يرجى المحاولة مجدداً.'), backgroundColor: Colors.red),
                );
              }
            },
          ),
          const Divider(height: 40, thickness: 1),

          _buildSectionTitle('طلبات السبر والاختبارات 🏆'),
          Text(
            'إذا أتم الطالب حفظ جزء أو سورة وتريد طلب اختبار رسمي له من الإدارة:',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSaberRequestDialog('جديد'),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('طلب سبر جديد'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showSaberRequestDialog('مراجعة'),
                  icon: const Icon(Icons.history),
                  label: const Text('طلب سبر مراجعة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabHistoryAndNotes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('ملاحظة لولي الأمر'),
          const CustomTextField(
            hintText: 'اكتب ملاحظة عن أداء الطالب اليوم...',
            icon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('سجل الحفظ والمراجعة 📖'),
          
          FutureBuilder<List<dynamic>>(
            future: _memorizationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text('حدث خطأ في جلب السجل', style: TextStyle(color: Colors.red)));
              }

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('لا يوجد سجلات تسميع مسجلة لهذا الطالب في هذه الحلقة حتى الآن.', textAlign: TextAlign.center),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  
                  Color resultColor;
                  String resultText;
                  switch(record['result']) {
                    case 'excellent': resultColor = Colors.green; resultText = 'ممتاز'; break;
                    case 'good': resultColor = Colors.orange; resultText = 'جيد'; break;
                    case 'redo': resultColor = Colors.red; resultText = 'إعادة'; break;
                    default: resultColor = Colors.grey; resultText = 'غير محدد';
                  }

                  String typeText = record['type'] == 'new' ? 'حفظ جديد' : 'مراجعة';
                  bool isPending = record['recorded_by_name'] == 'قيد المزامنة ⏳';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isPending ? Colors.blue.withOpacity(0.5) : resultColor.withOpacity(0.5), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'سورة ${record['surah_name']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: resultColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  resultText,
                                  style: TextStyle(color: resultColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.format_list_numbered, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('الآيات: ${record['from_ayah']} - ${record['to_ayah']}'),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(typeText, style: const TextStyle(color: Colors.blue, fontSize: 11)),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (isPending) const Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.blue),
                                  if (isPending) const SizedBox(width: 4),
                                  Text(
                                    isPending ? 'بانتظار الرفع للسيرفر' : 'المُسَمِّع: ${record['recorded_by_name']}',
                                    style: TextStyle(fontSize: 12, color: isPending ? Colors.blue : Colors.grey[700], fontWeight: isPending ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ],
                              ),
                              Text(record['recorded_at'].toString().split(' ')[0], style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabStudentProfile(Student student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- بطاقة المعلومات الشخصية ---
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor, const Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white24,
                    child: Text(
                      student.name.isNotEmpty ? student.name[0] : 'ط',
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    student.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileStat(Icons.phone, student.phone),
                      _buildVerticalDivider(),
                      _buildProfileStat(Icons.cake, student.dateOfBirth),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- الحلقات والدورات ---
          if (student.enrollments.isNotEmpty) ...[
            _buildSectionTitle('الحلقات والدورات المسجل بها 📚'),
            const SizedBox(height: 8),
            ...student.enrollments.map((enroll) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.school, color: Theme.of(context).primaryColor),
                  ),
                  title: Text(
                    enroll['course'] ?? 'دورة غير محددة',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  subtitle: Text(
                    'الحلقة: ${enroll['circle'] ?? 'غير محدد'} • المعلم: ${enroll['teacher'] ?? 'غير محدد'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],

          // --- زر السجل الأكاديمي ---
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecordsDashboardScreen(
                    studentId: widget.studentId,
                    studentName: widget.studentName,
                    enrollmentId: widget.enrollmentId,
                    courseId: widget.courseId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.analytics_outlined, size: 24),
            label: const Text('السجل الأكاديمي الشامل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white30);
  }

  void _showSaberRequestDialog(String saberType) {
    int? selectedPart; 
    TextEditingController notesController = TextEditingController(); 
    String backendQuizType = saberType == 'جديد' ? 'new' : 'review';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('إنشاء طلب سبر ($saberType)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('سيتم حفظ طلب السبر للجزء المحدد ورفعه للإدارة.'),
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedPart,
                      hint: Row(
                        children: [
                          Icon(Icons.stars, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 12),
                          const Text('اختر الجزء'),
                        ],
                      ),
                      items: List.generate(30, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('الجزء ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }),
                      onChanged: (value) => setDialogState(() => selectedPart = value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'ملاحظات للإدارة (اختياري)',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedPart == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء اختيار الجزء أولاً!'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext); 
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري الحفظ المحلي والمزامنة... ⏳')),
                  );

                  bool isSuccess = await _saberService.createSaberRequest(
                    enrollmentId: widget.enrollmentId,
                    quranPart: selectedPart!,
                    quizType: backendQuizType,
                    teacherNotes: notesController.text.trim(),
                  );

                  if (!mounted) return;

                  if (isSuccess) {
                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.success,
                      animType: AnimType.bottomSlide,
                      title: 'تم حفظ الطلب 🚀',
                      desc: 'تم حفظ طلب السبر محلياً وهو قيد الإرسال للإدارة في الخلفية.',
                      btnOkText: 'متابعة',
                      btnOkColor: Theme.of(context).primaryColor,
                      btnOkOnPress: () {},
                    ).show();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('حدث خطأ أثناء الحفظ. يرجى المحاولة مرة أخرى.'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                child: const Text('إرسال الطلب', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildSelectableCard(String title, IconData icon, bool isSelected, VoidCallback onTap, {Color? activeColor}) {
    Color selectedColor = activeColor ?? Theme.of(context).primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.grey[300]!,
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: selectedColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? selectedColor : Colors.grey, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? selectedColor : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
      ),
    );
  }
}