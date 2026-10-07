part of 'main.dart';

// ============================================================
// قاعدة البيانات المحلية SQLite
// ============================================================
class AppDB {
  AppDB._();
  static final AppDB instance = AppDB._();
  Database? _db;

  Future<void> init() async {
    final path = await getDatabasesPath();
    _db = await openDatabase(
      p.join(path, 'smart_skills.db'),
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createGrades(db);
        if (oldVersion < 3) await _createInstructors(db);
      },
      onCreate: (db, version) async {
        await _createGrades(db);
        await _createInstructors(db);
        await db.execute("""
          CREATE TABLE students(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            gender TEXT,
            course TEXT,
            groupName TEXT,
            joinDate TEXT,
            status TEXT,
            fees REAL DEFAULT 0,
            paid REAL DEFAULT 0
          )
        """);
        await db.execute("""
          CREATE TABLE courses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            instructor TEXT,
            duration TEXT,
            fee REAL DEFAULT 0,
            status TEXT
          )
        """);
        await db.execute("""
          CREATE TABLE attendance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId INTEGER NOT NULL,
            date TEXT NOT NULL,
            present INTEGER NOT NULL
          )
        """);
        await db.execute("""
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            studentId INTEGER NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT
          )
        """);
        await db.execute("""
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            note TEXT
          )
        """);
        await db.execute("""
          CREATE TABLE app_info(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        """);
        await db.insert('app_info', {
          'key': 'institute_name',
          'value': 'معهد سمارت سكلز للتدريب والتأهيل'
        });
        await db.insert('app_info', {
          'key': 'manager',
          'value': 'أ. أحمد داود طه شريف'
        });
        // Seed with a starter course so the student form always has
        // at least one option to pick from.
        await db.insert('courses', {
          'name': 'دبلوم الحاسوب',
          'instructor': 'أ. أحمد داود طه شريف',
          'duration': '3 أشهر',
          'fee': 0,
          'status': 'نشطة',
        });
      },
    );
  }

  Database get db => _db!;

  // ---------- Students ----------
  Future<List<Map<String, dynamic>>> students() =>
      db.query('students', orderBy: 'id DESC');

  Future<int> addStudent(Map<String, dynamic> data) =>
      db.insert('students', data);

  Future<int> updateStudent(int id, Map<String, dynamic> data) =>
      db.update('students', data, where: 'id=?', whereArgs: [id]);

  Future<void> deleteStudent(int id) async {
    await db.delete('attendance', where: 'studentId=?', whereArgs: [id]);
    await db.delete('grades', where: 'studentId=?', whereArgs: [id]);
    await db.delete('payments', where: 'studentId=?', whereArgs: [id]);
    await db.delete('students', where: 'id=?', whereArgs: [id]);
  }

  // ---------- Courses ----------
  Future<List<Map<String, dynamic>>> courses() =>
      db.query('courses', orderBy: 'id DESC');

  Future<int> addCourse(Map<String, dynamic> data) =>
      db.insert('courses', data);

  Future<int> updateCourse(int id, Map<String, dynamic> data) async {
    // عند تغيير اسم الدورة نحدّث المتدربين والدرجات المرتبطة بها.
    final old = await db.query('courses',
        columns: ['name'], where: 'id=?', whereArgs: [id]);
    final oldName = old.isEmpty ? null : old.first['name'] as String?;
    final newName = data['name'] as String?;
    if (oldName != null && newName != null && oldName != newName) {
      await db.update('students', {'course': newName},
          where: 'course=?', whereArgs: [oldName]);
      await db.update('grades', {'course': newName},
          where: 'course=?', whereArgs: [oldName]);
    }
    return db.update('courses', data, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteCourse(int id, String name) async {
    // Unlink any students who were enrolled in this course rather than
    // leaving them pointed at a course that no longer exists.
    await db.update(
      'students',
      {'course': null},
      where: 'course=?',
      whereArgs: [name],
    );
    await db.delete('courses', where: 'id=?', whereArgs: [id]);
  }

  Future<int> studentCountForCourse(String name) async {
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM students WHERE course=?',
            [name],
          ),
        ) ??
        0;
  }

  // ---------- Payments ----------
  Future<List<Map<String, dynamic>>> payments() => db.rawQuery("""
        SELECT p.*, s.name studentName
        FROM payments p
        LEFT JOIN students s ON s.id = p.studentId
        ORDER BY p.id DESC
      """);

  Future<int> addPayment(Map<String, dynamic> data) async {
    final id = await db.insert('payments', data);
    await db.rawUpdate(
      'UPDATE students SET paid = paid + ? WHERE id = ?',
      [data['amount'], data['studentId']],
    );
    return id;
  }

  Future<void> updatePayment(
      int id, int studentId, double oldAmount, Map<String, dynamic> data) async {
    await db.update('payments', data, where: 'id=?', whereArgs: [id]);
    final newStudent = (data['studentId'] as int?) ?? studentId;
    final newAmount = (data['amount'] as num).toDouble();
    if (newStudent != studentId) {
      // تغيّر المتدرب: نخصم من القديم ونضيف للجديد.
      await db.rawUpdate(
          'UPDATE students SET paid = paid - ? WHERE id = ?', [oldAmount, studentId]);
      await db.rawUpdate(
          'UPDATE students SET paid = paid + ? WHERE id = ?', [newAmount, newStudent]);
    } else if (newAmount != oldAmount) {
      await db.rawUpdate('UPDATE students SET paid = paid + ? WHERE id = ?',
          [newAmount - oldAmount, studentId]);
    }
  }

  Future<void> deletePayment(int id, int studentId, double amount) async {
    await db.delete('payments', where: 'id=?', whereArgs: [id]);
    await db.rawUpdate(
      'UPDATE students SET paid = paid - ? WHERE id = ?',
      [amount, studentId],
    );
  }

  // ---------- Expenses ----------
  Future<List<Map<String, dynamic>>> expenses() =>
      db.query('expenses', orderBy: 'id DESC');

  Future<int> addExpense(Map<String, dynamic> data) =>
      db.insert('expenses', data);

  Future<int> updateExpense(int id, Map<String, dynamic> data) =>
      db.update('expenses', data, where: 'id=?', whereArgs: [id]);

  Future<void> deleteExpense(int id) =>
      db.delete('expenses', where: 'id=?', whereArgs: [id]);

  // ---------- Attendance ----------
  Future<List<Map<String, dynamic>>> attendanceForDate(
      String date, String? courseFilter) async {
    if (courseFilter == null || courseFilter == 'الكل') {
      return db.rawQuery("""
        SELECT s.id, s.name, s.course,
               COALESCE(a.present, 0) present
        FROM students s
        LEFT JOIN attendance a
          ON a.studentId=s.id AND a.date=?
        ORDER BY s.name
      """, [date]);
    }
    return db.rawQuery("""
        SELECT s.id, s.name, s.course,
               COALESCE(a.present, 0) present
        FROM students s
        LEFT JOIN attendance a
          ON a.studentId=s.id AND a.date=?
        WHERE s.course=?
        ORDER BY s.name
      """, [date, courseFilter]);
  }

  Future<void> saveAttendance(
      String date, int studentId, bool present) async {
    final old = await db.query(
      'attendance',
      where: 'studentId=? AND date=?',
      whereArgs: [studentId, date],
    );
    if (old.isEmpty) {
      await db.insert('attendance', {
        'studentId': studentId,
        'date': date,
        'present': present ? 1 : 0,
      });
    } else {
      await db.update(
        'attendance',
        {'present': present ? 1 : 0},
        where: 'studentId=? AND date=?',
        whereArgs: [studentId, date],
      );
    }
  }

  Future<double> attendanceRateForStudent(int studentId) async {
    final total = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM attendance WHERE studentId=?',
          [studentId],
        )) ??
        0;
    if (total == 0) return -1; // no records yet
    final present = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM attendance WHERE studentId=? AND present=1',
          [studentId],
        )) ??
        0;
    return present / total * 100;
  }

  // ---------- App info / Settings ----------
  Future<String> getInfo(String key, String fallback) async {
    final rows =
        await db.query('app_info', where: 'key=?', whereArgs: [key]);
    if (rows.isEmpty) return fallback;
    return (rows.first['value'] as String?) ?? fallback;
  }

  Future<void> setInfo(String key, String value) async {
    await db.insert(
      'app_info',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- قفل التطبيق برمز سري ----------
  String _hashPin(String pin) {
    // تجزئة بسيطة محلية (ليست تشفيراً قوياً) — كافية لمنع فتح التطبيق
    // عشوائياً على جهاز مشترك، وتتجنب تخزين الرمز كنص واضح.
    var h = 0;
    for (final code in utf8.encode('smart_skills_salt::$pin')) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h.toString();
  }

  Future<bool> hasPin() async {
    final v = await getInfo('app_pin_hash', '');
    return v.isNotEmpty;
  }

  Future<void> setPin(String pin) => setInfo('app_pin_hash', _hashPin(pin));

  Future<void> clearPin() => setInfo('app_pin_hash', '');

  Future<bool> verifyPin(String pin) async {
    final stored = await getInfo('app_pin_hash', '');
    return stored.isNotEmpty && stored == _hashPin(pin);
  }

  // ---------- المدربون ----------
  static Future<void> _createInstructors(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS instructors(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        specialty TEXT,
        notes TEXT,
        status TEXT
      )
    """);
  }

  Future<List<Map<String, dynamic>>> instructors() =>
      db.query('instructors', orderBy: 'id DESC');

  Future<int> addInstructor(Map<String, dynamic> data) =>
      db.insert('instructors', data);

  Future<int> updateInstructor(int id, Map<String, dynamic> data) async {
    // عند تغيير اسم المدرب نحدّث الدورات المرتبطة به ليبقى الربط صحيحاً.
    final old = await db.query('instructors',
        columns: ['name'], where: 'id=?', whereArgs: [id]);
    final oldName = old.isEmpty ? null : old.first['name'] as String?;
    final newName = data['name'] as String?;
    if (oldName != null && newName != null && oldName != newName) {
      await db.update('courses', {'instructor': newName},
          where: 'instructor=?', whereArgs: [oldName]);
    }
    return db.update('instructors', data, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteInstructor(int id, String name) async {
    // إبقاء الدورات كما هي، وفك ارتباطها بالمدرب المحذوف فقط.
    await db.update(
      'courses',
      {'instructor': null},
      where: 'instructor=?',
      whereArgs: [name],
    );
    await db.delete('instructors', where: 'id=?', whereArgs: [id]);
  }

  Future<int> courseCountForInstructor(String name) async {
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM courses WHERE instructor=?',
            [name],
          ),
        ) ??
        0;
  }

  // ---------- إضافات الإصدار 3 ----------
  static Future<void> _createGrades(Database db) async {
    await db.execute("""
      CREATE TABLE IF NOT EXISTS grades(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        course TEXT NOT NULL,
        examName TEXT NOT NULL,
        maxScore REAL NOT NULL DEFAULT 100,
        score REAL NOT NULL,
        date TEXT,
        note TEXT
      )
    """);
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_grades_unique '
      'ON grades(studentId, course, examName)',
    );
  }

  Future<String> dbPath() async =>
      p.join(await getDatabasesPath(), 'smart_skills.db');

  Future<void> closeDb() async {
    await _db?.close();
    _db = null;
  }

  Future<Map<String, dynamic>?> studentById(int id) async {
    final r = await db.query('students', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> paymentById(int id) async {
    final r = await db.rawQuery("""
      SELECT p.*, s.name studentName
      FROM payments p
      LEFT JOIN students s ON s.id = p.studentId
      WHERE p.id = ?
    """, [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> expenseById(int id) async {
    final r = await db.query('expenses', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Map<String, dynamic>>> paymentsOfStudent(int id) => db.query(
        'payments',
        where: 'studentId=?',
        whereArgs: [id],
        orderBy: 'date ASC, id ASC',
      );

  Future<List<Map<String, dynamic>>> paymentsBetween(String? from, String? to) {
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('p.date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('p.date <= ?');
      args.add(to);
    }
    return db.rawQuery(
      'SELECT p.*, s.name studentName FROM payments p '
      'LEFT JOIN students s ON s.id = p.studentId '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY p.date ASC, p.id ASC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> expensesBetween(String? from, String? to) {
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to);
    }
    return db.rawQuery(
      'SELECT * FROM expenses '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY date ASC, id ASC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> courseFinance() => db.rawQuery("""
      SELECT COALESCE(course, 'بدون دورة') courseName,
             COUNT(*) cnt,
             COALESCE(SUM(fees), 0) fees,
             COALESCE(SUM(paid), 0) paid
      FROM students
      GROUP BY course
      ORDER BY courseName
    """);

  Future<void> ensureCourse(String name) async {
    final r = await db.query('courses', where: 'name=?', whereArgs: [name]);
    if (r.isEmpty) {
      await db.insert('courses', {
        'name': name,
        'instructor': '',
        'duration': '',
        'fee': 0,
        'status': 'نشطة',
      });
    }
  }

  Future<List<Map<String, dynamic>>> attendanceSummary(String? course) {
    final filtered = course != null && course != 'الكل';
    return db.rawQuery("""
      SELECT s.id, s.name, s.course,
             COALESCE(SUM(CASE WHEN a.present = 1 THEN 1 ELSE 0 END), 0) presentDays,
             COALESCE(SUM(CASE WHEN a.present = 0 THEN 1 ELSE 0 END), 0) absentDays
      FROM students s
      LEFT JOIN attendance a ON a.studentId = s.id
      ${filtered ? 'WHERE s.course = ?' : ''}
      GROUP BY s.id
      ORDER BY s.name
    """, filtered ? [course] : []);
  }

  // ---------- الدرجات ----------
  Future<List<Map<String, dynamic>>> studentsOfCourse(String course) =>
      db.query('students', where: 'course=?', whereArgs: [course], orderBy: 'name');

  Future<List<Map<String, dynamic>>> examsOfCourse(String course) =>
      db.rawQuery("""
        SELECT examName,
               MAX(maxScore) maxScore,
               COUNT(*) cnt,
               AVG(score) avg,
               MIN(id) firstId
        FROM grades
        WHERE course = ?
        GROUP BY examName
        ORDER BY firstId
      """, [course]);

  Future<List<Map<String, dynamic>>> gradesOfCourse(String course) =>
      db.query('grades', where: 'course=?', whereArgs: [course], orderBy: 'id');

  Future<List<Map<String, dynamic>>> gradesOfStudent(int studentId) =>
      db.query('grades', where: 'studentId=?', whereArgs: [studentId], orderBy: 'id');

  Future<void> _upsertGrade(DatabaseExecutor ex, int studentId, String course,
      String exam, double max, double? score) async {
    const where = 'studentId=? AND course=? AND examName=?';
    final args = [studentId, course, exam];
    if (score == null) {
      await ex.delete('grades', where: where, whereArgs: args);
      return;
    }
    final old =
        await ex.query('grades', columns: ['id'], where: where, whereArgs: args);
    final data = {
      'studentId': studentId,
      'course': course,
      'examName': exam,
      'maxScore': max,
      'score': score,
      'date': today(),
    };
    if (old.isEmpty) {
      await ex.insert('grades', data);
    } else {
      await ex.update('grades', data, where: where, whereArgs: args);
    }
  }

  /// يحفظ درجات اختبار لعدة متدربين. القيمة null تعني حذف الدرجة.
  Future<void> saveGrades(
      String course, String exam, double max, Map<int, double?> scores) async {
    await db.transaction((txn) async {
      for (final e in scores.entries) {
        await _upsertGrade(txn, e.key, course, exam, max, e.value);
      }
    });
  }

  Future<void> updateExamMax(String course, String exam, double max) => db.update(
        'grades',
        {'maxScore': max},
        where: 'course=? AND examName=?',
        whereArgs: [course, exam],
      );

  Future<void> renameExam(String course, String oldName, String newName) =>
      db.update(
        'grades',
        {'examName': newName},
        where: 'course=? AND examName=?',
        whereArgs: [course, oldName],
      );

  Future<void> deleteExam(String course, String exam) => db.delete(
        'grades',
        where: 'course=? AND examName=?',
        whereArgs: [course, exam],
      );
  // ---------- Totals ----------
  Future<Map<String, dynamic>> totals() async {
    final students = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM students'),
        ) ??
        0;
    final courses = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM courses'),
        ) ??
        0;
    final instructorsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM instructors'),
        ) ??
        0;
    final payments = ((await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) total FROM payments',
    )).first['total'] as num).toDouble();
    final expenses = ((await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) total FROM expenses',
    )).first['total'] as num).toDouble();
    final fees = ((await db.rawQuery(
      'SELECT COALESCE(SUM(fees),0) total FROM students',
    )).first['total'] as num).toDouble();

    return {
      'students': students,
      'courses': courses,
      'instructors': instructorsCount,
      'payments': payments,
      'expenses': expenses,
      'fees': fees,
      'balance': payments - expenses,
      'remaining': fees - payments,
    };
  }

  // ---------- لوحة التحكم: المتأخرون والإيرادات الشهرية ----------
  Future<List<Map<String, dynamic>>> topDebtors({int limit = 5}) => db.rawQuery("""
      SELECT id, name, course, fees, paid, (fees - paid) remaining
      FROM students
      WHERE (fees - paid) > 0
      ORDER BY remaining DESC
      LIMIT ?
    """, [limit]);

  /// إجمالي التحصيل لكل من آخر [months] أشهر (تصاعدياً من الأقدم للأحدث).
  Future<List<Map<String, dynamic>>> monthlyRevenue({int months = 6}) async {
    final now = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (var i = months - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final monthStart = '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}';
      final total = ((await db.rawQuery(
        "SELECT COALESCE(SUM(amount),0) total FROM payments WHERE date LIKE ?",
        ['$monthStart%'],
      )).first['total'] as num).toDouble();
      out.add({'month': monthStart, 'total': total});
    }
    return out;
  }
}

