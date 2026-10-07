part of 'main.dart';

// ============================================================
// لوحة التحكم
// ============================================================
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        AppDB.instance.totals(),
        AppDB.instance.getInfo('institute_name', 'معهد سمارت سكلز'),
        AppDB.instance.getInfo('manager', ''),
        AppDB.instance.topDebtors(),
        AppDB.instance.monthlyRevenue(),
      ]),
      builder: (_, AsyncSnapshot<List<dynamic>> snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final t = snap.data![0] as Map<String, dynamic>;
        final instituteName = snap.data![1] as String;
        final debtors = snap.data![3] as List<Map<String, dynamic>>;
        final revenue = snap.data![4] as List<Map<String, dynamic>>;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مرحباً بك 👋',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 7),
                  Text(
                    instituteName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'نظام الإدارة والمتابعة والمحاسبة',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  title: 'المتدربون',
                  value: '${t['students']}',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                StatCard(
                  title: 'الدورات',
                  value: '${t['courses']}',
                  icon: Icons.menu_book,
                  color: Colors.green,
                ),
                StatCard(
                  title: 'المدربون',
                  value: '${t['instructors']}',
                  icon: Icons.groups_outlined,
                  color: Colors.deepPurple,
                ),
                StatCard(
                  title: 'إجمالي التحصيل',
                  value: money(t['payments']),
                  icon: Icons.payments,
                  color: Colors.orange,
                ),
                StatCard(
                  title: 'المصروفات',
                  value: money(t['expenses']),
                  icon: Icons.money_off,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الموقف المالي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _line('إجمالي الرسوم', money(t['fees'])),
                    _line('المتحصل', money(t['payments'])),
                    _line('المتبقي', money(t['remaining'])),
                    _line('صافي الحركة', money(t['balance'])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (revenue.any((r) => (r['total'] as num) > 0))
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اتجاه التحصيل — آخر 6 أشهر',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      _RevenueChart(data: revenue),
                    ],
                  ),
                ),
              ),
            if (revenue.any((r) => (r['total'] as num) > 0))
              const SizedBox(height: 18),
            if (debtors.isNotEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'أعلى المتأخرين في السداد',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final d in debtors)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(d['name']),
                          subtitle: Text(d['course'] ?? 'بدون دورة'),
                          trailing: Text(
                            money(d['remaining']),
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentFormPage(studentId: d['id']),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _line(String a, String b) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(a)),
          Text(
            b,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ---------- رسم بياني بسيط لاتجاه التحصيل الشهري (بدون مكتبات خارجية) ----------
class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(
        0, (m, e) => (e['total'] as num).toDouble() > m ? (e['total'] as num).toDouble() : m);
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      thousands(r['total'] as num),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxVal == 0
                          ? 4
                          : 4 + ((r['total'] as num) / maxVal) * 76,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (r['month'] as String).split('-').last,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
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

// ============================================================
// المتدربون
// ============================================================
class StudentsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const StudentsPage({super.key, required this.onChanged});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String search = '';
  List<Map<String, dynamic>> all = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    all = await AppDB.instance.students();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final list = all.where((s) {
      final text =
          '${s['name']} ${s['phone']} ${s['course']} ${s['groupName']}'
              .toLowerCase();
      return text.contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final courses = await AppDB.instance.courses();
          if (courses.isEmpty) {
            if (context.mounted) {
              toast(context, 'أضف دورة تدريبية أولاً قبل تسجيل متدرب', error: true);
            }
            return;
          }
          if (!context.mounted) return;
          final ok = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentFormPage()),
          );
          if (ok == true) {
            await load();
            widget.onChanged();
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('متدرب جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => search = v),
                      decoration: const InputDecoration(
                        hintText: 'بحث بالاسم أو الهاتف أو الدورة أو المجموعة',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'المزيد',
                    onSelected: (v) => guarded(context, () async {
                      if (v == 'print') {
                        await openPdf(context, 'قائمة المتدربين',
                            () => PrintService.studentsList());
                      } else if (v == 'import') {
                        final msg = await XlsxTools.importStudents();
                        if (msg != null && mounted) {
                          await showInfo(context, 'نتيجة الاستيراد', msg);
                          await load();
                          widget.onChanged();
                        }
                      } else if (v == 'export') {
                        await XlsxTools.exportStudents();
                      } else if (v == 'template') {
                        await XlsxTools.studentsTemplate();
                      }
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'print', child: Text('طباعة قائمة المتدربين')),
                      PopupMenuItem(value: 'import', child: Text('استيراد المتدربين من Excel')),
                      PopupMenuItem(value: 'template', child: Text('تنزيل قالب Excel للمتدربين')),
                      PopupMenuItem(value: 'export', child: Text('تصدير المتدربين إلى Excel')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      text: all.isEmpty
                          ? 'لا يوجد متدربون بعد'
                          : 'لا توجد نتائج مطابقة للبحث',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final remaining =
                            (s['fees'] as num? ?? 0) - (s['paid'] as num? ?? 0);
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 9),
                          child: ListTile(
                            onTap: () async {
                              final ok = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentFormPage(existing: s),
                                ),
                              );
                              if (ok == true) {
                                await load();
                                widget.onChanged();
                              }
                            },
                            leading: CircleAvatar(
                              child: Text(
                                (s['name'] as String).isNotEmpty
                                    ? (s['name'] as String).substring(0, 1)
                                    : '?',
                              ),
                            ),
                            title: Text(
                              s['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${s['course'] ?? 'بدون دورة'} — ${s['phone'] ?? '-'}\n'
                              'المتبقي: ${money(remaining)} • الحالة: ${s['status'] ?? '-'}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'statement') {
                                  await openPdf(context, 'كشف حساب متدرب',
                                      () => PrintService.studentStatement(s['id']));
                                } else if (v == 'grades') {
                                  await openPdf(context, 'كشف درجات متدرب',
                                      () => PrintService.studentTranscript(s['id']));
                                } else if (v == 'pay') {
                                  final ok = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PaymentFormPage(studentId: s['id']),
                                    ),
                                  );
                                  if (ok == true) {
                                    await load();
                                    widget.onChanged();
                                  }
                                } else if (v == 'edit') {
                                  final ok = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentFormPage(existing: s),
                                    ),
                                  );
                                  if (ok == true) {
                                    await load();
                                    widget.onChanged();
                                  }
                                } else if (v == 'delete') {
                                  final sure = await confirmDialog(
                                    context,
                                    title: 'حذف المتدرب',
                                    content:
                                        'سيتم حذف "${s['name']}" وكل بيانات حضوره ومدفوعاته. هل أنت متأكد؟',
                                  );
                                  if (sure) {
                                    await AppDB.instance.deleteStudent(s['id']);
                                    await load();
                                    widget.onChanged();
                                    if (context.mounted) {
                                      toast(context, 'تم حذف المتدرب');
                                    }
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'pay', child: Text('تسجيل دفعة')),
                                PopupMenuItem(value: 'statement', child: Text('طباعة كشف حساب')),
                                PopupMenuItem(value: 'grades', child: Text('طباعة كشف درجات')),
                                PopupMenuItem(value: 'edit', child: Text('تعديل البيانات')),
                                PopupMenuItem(value: 'delete', child: Text('حذف المتدرب')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const StudentFormPage({super.key, this.existing});

  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController group;
  late TextEditingController fees;

  String gender = 'ذكر';
  String status = 'منتظم';
  String? course;
  List<Map<String, dynamic>> courses = [];
  bool loadingCourses = true;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    name = TextEditingController(text: e?['name'] ?? '');
    phone = TextEditingController(text: e?['phone'] ?? '');
    group = TextEditingController(text: e?['groupName'] ?? '');
    fees = TextEditingController(
      text: e == null ? '' : (e['fees'] as num? ?? 0).toString(),
    );
    gender = e?['gender'] ?? 'ذكر';
    status = e?['status'] ?? 'منتظم';
    course = e?['course'];
    loadCourses();
  }

  Future<void> loadCourses() async {
    courses = await AppDB.instance.courses();
    // Keep an existing course name selected even if it was since renamed
    // in a way that no longer matches — fall back to null rather than crash.
    if (course != null && !courses.any((c) => c['name'] == course)) {
      courses.add({'name': course});
    }
    if (mounted) setState(() => loadingCourses = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل بيانات متدرب' : 'تسجيل متدرب جديد')),
      body: loadingCourses
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'اسم المتدرب *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'الجنس'),
                    items: ['ذكر', 'أنثى']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => gender = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: group,
                    decoration: const InputDecoration(
                      labelText: 'المجموعة / الشعبة',
                      prefixIcon: Icon(Icons.groups),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: course,
                    decoration: const InputDecoration(labelText: 'الدورة *'),
                    items: courses
                        .map<DropdownMenuItem<String>>(
                          (c) => DropdownMenuItem(
                            value: c['name'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => course = v),
                    validator: (v) => v == null ? 'اختر دورة' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fees,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الرسوم الكلية',
                      prefixIcon: Icon(Icons.payments),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: ['منتظم', 'متوقف', 'منسحب', 'متخرج']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => status = v!),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final data = {
                          'name': name.text.trim(),
                          'phone': phone.text.trim(),
                          'gender': gender,
                          'course': course,
                          'groupName': group.text.trim(),
                          'status': status,
                          'fees': double.tryParse(fees.text) ?? 0,
                        };

                        if (isEdit) {
                          await AppDB.instance
                              .updateStudent(widget.existing!['id'], data);
                        } else {
                          await AppDB.instance.addStudent({
                            ...data,
                            'joinDate': today(),
                            'paid': 0,
                          });
                        }

                        if (mounted) {
                          toast(context, isEdit ? 'تم تحديث بيانات المتدرب' : 'تم حفظ المتدرب');
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ المتدرب'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

