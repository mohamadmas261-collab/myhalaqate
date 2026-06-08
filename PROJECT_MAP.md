# 📘 PROJECT MAP — تطبيق myhalaqat

## 1. نظرة عامة ومعمارية التطبيق

تطبيق **myhalaqat** (حلقات القرآن الكريم) هو تطبيق فلاتر لإدارة حلقات تحفيظ القرآن الكريم للمعلمين. يعمل التطبيق بنظام **Offline-First** حيث يتم حفظ جميع العمليات محلياً أولاً في SQLite ثم مزامنتها مع الخادم الخلفي (API) عند توفر الاتصال.

**المعمارية:**
- **Presentation Layer:** شاشات Flutter مع StatefulWidgets
- **Service Layer:** خدمات لكل كيان (circles, students, attendance, ...)
- **Data Layer:** SQLite للتخزين المحلي + SharedPreferences للـ Cache + Dio للـ API Calls
- **Sync Layer:** SyncManager يدير المزامنة مع Exponential Backoff

## 2. هيكل الدليل (Directory Structure)

```
myhalaqat_flutter/
├── lib/
│   ├── main.dart                     # نقطة الدخول + تهيئة WorkManager
│   ├── core/
│   │   ├── database/
│   │   │   └── database_helper.dart   # SQLite (DB version 6)
│   │   ├── network/
│   │   │   ├── api_client.dart         # Dio + Token Interceptor + Refresh
│   │   │   └── sync_manager.dart       # محرك المزامنة الرئيسي
│   │   ├── notifiers/
│   │   │   └── app_notifiers.dart      # ValueNotifiers عامة
│   │   ├── theme/
│   │   │   └── app_theme.dart          # ثيمات (Light/Dark) + Google Fonts
│   │   └── widgets/
│   │       ├── custom_button.dart
│   │       ├── custom_shimmer.dart
│   │       ├── custom_snackbar.dart
│   │       ├── custom_text_field.dart
│   │       └── sync_indicator.dart     # SyncAppBarAction + SyncIndicator
│   └── features/
│       ├── auth/
│       │   ├── screens/
│       │   │   ├── auth_wrapper.dart   # AuthWrapper (التحقق من التوكن)
│       │   │   └── login_screen.dart   # شاشة تسجيل الدخول
│       │   └── services/
│       │       └── auth_service.dart   # AuthService (login + حفظ البروفايل)
│       ├── circles/
│       │   ├── screens/
│       │   │   ├── circle_details_screen.dart
│       │   │   ├── courses_list_screen.dart
│       │   │   └── course_details_screen.dart
│       │   └── services/
│       │       ├── circle_service.dart
│       │       └── course_service.dart  # التحقق من أيام الدورة
│       ├── dashboard/
│       │   └── screens/
│       │       ├── home_screen.dart     # الشاشة الرئيسية (قائمة الدورات)
│       │       ├── main_screen.dart     # الـ Scaffold الرئيسي مع BottomNav
│       │       └── notifications_screen.dart
│       ├── attendance/
│       │   ├── screens/
│       │   │   ├── attendance_screen.dart           # تسجيل الحضور
│       │   │   └── circle_attendance_record_screen.dart
│       │   └── services/
│       │       └── attendance_service.dart
│       ├── students/
│       │   ├── models/
│       │   │   ├── student_model.dart
│       │   │   └── surahs_data.dart
│       │   ├── screens/
│       │   │   ├── students_list_screen.dart
│       │   │   ├── student_evaluation_screen.dart    # تقييم الطالب (3 تبويبات)
│       │   │   ├── batch_memorization_screen.dart
│       │   │   ├── circle_memorization_record_screen.dart
│       │   │   └── enrollment_details_screen.dart
│       │   └── services/
│       │       ├── student_service.dart
│       │       └── memorization_service.dart
│       ├── saber/
│       │   ├── screens/
│       │   │   ├── saber_requests_screen.dart        # قائمة طلبات السبر
│       │   │   └── create_saber_request_screen.dart
│       │   └── services/
│       │       └── saber_service.dart
│       ├── records/
│       │   ├── screens/
│       │   │   ├── records_dashboard_screen.dart
│       │   │   ├── student_points_screen.dart
│       │   │   ├── student_quizzes_screen.dart
│       │   │   ├── student_parts_screen.dart
│       │   │   └── point_types_screen.dart
│       │   └── services/
│       │       └── records_service.dart
│       ├── reports/
│       │   ├── screens/
│       │   │   ├── reports_screen.dart
│       │   │   ├── absence_report_screen.dart
│       │   │   ├── student_weekly_report_screen.dart
│       │   │   └── student_comprehensive_report_screen.dart
│       │   └── services/
│       │       └── reports_service.dart
│       └── teacher_profile/
│           └── screens/
│               ├── profile_screen.dart
│               └── teacher_dashboard_screen.dart
├── test/
│   ├── widget_test.dart               # اختبار بسيط
│   └── phase1_fixes_test.dart          # 56 اختبار وحدة
├── assets/
│   └── icon/
│       └── app_icon.png
├── .env                                # BASE_URL=http://10.0.2.2:8000
├── pubspec.yaml
├── halaqat_postman.json               # Postman collection
└── POSTMAN_API.md
```

## 3. التقنيات المستخدمة (Tech Stack)

| التقنية | الإصدار | الاستخدام |
|---------|---------|-----------|
| Flutter | 3.41.9 | إطار العمل الرئيسي |
| Dart | 3.11.5 | لغة التطوير |
| Dio | ^5.9.2 | HTTP client مع Interceptors |
| sqflite | ^2.4.2+1 | قاعدة بيانات SQLite محلية |
| shared_preferences | ^2.5.5 | Cache key-value للتخزين السريع |
| connectivity_plus | ^7.1.1 | مراقبة حالة الاتصال بالإنترنت |
| workmanager | ^0.9.0+3 | مزامنة خلفية دورية (كل 15 دقيقة) |
| google_fonts | ^8.1.0 | خط Cairo للغة العربية |
| shimmer | ^3.0.0 | تأثيرات التحميل |
| lottie | ^3.3.3 | رسوم متحركة خفيفة |
| awesome_dialog | ^3.3.0 | نوافذ حوار محسّنة |
| path_provider | ^2.1.5 | مسارات الملفات |
| flutter_dotenv | ^6.0.1 | تحميل متغيرات البيئة (.env) |
| intl & flutter_localization | - | تدويل عربي |
| flutter_lints | ^6.0.0 | تحليل الكود |
| change_app_package_name | ^1.5.0 | تغيير package name |
| flutter_launcher_icons | ^0.14.4 | أيقونة التطبيق |

## 4. الميزات المنفّذة

- **المصادقة:** تسجيل دخول باستخدام JWT tokens مع refresh تلقائي
- **الدورات:** عرض قائمة الدورات المسندة للمعلم مع حالة كل دورة (نشط/منتهي)
- **الحلقات:** عرض حلقات كل دورة مع تفاصيلها وعدد الطلاب
- **الحضور:** تسجيل حضور/غياب/استئذان مع دعم الدفعات (Bulk) والبحث والترتيب
- **الحفظ:** تسجيل تسميع الحفظ (سورة + آيات) مع التقييم
- **السبر:** إنشاء وعرض طلبات السبر (اختبار شفوي) بحالات متعددة
- **السجلات:** سجل النقاط، الاختبارات، الأجزاء مع دعم العرض دون اتصال
- **التقارير:** تقارير الغياب، التقارير الأسبوعية والشاملة للطلاب
- **التقييم:** شاشة تقييم الطالب بثلاث تبويبات (الملف الشخصي، التلاوة، السجل)
- **الملف الشخصي:** عرض الملف الشخصي للمعلم ولوحة الإحصائيات
- **الوضع المظلم:** دعم Dark Mode مع حفظ التفضيل في SharedPreferences
- **المزامنة الخلفية:** مزامنة دورية عبر WorkManager كل 15 دقيقة
- **الترجمة:** واجهة كاملة باللغة العربية مع دعم التقويم الهجري

## 5. نظام المزامنة (Sync System)

### 5.1 المعمارية

```
تسجيل عملية → SQLite pending table → SyncManager.syncAll() → API Server
                                          ↕
                              pendingCountNotifier → UI تحديث
```

### 5.2 جداول SQLite للمهام المعلقة (Pending Tables)

- **pending_attendance:** سجلات الحضور غير المُزامنة
- **pending_memorizations:** سجلات الحفظ غير المُزامنة
- **pending_quiz_requests:** طلبات السبر غير المُزامنة

كل جدول يحتوي على أعمدة: `sync_status` (pending/sending/synced/failed)، `retry_count`، `action` (create/update)، `server_id`، `last_attempt_at`

### 5.3 SharedPreferences Cache

يُستخدم لتخزين مؤقت سريع للبيانات المسحوبة من API:
- `cached_circles` — قائمة الحلقات
- `cache_attendance_record_circle_$id` — سجل الحضور
- `cache_memo_record_circle_$id` — سجل الحفظ
- `cache_student_ranking` — ترتيب الطلاب
- `cache_memo_stats` — إحصائيات الحفظ
- `cache_teacher_dashboard` — لوحة المعلم
- `cache_points_$enrollmentId` — نقاط الطالب
- `cache_quizzes_$enrollmentId` — اختبارات الطالب
- `cache_parts_$enrollmentId` — أجزاء الطالب
- `cache_absence_report` — تقرير الغياب
- `cache_weekly_report_$enrollmentId` — تقرير أسبوعي

### 5.4 pendingCountNotifier

`ValueNotifier<int>` يُحدَّث بعد كل عملية مزامنة ليعكس عدد العناصر المعلقة (pending + sending + failed). يُستخدم بواسطة `SyncAppBarAction` لعرض شارة (Badge) في AppBar.

### 5.5 آلية إعادة المحاولة (Exponential Backoff)

- **MAX_RETRIES = 5**
- أوقات الانتظار: 5، 25، 125، 625، 3125 ثانية
- يتم تجاهل `ConnectivityResult.other` (VPN/Captive Portal)
- العناصر الفاشلة تُعاد جدولتها تلقائياً عند عودة الاتصال
- العناصر المُزامَنة تُحذف بعد 7 أيام تلقائياً

### 5.6 المزامنة الخلفية (Background Sync)

- WorkManager: `myhalaqat-sync` كل 15 دقيقة مع اشتراط وجود اتصال
- استماع فوري: `connectivity_plus` يكتشف عودة الاتصال ويُشغّل المزامنة
- مزامنة دورية صامتة كل 30 ثانية

## 6. schema قاعدة البيانات

**الملف:** `lib/core/database/database_helper.dart`

**الإصدار الحالي:** 6

### جداول الكاش (Cache):
- `cached_students` — الطلاب مع `sync_status` و `deleted_at` (للمؤرشفين)
- `cached_memorizations` — سجل الحفظ

### جداول العمليات المعلقة:
- `pending_attendance` — الحضور
- `pending_memorizations` — الحفظ
- `pending_quiz_requests` — طلبات السبر

### جداول المزامنة:
- `sync_queue` — قائمة انتظار المزامنة العامة
- `sync_log` — سجل عمليات المزامنة (started_at، finished_at، success_count، fail_count، status)

### الترحيلات (Migrations):
- **v1→v2:** إضافة action، server_id، last_attempt_at لجداول pending
- **v2→v3:** إضافة sync_status و deleted_at لـ cached_students
- **v3→v4:** إضافة total_points، attendance_count، total_sessions لـ cached_students
- **v4→v5:** إنشاء جدول sync_log
- **v5→v6:** إضافة عمود notes لـ pending_memorizations

## 7. مرجع API

- **المصادقة:** `POST /api/token/`, `POST /api/token/refresh/`, `GET /api/profile/`
- **الدورات:** `GET /api/courses/`, `GET /api/courses/:id/`
- **الحلقات:** `GET /api/circles/`, `GET /api/circles/:id/`
- **التسجيلات:** `GET /api/enrollments/?circle=:id`
- **الحضور:** `GET /api/attendance/`, `POST /api/attendance/batch/`
- **الحفظ:** `GET /api/memorizations/`, `POST /api/memorizations/batch/`
- **السبر:** `GET /api/quiz-requests/`, `GET /api/quiz-requests/my_requests/`, `POST /api/quiz-requests/`
- **لوحة البيانات:** `GET /api/dashboard/student-ranking/`, `GET /api/dashboard/memorization-stats/`, `GET /api/dashboard/teacher-dashboard/`, `GET /api/dashboard/absence-report/`, `GET /api/dashboard/weekly-report/`
- **الطلاب:** `GET /api/students/`, `GET /api/students/:id/`
- **النقاط:** `GET /api/student-points/`, `GET /api/point-event-types/`
- **الاختبارات:** `GET /api/quizzes/`
- **الأجزاء:** `GET /api/student-parts/`

راجع `POSTMAN_API.md` و `halaqat_postman.json` لتفاصيل الطلبات.

## 8. هيكل واجهة المستخدم (UI)

### تدفق التنقل (Navigation Flow):
```
AuthWrapper
├── LoginScreen (إذا لا يوجد توكن)
└── MainScreen (إذا يوجد توكن)
    ├── HomeScreen (تبويب "الدورات")
    │   ├── _CirclesScreen (قائمة حلقات الدورة)
    │   │   └── CircleDetailsScreen
    │   │       ├── AttendanceScreen (تسجيل الحضور)
    │   │       ├── BatchMemorizationScreen (تسجيل حفظ)
    │   │       ├── CreateSaberRequestScreen (طلب سبر)
    │   │       ├── StudentsListScreen (قائمة الطلاب)
    │   │       ├── CircleAttendanceRecordScreen (سجل الحضور)
    │   │       └── CircleMemorizationRecordScreen (سجل الحفظ)
    └── ProfileScreen (تبويب "ملفي")
        ├── TeacherDashboardScreen
        ├── ReportsScreen
        ├── SaberRequestsScreen
        ├── RecordsDashboardScreen
        └── NotificationsScreen
```

### الـ Bottom Navigation:
- **« الدورات »** (HomeScreen) — أيقونة المنزل
- **« ملفي »** (ProfileScreen) — أيقونة الشخص

### الشاشات الرئيسية:
- **LoginScreen:** واجهة دخول أنيقة مع تدرج لوني أخضر، رسوم متحركة Fade+Slide
- **HomeScreen:** قائمة الدورات + شريط حالة المزامنة + SyncAppBarAction
- **CircleDetailsScreen:** بطاقة الحلقة مع عدد الطلاب + شبكة الإجراءات (حضور، حفظ، سبر)
- **AttendanceScreen:** تسجيل الحضور مع تبويبين (تسجيل + سجل)، بحث، تحديد الكل، تحقق من أيام الدورة
- **StudentEvaluationScreen:** 3 تبويبات (الملف الشخصي، التلاوة، السجل)
- **SaberRequestsScreen:** 4 تبويبات (الكل، قيد الانتظار، تم، مرفوض)

## 9. اختبارات (Testing)

**الموقع:** `test/phase1_fixes_test.dart`

**إجمالي الاختبارات:** 56 اختبار وحدة (unit tests)

### مجاميع الاختبارات:

| المجموعة | الوصف |
|----------|-------|
| SyncResult | التحقق من hasPending و hasFailed |
| API endpoints | صحة نقاط API |
| Student sorting | ترتيب الطلاب بالنقاط والحضور |
| Student Evaluation | شاشة التقييم بثلاث تبويبات |
| Course day validation | التحقق من أيام الدورة |
| Sync Log | تسجيل عمليات المزامنة |
| Course day & sync indicator | شريط حالة المزامنة |
| Comprehensive Sync Tests | اختبارات المزامنة الشاملة |
| Sync status bar | حالات شريط المزامنة |
| Offline reports cache | التخزين المؤقت للتقارير |
| Archived/Deleted students | الطلاب المؤرشفين |
| Edit Before Sync | تعديل السجلات قبل المزامنة |
| Sync system | نظام المزامنة مع backoff |
| CircleDetails enhancements | التحسينات الحالية |

### ملف الاختبار الأساسي:
`test/widget_test.dart` — اختبار بسيط يتأكد من أن التطبيق يعمل دون تعطل.

## 10. أحدث التغييرات (آخر 3 تغييرات)

### 1. إزالة عدد الطلاب من بطاقة الحلقة + عرض كامل لبطاقة السبر
- **الملف:** `lib/features/circles/screens/circle_details_screen.dart`
- إزالة `students_count` من بطاقة رأس الحلقة في `_buildCircleHeader` (طلب المستخدم)
- إصلاح عرض بطاقة "طلب سبر" لتأخذ العرض الكامل باستخدام `SizedBox(width: double.infinity)` بدلاً من `Expanded` — السطر 140-150

### 2. SyncAppBarAction — مؤشر حالة المزامنة في شريط التطبيق
- **الملف:** `lib/core/widgets/sync_indicator.dart` (السطور 100-170)
- إنشاء widget جديد `SyncAppBarAction` يُضاف إلى `actions:` في AppBar
- يستمع إلى `pendingCountNotifier` عبر `ListenableBuilder` — تحديث فوري
- يعرض أيقونة سحابة ملونة: أبيض `cloud_done` (مزامن ← لون أبيض ليتناسب مع خلفية AppBar الخضراء)، 🟠 `cloud_upload` مع Badge (معلق)، 🔴 `cloud_off` (غير متصل)
- بالضغط يُشغّل `SyncManager.instance.syncAll()`
- أُضيف إلى **home_screen.dart** (السطر 133) و **circle_details_screen.dart** (السطر 51)

### 3. إزالة SyncIndicator من main_screen.dart
- **الملف:** `lib/features/dashboard/screens/main_screen.dart`
- تم إزالة `SyncIndicator` (الذي كان يلف body كـ Stack) بالكامل
- الاستبدال: استخدام `SyncAppBarAction` في كل شاشة على حدة مباشرة في AppBar
- هذا يمنع تداخل الـ Stack ويحسّن المظهر

## 11. المشكلات المعروفة والخطوات القادمة

### مشكلات معروفة:
- بطاقة طلب السبر في `CircleDetailsScreen` تعمل بـ `SizedBox` بدلاً من `Expanded` لتجنب الخطأ — قد تحتاج مراجعة لاتساق التصميم
- التاريخ المستقبلي يُمنع في AttendanceScreen لكن المقارنة قد لا تكون دقيقة في كل المناطق الزمنية
- عند حذف طالب من السيرفر، يبقى في الكاش المحلي 30 يوماً قبل الحذف النهائي

### خطوات مقترحة:
- إضافة اختبارات واجهة المستخدم (Widget Tests) للشاشات الرئيسية
- تحسين إدارة الحالة باستخدام Provider أو Riverpod
- إضافة دعم الإشعارات (Firebase Cloud Messaging)
- إضافة خاصية إدارة طلاب جدد (إضافة/تعديل)
- تحسين أداء المزامنة مع دفعات أكبر
- إضافة تقارير PDF قابلة للتصدير
- دعم الصور والملفات المرفوعة
- إضافة اختبارات التكامل (Integration Tests)
