part of 'main.dart';

// ============================================================
// الحضور والغياب
// ============================================================
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String date = today();
  String courseFilter = 'الكل';
  List<Map<String, dynamic>> rows = [];
  List<String> courseNames = ['الكل'];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final courses = await AppDB.instance.courses();
    courseNames = ['الكل', ...courses.map((c) => c['name'] as String)];
    rows = await AppDB.instance.attendanceForDate(
      date,
      courseFilter == 'الكل' ? null : courseFilter,
    );
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final present = rows.where((r) => r['present'] == 1).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'التاريخ: $date',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDate: DateTime.tryParse(date) ?? DateTime.now(),
                  );
                  if (d != null) {
                    date = d.toIso8601String().substring(0, 10);
                    await load();
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('التاريخ'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: courseFilter,
            decoration: const InputDecoration(labelText: 'تصفية حسب الدورة'),
            items: courseNames
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) async {
              courseFilter = v!;
              await load();
            },
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                Expanded(child: Text('الحاضرون: $present من ${rows.length}')),
                IconButton(
                  tooltip: 'طباعة كشف الحضور',
                  icon: const Icon(Icons.print_outlined),
                  onPressed: () => openPdf(context, 'كشف الحضور',
                      () => PrintService.attendanceDaily(date, courseFilter, rows)),
                ),
                IconButton(
                  tooltip: 'تقرير الحضور الإجمالي',
                  icon: const Icon(Icons.summarize_outlined),
                  onPressed: () => openPdf(context, 'تقرير الحضور',
                      () => PrintService.attendanceSummary(courseFilter)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const EmptyState(text: 'لا يوجد متدربون لتسجيل الحضور')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final isPresent = r['present'] == 1;

                        return Card(
                          elevation: 0,
                          child: SwitchListTile(
                            value: isPresent,
                            onChanged: (v) async {
                              await AppDB.instance.saveAttendance(date, r['id'], v);
                              await load();
                            },
                            title: Text(
                              r['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: FutureBuilder<double>(
                              future: AppDB.instance.attendanceRateForStudent(r['id']),
                              builder: (_, snap) {
                                final rate = snap.data;
                                final rateText = (rate == null)
                                    ? ''
                                    : rate < 0
                                        ? ''
                                        : ' • نسبة الحضور: ${rate.toStringAsFixed(0)}%';
                                return Text('${r['course'] ?? '-'}$rateText');
                              },
                            ),
                            secondary: Icon(
                              isPresent ? Icons.check_circle : Icons.cancel_outlined,
                              color: isPresent ? Colors.green : Colors.grey,
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

