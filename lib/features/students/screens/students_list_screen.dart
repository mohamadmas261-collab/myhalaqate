import 'package:flutter/material.dart';
import 'package:myhalaqat/core/widgets/custom_shimmer.dart';
import 'package:myhalaqat/features/reports/screens/student_comprehensive_report_screen.dart';
import 'package:myhalaqat/features/students/services/student_service.dart';

class StudentsListScreen extends StatefulWidget {
  final int circleId;
  final String circleName;

  const StudentsListScreen({
    Key? key,
    required this.circleId,
    required this.circleName,
  }) : super(key: key);

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final StudentService _studentService = StudentService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = true;
  String _sortBy = 'name'; // name, points, attendance, absence

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final name = (student['student_name'] ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
      _sortStudents();
    });
  }

  void _sortStudents() {
    switch (_sortBy) {
      case 'name':
        _filteredStudents.sort(
          (a, b) =>
              (a['student_name'] ?? '').compareTo(b['student_name'] ?? ''),
        );
        break;
      case 'points':
        _filteredStudents.sort(
          (a, b) => (b['total_points'] ?? 0).compareTo(a['total_points'] ?? 0),
        );
        break;
      case 'attendance':
        _filteredStudents.sort(
          (a, b) => (b['attendance_count'] ?? 0).compareTo(
            a['attendance_count'] ?? 0,
          ),
        );
        break;
      case 'absence':
        _filteredStudents.sort(
          (a, b) => (a['attendance_count'] ?? 0).compareTo(
            b['attendance_count'] ?? 0,
          ),
        );
        break;
    }
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    final data = await _studentService.getStudentsByCircle(widget.circleId);
    if (mounted) {
      setState(() {
        _allStudents = data;
        _filteredStudents = data;
        _sortStudents();
        _isLoading = false;
      });
    }
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortStudents();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.circleName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن طالب...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('أبجدي', 'name'),
                      const SizedBox(width: 8),
                      _buildSortChip('الأعلى نقاطاً', 'points'),
                      const SizedBox(width: 8),
                      _buildSortChip('الأعلى حضوراً', 'attendance'),
                      const SizedBox(width: 8),
                      _buildSortChip('الأكثر غياباً', 'absence'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : RefreshIndicator(
              onRefresh: _fetchStudents,
              child: _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'لا يوجد طالب بهذا الاسم'
                                : 'لا يوجد طلاب في هذه الحلقة',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        return _buildStudentCard(student, index);
                      },
                    ),
            ),
    );
  }

  Widget _buildStudentCard(dynamic student, int index) {
    final bool isActive = student['status'] == 'active';
    final bool isArchived = student['status'] == 'archived';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isArchived ? 0 : 2,
      color: isArchived ? Colors.grey.shade100 : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isArchived) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('هذا الطالب مؤرشف — لا يمكن تسجيل حضوره'),
                backgroundColor: Colors.grey,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentComprehensiveReportScreen(
                studentId: student['student'],
                courseId: student['course_id'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // --- الأفاتار ---
              CircleAvatar(
                radius: 26,
                backgroundColor: isArchived
                    ? Colors.grey.shade300
                    : Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isArchived
                        ? Colors.grey.shade600
                        : Theme.of(context).primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // --- البيانات ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          student['student_name'] ?? 'بدون اسم',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isArchived ? Colors.grey : Colors.black87,
                          ),
                        ),
                        if (isArchived) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'مؤرشف',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تاريخ التسجيل: ${student['enrolled_at'] ?? ''}',
                      style: TextStyle(
                        color: isArchived
                            ? Colors.grey.shade400
                            : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // --- الحالة ---
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isArchived
                          ? Colors.grey.withOpacity(0.1)
                          : isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isArchived
                          ? 'مؤرشف'
                          : isActive
                          ? 'نشط'
                          : 'غير نشط',
                      style: TextStyle(
                        color: isArchived
                            ? Colors.grey
                            : isActive
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isArchived ? Colors.grey.shade300 : Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    itemBuilder: (context, index) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12.0),
        child: CustomShimmer(height: 80, borderRadius: 14),
      );
    },
  );
}
}
