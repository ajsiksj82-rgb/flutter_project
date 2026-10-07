part of 'main.dart';

// ============================================================
// خدمة الطباعة (PDF)
// ============================================================
class PrintService {
  PrintService._();

  static pw.Font? _regular;
  static pw.Font? _bold;
  static final PdfColor _blue = PdfColor.fromInt(0xFF1565C0);
  static final PdfColor _lightBlue = PdfColor.fromInt(0xFFE3F2FD);
  static final PdfColor _zebra = PdfColor.fromInt(0xFFF5F7FA);

  /// يحمّل خط Cairo من assets/fonts (يعمل بدون إنترنت).
  /// وإن لم يوجد يحمّله من الإنترنت لمرة واحدة.
  static Future<void> _ensureFonts() async {
    if (_regular != null && _bold != null) return;
    try {
      _regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
      _bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
    } catch (_) {
      _regular = await PdfGoogleFonts.cairoRegular();
      _bold = await PdfGoogleFonts.cairoBold();
    }
  }

  // ---------- عناصر مشتركة ----------
  static pw.Widget _t(
    String s, {
    double size = 10,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    return pw.Text(
      s,
      textDirection: pw.TextDirection.rtl,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  static pw.Widget _header(OrgInfo o, String title, String? subtitle) {
    final contact = [
      if (o.address.isNotEmpty) o.address,
      if (o.phone.isNotEmpty) 'هاتف: ${o.phone}',
    ].join('   |   ');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: pw.BoxDecoration(
            color: _blue,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              _t(o.name,
                  size: 17,
                  bold: true,
                  color: PdfColors.white,
                  align: pw.TextAlign.center),
              if (contact.isNotEmpty)
                _t(contact, size: 9, color: PdfColors.white, align: pw.TextAlign.center),
            ],
          ),
        ),
        pw.SizedBox(height: 9),
        _t(title, size: 15, bold: true, align: pw.TextAlign.center),
        if (subtitle != null)
          _t(subtitle, size: 9.5, color: PdfColors.grey700, align: pw.TextAlign.center),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _footer(OrgInfo o, pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey500, width: 0.5)),
      ),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _t('${o.name} — طُبع بتاريخ ${today()}', size: 8, color: PdfColors.grey700),
            _t('صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                size: 8, color: PdfColors.grey700),
          ],
        ),
      ),
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 95, child: _t('$label :', bold: true)),
            pw.Expanded(child: _t(value)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _infoBox(List<List<String>> pairs) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [for (final pr in pairs) _kv(pr[0], pr[1])],
      ),
    );
  }

  static pw.Widget _summary(List<List<String>> items) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          children: [
            for (final it in items)
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                  padding: const pw.EdgeInsets.symmetric(vertical: 7),
                  decoration: pw.BoxDecoration(
                    color: _lightBlue,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      _t(it[0],
                          size: 9, color: PdfColors.grey800, align: pw.TextAlign.center),
                      pw.SizedBox(height: 2),
                      _t(it[1], size: 11.5, bold: true, align: pw.TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _signatures(List<String> labels, {double top = 34}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: top),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            for (final l in labels)
              pw.Column(
                children: [
                  _t(l, bold: true),
                  pw.SizedBox(height: 22),
                  pw.Container(width: 110, height: 0.6, color: PdfColors.grey700),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// جدول عربي: العمود الأول (المنطقي) يظهر في أقصى اليمين.
  /// نعكس الأعمدة يدوياً ونفرض اتجاه LTR على الجدول ليكون الناتج مضموناً.
  static pw.Widget _grid(
    List<String> headers,
    List<List<String>> rows,
    List<double> flex, {
    List<String>? footer,
  }) {
    final n = headers.length;
    final rf = flex.reversed.toList();
    final Map<int, pw.TableColumnWidth> widths = {
      for (var i = 0; i < n; i++) i: pw.FlexColumnWidth(rf[i]),
    };

    pw.Widget cell(String text, {bool bold = false, PdfColor? bg, PdfColor? fg}) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        color: bg,
        child: _t(text, size: 9.5, bold: bold, color: fg, align: pw.TextAlign.center),
      );
    }

    pw.TableRow line(List<String> cells,
        {bool header = false, bool bold = false, PdfColor? bg, PdfColor? fg}) {
      final r = cells.reversed.toList();
      return pw.TableRow(
        repeat: header,
        children: [for (final c in r) cell(c, bold: header || bold, bg: bg, fg: fg)],
      );
    }

    return pw.Directionality(
      textDirection: pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
        columnWidths: widths,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          line(headers, header: true, bg: _blue, fg: PdfColors.white),
          for (var i = 0; i < rows.length; i++)
            line(rows[i], bg: i.isOdd ? _zebra : null),
          if (footer != null) line(footer, bold: true, bg: _lightBlue),
        ],
      ),
    );
  }

  static String _rangeText(String? from, String? to) {
    if (from == null && to == null) return 'جميع الفترات';
    return 'الفترة: من ${from ?? 'البداية'} إلى ${to ?? today()}';
  }

  static Future<pw.Document> _newDoc(String title, OrgInfo org) async {
    await _ensureFonts();
    return pw.Document(
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
      title: title,
      author: org.name,
    );
  }

  static Future<Uint8List> _doc(
    String title,
    List<pw.Widget> body, {
    String? subtitle,
    bool landscape = false,
  }) async {
    final org = await OrgInfo.load();
    final doc = await _newDoc(title, org);
    doc.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [_header(org, title, subtitle), ...body],
        footer: (ctx) => _footer(org, ctx),
      ),
    );
    return doc.save();
  }

  /// سند بحجم A5 أفقي (سند قبض / سند صرف).
  static Future<Uint8List> _voucher(
    OrgInfo org, {
    required String title,
    required String no,
    required String date,
    required List<List<String>> fields,
    List<List<String>>? summary,
    required List<String> signs,
  }) async {
    final doc = await _newDoc(title, org);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
        margin: const pw.EdgeInsets.all(20),
        textDirection: pw.TextDirection.rtl,
        build: (_) => pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _blue, width: 1.4),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(org, title, null),
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _t('رقم السند: $no', bold: true),
                    _t('التاريخ: $date', bold: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              for (final f in fields) _kv(f[0], f[1]),
              if (summary != null) _summary(summary),
              pw.Spacer(),
              _signatures(signs, top: 14),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  // ============================================================
  // السندات
  // ============================================================
  static Future<Uint8List> receipt(int paymentId) async {
    final org = await OrgInfo.load();
    final pay = await AppDB.instance.paymentById(paymentId);
    if (pay == null) throw Exception('السند غير موجود');
    final st = await AppDB.instance.studentById(pay['studentId'] as int);
    final amount = (pay['amount'] as num).toDouble();
    final fees = (st?['fees'] as num? ?? 0).toDouble();
    final paid = (st?['paid'] as num? ?? 0).toDouble();
    final note = '${pay['note'] ?? ''}'.trim();

    return _voucher(
      org,
      title: 'سند قبض',
      no: paymentId.toString().padLeft(5, '0'),
      date: '${pay['date']}',
      fields: [
        ['استلمنا من', '${pay['studentName'] ?? 'غير معروف'}'],
        ['مبلغ وقدره', rialF(amount)],
        ['كتابةً', '${tafqeet(amount.round())} ريال فقط لا غير'],
        [
          'وذلك عن',
          note.isNotEmpty ? note : 'رسوم دورة ${st?['course'] ?? ''}',
        ],
      ],
      summary: [
        ['إجمالي الرسوم', rialF(fees)],
        ['إجمالي المدفوع', rialF(paid)],
        ['المتبقي', rialF(fees - paid)],
      ],
      signs: ['المستلم / أمين الصندوق', 'المتدرب', 'الختم'],
    );
  }

  static Future<Uint8List> expenseVoucher(int expenseId) async {
    final org = await OrgInfo.load();
    final e = await AppDB.instance.expenseById(expenseId);
    if (e == null) throw Exception('السند غير موجود');
    final amount = (e['amount'] as num).toDouble();
    final note = '${e['note'] ?? ''}'.trim();

    return _voucher(
      org,
      title: 'سند صرف',
      no: expenseId.toString().padLeft(5, '0'),
      date: '${e['date']}',
      fields: [
        ['صُرف مقابل', '${e['title']}'],
        ['مبلغ وقدره', rialF(amount)],
        ['كتابةً', '${tafqeet(amount.round())} ريال فقط لا غير'],
        if (note.isNotEmpty) ['ملاحظات', note],
      ],
      signs: ['المستلم', 'أمين الصندوق', 'المدير'],
    );
  }

  // ============================================================
  // المتدربون والدورات
  // ============================================================
  static Future<Uint8List> studentStatement(int studentId) async {
    final st = await AppDB.instance.studentById(studentId);
    if (st == null) throw Exception('المتدرب غير موجود');
    final pays = await AppDB.instance.paymentsOfStudent(studentId);
    final fees = (st['fees'] as num? ?? 0).toDouble();
    final paid = (st['paid'] as num? ?? 0).toDouble();

    final rows = <List<String>>[
      for (var i = 0; i < pays.length; i++)
        [
          '${i + 1}',
          '${pays[i]['id']}'.padLeft(5, '0'),
          '${pays[i]['date']}',
          '${pays[i]['note'] ?? ''}',
          thousands(pays[i]['amount'] as num),
        ],
    ];

    return _doc(
      'كشف حساب متدرب',
      [
        _infoBox([
          ['اسم المتدرب', '${st['name']}'],
          ['الدورة', '${st['course'] ?? '-'}'],
          ['المجموعة', '${st['groupName'] ?? '-'}'],
          ['رقم الهاتف', '${st['phone'] ?? '-'}'],
          ['تاريخ الالتحاق', '${st['joinDate'] ?? '-'}'],
          ['الحالة', '${st['status'] ?? '-'}'],
        ]),
        pw.SizedBox(height: 10),
        _grid(
          ['م', 'رقم السند', 'التاريخ', 'البيان', 'المبلغ (ريال)'],
          rows,
          [0.6, 1.2, 1.5, 3, 1.5],
        ),
        _summary([
          ['إجمالي الرسوم', rialF(fees)],
          ['إجمالي المدفوع', rialF(paid)],
          ['المتبقي', rialF(fees - paid)],
        ]),
        _signatures(['أمين الصندوق', 'الإدارة']),
      ],
    );
  }

  static Future<Uint8List> studentsList() async {
    final list = [...await AppDB.instance.students()]
      ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    var fees = 0.0, paid = 0.0;
    final rows = <List<String>>[];
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      final f = (s['fees'] as num? ?? 0).toDouble();
      final pd = (s['paid'] as num? ?? 0).toDouble();
      fees += f;
      paid += pd;
      rows.add([
        '${i + 1}',
        '${s['name']}',
        '${s['phone'] ?? ''}',
        '${s['course'] ?? '-'}',
        '${s['groupName'] ?? ''}',
        '${s['status'] ?? ''}',
        thousands(f),
        thousands(pd),
        thousands(f - pd),
      ]);
    }
    return _doc(
      'قائمة المتدربين',
      [
        _grid(
          ['م', 'اسم المتدرب', 'الهاتف', 'الدورة', 'المجموعة', 'الحالة', 'الرسوم', 'المدفوع', 'المتبقي'],
          rows,
          [0.5, 3, 1.6, 2, 1.3, 1.1, 1.2, 1.2, 1.2],
          footer: ['', 'الإجمالي (${list.length})', '', '', '', '', thousands(fees), thousands(paid), thousands(fees - paid)],
        ),
      ],
      subtitle: 'عدد المتدربين: ${list.length}',
      landscape: true,
    );
  }

  static Future<Uint8List> coursesList() async {
    final list = await AppDB.instance.courses();
    final rows = <List<String>>[];
    for (var i = 0; i < list.length; i++) {
      final c = list[i];
      final cnt = await AppDB.instance.studentCountForCourse('${c['name']}');
      rows.add([
        '${i + 1}',
        '${c['name']}',
        '${c['instructor'] ?? ''}',
        '${c['duration'] ?? ''}',
        thousands((c['fee'] as num? ?? 0)),
        '$cnt',
        '${c['status'] ?? ''}',
      ]);
    }
    return _doc(
      'قائمة الدورات التدريبية',
      [
        _grid(
          ['م', 'اسم الدورة', 'المدرب', 'المدة', 'الرسوم', 'المتدربون', 'الحالة'],
          rows,
          [0.5, 3, 2.2, 1.4, 1.2, 1.1, 1],
        ),
      ],
      subtitle: 'عدد الدورات: ${list.length}',
    );
  }

  // ============================================================
  // المالية
  // ============================================================
  static Future<Uint8List> paymentsReport(String? from, String? to) async {
    final list = await AppDB.instance.paymentsBetween(from, to);
    var total = 0.0;
    final rows = <List<String>>[];
    for (var i = 0; i < list.length; i++) {
      final x = list[i];
      total += (x['amount'] as num).toDouble();
      rows.add([
        '${i + 1}',
        '${x['id']}'.padLeft(5, '0'),
        '${x['date']}',
        '${x['studentName'] ?? 'غير معروف'}',
        '${x['note'] ?? ''}',
        thousands(x['amount'] as num),
      ]);
    }
    return _doc(
      'كشف التحصيل (سندات القبض)',
      [
        _grid(
          ['م', 'رقم السند', 'التاريخ', 'المتدرب', 'البيان', 'المبلغ (ريال)'],
          rows,
          [0.5, 1.1, 1.4, 2.6, 2.4, 1.4],
          footer: ['', '', '', '', 'الإجمالي (${list.length} سند)', thousands(total)],
        ),
      ],
      subtitle: _rangeText(from, to),
    );
  }

  static Future<Uint8List> expensesReport(String? from, String? to) async {
    final list = await AppDB.instance.expensesBetween(from, to);
    var total = 0.0;
    final rows = <List<String>>[];
    for (var i = 0; i < list.length; i++) {
      final x = list[i];
      total += (x['amount'] as num).toDouble();
      rows.add([
        '${i + 1}',
        '${x['date']}',
        '${x['title']}',
        '${x['note'] ?? ''}',
        thousands(x['amount'] as num),
      ]);
    }
    return _doc(
      'كشف المصروفات',
      [
        _grid(
          ['م', 'التاريخ', 'بند المصروف', 'ملاحظات', 'المبلغ (ريال)'],
          rows,
          [0.5, 1.4, 2.8, 2.6, 1.4],
          footer: ['', '', '', 'الإجمالي (${list.length})', thousands(total)],
        ),
      ],
      subtitle: _rangeText(from, to),
    );
  }

  static Future<Uint8List> financialSummary(String? from, String? to) async {
    final pays = await AppDB.instance.paymentsBetween(from, to);
    final exps = await AppDB.instance.expensesBetween(from, to);
    final totals = await AppDB.instance.totals();
    final byCourse = await AppDB.instance.courseFinance();

    final income = pays.fold<double>(0, (a, x) => a + (x['amount'] as num).toDouble());
    final spent = exps.fold<double>(0, (a, x) => a + (x['amount'] as num).toDouble());

    final rows = <List<String>>[
      for (var i = 0; i < byCourse.length; i++)
        [
          '${i + 1}',
          '${byCourse[i]['courseName']}',
          '${byCourse[i]['cnt']}',
          thousands(byCourse[i]['fees'] as num),
          thousands(byCourse[i]['paid'] as num),
          thousands((byCourse[i]['fees'] as num) - (byCourse[i]['paid'] as num)),
        ],
    ];

    return _doc(
      'الملخص المالي',
      [
        _infoBox([
          ['التحصيل في الفترة', rialF(income)],
          ['المصروفات في الفترة', rialF(spent)],
          ['صافي الفترة', rialF(income - spent)],
        ]),
        pw.SizedBox(height: 6),
        _summary([
          ['إجمالي الرسوم المستحقة', rialF(totals['fees'] as num)],
          ['إجمالي المحصّل', rialF(totals['payments'] as num)],
          ['المتبقي على المتدربين', rialF(totals['remaining'] as num)],
        ]),
        pw.SizedBox(height: 12),
        _t('تفصيل حسب الدورة', size: 12, bold: true),
        pw.SizedBox(height: 4),
        _grid(
          ['م', 'الدورة', 'المتدربون', 'الرسوم', 'المحصّل', 'المتبقي'],
          rows,
          [0.5, 3, 1.2, 1.4, 1.4, 1.4],
        ),
        _signatures(['المحاسب', 'المدير']),
      ],
      subtitle: _rangeText(from, to),
    );
  }

  static Future<Uint8List> debtors() async {
    final list = (await AppDB.instance.students())
        .where((s) => ((s['fees'] as num? ?? 0) - (s['paid'] as num? ?? 0)) > 0)
        .toList()
      ..sort((a, b) {
        final ra = ((a['fees'] as num?) ?? 0) - ((a['paid'] as num?) ?? 0);
        final rb = ((b['fees'] as num?) ?? 0) - ((b['paid'] as num?) ?? 0);
        return rb.compareTo(ra);
      });
    var total = 0.0;
    final rows = <List<String>>[];
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      final f = (s['fees'] as num? ?? 0).toDouble();
      final pd = (s['paid'] as num? ?? 0).toDouble();
      total += f - pd;
      rows.add([
        '${i + 1}',
        '${s['name']}',
        '${s['phone'] ?? ''}',
        '${s['course'] ?? '-'}',
        thousands(f),
        thousands(pd),
        thousands(f - pd),
      ]);
    }
    return _doc(
      'المتدربون المتبقي عليهم مبالغ',
      [
        _grid(
          ['م', 'اسم المتدرب', 'الهاتف', 'الدورة', 'الرسوم', 'المدفوع', 'المتبقي'],
          rows,
          [0.5, 3, 1.7, 2, 1.2, 1.2, 1.3],
          footer: ['', 'إجمالي المتبقي (${list.length})', '', '', '', '', thousands(total)],
        ),
      ],
      subtitle: 'مرتّبة من الأعلى مبلغاً متبقياً إلى الأقل',
    );
  }

  // ============================================================
  // الحضور
  // ============================================================
  static Future<Uint8List> attendanceDaily(
    String date,
    String course,
    List<Map<String, dynamic>> rowsData,
  ) async {
    final present = rowsData.where((r) => r['present'] == 1).length;
    final rows = <List<String>>[
      for (var i = 0; i < rowsData.length; i++)
        [
          '${i + 1}',
          '${rowsData[i]['name']}',
          '${rowsData[i]['course'] ?? '-'}',
          rowsData[i]['present'] == 1 ? 'حاضر' : 'غائب',
        ],
    ];
    return _doc(
      'كشف الحضور والغياب',
      [
        _grid(['م', 'اسم المتدرب', 'الدورة', 'الحالة'], rows, [0.6, 3.5, 2.5, 1.2]),
        _summary([
          ['الحاضرون', '$present'],
          ['الغائبون', '${rowsData.length - present}'],
          ['الإجمالي', '${rowsData.length}'],
        ]),
        _signatures(['المدرب', 'الإدارة']),
      ],
      subtitle: 'التاريخ: $date   •   الدورة: $course',
    );
  }

  static Future<Uint8List> attendanceSummary(String course) async {
    final list = await AppDB.instance.attendanceSummary(course);
    final rows = <List<String>>[];
    for (var i = 0; i < list.length; i++) {
      final r = list[i];
      final pr = (r['presentDays'] as num).toInt();
      final ab = (r['absentDays'] as num).toInt();
      final total = pr + ab;
      rows.add([
        '${i + 1}',
        '${r['name']}',
        '${r['course'] ?? '-'}',
        '$pr',
        '$ab',
        total == 0 ? '-' : '${(pr / total * 100).toStringAsFixed(0)}%',
      ]);
    }
    return _doc(
      'تقرير الحضور والغياب',
      [
        _grid(
          ['م', 'اسم المتدرب', 'الدورة', 'أيام الحضور', 'أيام الغياب', 'نسبة الحضور'],
          rows,
          [0.5, 3, 2.2, 1.2, 1.2, 1.2],
        ),
      ],
      subtitle: 'الدورة: $course',
    );
  }

  // ============================================================
  // الدرجات
  // ============================================================
  static Future<Uint8List> gradesSheet(String course) async {
    final t = await buildGradeTable(course);
    final flex = <double>[
      0.5,
      3,
      for (var i = 0; i < t.examCount; i++) 1.3,
      1.5,
      1.1,
      1.3,
      0.9,
    ];
    return _doc(
      'كشف الدرجات',
      [
        _grid(t.headers, t.rows, flex),
        pw.SizedBox(height: 6),
        _t('ملاحظة: المجموع والنسبة محسوبان على الاختبارات التي أُدخلت للمتدرب فقط.',
            size: 8.5, color: PdfColors.grey700),
        _signatures(['المدرب', 'رئيس القسم', 'المدير']),
      ],
      subtitle: 'الدورة: $course',
      landscape: t.examCount > 3,
    );
  }

  static Future<Uint8List> examSheet(String course, String exam) async {
    final students = await AppDB.instance.studentsOfCourse(course);
    final grades = (await AppDB.instance.gradesOfCourse(course))
        .where((g) => g['examName'] == exam)
        .toList();
    final scoreOf = <int, double>{
      for (final g in grades) g['studentId'] as int: (g['score'] as num).toDouble(),
    };
    final max = grades.isEmpty ? 100.0 : (grades.first['maxScore'] as num).toDouble();

    final rows = <List<String>>[];
    for (var i = 0; i < students.length; i++) {
      final id = students[i]['id'] as int;
      final sc = scoreOf[id];
      rows.add([
        '${i + 1}',
        '${students[i]['name']}',
        sc == null ? '-' : fmtN(sc),
        fmtN(max),
        sc == null ? '-' : '${(sc / max * 100).toStringAsFixed(1)}%',
        sc == null ? '-' : ratingOf(sc / max * 100),
      ]);
    }
    final vals = scoreOf.values.toList();
    final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;

    return _doc(
      'كشف درجات: $exam',
      [
        _grid(
          ['م', 'اسم المتدرب', 'الدرجة', 'العظمى', 'النسبة', 'التقدير'],
          rows,
          [0.5, 3.2, 1.1, 1.1, 1.2, 1.4],
        ),
        _summary([
          ['عدد المختبَرين', '${vals.length}'],
          ['المتوسط', vals.isEmpty ? '-' : avg.toStringAsFixed(1)],
          ['الأعلى', vals.isEmpty ? '-' : fmtN(vals.reduce((a, b) => a > b ? a : b))],
          ['الأدنى', vals.isEmpty ? '-' : fmtN(vals.reduce((a, b) => a < b ? a : b))],
        ]),
        _signatures(['المدرب', 'المدير']),
      ],
      subtitle: 'الدورة: $course',
    );
  }

  static Future<Uint8List> studentTranscript(int studentId) async {
    final st = await AppDB.instance.studentById(studentId);
    if (st == null) throw Exception('المتدرب غير موجود');
    final grades = await AppDB.instance.gradesOfStudent(studentId);
    final rate = await AppDB.instance.attendanceRateForStudent(studentId);

    var sum = 0.0, max = 0.0;
    final rows = <List<String>>[];
    for (var i = 0; i < grades.length; i++) {
      final g = grades[i];
      final sc = (g['score'] as num).toDouble();
      final mx = (g['maxScore'] as num).toDouble();
      sum += sc;
      max += mx;
      rows.add([
        '${i + 1}',
        '${g['examName']}',
        fmtN(sc),
        fmtN(mx),
        '${(mx == 0 ? 0 : sc / mx * 100).toStringAsFixed(1)}%',
        ratingOf(mx == 0 ? 0 : sc / mx * 100),
      ]);
    }
    final pct = max == 0 ? 0.0 : sum / max * 100;

    return _doc(
      'كشف درجات متدرب',
      [
        _infoBox([
          ['اسم المتدرب', '${st['name']}'],
          ['الدورة', '${st['course'] ?? '-'}'],
          ['المجموعة', '${st['groupName'] ?? '-'}'],
          if (rate >= 0) ['نسبة الحضور', '${rate.toStringAsFixed(0)}%'],
        ]),
        pw.SizedBox(height: 10),
        if (grades.isEmpty)
          _t('لا توجد درجات مسجلة لهذا المتدرب.', align: pw.TextAlign.center)
        else ...[
          _grid(
            ['م', 'الاختبار / المادة', 'الدرجة', 'العظمى', 'النسبة', 'التقدير'],
            rows,
            [0.5, 3.4, 1.1, 1.1, 1.2, 1.4],
          ),
          _summary([
            ['المجموع', '${fmtN(sum)} / ${fmtN(max)}'],
            ['النسبة المئوية', '${pct.toStringAsFixed(1)}%'],
            ['التقدير العام', ratingOf(pct)],
          ]),
        ],
        _signatures(['المدرب', 'المدير']),
      ],
    );
  }
}