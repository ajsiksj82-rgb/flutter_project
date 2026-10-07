part of 'main.dart';

// ============================================================
// أدوات مشتركة
// ============================================================
String today() => DateTime.now().toIso8601String().substring(0, 10);
String money(num v) => '${v.toStringAsFixed(0)} ريال';

void toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class EmptyState extends StatelessWidget {
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 70, color: Colors.grey),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.grey)),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.12),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// أدوات مشتركة إضافية (الطباعة، الأرقام، الدرجات)
// ============================================================
Future<void> guarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) toast(context, 'حدث خطأ: $e', error: true);
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String content,
  String okLabel = 'متابعة',
  String cancelLabel = 'إلغاء',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<void> showInfo(BuildContext context, String title, String text) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
      ],
    ),
  );
}

Future<String?> pickDateStr(BuildContext context, {String? initial}) async {
  final d = await showDatePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(2040),
    initialDate: DateTime.tryParse(initial ?? '') ?? DateTime.now(),
  );
  return d?.toIso8601String().substring(0, 10);
}

/// 12500 -> 12,500
String thousands(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

String rialF(num v) => '${thousands(v)} ريال';

/// 85.0 -> 85 ، 85.5 -> 85.5
String fmtN(num v) {
  final d = v.toDouble();
  return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}

String normDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (ch == '٫' || ch == '،') {
      b.write('.');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

double? parseNum(String s) {
  final t = normDigits(s.trim()).replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// سلّم التقدير — عدّل الحدود هنا إن لزم.
String ratingOf(double pct) {
  if (pct >= 85) return 'ممتاز';
  if (pct >= 75) return 'جيد جداً';
  if (pct >= 65) return 'جيد';
  if (pct >= 50) return 'مقبول';
  return 'ضعيف';
}

class GradeStat {
  double sum = 0;
  double max = 0;
  int count = 0;
  double get pct => max == 0 ? 0 : sum / max * 100;
}

Map<int, GradeStat> gradeStats(List<Map<String, dynamic>> grades) {
  final out = <int, GradeStat>{};
  for (final g in grades) {
    final st = out.putIfAbsent(g['studentId'] as int, () => GradeStat());
    st.sum += (g['score'] as num).toDouble();
    st.max += (g['maxScore'] as num).toDouble();
    st.count++;
  }
  return out;
}

Map<int, int> rankOf(Map<int, GradeStat> stats) {
  final list = stats.entries.where((e) => e.value.count > 0).toList()
    ..sort((a, b) => b.value.pct.compareTo(a.value.pct));
  final r = <int, int>{};
  for (var i = 0; i < list.length; i++) {
    if (i > 0 && (list[i].value.pct - list[i - 1].value.pct).abs() < 0.0001) {
      r[list[i].key] = r[list[i - 1].key]!;
    } else {
      r[list[i].key] = i + 1;
    }
  }
  return r;
}

// ---------- تفقيط المبلغ بالعربية ----------
const _ones = [
  '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية',
  'تسعة', 'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر',
  'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
];
const _tens = [
  '', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون',
];
const _hundreds = [
  '', 'مئة', 'مئتان', 'ثلاثمئة', 'أربعمئة', 'خمسمئة', 'ستمئة', 'سبعمئة',
  'ثمانمئة', 'تسعمئة',
];

String _below1000(int x) {
  final parts = <String>[];
  final h = x ~/ 100;
  final r = x % 100;
  if (h > 0) parts.add(_hundreds[h]);
  if (r > 0) {
    if (r < 20) {
      parts.add(_ones[r]);
    } else {
      final o = r % 10;
      final t = r ~/ 10;
      parts.add(o > 0 ? '${_ones[o]} و${_tens[t]}' : _tens[t]);
    }
  }
  return parts.join(' و');
}

String _scale(int c, String one, String two, String few, String many) {
  if (c == 1) return one;
  if (c == 2) return two;
  if (c == 200) return 'مئتا ${one == 'ألف' ? 'ألف' : 'مليون'}';
  if (c <= 10) return '${_below1000(c)} $few';
  return '${_below1000(c)} $many';
}

String tafqeet(int n) {
  if (n == 0) return 'صفر';
  if (n >= 1000000000) return thousands(n);
  final parts = <String>[];
  final m = n ~/ 1000000;
  final th = (n % 1000000) ~/ 1000;
  final rest = n % 1000;
  if (m > 0) parts.add(_scale(m, 'مليون', 'مليونان', 'ملايين', 'مليوناً'));
  if (th > 0) parts.add(_scale(th, 'ألف', 'ألفان', 'آلاف', 'ألفاً'));
  if (rest > 0) parts.add(_below1000(rest));
  return parts.join(' و');
}

// ---------- معاينة PDF / طباعة / مشاركة ----------
Future<void> openPdf(
  BuildContext context,
  String title,
  Future<Uint8List> Function() builder, {
  String? fileName,
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PdfPreviewPage(
        title: title,
        builder: builder,
        fileName: fileName ?? 'smart_skills_${today()}.pdf',
      ),
    ),
  );
}

class PdfPreviewPage extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() builder;
  final String fileName;
  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.builder,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => builder(),
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        maxPageWidth: 700,
        onError: (ctx, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'تعذر إنشاء الملف\n$error\n\n'
              'تأكد من إضافة خط Cairo إلى assets/fonts أو من توفر الإنترنت لأول مرة.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> shareBytes(List<int> bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final f = File(p.join(dir.path, fileName));
  await f.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(f.path)]);
}

// ---------- بيانات المعهد للطباعة ----------
class OrgInfo {
  final String name;
  final String manager;
  final String phone;
  final String address;
  OrgInfo(this.name, this.manager, this.phone, this.address);

  static Future<OrgInfo> load() async => OrgInfo(
        await AppDB.instance.getInfo('institute_name', 'معهد سمارت سكلز'),
        await AppDB.instance.getInfo('manager', ''),
        await AppDB.instance.getInfo('institute_phone', ''),
        await AppDB.instance.getInfo('institute_address', ''),
      );
}

// ---------- جدول الدرجات (يُستخدم في PDF وExcel) ----------
class GradeTable {
  final List<String> headers;
  final List<List<String>> rows;
  final int examCount;
  GradeTable(this.headers, this.rows, this.examCount);
}

Future<GradeTable> buildGradeTable(String course) async {
  final students = await AppDB.instance.studentsOfCourse(course);
  final exams = await AppDB.instance.examsOfCourse(course);
  final grades = await AppDB.instance.gradesOfCourse(course);

  final byStudent = <int, Map<String, double>>{};
  for (final g in grades) {
    byStudent.putIfAbsent(g['studentId'] as int, () => {})[g['examName'] as String] =
        (g['score'] as num).toDouble();
  }
  final stats = gradeStats(grades);
  final ranks = rankOf(stats);

  final headers = <String>[
    'م',
    'اسم المتدرب',
    for (final e in exams) '${e['examName']} (${fmtN(e['maxScore'] as num)})',
    'المجموع',
    'النسبة',
    'التقدير',
    'الترتيب',
  ];

  final rows = <List<String>>[];
  for (var i = 0; i < students.length; i++) {
    final s = students[i];
    final id = s['id'] as int;
    final st = stats[id];
    final sc = byStudent[id] ?? <String, double>{};
    String cellOf(String n) => sc.containsKey(n) ? fmtN(sc[n]!) : '-';
    final has = st != null && st.count > 0;
    rows.add([
      '${i + 1}',
      '${s['name']}',
      for (final e in exams) cellOf(e['examName'] as String),
      has ? '${fmtN(st!.sum)} / ${fmtN(st.max)}' : '-',
      has ? '${st!.pct.toStringAsFixed(1)}%' : '-',
      has ? ratingOf(st!.pct) : '-',
      has ? '${ranks[id]}' : '-',
    ]);
  }
  return GradeTable(headers, rows, exams.length);
}

