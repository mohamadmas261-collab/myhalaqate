# Postman API Collection
> تم الاستخراج من ملف Postman تلقائيا
---

# المصادقة (Auth)

| Method | Endpoint |
|--------|----------|
| POST | `{{base_url}}/api/token/` |
| POST | `{{base_url}}/api/token/` |
| POST | `{{base_url}}/api/token/refresh/` |
| POST | `{{base_url}}/api/token/blacklist/` |

# لوحة التحكم - أدمن (Admin)

| Method | Endpoint |
|--------|----------|

## المستخدمون (Users)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/users` |
| POST | `{{base_url}}/api/users` |
| GET | `{{base_url}}/api/users/1` |
| PATCH | `{{base_url}}/api/users/1` |
| DELETE | `{{base_url}}/api/users/1` |

## الملف الشخصي (Profile)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/profile` |
| GET | `{{base_url}}/api/users/me` |

## الطلاب (Students) — الأجزاء المحفوظة + السبر العام + التسجيلات

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/students` |
| GET | `{{base_url}}/api/students/?search=أحمد?search=أحمد` |
| GET | `{{base_url}}/api/students/{{student_id}}` |
| POST | `{{base_url}}/api/students` |
| PATCH | `{{base_url}}/api/students/{{student_id}}` |
| DELETE | `{{base_url}}/api/students/{{student_id}}` |

## المدرسون (Teachers) — يعيد username, user_email, user_role

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/teachers` |
| POST | `{{base_url}}/api/teachers` |
| GET | `{{base_url}}/api/teachers/{{teacher_id}}` |
| PATCH | `{{base_url}}/api/teachers/{{teacher_id}}` |
| DELETE | `{{base_url}}/api/teachers/{{teacher_id}}` |

## القرآن (عام - بدون توكن)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/quran-parts` |
| GET | `{{base_url}}/api/quran-parts/1` |
| GET | `{{base_url}}/api/surahs` |
| GET | `{{base_url}}/api/surahs/1` |

## الدورات (Courses) — days + total_points

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/courses` |
| GET | `{{base_url}}/api/courses/?is_active=true?is_active=true` |
| POST | `{{base_url}}/api/courses` |
| GET | `{{base_url}}/api/courses/{{course_id}}` |
| PATCH | `{{base_url}}/api/courses/{{course_id}}` |
| POST | `{{base_url}}/api/courses/{{course_id}}/transfer` |
| DELETE | `{{base_url}}/api/courses/{{course_id}}` |

## أيام الدورة (CourseDays) — course_title

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/course-days` |
| POST | `{{base_url}}/api/course-days` |
| GET | `{{base_url}}/api/course-days/1` |
| PATCH | `{{base_url}}/api/course-days/1` |
| DELETE | `{{base_url}}/api/course-days/1` |
| GET | `{{base_url}}/api/course-days??course={{course_id}}??course={{course_id}}` |

## مدرسي الدورة (CourseTeachers) — course_title, teacher_name

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/course-teachers` |
| POST | `{{base_url}}/api/course-teachers` |
| GET | `{{base_url}}/api/course-teachers/1` |
| DELETE | `{{base_url}}/api/course-teachers/1` |
| GET | `{{base_url}}/api/course-teachers??course={{course_id}}??course={{course_id}}` |

## الحلقات (Circles) — course_title, teacher_name

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/circles` |
| GET | `{{base_url}}/api/circles/?course={{course_id}}?course={{course_id}}` |
| POST | `{{base_url}}/api/circles` |
| GET | `{{base_url}}/api/circles/{{circle_id}}` |
| PATCH | `{{base_url}}/api/circles/{{circle_id}}` |
| DELETE | `{{base_url}}/api/circles/{{circle_id}}` |

## التسجيلات (Enrollments) — student_name, circle_name, course_title

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/enrollments` |
| GET | `{{base_url}}/api/enrollments/?circle={{circle_id}}?circle={{circle_id}}` |
| GET | `{{base_url}}/api/enrollments/?status=active?status=active` |
| GET | `{{base_url}}/api/enrollments/?course={{course_id}}?course={{course_id}}` |
| POST | `{{base_url}}/api/enrollments` |
| GET | `{{base_url}}/api/enrollments/{{enrollment_id}}` |
| PATCH | `{{base_url}}/api/enrollments/{{enrollment_id}}` |
| POST | `{{base_url}}/api/enrollments/{{enrollment_id}}/archive` |
| POST | `{{base_url}}/api/enrollments/{{enrollment_id}}/activate` |
| DELETE | `{{base_url}}/api/enrollments/{{enrollment_id}}` |
| POST | `{{base_url}}/api/enrollments/batch/` |
| POST | `{{base_url}}/api/enrollments/assign_circle/` |
| GET | `{{base_url}}/api/enrollments/?course={{course_id}}&circle__isnull=true?course={{course_id}}&circle__isnull=true` |

## الحضور (Attendance) — student_name, circle_name, course_title

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/attendance` |
| GET | `{{base_url}}/api/attendance/?course={{course_id}}?course={{course_id}}` |
| POST | `{{base_url}}/api/attendance/` |
| POST | `{{base_url}}/api/attendance` |
| POST | `{{base_url}}/api/attendance` |
| GET | `{{base_url}}/api/attendance/{{attendance_id}}` |
| PATCH | `{{base_url}}/api/attendance/{{attendance_id}}` |
| DELETE | `{{base_url}}/api/attendance/{{attendance_id}}` |
| POST | `{{base_url}}/api/attendance/batch/` |
| GET | `{{base_url}}/api/attendance??date=2026-06-03??date=2026-06-03` |
| GET | `{{base_url}}/api/attendance??status=absent??status=absent` |
| GET | `{{base_url}}/api/attendance??enrollment={{enrollment_id}}??enrollment={{enrollment_id}}` |
| GET | `{{base_url}}/api/attendance/stats/?course={{course_id}}` |

## سجل الحفظ (Memorization) — student_name, surah_name, recorded_by_name

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/memorizations` |
| GET | `{{base_url}}/api/memorizations/?type=new?type=new` |
| GET | `` |
| POST | `{{base_url}}/api/memorizations/` |
| POST | `{{base_url}}/api/memorizations` |
| POST | `{{base_url}}/api/memorizations/` |
| GET | `` |
| POST | `{{base_url}}/api/memorizations/` |
| POST | `{{base_url}}/api/memorizations/` |
| POST | `{{base_url}}/api/memorizations` |
| GET | `{{base_url}}/api/memorizations/{{memorization_id}}` |
| PATCH | `{{base_url}}/api/memorizations/{{memorization_id}}` |
| DELETE | `{{base_url}}/api/memorizations/{{memorization_id}}` |
| POST | `{{base_url}}/api/memorizations/batch/` |
| GET | `{{base_url}}/api/memorizations??course={{course_id}}??course={{course_id}}` |
| GET | `{{base_url}}/api/memorizations??enrollment={{enrollment_id}}??enrollment={{enrollment_id}}` |
| GET | `{{base_url}}/api/memorizations??result=excellent??result=excellent` |
| GET | `{{base_url}}/api/memorizations/stats/?course={{course_id}}` |

## طلبات السبر (QuizRequests) — student_name, part_name, created_by_name

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/quiz-requests` |
| GET | `{{base_url}}/api/quiz-requests/?status=pending?status=pending` |
| POST | `{{base_url}}/api/quiz-requests` |
| POST | `{{base_url}}/api/quiz-requests` |
| GET | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}` |
| POST | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}/complete` |
| GET | `{{base_url}}/api/quiz-requests??course={{course_id}}??course={{course_id}}` |
| GET | `{{base_url}}/api/quiz-requests??enrollment={{enrollment_id}}??enrollment={{enrollment_id}}` |

## سبر الدفعات (QuizBatches) — student_name

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/quiz-batches` |
| GET | `{{base_url}}/api/quiz-batches/?enrollment={{enrollment_id}}?enrollment={{enrollment_id}}` |
| POST | `{{base_url}}/api/quiz-batches` |
| GET | `{{base_url}}/api/quiz-batches/{{quiz_batch_id}}` |

## السبرات (Quizzes) — student_name, part_name, source_course_title

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/quizzes` |
| GET | `{{base_url}}/api/quizzes/?source=admin_direct?source=admin_direct` |
| POST | `{{base_url}}/api/quizzes` |
| POST | `{{base_url}}/api/quizzes` |
| GET | `{{base_url}}/api/quizzes/{{quiz_id}}` |
| PATCH | `{{base_url}}/api/quizzes/{{quiz_id}}` |
| DELETE | `{{base_url}}/api/quizzes/{{quiz_id}}` |
| GET | `{{base_url}}/api/quizzes??course={{course_id}}??course={{course_id}}` |
| GET | `{{base_url}}/api/quizzes??student={{student_id}}??student={{student_id}}` |
| GET | `{{base_url}}/api/quizzes??quiz_type=new??quiz_type=new` |
| GET | `{{base_url}}/api/quizzes/stats/?course={{course_id}}` |

## أنواع أحداث النقاط (عام)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/point-event-types` |
| GET | `{{base_url}}/api/point-event-types/1` |

## قواعد النقاط (PointRules) — event_type_name, event_type_code, course_title

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/point-rules` |
| GET | `{{base_url}}/api/point-rules/?event_type=1?event_type=1` |
| POST | `{{base_url}}/api/point-rules` |
| POST | `{{base_url}}/api/point-rules` |
| GET | `{{base_url}}/api/point-rules/1` |
| PATCH | `{{base_url}}/api/point-rules/1` |
| DELETE | `{{base_url}}/api/point-rules/1` |
| GET | `{{base_url}}/api/point-rules??course={{course_id}}??course={{course_id}}` |

## النقاط والسجلات — student_name, event_type_name

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/student-points` |
| GET | `{{base_url}}/api/student-points/?course={{course_id}}?course={{course_id}}` |
| GET | `{{base_url}}/api/student-points/1` |
| GET | `{{base_url}}/api/student-parts` |
| GET | `{{base_url}}/api/student-parts/?student={{student_id}}?student={{student_id}}` |
| GET | `{{base_url}}/api/student-parts/1` |

# لوحة التقارير (Dashboard)

| Method | Endpoint |
|--------|----------|

## ترتيب الطلاب بالنقاط (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/student-ranking` |
| GET | `{{base_url}}/api/dashboard/student-ranking/?period=weekly?period=weekly` |
| GET | `{{base_url}}/api/dashboard/student-ranking/?period=monthly?period=monthly` |
| GET | `{{base_url}}/api/dashboard/student-ranking/?circle={{circle_id}}?circle={{circle_id}}` |
| GET | `{{base_url}}/api/dashboard/student-ranking/?circle={{circle_id}}&period=weekly?circle={{circle_id}}&period=weekly` |
| GET | `{{base_url}}/api/dashboard/student-ranking?course={{course_id}}?course={{course_id}}` |
| GET | `{{base_url}}/api/dashboard/student-ranking??from_date=2026-01-01&to_date=2026-12-31??from_date=2026-01-01&to_date=2026-12-31` |

## إحصائيات الحفظ (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/memorization-stats` |
| GET | `{{base_url}}/api/dashboard/memorization-stats/?circle={{circle_id}}?circle={{circle_id}}` |
| GET | `{{base_url}}/api/dashboard/memorization-stats?course={{course_id}}?course={{course_id}}` |
| GET | `{{base_url}}/api/dashboard/memorization-stats??period=weekly??period=weekly` |
| GET | `{{base_url}}/api/dashboard/memorization-stats??period=monthly??period=monthly` |
| GET | `{{base_url}}/api/dashboard/memorization-stats??from_date=2026-01-01&to_date=2026-12-31??from_date=2026-01-01&to_date=2026-12-31` |

## إحصائيات الحلقة (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/circle-stats/?circle={{circle_id}}?circle={{circle_id}}` |
| GET | `{{base_url}}/api/dashboard/circle-stats/?circle={{circle_id}}&period=weekly?circle={{circle_id}}&period=weekly` |

## تقرير الغياب (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/absence-report/?threshold=3?threshold=3` |
| GET | `{{base_url}}/api/dashboard/absence-report/?threshold=3&course={{course_id}}&period=weekly?threshold=3&course={{course_id}}&period=weekly` |

## التقرير الأسبوعي (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}?enrollment={{enrollment_id}}` |
| GET | `{{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}&period=monthly?enrollment={{enrollment_id}}&period=monthly` |
| GET | `{{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}&from_date=2026-01-01&to_date=2026-12-31?enrollment={{enrollment_id}}&from_date=2026-01-01&to_date=2026-12-31` |

## تقرير شامل للطالب (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}?student={{student_id}}&course={{course_id}}` |
| GET | `{{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}&period=monthly?student={{student_id}}&course={{course_id}}&period=monthly` |
| GET | `{{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}&from_date=2026-01-01&to_date=2026-12-31?student={{student_id}}&course={{course_id}}&from_date=2026-01-01&to_date=2026-12-31` |

## لوحة المدرس (Dashboard)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/teacher-dashboard/?teacher={{teacher_id}}?teacher={{teacher_id}}` |
| GET | `{{base_url}}/api/dashboard/teacher-dashboard/?teacher={{teacher_id}}&period=weekly?teacher={{teacher_id}}&period=weekly` |
| GET | `{{base_url}}/api/dashboard/teacher-dashboard/?teacher={{teacher_id}}&course={{course_id}}?teacher={{teacher_id}}&course={{course_id}}` |

# المدرس (Teacher)

| Method | Endpoint |
|--------|----------|

## الطلاب (طلاب حلقتي فقط)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/students` |
| GET | `{{base_url}}/api/students/{{student_id}}` |

## دوراتي وحلقاتي

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/courses` |
| GET | `{{base_url}}/api/courses/{{course_id}}` |
| GET | `{{base_url}}/api/circles` |
| GET | `{{base_url}}/api/circles/{{circle_id}}` |
| GET | `{{base_url}}/api/enrollments` |
| GET | `{{base_url}}/api/enrollments/?course={{course_id}}?course={{course_id}}` |
| GET | `{{base_url}}/api/enrollments/{{enrollment_id}}` |

## الحضور (حضور طلابي)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/attendance` |
| POST | `{{base_url}}/api/attendance` |
| POST | `{{base_url}}/api/attendance` |
| POST | `{{base_url}}/api/attendance` |
| GET | `{{base_url}}/api/attendance??course={{course_id}}??course={{course_id}}` |
| GET | `{{base_url}}/api/attendance??date=2026-06-03??date=2026-06-03` |
| POST | `{{base_url}}/api/attendance/batch/` |
| PATCH | `{{base_url}}/api/attendance/{{attendance_id}}` |
| DELETE | `{{base_url}}/api/attendance/{{attendance_id}}` |
| GET | `{{base_url}}/api/attendance/stats/?course={{course_id}}` |

## الحفظ اليومي

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/memorizations` |
| POST | `{{base_url}}/api/memorizations` |
| POST | `{{base_url}}/api/memorizations` |
| POST | `{{base_url}}/api/memorizations/` |
| POST | `{{base_url}}/api/memorizations` |
| POST | `{{base_url}}/api/memorizations` |
| POST | `{{base_url}}/api/memorizations` |
| GET | `{{base_url}}/api/memorizations??course={{course_id}}??course={{course_id}}` |
| POST | `{{base_url}}/api/memorizations/batch/` |
| PATCH | `{{base_url}}/api/memorizations/{{memorization_id}}` |

## طلبات السبر (خاصة بي)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/quiz-requests` |
| GET | `{{base_url}}/api/quiz-requests/my_requests` |
| POST | `{{base_url}}/api/quiz-requests` |
| POST | `{{base_url}}/api/quiz-requests` |
| PATCH | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}` |
| DELETE | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}` |
| GET | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}` |
| GET | `{{base_url}}/api/quiz-requests??course={{course_id}}??course={{course_id}}` |
| PATCH | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}` |
| DELETE | `{{base_url}}/api/quiz-requests/{{quiz_request_id}}` |

## النقاط والسجلات

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/student-points` |
| GET | `{{base_url}}/api/quizzes` |
| GET | `{{base_url}}/api/student-parts` |
| GET | `{{base_url}}/api/point-event-types` |
| GET | `{{base_url}}/api/point-rules` |
| GET | `{{base_url}}/api/student-points??course={{course_id}}??course={{course_id}}` |
| GET | `{{base_url}}/api/quizzes??course={{course_id}}??course={{course_id}}` |
| GET | `{{base_url}}/api/quizzes/stats/?course={{course_id}}` |

## التقارير (طلابي فقط)

| Method | Endpoint |
|--------|----------|
| GET | `{{base_url}}/api/dashboard/student-ranking` |
| GET | `{{base_url}}/api/dashboard/student-ranking?course={{course_id}}?course={{course_id}}` |
| GET | `{{base_url}}/api/dashboard/memorization-stats` |
| GET | `{{base_url}}/api/dashboard/circle-stats/?circle={{circle_id}}?circle={{circle_id}}` |
| GET | `{{base_url}}/api/dashboard/absence-report/?threshold=3?threshold=3` |
| GET | `{{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}?enrollment={{enrollment_id}}` |
| GET | `{{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}?student={{student_id}}&course={{course_id}}` |
| GET | `{{base_url}}/api/dashboard/teacher-dashboard` |

---

## التفاصيل الكاملة مع الـ Body (214 endpoints)

# المصادقة (Auth)

### تسجيل دخول المسؤول (Admin) → يحفظ التوكن تلقائياً
**API:** `POST {{base_url}}/api/token/`
```json
{
  "username": "admin",
  "password": "admin123"
}
```

### تسجيل دخول المدرس (Teacher) → يحفظ التوكن تلقائياً
**API:** `POST {{base_url}}/api/token/`
```json
{
  "username": "teacher1",
  "password": "pass123"
}
```

### تحديث التوكن
**API:** `POST {{base_url}}/api/token/refresh/`
```json
{
  "refresh": "YOUR_REFRESH_TOKEN"
}
```

### تسجيل الخروج (إبطال التوكن)
**API:** `POST {{base_url}}/api/token/blacklist/`
```json
{
  "refresh": "YOUR_REFRESH_TOKEN"
}
```

# لوحة التحكم - أدمن (Admin)

## المستخدمون (Users)

### عرض جميع المستخدمين
**API:** `GET {{base_url}}/api/users`

### إنشاء مستخدم
**API:** `POST {{base_url}}/api/users`
```json
{
  "username": "teacher_new",
  "password": "pass123",
  "role": "teacher",
  "first_name": "خالد",
  "last_name": "التميمي"
}
```

### عرض مستخدم
**API:** `GET {{base_url}}/api/users/1`

### تعديل مستخدم
**API:** `PATCH {{base_url}}/api/users/1`
```json
{
  "first_name": "محمود"
}
```

### حذف مستخدم
**API:** `DELETE {{base_url}}/api/users/1`

## الملف الشخصي (Profile)

### عرض حسابي الشخصي (teacher_id, teacher_name مع المدرس)
**API:** `GET {{base_url}}/api/profile`

### عرض حسابي عبر /users/me/
**API:** `GET {{base_url}}/api/users/me`

## الطلاب (Students) — الأجزاء المحفوظة + السبر العام + التسجيلات

### قائمة الطلاب
**API:** `GET {{base_url}}/api/students`

### بحث بالاسم: ?search=...
**API:** `GET {{base_url}}/api/students/?search=أحمد?search=أحمد`

### عرض طالب مع التفاصيل
**API:** `GET {{base_url}}/api/students/{{student_id}}`

### إضافة طالب
**API:** `POST {{base_url}}/api/students`
```json
{
  "name": "أحمد محمد",
  "date_of_birth": "2005-03-15",
  "phone": "0555123456",
  "course": "{{course_id}}  # optional, can use circle instead",
  "circle": "{{circle_id}}  # optional, can use course instead"
}
```

### تعديل طالب
**API:** `PATCH {{base_url}}/api/students/{{student_id}}`
```json
{
  "phone": "0555987654"
}
```

### حذف طالب
**API:** `DELETE {{base_url}}/api/students/{{student_id}}`

## المدرسون (Teachers) — يعيد username, user_email, user_role

### قائمة المدرسين
**API:** `GET {{base_url}}/api/teachers`

### إضافة مدرس
**API:** `POST {{base_url}}/api/teachers`
```json
{
  "name": "الشيخ عبدالله",
  "phone": "0555000010",
  "user": 1
}
```

### عرض مدرس (username, user_email, user_role ظاهرة)
**API:** `GET {{base_url}}/api/teachers/{{teacher_id}}`

### تعديل مدرس
**API:** `PATCH {{base_url}}/api/teachers/{{teacher_id}}`
```json
{
  "phone": "0555111111"
}
```

### حذف مدرس
**API:** `DELETE {{base_url}}/api/teachers/{{teacher_id}}`

## القرآن (عام - بدون توكن)

### قائمة الأجزاء (30 جزء)
**API:** `GET {{base_url}}/api/quran-parts`

### عرض جزء
**API:** `GET {{base_url}}/api/quran-parts/1`

### قائمة السور (114 سورة)
**API:** `GET {{base_url}}/api/surahs`

### عرض سورة
**API:** `GET {{base_url}}/api/surahs/1`

## الدورات (Courses) — days + total_points

### قائمة الدورات
**API:** `GET {{base_url}}/api/courses`

### تصفية: ?is_active=true
**API:** `GET {{base_url}}/api/courses/?is_active=true?is_active=true`

### إضافة دورة
**API:** `POST {{base_url}}/api/courses`
```json
{
  "title": "الدورة الصيفية",
  "description": "دورة تحفيظ",
  "start_date": "2026-06-01",
  "end_date": "2026-09-01",
  "is_active": true
}
```

### عرض دورة (مع النقاط والأيام)
**API:** `GET {{base_url}}/api/courses/{{course_id}}`

### تعديل دورة
**API:** `PATCH {{base_url}}/api/courses/{{course_id}}`
```json
{
  "title": "محدث"
}
```

### إغلاق وترحيل
**API:** `POST {{base_url}}/api/courses/{{course_id}}/transfer`

### حذف دورة
**API:** `DELETE {{base_url}}/api/courses/{{course_id}}`

## أيام الدورة (CourseDays) — course_title

### قائمة الأيام
**API:** `GET {{base_url}}/api/course-days`

### إضافة يوم
**API:** `POST {{base_url}}/api/course-days`
```json
{
  "course": {{course_id}},
  "day": 0
}
```

### عرض يوم (course_title)
**API:** `GET {{base_url}}/api/course-days/1`

### تعديل اليوم
**API:** `PATCH {{base_url}}/api/course-days/1`
```json
{
  "day": 5
}
```

### حذف يوم
**API:** `DELETE {{base_url}}/api/course-days/1`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/course-days??course={{course_id}}??course={{course_id}}`

## مدرسي الدورة (CourseTeachers) — course_title, teacher_name

### قائمة المدرسين المرتبطين
**API:** `GET {{base_url}}/api/course-teachers`

### إضافة مدرس لدورة
**API:** `POST {{base_url}}/api/course-teachers`
```json
{
  "course": {{course_id}},
  "teacher": {{teacher_id}}
}
```

### عرض رابط (course_title, teacher_name)
**API:** `GET {{base_url}}/api/course-teachers/1`

### حذف رابط
**API:** `DELETE {{base_url}}/api/course-teachers/1`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/course-teachers??course={{course_id}}??course={{course_id}}`

## الحلقات (Circles) — course_title, teacher_name

### قائمة الحلقات
**API:** `GET {{base_url}}/api/circles`

### تصفية: ?course=1
**API:** `GET {{base_url}}/api/circles/?course={{course_id}}?course={{course_id}}`

### إضافة حلقة
**API:** `POST {{base_url}}/api/circles`
```json
{
  "course": {{course_id}},
  "teacher": {{teacher_id}},
  "name": "حلقة الفجر",
  "notes": "بعد الفجر"
}
```

### عرض حلقة (course_title, teacher_name)
**API:** `GET {{base_url}}/api/circles/{{circle_id}}`

### تعديل حلقة
**API:** `PATCH {{base_url}}/api/circles/{{circle_id}}`
```json
{
  "name": "محدثة"
}
```

### حذف حلقة
**API:** `DELETE {{base_url}}/api/circles/{{circle_id}}`

## التسجيلات (Enrollments) — student_name, circle_name, course_title

### قائمة التسجيلات
**API:** `GET {{base_url}}/api/enrollments`

### تصفية: ?circle=1
**API:** `GET {{base_url}}/api/enrollments/?circle={{circle_id}}?circle={{circle_id}}`

### تصفية: ?status=active
**API:** `GET {{base_url}}/api/enrollments/?status=active?status=active`

### تصفية: ?course=1
**API:** `GET {{base_url}}/api/enrollments/?course={{course_id}}?course={{course_id}}`

### تسجيل طالب
**API:** `POST {{base_url}}/api/enrollments`
```json
{
  "circle": {{circle_id}},
  "student": {{student_id}}
}
```

### عرض تسجيل (student_name, circle_name, course_title)
**API:** `GET {{base_url}}/api/enrollments/{{enrollment_id}}`

### تعديل
**API:** `PATCH {{base_url}}/api/enrollments/{{enrollment_id}}`
```json
{
  "status": "active"
}
```

### أرشفة
**API:** `POST {{base_url}}/api/enrollments/{{enrollment_id}}/archive`

### إعادة تفعيل
**API:** `POST {{base_url}}/api/enrollments/{{enrollment_id}}/activate`

### حذف
**API:** `DELETE {{base_url}}/api/enrollments/{{enrollment_id}}`

### تسجيل دفعة (Batch): ?course=1&students=[1,2,3]
**API:** `POST {{base_url}}/api/enrollments/batch/`
```json
{
  "course": "{{course_id}}",
  "students": [
    1,
    2,
    3
  ]
}
```

### تعيين حلقة (Assign Circle): ?circle=1&students=[1,2,3]
**API:** `POST {{base_url}}/api/enrollments/assign_circle/`
```json
{
  "circle": "{{circle_id}}  # optional, can use course instead",
  "students": [
    1,
    2,
    3
  ],
  "course": "{{course_id}}  # optional, can use circle instead"
}
```

### تصفية بدون حلقة: ?course=1&circle__isnull=true
**API:** `GET {{base_url}}/api/enrollments/?course={{course_id}}&circle__isnull=true?course={{course_id}}&circle__isnull=true`

## الحضور (Attendance) — student_name, circle_name, course_title

### قائمة الحضور
**API:** `GET {{base_url}}/api/attendance`

### تصفية: ?date=, ?enrollment=, ?course=, ?status=
**API:** `GET {{base_url}}/api/attendance/?course={{course_id}}?course={{course_id}}`

### تسجيل حضور (+10)
**API:** `POST {{base_url}}/api/attendance/`
```json
{
  "enrollment": {{enrollment_id}},
  "date": "2026-06-03",
  "status": "present"
}
```

### تسجيل غياب (-5)
**API:** `POST {{base_url}}/api/attendance`
```json
{
  "enrollment": {{enrollment_id}},
  "date": "2026-06-03",
  "status": "absent"
}
```

### تسجيل اعتذار (0)
**API:** `POST {{base_url}}/api/attendance`
```json
{
  "enrollment": {{enrollment_id}},
  "date": "2026-06-05",
  "status": "excused"
}
```

### عرض (student_name, circle_name, course_title)
**API:** `GET {{base_url}}/api/attendance/{{attendance_id}}`

### تعديل
**API:** `PATCH {{base_url}}/api/attendance/{{attendance_id}}`
```json
{
  "status": "present"
}
```

### حذف
**API:** `DELETE {{base_url}}/api/attendance/{{attendance_id}}`

### حضور دفعة (Batch): ?circle=1&date=2026-06-03
**API:** `POST {{base_url}}/api/attendance/batch/`
```json
{
  "circle": "{{circle_id}}",
  "date": "2026-06-03",
  "records": [
    {
      "enrollment": "{{enrollment_id}}",
      "status": "present"
    },
    {
      "enrollment": "{{enrollment_id2}}",
      "status": "absent"
    }
  ]
}
```

### تاريخ: ?date=2026-06-03
**API:** `GET {{base_url}}/api/attendance??date=2026-06-03??date=2026-06-03`

### غياب: ?status=absent
**API:** `GET {{base_url}}/api/attendance??status=absent??status=absent`

### طالب: ?enrollment=1
**API:** `GET {{base_url}}/api/attendance??enrollment={{enrollment_id}}??enrollment={{enrollment_id}}`

### إحصائيات الحضور: ?course=1
**API:** `GET {{base_url}}/api/attendance/stats/?course={{course_id}}`

## سجل الحفظ (Memorization) — student_name, surah_name, recorded_by_name

### قائمة
**API:** `GET {{base_url}}/api/memorizations`

### تصفية: ?type=, ?enrollment=, ?result=
**API:** `GET {{base_url}}/api/memorizations/?type=new?type=new`

### ----- جديد -----
**API:** `GET `

### جديد + ممتاز (+15)
**API:** `POST {{base_url}}/api/memorizations/`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "new",
  "result": "excellent",
  "date": "2026-06-03",
  "recorded_by": {{teacher_id}}
}
```

### جديد + جيد (+10)
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 8,
  "to_ayah": 14,
  "type": "new",
  "result": "good",
  "date": "2026-06-03",
  "recorded_by": {{teacher_id}}
}
```

### جديد + إعادة (0)
**API:** `POST {{base_url}}/api/memorizations/`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 3,
  "type": "new",
  "result": "redo",
  "date": "2026-06-03",
  "recorded_by": {{teacher_id}}
}
```

### ----- مراجعة -----
**API:** `GET `

### مراجعة + ممتاز (+10)
**API:** `POST {{base_url}}/api/memorizations/`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "review",
  "result": "excellent",
  "date": "2026-06-03",
  "recorded_by": {{teacher_id}}
}
```

### مراجعة + جيد (+5)
**API:** `POST {{base_url}}/api/memorizations/`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "review",
  "result": "good",
  "date": "2026-06-03",
  "recorded_by": {{teacher_id}}
}
```

### مراجعة + إعادة (0)
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "review",
  "result": "redo",
  "date": "2026-06-03",
  "recorded_by": {{teacher_id}}
}
```

### عرض (student_name, surah_name, recorded_by_name)
**API:** `GET {{base_url}}/api/memorizations/{{memorization_id}}`

### تعديل
**API:** `PATCH {{base_url}}/api/memorizations/{{memorization_id}}`
```json
{
  "result": "good"
}
```

### حذف
**API:** `DELETE {{base_url}}/api/memorizations/{{memorization_id}}`

### حفظ دفعة (Batch)
**API:** `POST {{base_url}}/api/memorizations/batch/`
```json
{
  "records": [
    {
      "enrollment": "{{enrollment_id}}",
      "surah": 1,
      "from_ayah": 1,
      "to_ayah": 7,
      "type": "new",
      "date": "2026-06-03",
      "result": "excellent"
    },
    {
      "enrollment": "{{enrollment_id}}",
      "surah": 2,
      "from_ayah": 1,
      "to_ayah": 10,
      "type": "new",
      "date": "2026-06-03",
      "result": "good"
    }
  ]
}
```

### دورة: ?course=1
**API:** `GET {{base_url}}/api/memorizations??course={{course_id}}??course={{course_id}}`

### طالب: ?enrollment=1
**API:** `GET {{base_url}}/api/memorizations??enrollment={{enrollment_id}}??enrollment={{enrollment_id}}`

### ممتاز: ?result=excellent
**API:** `GET {{base_url}}/api/memorizations??result=excellent??result=excellent`

### إحصائيات الحفظ: ?course=1
**API:** `GET {{base_url}}/api/memorizations/stats/?course={{course_id}}`

## طلبات السبر (QuizRequests) — student_name, part_name, created_by_name

### قائمة
**API:** `GET {{base_url}}/api/quiz-requests`

### تصفية: ?status=pending, ?enrollment=, ?course=
**API:** `GET {{base_url}}/api/quiz-requests/?status=pending?status=pending`

### إنشاء (جديد)
**API:** `POST {{base_url}}/api/quiz-requests`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part": {{quran_part_id}},
  "quiz_type": "new",
  "teacher_notes": "جاهز"
}
```

### إنشاء (مراجعة)
**API:** `POST {{base_url}}/api/quiz-requests`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part": 2,
  "quiz_type": "review",
  "teacher_notes": "مراجعة ثاني"
}
```

### عرض (student_name, part_name, created_by_name)
**API:** `GET {{base_url}}/api/quiz-requests/{{quiz_request_id}}`

### إكمال الطلب (الأدمن)
**API:** `POST {{base_url}}/api/quiz-requests/{{quiz_request_id}}/complete`
```json
{
  "admin_score": 95,
  "admin_max_score": 100,
  "admin_notes": "ممتاز"
}
```

### دورة: ?course=1
**API:** `GET {{base_url}}/api/quiz-requests??course={{course_id}}??course={{course_id}}`

### طالب: ?enrollment=1
**API:** `GET {{base_url}}/api/quiz-requests??enrollment={{enrollment_id}}??enrollment={{enrollment_id}}`

## سبر الدفعات (QuizBatches) — student_name

### قائمة
**API:** `GET {{base_url}}/api/quiz-batches`

### تصفية: ?enrollment=1
**API:** `GET {{base_url}}/api/quiz-batches/?enrollment={{enrollment_id}}?enrollment={{enrollment_id}}`

### إنشاء دفعة
**API:** `POST {{base_url}}/api/quiz-batches`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part_ids": [1, 2, 3],
  "quiz_type": "new",
  "score": 92,
  "max_score": 100
}
```

### عرض (student_name)
**API:** `GET {{base_url}}/api/quiz-batches/{{quiz_batch_id}}`

## السبرات (Quizzes) — student_name, part_name, source_course_title

### قائمة
**API:** `GET {{base_url}}/api/quizzes`

### تصفية: ?student=, ?source=, ?quiz_type=, ?course=
**API:** `GET {{base_url}}/api/quizzes/?source=admin_direct?source=admin_direct`

### سبر مباشر جديد (+200)
**API:** `POST {{base_url}}/api/quizzes`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part": {{quran_part_id}},
  "student": {{student_id}},
  "quiz_type": "new",
  "score": 90,
  "max_score": 100,
  "source_course": {{course_id}}
}
```

### سبر مباشر مراجعة (+100)
**API:** `POST {{base_url}}/api/quizzes`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part": {{quran_part_id}},
  "student": {{student_id}},
  "quiz_type": "review",
  "score": 85,
  "max_score": 100,
  "source_course": {{course_id}}
}
```

### عرض (student_name, part_name, source_course_title)
**API:** `GET {{base_url}}/api/quizzes/{{quiz_id}}`

### تعديل
**API:** `PATCH {{base_url}}/api/quizzes/{{quiz_id}}`
```json
{
  "score": 98
}
```

### حذف
**API:** `DELETE {{base_url}}/api/quizzes/{{quiz_id}}`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/quizzes??course={{course_id}}??course={{course_id}}`

### طالب: ?student=1
**API:** `GET {{base_url}}/api/quizzes??student={{student_id}}??student={{student_id}}`

### جديد: ?quiz_type=new
**API:** `GET {{base_url}}/api/quizzes??quiz_type=new??quiz_type=new`

### إحصائيات السبرات: ?course=1
**API:** `GET {{base_url}}/api/quizzes/stats/?course={{course_id}}`

## أنواع أحداث النقاط (عام)

### قائمة
**API:** `GET {{base_url}}/api/point-event-types`

### عرض
**API:** `GET {{base_url}}/api/point-event-types/1`

## قواعد النقاط (PointRules) — event_type_name, event_type_code, course_title

### قائمة
**API:** `GET {{base_url}}/api/point-rules`

### تصفية: ?event_type=1, ?course=1
**API:** `GET {{base_url}}/api/point-rules/?event_type=1?event_type=1`

### إضافة قاعدة عامة
**API:** `POST {{base_url}}/api/point-rules`
```json
{
  "event_type": 1,
  "points_per_unit": 20
}
```

### قاعدة خاصة بدورة
**API:** `POST {{base_url}}/api/point-rules`
```json
{
  "event_type": 1,
  "course": {{course_id}},
  "points_per_unit": 50
}
```

### عرض (event_type_name, event_type_code)
**API:** `GET {{base_url}}/api/point-rules/1`

### تعديل
**API:** `PATCH {{base_url}}/api/point-rules/1`
```json
{
  "points_per_unit": 25
}
```

### حذف
**API:** `DELETE {{base_url}}/api/point-rules/1`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/point-rules??course={{course_id}}??course={{course_id}}`

## النقاط والسجلات — student_name, event_type_name

### نقاط الطلاب
**API:** `GET {{base_url}}/api/student-points`

### تصفية: ?enrollment=1, ?course=1
**API:** `GET {{base_url}}/api/student-points/?course={{course_id}}?course={{course_id}}`

### عرض (student_name, event_type_name)
**API:** `GET {{base_url}}/api/student-points/1`

### الأجزاء المحفوظة (عام) — student_name, part_name
**API:** `GET {{base_url}}/api/student-parts`

### أجزاء طالب: ?student=1
**API:** `GET {{base_url}}/api/student-parts/?student={{student_id}}?student={{student_id}}`

### عرض جزء (student_name, part_name)
**API:** `GET {{base_url}}/api/student-parts/1`

# لوحة التقارير (Dashboard)

## ترتيب الطلاب بالنقاط (Dashboard)

### ترتيب الطلاب (الكل)
**API:** `GET {{base_url}}/api/dashboard/student-ranking`

### أسبوعي: ?period=weekly
**API:** `GET {{base_url}}/api/dashboard/student-ranking/?period=weekly?period=weekly`

### شهري: ?period=monthly
**API:** `GET {{base_url}}/api/dashboard/student-ranking/?period=monthly?period=monthly`

### حلقة: ?circle=1
**API:** `GET {{base_url}}/api/dashboard/student-ranking/?circle={{circle_id}}?circle={{circle_id}}`

### حلقة + أسبوعي: ?circle=1&period=weekly
**API:** `GET {{base_url}}/api/dashboard/student-ranking/?circle={{circle_id}}&period=weekly?circle={{circle_id}}&period=weekly`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/dashboard/student-ranking?course={{course_id}}?course={{course_id}}`

### مخصص: from_date&to_date
**API:** `GET {{base_url}}/api/dashboard/student-ranking??from_date=2026-01-01&to_date=2026-12-31??from_date=2026-01-01&to_date=2026-12-31`

## إحصائيات الحفظ (Dashboard)

### إحصائيات كاملة (السبرات, الصفحات, المراجعات, الأجزاء)
**API:** `GET {{base_url}}/api/dashboard/memorization-stats`

### حلقة: ?circle=1
**API:** `GET {{base_url}}/api/dashboard/memorization-stats/?circle={{circle_id}}?circle={{circle_id}}`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/dashboard/memorization-stats?course={{course_id}}?course={{course_id}}`

### أسبوعي: ?period=weekly
**API:** `GET {{base_url}}/api/dashboard/memorization-stats??period=weekly??period=weekly`

### شهري: ?period=monthly
**API:** `GET {{base_url}}/api/dashboard/memorization-stats??period=monthly??period=monthly`

### مخصص: from_date&to_date
**API:** `GET {{base_url}}/api/dashboard/memorization-stats??from_date=2026-01-01&to_date=2026-12-31??from_date=2026-01-01&to_date=2026-12-31`

## إحصائيات الحلقة (Dashboard)

### إحصائيات حلقة: ?circle=1 (مطلوب)
**API:** `GET {{base_url}}/api/dashboard/circle-stats/?circle={{circle_id}}?circle={{circle_id}}`

### حلقة + أسبوعي: ?circle=1&period=weekly
**API:** `GET {{base_url}}/api/dashboard/circle-stats/?circle={{circle_id}}&period=weekly?circle={{circle_id}}&period=weekly`

## تقرير الغياب (Dashboard)

### تقرير الغياب: ?threshold=3
**API:** `GET {{base_url}}/api/dashboard/absence-report/?threshold=3?threshold=3`

### غياب + دورة: ?threshold=3&course=1&period=weekly
**API:** `GET {{base_url}}/api/dashboard/absence-report/?threshold=3&course={{course_id}}&period=weekly?threshold=3&course={{course_id}}&period=weekly`

## التقرير الأسبوعي (Dashboard)

### تقرير أسبوعي: ?enrollment=1
**API:** `GET {{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}?enrollment={{enrollment_id}}`

### شهري: ?enrollment=1&period=monthly
**API:** `GET {{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}&period=monthly?enrollment={{enrollment_id}}&period=monthly`

### من تاريخ إلى تاريخ: ?enrollment=1&from_date=2026-01-01&to_date=2026-12-31
**API:** `GET {{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}&from_date=2026-01-01&to_date=2026-12-31?enrollment={{enrollment_id}}&from_date=2026-01-01&to_date=2026-12-31`

## تقرير شامل للطالب (Dashboard)

### تقرير طالب في دورة: ?student=1&course=1
**API:** `GET {{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}?student={{student_id}}&course={{course_id}}`

### شهري: ?student=1&course=1&period=monthly
**API:** `GET {{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}&period=monthly?student={{student_id}}&course={{course_id}}&period=monthly`

### من تاريخ إلى تاريخ: ?student=1&course=1&from_date=2026-01-01&to_date=2026-12-31
**API:** `GET {{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}&from_date=2026-01-01&to_date=2026-12-31?student={{student_id}}&course={{course_id}}&from_date=2026-01-01&to_date=2026-12-31`

## لوحة المدرس (Dashboard)

### لوحة المدرس: ?teacher=1
**API:** `GET {{base_url}}/api/dashboard/teacher-dashboard/?teacher={{teacher_id}}?teacher={{teacher_id}}`

### أسبوعي: ?teacher=1&period=weekly
**API:** `GET {{base_url}}/api/dashboard/teacher-dashboard/?teacher={{teacher_id}}&period=weekly?teacher={{teacher_id}}&period=weekly`

### دورة: ?teacher=1&course=1
**API:** `GET {{base_url}}/api/dashboard/teacher-dashboard/?teacher={{teacher_id}}&course={{course_id}}?teacher={{teacher_id}}&course={{course_id}}`

# المدرس (Teacher)

## الطلاب (طلاب حلقتي فقط)

### قائمة طلابي
**API:** `GET {{base_url}}/api/students`

### عرض طالب
**API:** `GET {{base_url}}/api/students/{{student_id}}`

## دوراتي وحلقاتي

### دوراتي (التي أدرس فيها)
**API:** `GET {{base_url}}/api/courses`

### عرض دورة
**API:** `GET {{base_url}}/api/courses/{{course_id}}`

### حلقاتي
**API:** `GET {{base_url}}/api/circles`

### عرض حلقة (course_title, teacher_name)
**API:** `GET {{base_url}}/api/circles/{{circle_id}}`

### تسجيلات حلقاتي
**API:** `GET {{base_url}}/api/enrollments`

### تصفية: ?circle=1 أو ?course=1
**API:** `GET {{base_url}}/api/enrollments/?course={{course_id}}?course={{course_id}}`

### عرض تسجيل (student_name, circle_name, course_title)
**API:** `GET {{base_url}}/api/enrollments/{{enrollment_id}}`

## الحضور (حضور طلابي)

### قائمة الحضور
**API:** `GET {{base_url}}/api/attendance`

### تسجيل حضور (+10)
**API:** `POST {{base_url}}/api/attendance`
```json
{
  "enrollment": "{{enrollment_id}}",
  "date": "2026-06-03",
  "status": "present"
}
```

### تسجيل غياب (-5)
**API:** `POST {{base_url}}/api/attendance`
```json
{
  "enrollment": "{{enrollment_id}}",
  "date": "2026-06-03",
  "status": "present"
}
```

### تسجيل اعتذار (0)
**API:** `POST {{base_url}}/api/attendance`
```json
{
  "enrollment": "{{enrollment_id}}",
  "date": "2026-06-03",
  "status": "present"
}
```

### دورة: ?course=1
**API:** `GET {{base_url}}/api/attendance??course={{course_id}}??course={{course_id}}`

### تاريخ: ?date=2026-06-03
**API:** `GET {{base_url}}/api/attendance??date=2026-06-03??date=2026-06-03`

### حضور دفعة (Batch)
**API:** `POST {{base_url}}/api/attendance/batch/`
```json
{
  "circle": "{{circle_id}}",
  "date": "2026-06-03",
  "records": [
    {
      "enrollment": "{{enrollment_id}}",
      "status": "present"
    },
    {
      "enrollment": "{{enrollment_id2}}",
      "status": "absent"
    }
  ]
}
```

### تعديل حضور
**API:** `PATCH {{base_url}}/api/attendance/{{attendance_id}}`
```json
{
  "status": "absent"
}
```

### حذف حضور
**API:** `DELETE {{base_url}}/api/attendance/{{attendance_id}}`

### إحصائيات الحضور
**API:** `GET {{base_url}}/api/attendance/stats/?course={{course_id}}`

## الحفظ اليومي

### قائمة الحفظ
**API:** `GET {{base_url}}/api/memorizations`

### جديد + ممتاز
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "new",
  "result": "excellent",
  "recorded_by": {{teacher_id}}
}
```

### جديد + جيد
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 2,
  "from_ayah": 1,
  "to_ayah": 10,
  "type": "new",
  "result": "good",
  "recorded_by": {{teacher_id}}
}
```

### جديد + اعادة
**API:** `POST {{base_url}}/api/memorizations/`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 2,
  "from_ayah": 1,
  "to_ayah": 10,
  "type": "new",
  "result": "redo",
  "recorded_by": {{teacher_id}}
}
```

### مراجعة + ممتاز
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "review",
  "result": "excellent",
  "recorded_by": {{teacher_id}}
}
```

### مراجعة + جيد
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "review",
  "result": "good",
  "recorded_by": {{teacher_id}}
}
```

### مراجعة + اعادة
**API:** `POST {{base_url}}/api/memorizations`
```json
{
  "enrollment": {{enrollment_id}},
  "surah": 1,
  "from_ayah": 1,
  "to_ayah": 7,
  "type": "review",
  "result": "redo",
  "recorded_by": {{teacher_id}}
}
```

### دورة: ?course=1
**API:** `GET {{base_url}}/api/memorizations??course={{course_id}}??course={{course_id}}`

### حفظ دفعة (Batch)
**API:** `POST {{base_url}}/api/memorizations/batch/`
```json
{
  "records": [
    {
      "enrollment": "{{enrollment_id}}",
      "surah": 1,
      "from_ayah": 1,
      "to_ayah": 7,
      "type": "new",
      "date": "2026-06-03",
      "result": "excellent"
    },
    {
      "enrollment": "{{enrollment_id}}",
      "surah": 2,
      "from_ayah": 1,
      "to_ayah": 10,
      "type": "new",
      "date": "2026-06-03",
      "result": "good"
    }
  ]
}
```

### تعديل حفظ
**API:** `PATCH {{base_url}}/api/memorizations/{{memorization_id}}`
```json
{
  "result": "excellent",
  "date": "2026-05-23"
}
```

## طلبات السبر (خاصة بي)

### قائمة طلباتي
**API:** `GET {{base_url}}/api/quiz-requests`

### طلباتي فقط: /my_requests/
**API:** `GET {{base_url}}/api/quiz-requests/my_requests`

### إنشاء طلب (جديد)
**API:** `POST {{base_url}}/api/quiz-requests`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part": {{quran_part_id}},
  "quiz_type": "new",
  "teacher_notes": "جاهز"
}
```

### إنشاء طلب (مراجعة)
**API:** `POST {{base_url}}/api/quiz-requests`
```json
{
  "enrollment": {{enrollment_id}},
  "quran_part": 2,
  "quiz_type": "review",
  "teacher_notes": "مراجعة"
}
```

### تعديل طلبي
**API:** `PATCH {{base_url}}/api/quiz-requests/{{quiz_request_id}}`
```json
{
  "teacher_notes": "محدث"
}
```

### حذف طلبي (معلق)
**API:** `DELETE {{base_url}}/api/quiz-requests/{{quiz_request_id}}`

### عرض نتيجة السبر (admin_score, admin_notes)
**API:** `GET {{base_url}}/api/quiz-requests/{{quiz_request_id}}`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/quiz-requests??course={{course_id}}??course={{course_id}}`

### تعديل طلب
**API:** `PATCH {{base_url}}/api/quiz-requests/{{quiz_request_id}}`
```json
{
  "teacher_notes": "محدث",
  "quiz_type": "review"
}
```

### حذف طلبي (معلق)
**API:** `DELETE {{base_url}}/api/quiz-requests/{{quiz_request_id}}`

## النقاط والسجلات

### نقاط طلابي
**API:** `GET {{base_url}}/api/student-points`

### سبرات طلابي
**API:** `GET {{base_url}}/api/quizzes`

### أجزاء طلابي المحفوظة
**API:** `GET {{base_url}}/api/student-parts`

### أنواع النقاط (عام)
**API:** `GET {{base_url}}/api/point-event-types`

### قواعد النقاط
**API:** `GET {{base_url}}/api/point-rules`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/student-points??course={{course_id}}??course={{course_id}}`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/quizzes??course={{course_id}}??course={{course_id}}`

### إحصائيات السبرات
**API:** `GET {{base_url}}/api/quizzes/stats/?course={{course_id}}`

## التقارير (طلابي فقط)

### ترتيب طلابي بالنقاط
**API:** `GET {{base_url}}/api/dashboard/student-ranking`

### دورة: ?course=1
**API:** `GET {{base_url}}/api/dashboard/student-ranking?course={{course_id}}?course={{course_id}}`

### إحصائيات الحفظ
**API:** `GET {{base_url}}/api/dashboard/memorization-stats`

### إحصائيات حلقة: ?circle=1
**API:** `GET {{base_url}}/api/dashboard/circle-stats/?circle={{circle_id}}?circle={{circle_id}}`

### تقرير الغياب: ?threshold=3
**API:** `GET {{base_url}}/api/dashboard/absence-report/?threshold=3?threshold=3`

### التقرير الأسبوعي: ?enrollment=1
**API:** `GET {{base_url}}/api/dashboard/weekly-report/?enrollment={{enrollment_id}}?enrollment={{enrollment_id}}`

### تقرير شامل للطالب: ?student=1&course=1
**API:** `GET {{base_url}}/api/dashboard/student-course-report/?student={{student_id}}&course={{course_id}}?student={{student_id}}&course={{course_id}}`

### لوحة المدرس (خاصة بي)
**API:** `GET {{base_url}}/api/dashboard/teacher-dashboard`
