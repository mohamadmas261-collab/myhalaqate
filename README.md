تطبيق حلقاتي (MyHalaqat) 📖
تطبيق فلاتر (Flutter) متكامل مصمم لإدارة وتتبع حلقات تحفيظ القرآن الكريم. مبني بآلية العمل دون اتصال بالإنترنت (Offline-first)، مع مزامنة في الخلفية، وهيكلية معمارية نظيفة واحترافية تعتمد على الميزات (Feature-Driven Architecture).

🚀 أهم المميزات
دعم العمل دون اتصال بالإنترنت (Offline-First): وظائف كاملة للعمل دون إنترنت باستخدام قاعدة بيانات sqflite. يمكن للمعلمين تسجيل الحضور، التسميع، وطلبات السبر (الاختبارات) محلياً دون الحاجة لاتصال بالشبكة.

المزامنة في الخلفية (Background Synchronization): تم استخدام حزمة Workmanager للمزامنة الصامتة في الخلفية. يتضمن محرك مزامنة مخصص SyncManager يتعامل مع فشل الشبكة باستخدام خوارزمية (Exponential Backoff) ويدعم إرسال الطلبات المجمعة (Batch Processing) لتخفيف الضغط على السيرفر.

إدارة شبكات متقدمة (Advanced Networking): استخدام مكتبة Dio مع اعتراض الطلبات (Interceptors) لتجديد توكن JWT تلقائياً خلف الكواليس، مما يضمن معالجة أخطاء (401 Unauthorized) بسلاسة تامة دون إزعاج المستخدم.

لوحات تحكم متخصصة: لوحات تحكم وتقارير شاملة للمعلمين لتتبع تقدم الطلاب، الغيابات، والإنجازات (لوحة الشرف).

واجهة مستخدم ديناميكية: يدعم التطبيق الوضعين الفاتح والداكن (Light/Dark modes) بسلاسة، مع تأثيرات تحميل (Shimmer) ديناميكية لتجربة مستخدم عصرية.

🛠 التقنيات المستخدمة
إطار العمل: Flutter

قاعدة البيانات المحلية: sqflite (مع عمليات تهيئة Migration متقدمة وتخزين كاش محلي)

الشبكات API: dio (Interceptors, Token Refresh, Batch Requests)

مهام الخلفية: workmanager

مراقبة الاتصال: connectivity_plus

إدارة متغيرات البيئة: flutter_dotenv

المعمارية: Feature-Driven Architecture (معمارية مبنية على الميزات)

📂 هيكلية المشروع
يتبع المشروع معمارية Feature-Driven Architecture القابلة للتوسع، مما يفصل المهام ويجعل الكود قابلاً للصيانة والتطوير:

lib/
├── core/                   # الموارد المشتركة في التطبيق
│   ├── database/           # إعدادات SQLite والجداول
│   ├── network/            # إعدادات Dio ومحرك المزامنة SyncManager
│   ├── notifiers/          # إدارة الحالة العامة للتطبيق
│   ├── theme/              # الألوان والسمات (الداكن/الفاتح)
│   └── widgets/            # عناصر واجهة المستخدم المشتركة (UI Widgets)
├── features/               # ميزات التطبيق (Features)
│   ├── attendance/         # إدارة الحضور والغياب
│   ├── auth/               # تسجيل الدخول وإدارة التوكن
│   ├── circles/            # إدارة الحلقات والدورات
│   ├── dashboard/          # لوحة التحكم الرئيسية
│   ├── records/            # السجلات الأكاديمية للطلاب
│   ├── reports/            # التقارير والإحصائيات والإنذارات
│   ├── saber/              # طلبات السبر (الاختبارات)
│   ├── students/           # إدارة الطلاب وتسجيل الحفظ
│   └── teacher_profile/    # الملف الشخصي للمعلم وإعدادات المزامنة
└── main.dart               # نقطة البداية للتطبيق

⚙️ خطوات التشغيل
المتطلبات الأساسية
Flutter SDK (إصدار >=3.0.0)

Dart SDK

التثبيت
قم باستنساخ المستودع (Clone):

git clone https://github.com/yourusername/myhalaqat.git

انتقل إلى مجلد المشروع:

cd myhalaqat

قم بتثبيت الحزم والاعتماديات:

flutter pub get

قم بإنشاء ملف .env في المسار الرئيسي للمشروع وأضف رابط السيرفر الخاص بك:

BASE_URL=http://your-api-url.com

تشغيل التطبيق:

flutter run

🧠 إضاءات تقنية (للمراجعين التقنيين)
محرك المزامنة SyncManager: محرك مزامنة متين يقوم بقراءة السجلات المعلقة من SQLite، وتجميعها في دفعات (Batches)، ثم إرسالها للسيرفر. في حال فشل الإرسال، يستخدم خوارزمية (Exponential Backoff) لتأخير المحاولات القادمة تدريجياً لضمان عدم إرهاق الشبكة.

معترضات الاتصال Dio Interceptors: تلتقط أخطاء 401 تلقائياً، وتستدعي نقطة نهاية تجديد التوكن (Refresh Token)، وتحفظ التوكن الجديد، ثم تعيد إرسال الطلب الأصلي الذي فشل، كل ذلك بلمح البصر دون أن يشعر المستخدم بأي انقطاع.

تم بناء هذا التطبيق بحب باستخدام فلاتر ❤️.    






MyHalaqat (حلقات القرآن) 📖

A comprehensive Flutter application designed to manage and track Quran memorization circles (Halaqat). Built with offline-first capabilities, background synchronization, and a clean feature-driven architecture.

🚀 Key Features

Offline-First Support: Full offline functionality using sqflite. Teachers can record attendance, memorizations, and quiz requests without an internet connection.

Background Synchronization: Implemented Workmanager for silent background syncing. Includes a custom SyncManager with exponential backoff for failed network requests and batch processing.

Advanced Networking: Utilizes Dio with custom interceptors for automatic JWT token refreshing (handling 401 Unauthorized errors seamlessly).

Role-Based Dashboards: Specific dashboards and comprehensive reports for teachers to track students' progress, absences, and achievements.

Dynamic UI & Theming: Supports both Light and Dark modes with dynamic Shimmer loading effects and smooth animations.

🛠 Tech Stack

Framework: Flutter

Local Database: sqflite (with complex migrations and local caching)

Networking: dio (Interceptors, Token Refresh, Batch Requests)

Background Tasks: workmanager

Connectivity: connectivity_plus

Environment Management: flutter_dotenv

Architecture: Feature-Driven Architecture

📂 Project Architecture

The project follows a scalable Feature-Driven Architecture, separating concerns and making the codebase easy to maintain and scale:

lib/
├── core/                   # Shared resources across the app
│   ├── database/           # SQLite setup and migrations
│   ├── network/            # Dio client and SyncManager
│   ├── notifiers/          # Global state notifiers
│   ├── theme/              # Light/Dark themes and colors
│   └── widgets/            # Reusable UI components
├── features/               # App features
│   ├── attendance/         # Attendance tracking
│   ├── auth/               # Login & Token handling
│   ├── circles/            # Halaqa/Course management
│   ├── dashboard/          # Main UI wrappers
│   ├── records/            # Student academic records
│   ├── reports/            # Analytics and warnings
│   ├── saber/              # Quiz (Saber) requests
│   ├── students/           # Student management & grading
│   └── teacher_profile/    # Teacher settings & sync controls
└── main.dart               # App entry point



⚙️ Getting Started

Prerequisites

Flutter SDK (>=3.0.0)

Dart SDK

Installation

Clone the repository:

git clone https://github.com/yourusername/myhalaqat.git



Navigate to the project directory:

cd myhalaqat



Install dependencies:

flutter pub get



Create a .env file in the root directory and add your base URL:

BASE_URL=http://your-api-url.com



Run the app:

flutter run



🧠 Technical Highlights (For Reviewers)

SyncManager (lib/core/network/sync_manager.dart): A robust syncing engine that handles pending local SQLite records, groups them into batches, and sends them to the server. If it fails, it applies an exponential backoff algorithm before retrying.

Dio Interceptors (lib/core/network/api_client.dart): Automatically catches 401 errors, calls the refresh token endpoint, saves the new token, and seamlessly retries the original failed request without user interruption.

Built with ❤️ using Flutter.