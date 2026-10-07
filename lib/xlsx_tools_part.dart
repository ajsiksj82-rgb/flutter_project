part of 'main.dart';

// ============================================================
// Excel: استيراد وتصدير
// ============================================================
class XlsxTools {
  XlsxTools._();

  static String _cell(xl.Data? d) {
    final v = d?.value;
    if (v == null) return '';
    if (v is xl.DoubleCellValue) {
      final x = v.value;
      return x == x.roundToDouble() ? x.toInt().toString() : x.toString();
    }
    return v.toString().trim();
  }

  /// توحيد الأحرف العربية للمقارنة (أ/إ/آ → ا ، ة → ه ، ى → ي ...).
  static String norm(String s) {
    var t = normDigits(s).trim().toLowerCase();
    t = t
        .replaceAll(RegExp(r'[\u064B-\u065F\u0640]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }

  static Future<List<List<String>>?> pickRows() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return null;
    final book = xl.Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) return <List<String>>[];
    final sheet = book.tables.values.first;
    final out = <List<String>>[];
    for (final row in sheet.rows) {
      final cells = row.map(_cell).toList();
      if (cells.every((c) => c.isEmpty)) continue;
      out.add(cells);
    }
    return out;
  }

  static Future<void> saveTable(
    String fileName,
    List<String> headers,
    List<List<dynamic>> rows,
  ) async {
    final book = xl.Excel.createExcel();
    final sheet = book['Sheet1'];
    final head = <xl.CellValue?>[];
    for (final h in headers) {
      head.add(xl.TextCellValue(h));
    }
    sheet.appendRow(head);
    for (final r in rows) {
      final line = <xl.CellValue?>[];
      for (final v in r) {
        if (v is num) {
          line.add(xl.DoubleCellValue(v.toDouble()));
        } else {
          line.add(xl.TextCellValue('${v ?? ''}'));
        }
      }
      sheet.appendRow(line);
    }
    final bytes = book.encode();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel');
    await shareBytes(bytes, fileName);
  }

  static int _col(List<String> normHeaders, List<String> names) {
    for (final n in names) {
      final i = normHeaders.indexOf(norm(n));
      if (i >= 0) return i;
    }
    return -1;
  }

  static String _at(List<String> row, int i) =>
      (i >= 0 && i < row.length) ? row[i].trim() : '';

  // ---------- المتدربون ----------
  static Future<void> studentsTemplate() => saveTable(
        'students_template.xlsx',
        ['اسم المتدرب', 'رقم الهاتف', 'الجنس', 'الدورة', 'المجموعة', 'الرسوم', 'الحالة'],
        [],
      );

  static Future<void> exportStudents() async {
    final list = await AppDB.instance.students();
    await saveTable(
      'students_${today()}.xlsx',
      [
        'رقم المتدرب', 'اسم المتدرب', 'رقم الهاتف', 'الجنس', 'الدورة',
        'المجموعة', 'الحالة', 'الرسوم', 'المدفوع', 'المتبقي',
      ],
      [
        for (final s in list)
          [
            s['id'],
            s['name'],
            s['phone'],
            s['gender'],
            s['course'],
            s['groupName'],
            s['status'],
            (s['fees'] as num? ?? 0),
            (s['paid'] as num? ?? 0),
            ((s['fees'] as num? ?? 0) - (s['paid'] as num? ?? 0)),
          ],
      ],
    );
  }

  static Future<void> exportPayments() async {
    final list = await AppDB.instance.paymentsBetween(null, null);
    await saveTable(
      'payments_${today()}.xlsx',
      ['رقم السند', 'التاريخ', 'المتدرب', 'المبلغ', 'البيان'],
      [
        for (final x in list)
          [x['id'], x['date'], x['studentName'], (x['amount'] as num), x['note']],
      ],
    );
  }

  /// يعيد نص النتيجة، أو null إذا أُلغي الاختيار.
  static Future<String?> importStudents() async {
    final rows = await pickRows();
    if (rows == null) return null;
    if (rows.length < 2) return 'الملف فارغ أو لا يحتوي على بيانات.';

    final h = rows.first.map(norm).toList();
    final cName = _col(h, ['اسم المتدرب', 'الاسم', 'المتدرب', 'name']);
    if (cName < 0) return 'لم أجد عمود "اسم المتدرب" في الصف الأول.';
    final cPhone = _col(h, ['رقم الهاتف', 'الهاتف', 'الجوال', 'phone']);
    final cGender = _col(h, ['الجنس']);
    final cCourse = _col(h, ['الدورة', 'course']);
    final cGroup = _col(h, ['المجموعة', 'الشعبة']);
    final cFees = _col(h, ['الرسوم', 'الرسوم الكلية', 'fees']);
    final cStatus = _col(h, ['الحالة']);

    final existing = await AppDB.instance.students();
    final seen = <String>{
      for (final s in existing) '${norm('${s['name']}')}|${'${s['phone'] ?? ''}'.trim()}',
    };

    var added = 0;
    var skipped = 0;
    for (final r in rows.skip(1)) {
      final name = _at(r, cName);
      if (name.isEmpty) continue;
      final phone = _at(r, cPhone);
      final key = '${norm(name)}|$phone';
      if (seen.contains(key)) {
        skipped++;
        continue;
      }
      seen.add(key);

      final course = _at(r, cCourse);
      if (course.isNotEmpty) await AppDB.instance.ensureCourse(course);
      final g = norm(_at(r, cGender));
      final status = _at(r, cStatus);
      await AppDB.instance.addStudent({
        'name': name,
        'phone': phone,
        'gender': g.contains('انث') ? 'أنثى' : 'ذكر',
        'course': course.isEmpty ? null : course,
        'groupName': _at(r, cGroup),
        'status': status.isEmpty ? 'منتظم' : status,
        'fees': parseNum(_at(r, cFees)) ?? 0,
        'paid': 0,
        'joinDate': today(),
      });
      added++;
    }
    return 'تمت إضافة $added متدرب.'
        '${skipped > 0 ? '\nتم تجاهل $skipped مكرر (نفس الاسم والهاتف).' : ''}';
  }

  // ---------- الدرجات ----------
  static Future<void> gradesTemplate(String course) async {
    final students = await AppDB.instance.studentsOfCourse(course);
    await saveTable(
      'grades_template.xlsx',
      ['رقم المتدرب', 'اسم المتدرب', 'الاختبار الأول (100)', 'الاختبار الثاني (100)'],
      [
        for (final s in students) [s['id'], s['name'], '', ''],
      ],
    );
  }

  static Future<void> exportGrades(String course) async {
    final t = await buildGradeTable(course);
    await saveTable('grades_${today()}.xlsx', t.headers, t.rows);
  }

  static Future<String?> importGrades(String course, double defaultMax) async {
    final rows = await pickRows();
    if (rows == null) return null;
    if (rows.length < 2) return 'الملف فارغ أو لا يحتوي على بيانات.';

    final students = await AppDB.instance.studentsOfCourse(course);
    if (students.isEmpty) return 'لا يوجد متدربون في هذه الدورة.';
    final byName = <String, int>{
      for (final s in students) norm('${s['name']}'): s['id'] as int,
    };
    final ids = <int>{for (final s in students) s['id'] as int};

    final head = rows.first;
    final nh = head.map(norm).toList();
    var cName = _col(nh, ['اسم المتدرب', 'الاسم', 'المتدرب', 'name']);
    final cId = _col(nh, ['رقم المتدرب', 'الرقم', 'id', 'المعرف']);
    if (cName < 0 && cId < 0) cName = 0;

    final skip = <String>{
      'م', '#', 'no', 'المجموع', 'المجموع الكلي', 'النسبه', 'التقدير', 'الترتيب',
    };
    final examCols = <int>[];
    final examNames = <int, String>{};
    final examMax = <int, double>{};
    final headRe = RegExp(r'^(.*?)\s*[\(\[]\s*([0-9]+(?:\.[0-9]+)?)\s*[\)\]]\s*$');
    for (var i = 0; i < head.length; i++) {
      if (i == cName || i == cId) continue;
      final raw = normDigits(head[i]).trim();
      if (raw.isEmpty || skip.contains(norm(raw))) continue;
      final m = headRe.firstMatch(raw);
      if (m != null && m.group(1)!.trim().isNotEmpty) {
        examNames[i] = m.group(1)!.trim();
        examMax[i] = double.tryParse(m.group(2)!) ?? defaultMax;
      } else {
        examNames[i] = raw;
        examMax[i] = defaultMax;
      }
      examCols.add(i);
    }
    if (examCols.isEmpty) return 'لم أجد أعمدة اختبارات بعد عمود الاسم.';

    final scores = <int, Map<int, double>>{for (final c in examCols) c: {}};
    final unmatched = <String>[];
    var invalid = 0;

    for (final r in rows.skip(1)) {
      int? sid;
      if (cId >= 0) {
        final n = int.tryParse(normDigits(_at(r, cId)).split('.').first);
        if (n != null && ids.contains(n)) sid = n;
      }
      if (sid == null && cName >= 0) {
        final nm = _at(r, cName);
        if (nm.isEmpty && cId < 0) continue;
        sid = byName[norm(nm)];
        if (sid == null) {
          if (nm.isNotEmpty) unmatched.add(nm);
          continue;
        }
      }
      if (sid == null) continue;

      for (final c in examCols) {
        final txt = _at(r, c);
        if (txt.isEmpty) continue;
        final v = parseNum(txt);
        if (v == null || v < 0 || v > examMax[c]!) {
          invalid++;
          continue;
        }
        scores[c]![sid] = v;
      }
    }

    var total = 0;
    for (final c in examCols) {
      final map = scores[c]!;
      if (map.isEmpty) continue;
      await AppDB.instance.updateExamMax(course, examNames[c]!, examMax[c]!);
      await AppDB.instance.saveGrades(
        course,
        examNames[c]!,
        examMax[c]!,
        {for (final e in map.entries) e.key: e.value},
      );
      total += map.length;
    }

    final b = StringBuffer('تم استيراد $total درجة في ${examCols.length} اختبار/أعمدة.');
    if (invalid > 0) b.write('\nتم تجاهل $invalid خلية غير صالحة (نص أو أكبر من الدرجة العظمى).');
    if (unmatched.isNotEmpty) {
      final shown = unmatched.take(15).join('، ');
      b.write('\nلم يُعثر على ${unmatched.length} اسم في هذه الدورة:\n$shown');
    }
    return b.toString();
  }
}

