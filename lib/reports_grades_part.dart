part of 'main.dart';

// ============================================================
// التقارير والطباعة
// ============================================================
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? from;
  String? to;
  String attCourse = 'الكل';
  List<String> courseNames = ['الكل'];
  Map<String, dynamic>? t;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final totals = await AppDB.instance.totals();
    final courses = await AppDB.instance.courses();
    if (!mounted) return;
    setState(() {
      t = totals;
      courseNames = ['الكل', ...courses.map((c) => c['name'] as String)];
      if (!courseNames.contains(attCourse)) attCourse = 'الكل';
    });
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.print_outlined),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (t == null) return const Center(child: CircularProgressIndicator());
    final tt = t!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'التقارير الإدارية والمالية',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'اضغط على أي تقرير لمعاينته ثم طباعته أو مشاركته كملف PDF',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الفترة (للتحصيل والمصروفات والملخص المالي)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await pickDateStr(context, initial: from);
                          if (d != null) setState(() => from = d);
                        },
                        icon: const Icon(Icons.event),
                        label: Text('من: ${from ?? 'البداية'}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await pickDateStr(context, initial: to);
                          if (d != null) setState(() => to = d);
                        },
                        icon: const Icon(Icons.event),
                        label: Text('إلى: ${to ?? 'اليوم'}'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'مسح الفترة',
                      onPressed: () => setState(() {
                        from = null;
                        to = null;
                      }),
                      icon: const Icon(Icons.clear),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _tile(Icons.people, 'تقرير المتدربين', 'إجمالي المتدربين: ${tt['students']}',
            () => openPdf(context, 'قائمة المتدربين', () => PrintService.studentsList())),
        _tile(Icons.menu_book, 'تقرير الدورات', 'إجمالي الدورات: ${tt['courses']}',
            () => openPdf(context, 'قائمة الدورات', () => PrintService.coursesList())),
        _tile(Icons.receipt_long, 'تقرير التحصيل',
            'إجمالي التحصيل: ${money(tt['payments'])}',
            () => openPdf(context, 'كشف التحصيل', () => PrintService.paymentsReport(from, to))),
        _tile(Icons.money_off, 'تقرير المصروفات',
            'إجمالي المصروفات: ${money(tt['expenses'])}',
            () => openPdf(context, 'كشف المصروفات', () => PrintService.expensesReport(from, to))),
        _tile(Icons.account_balance, 'الملخص المالي', 'الصافي: ${money(tt['balance'])}',
            () => openPdf(context, 'الملخص المالي', () => PrintService.financialSummary(from, to))),
        _tile(Icons.warning_amber, 'المبالغ المتبقية (المديونيات)',
            'المتبقي: ${money(tt['remaining'])}',
            () => openPdf(context, 'المتبقي على المتدربين', () => PrintService.debtors())),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: attCourse,
          decoration: const InputDecoration(labelText: 'الدورة (لتقرير الحضور)'),
          items: courseNames
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => attCourse = v ?? 'الكل'),
        ),
        const SizedBox(height: 10),
        _tile(Icons.fact_check, 'تقرير الحضور والغياب',
            'ملخص أيام الحضور والغياب ونسبة الحضور',
            () => openPdf(context, 'تقرير الحضور', () => PrintService.attendanceSummary(attCourse))),
        _tile(Icons.grade, 'كشوف الدرجات', 'من قسم "الدرجات" في صفحة المزيد',
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubPage(title: 'الدرجات', child: GradesPage()),
                  ),
                )),
      ],
    );
  }
}

// ============================================================
// الدرجات
// ============================================================
class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  List<String> courseNames = [];
  String? course;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> exams = [];
  List<Map<String, dynamic>> grades = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  Future<void> loadCourses() async {
    final cs = await AppDB.instance.courses();
    courseNames = cs.map((c) => c['name'] as String).toList();
    if (course == null || !courseNames.contains(course)) {
      course = courseNames.isEmpty ? null : courseNames.first;
    }
    await load();
  }

  Future<void> load() async {
    if (course == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    students = await AppDB.instance.studentsOfCourse(course!);
    exams = await AppDB.instance.examsOfCourse(course!);
    grades = await AppDB.instance.gradesOfCourse(course!);
    if (mounted) setState(() => loading = false);
  }

  Future<void> openEntry({String? examName, double? maxScore}) async {
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GradeEntryPage(
          course: course!,
          examName: examName,
          maxScore: maxScore,
        ),
      ),
    );
    if (ok == true) await load();
  }

  Future<void> importExcel() async {
    final maxCtrl = TextEditingController(text: '100');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استيراد الدرجات من Excel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الصف الأول عناوين الأعمدة: عمود "اسم المتدرب" (أو "رقم المتدرب") '
              'ثم عمود لكل اختبار. يمكن كتابة الدرجة العظمى بين قوسين في العنوان '
              'مثل: الاختبار الأول (50). يُفضّل تنزيل القالب أولاً.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'الدرجة العظمى الافتراضية',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اختيار الملف')),
        ],
      ),
    );
    if (go != true) return;
    final max = parseNum(maxCtrl.text);
    if (max == null || max <= 0) {
      if (mounted) toast(context, 'الدرجة العظمى غير صحيحة', error: true);
      return;
    }
    if (!mounted) return;
    await guarded(context, () async {
      final msg = await XlsxTools.importGrades(course!, max);
      if (msg != null) {
        if (!mounted) return;
        await showInfo(context, 'نتيجة الاستيراد', msg);
        await load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (course == null) {
      return const EmptyState(text: 'أضف دورة ومتدربين أولاً لإدخال الدرجات');
    }

    final stats = gradeStats(grades);
    final ranks = rankOf(stats);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: DropdownButtonFormField<String>(
            value: course,
            decoration: const InputDecoration(labelText: 'الدورة'),
            items: courseNames
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) async {
              course = v;
              await load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: students.isEmpty ? null : () => openEntry(),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('إدخال درجات اختبار جديد'),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'المزيد',
                onSelected: (v) => guarded(context, () async {
                  if (v == 'import') {
                    await importExcel();
                  } else if (v == 'template') {
                    await XlsxTools.gradesTemplate(course!);
                  } else if (v == 'print') {
                    await openPdf(context, 'كشف الدرجات',
                        () => PrintService.gradesSheet(course!));
                  } else if (v == 'export') {
                    await XlsxTools.exportGrades(course!);
                  }
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'import', child: Text('استيراد الدرجات من Excel')),
                  PopupMenuItem(value: 'template', child: Text('تنزيل قالب Excel')),
                  PopupMenuItem(value: 'print', child: Text('طباعة كشف الدرجات')),
                  PopupMenuItem(value: 'export', child: Text('تصدير الكشف إلى Excel')),
                ],
              ),
            ],
          ),
        ),
        if (exams.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: exams.map((e) {
                final max = (e['maxScore'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: InputChip(
                    avatar: const Icon(Icons.edit_note, size: 18),
                    label: Text('${e['examName']} (${fmtN(max)})'),
                    deleteButtonTooltipMessage: 'حذف الاختبار',
                    onPressed: () => openEntry(
                      examName: e['examName'] as String,
                      maxScore: max,
                    ),
                    onDeleted: () async {
                      final sure = await confirmDialog(
                        context,
                        title: 'حذف الاختبار',
                        content:
                            'سيتم حذف كل درجات "${e['examName']}" لهذه الدورة. هل أنت متأكد؟',
                      );
                      if (sure) {
                        await AppDB.instance.deleteExam(course!, e['examName'] as String);
                        await load();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: students.isEmpty
              ? const EmptyState(text: 'لا يوجد متدربون في هذه الدورة')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final s = students[i];
                    final id = s['id'] as int;
                    final st = stats[id];
                    final has = st != null && st.count > 0;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentGradesPage(student: s),
                            ),
                          );
                          await load();
                        },
                        leading: CircleAvatar(
                          child: Text((s['name'] as String).isNotEmpty
                              ? (s['name'] as String).substring(0, 1)
                              : '?'),
                        ),
                        title: Text('${s['name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          has
                              ? 'المجموع: ${fmtN(st!.sum)} / ${fmtN(st.max)} • ${st.pct.toStringAsFixed(1)}%\n'
                                  '${ratingOf(st.pct)} • الترتيب: ${ranks[id]}'
                              : 'لا توجد درجات مسجلة',
                        ),
                        isThreeLine: has,
                        trailing: IconButton(
                          tooltip: 'طباعة كشف درجات المتدرب',
                          icon: const Icon(Icons.print_outlined),
                          onPressed: () => openPdf(context, 'كشف درجات متدرب',
                              () => PrintService.studentTranscript(id)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class GradeEntryPage extends StatefulWidget {
  final String course;
  final String? examName;
  final double? maxScore;
  const GradeEntryPage({
    super.key,
    required this.course,
    this.examName,
    this.maxScore,
  });

  @override
  State<GradeEntryPage> createState() => _GradeEntryPageState();
}

class _GradeEntryPageState extends State<GradeEntryPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController maxCtrl;
  final Map<int, TextEditingController> scoreCtrls = {};
  List<Map<String, dynamic>> students = [];
  bool loading = true;

  bool get isEdit => widget.examName != null;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.examName ?? '');
    maxCtrl = TextEditingController(
      text: widget.maxScore == null ? '100' : fmtN(widget.maxScore!),
    );
    load();
  }

  Future<void> load() async {
    students = await AppDB.instance.studentsOfCourse(widget.course);
    final existing = <int, double>{};
    if (isEdit) {
      final gs = await AppDB.instance.gradesOfCourse(widget.course);
      for (final g in gs) {
        if (g['examName'] == widget.examName) {
          existing[g['studentId'] as int] = (g['score'] as num).toDouble();
        }
      }
    }
    for (final s in students) {
      final id = s['id'] as int;
      scoreCtrls[id] = TextEditingController(
        text: existing.containsKey(id) ? fmtN(existing[id]!) : '',
      );
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    maxCtrl.dispose();
    for (final c in scoreCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final name = nameCtrl.text.trim();
    final max = parseNum(maxCtrl.text);
    if (name.isEmpty) {
      toast(context, 'اكتب اسم الاختبار / المادة', error: true);
      return;
    }
    if (max == null || max <= 0) {
      toast(context, 'الدرجة العظمى غير صحيحة', error: true);
      return;
    }

    final scores = <int, double?>{};
    for (final s in students) {
      final id = s['id'] as int;
      final txt = scoreCtrls[id]!.text.trim();
      if (txt.isEmpty) {
        scores[id] = null;
        continue;
      }
      final v = parseNum(txt);
      if (v == null || v < 0 || v > max) {
        toast(context, 'درجة غير صحيحة للمتدرب: ${s['name']}', error: true);
        return;
      }
      scores[id] = v;
    }
    if (!isEdit && !scores.values.any((v) => v != null)) {
      toast(context, 'لم تُدخل أي درجة بعد', error: true);
      return;
    }

    final existing = await AppDB.instance.examsOfCourse(widget.course);
    final clash = existing.any((e) => e['examName'] == name);
    if ((!isEdit && clash) || (isEdit && name != widget.examName && clash)) {
      if (mounted) toast(context, 'يوجد اختبار بنفس الاسم في هذه الدورة', error: true);
      return;
    }

    if (isEdit && name != widget.examName) {
      await AppDB.instance.renameExam(widget.course, widget.examName!, name);
    }
    await AppDB.instance.updateExamMax(widget.course, name, max);
    await AppDB.instance.saveGrades(widget.course, name, max, scores);

    if (mounted) {
      toast(context, 'تم حفظ الدرجات');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل: ${widget.examName}' : 'إدخال درجات جديد'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'طباعة كشف الاختبار',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => openPdf(
                context,
                'كشف اختبار',
                () => PrintService.examSheet(widget.course, widget.examName!),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الاختبار / المادة',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: maxCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'الدرجة العظمى',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? const EmptyState(text: 'لا يوجد متدربون في هذه الدورة')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: students.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = students[i];
                            return ListTile(
                              leading: Text('${i + 1}'),
                              title: Text('${s['name']}'),
                              trailing: SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: scoreCtrls[s['id'] as int],
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: const InputDecoration(
                                    hintText: '-',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: save,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ الدرجات'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class StudentGradesPage extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentGradesPage({super.key, required this.student});

  @override
  State<StudentGradesPage> createState() => _StudentGradesPageState();
}

class _StudentGradesPageState extends State<StudentGradesPage> {
  List<Map<String, dynamic>> grades = [];
  bool loading = true;

  int get sid => widget.student['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    grades = await AppDB.instance.gradesOfStudent(sid);
    if (mounted) setState(() => loading = false);
  }

  Future<void> editScore(Map<String, dynamic> g) async {
    final ctrl = TextEditingController(text: fmtN(g['score'] as num));
    final max = (g['maxScore'] as num).toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${g['examName']} (من ${fmtN(max)})'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'الدرجة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    final v = parseNum(ctrl.text);
    if (v == null || v < 0 || v > max) {
      if (mounted) toast(context, 'درجة غير صحيحة', error: true);
      return;
    }
    await AppDB.instance.saveGrades(
      g['course'] as String,
      g['examName'] as String,
      max,
      {sid: v},
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final stats = gradeStats(grades)[sid];
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student['name']}'),
        actions: [
          IconButton(
            tooltip: 'طباعة كشف الدرجات',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => openPdf(context, 'كشف درجات متدرب',
                () => PrintService.studentTranscript(sid)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : grades.isEmpty
              ? const EmptyState(text: 'لا توجد درجات لهذا المتدرب')
              : ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (stats != null)
                      Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'المجموع: ${fmtN(stats.sum)} / ${fmtN(stats.max)}\n'
                            'النسبة: ${stats.pct.toStringAsFixed(1)}% • ${ratingOf(stats.pct)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    for (final g in grades)
                      Card(
                        elevation: 0,
                        child: ListTile(
                          onTap: () => editScore(g),
                          title: Text('${g['examName']}'),
                          subtitle: Text('${g['course']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${fmtN(g['score'] as num)} / ${fmtN(g['maxScore'] as num)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final sure = await confirmDialog(
                                    context,
                                    title: 'حذف الدرجة',
                                    content: 'حذف درجة "${g['examName']}" لهذا المتدرب؟',
                                  );
                                  if (sure) {
                                    await AppDB.instance.saveGrades(
                                      g['course'] as String,
                                      g['examName'] as String,
                                      (g['maxScore'] as num).toDouble(),
                                      {sid: null},
                                    );
                                    await load();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

