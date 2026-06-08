class Student {
  final int id;
  final String name;
  final String dateOfBirth;
  final String phone;
  final List<dynamic> generalParts;
  final List<dynamic> sabrRecords;
  final List<dynamic> enrollments;

  Student({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.phone,
    required this.generalParts,
    required this.sabrRecords,
    required this.enrollments,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'بدون اسم',
      dateOfBirth: json['date_of_birth'] ?? 'غير محدد',
      phone: json['phone'] ?? 'لا يوجد رقم',
      generalParts: json['general_parts'] ?? [],
      sabrRecords: json['sabr_records'] ?? [],
      enrollments: json['enrollments'] ?? [],
    );
  }
}