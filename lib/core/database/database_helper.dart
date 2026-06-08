import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('teacher_offline_sync_v2.db'); // غيرنا الاسم لضمان بناء جديد
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // ==========================================
    // 1. جداول التخزين المؤقت (Cache)
    // ==========================================
    await db.execute('''
      CREATE TABLE cached_students (
        id INTEGER PRIMARY KEY,
        enrollment_id INTEGER,
        name TEXT,
        circle_id INTEGER,
        course_id INTEGER,
        circle_name TEXT,
        status TEXT,
        sync_status TEXT DEFAULT 'synced',
        deleted_at TEXT,
        total_points INTEGER DEFAULT 0,
        attendance_count INTEGER DEFAULT 0,
        total_sessions INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_memorizations (
        id INTEGER PRIMARY KEY,
        enrollment_id INTEGER,
        student_name TEXT,
        surah_name TEXT,
        from_ayah INTEGER,
        to_ayah INTEGER,
        type TEXT,
        result TEXT,
        date TEXT,
        recorded_by TEXT
      )
    ''');

    // ==========================================
    // 2. جداول العمليات المعلقة (Pending) مع أعمدة المزامنة الكاملة
    // ==========================================
    await db.execute('''
      CREATE TABLE pending_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enrollment_id INTEGER,
        date TEXT,
        status TEXT,
        circle_id INTEGER,
        created_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        action TEXT DEFAULT 'create',
        server_id INTEGER,
        last_attempt_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_memorizations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enrollment_id INTEGER,
        surah_id INTEGER,
        surah_name TEXT,
        from_ayah INTEGER,
        to_ayah INTEGER,
        type TEXT,
        result TEXT,
        notes TEXT,
        date TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        action TEXT DEFAULT 'create',
        server_id INTEGER,
        last_attempt_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_quiz_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enrollment_id INTEGER,
        quran_part_id INTEGER,
        quiz_type TEXT,
        teacher_notes TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        action TEXT DEFAULT 'create',
        last_attempt_at TEXT
      )
    ''');

    // ==========================================
    // 3. جدول المزامنة الأساسي (Sync Queue)
    // ==========================================
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT UNIQUE,
        entity_type TEXT,
        action TEXT DEFAULT 'create',
        server_id INTEGER,
        payload TEXT,
        sync_status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT,
        finished_at TEXT,
        attendance_count INTEGER DEFAULT 0,
        memorization_count INTEGER DEFAULT 0,
        quiz_count INTEGER DEFAULT 0,
        success_count INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        status TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE pending_attendance ADD COLUMN action TEXT DEFAULT \'create\'');
      await db.execute('ALTER TABLE pending_attendance ADD COLUMN server_id INTEGER');
      await db.execute('ALTER TABLE pending_attendance ADD COLUMN last_attempt_at TEXT');
      await db.execute('ALTER TABLE pending_memorizations ADD COLUMN action TEXT DEFAULT \'create\'');
      await db.execute('ALTER TABLE pending_memorizations ADD COLUMN server_id INTEGER');
      await db.execute('ALTER TABLE pending_memorizations ADD COLUMN last_attempt_at TEXT');
      await db.execute('ALTER TABLE pending_quiz_requests ADD COLUMN action TEXT DEFAULT \'create\'');
      await db.execute('ALTER TABLE pending_quiz_requests ADD COLUMN last_attempt_at TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE cached_students ADD COLUMN sync_status TEXT DEFAULT \'synced\'');
      await db.execute('ALTER TABLE cached_students ADD COLUMN deleted_at TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE cached_students ADD COLUMN total_points INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE cached_students ADD COLUMN attendance_count INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE cached_students ADD COLUMN total_sessions INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at TEXT,
          finished_at TEXT,
          attendance_count INTEGER DEFAULT 0,
          memorization_count INTEGER DEFAULT 0,
          quiz_count INTEGER DEFAULT 0,
          success_count INTEGER DEFAULT 0,
          fail_count INTEGER DEFAULT 0,
          status TEXT
        )
      ''');
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE pending_memorizations ADD COLUMN notes TEXT');
      } catch (e) {
        // العمود قد يكون موجوداً مسبقاً (تمت الترقية جزئياً)
      }
    }
  }

  // ==========================================
  // دوال مساعدة
  // ==========================================

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table, {String? orderBy}) async {
    final db = await instance.database;
    return await db.query(table, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> queryWhere(String table, String where, List<dynamic> whereArgs) async {
    final db = await instance.database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    final db = await instance.database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await instance.database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> clearTable(String table) async {
    final db = await instance.database;
    await db.delete(table);
  }
}