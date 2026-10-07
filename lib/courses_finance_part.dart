part of 'main.dart';

// ============================================================
// الدورات التدريبية
// ============================================================
class CoursesPage extends StatefulWidget {
  final VoidCallback onChanged;
  const CoursesPage({super.key, required this.onChanged});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
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
    all = await AppDB.instance.courses();
    if (mounted) setState(() => loading = false);
  }

  Future<void> openForm({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name'] ?? '');
    final duration = TextEditingController(text: existing?['duration'] ?? '');
    final fee = TextEditingController(
      text: existing == null ? '' : (existing['fee'] as num? ?? 0).toString(),
    );
    String status = existing?['status'] ?? 'نشطة';
    String? instructor = existing?['instructor'];
    final formKey = GlobalKey<FormState>();

    var instructorNames = (await AppDB.instance.instructors())
        .map((i) => i['name'] as String)
        .toList();
    // إن كانت الدورة تحمل اسم مدرب لم يعد مسجلاً في جدول المدربين
    // (بيانات قديمة)، نبقيه في القائمة حتى لا يُفقد عند الحفظ.
    if (instructor != null &&
        instructor!.isNotEmpty &&
        !instructorNames.contains(instructor)) {
      instructorNames = [instructor!, ...instructorNames];
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة دورة' : 'تعديل الدورة'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم الدورة *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  instructorNames.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'لا يوجد مدربون مسجلون بعد — أضف مدرباً أولاً من قسم "المدربون" في صفحة المزيد.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: instructor,
                          decoration: const InputDecoration(labelText: 'المدرب'),
                          items: instructorNames
                              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => instructor = v),
                        ),
                  TextFormField(
                    controller: duration,
                    decoration: const InputDecoration(labelText: 'المدة'),
                  ),
                  TextFormField(
                    controller: fee,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الرسوم'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: ['نشطة', 'منتهية', 'قادمة']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => status = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'name': name.text.trim(),
                  'instructor': instructor,
                  'duration': duration.text.trim(),
                  'fee': double.tryParse(fee.text) ?? 0,
                  'status': status,
                };
                if (existing == null) {
                  await AppDB.instance.addCourse(data);
                } else {
                  await AppDB.instance.updateCourse(existing['id'], data);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    await load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final list = all.where((c) {
      final text = '${c['name']} ${c['instructor']}'.toLowerCase();
      return text.contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.add),
        label: const Text('دورة جديدة'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  hintText: 'بحث باسم الدورة أو المدرب',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      text: all.isEmpty ? 'لا توجد دورات مسجلة' : 'لا توجد نتائج مطابقة',
                      actionLabel: all.isEmpty ? 'إضافة دورة' : null,
                      onAction: all.isEmpty ? () => openForm() : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return FutureBuilder<int>(
                          future: AppDB.instance.studentCountForCourse(c['name']),
                          builder: (_, snap) {
                            final count = snap.data ?? 0;
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                onTap: () => openForm(existing: c),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.menu_book),
                                ),
                                title: Text(
                                  c['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'المدرب: ${c['instructor'] ?? '-'}\n'
                                  'المدة: ${c['duration'] ?? '-'} • الرسوم: ${money(c['fee'] ?? 0)}\n'
                                  'المسجلون: $count • الحالة: ${c['status'] ?? '-'}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      openForm(existing: c);
                                    } else if (v == 'delete') {
                                      final sure = await confirmDialog(
                                        context,
                                        title: 'حذف الدورة',
                                        content: count > 0
                                            ? 'يوجد $count متدرب مسجل في هذه الدورة. سيتم إبقاء بياناتهم وإزالة ربطهم بها فقط. هل تريد المتابعة؟'
                                            : 'هل أنت متأكد من حذف "${c['name']}"؟',
                                      );
                                      if (sure) {
                                        await AppDB.instance
                                            .deleteCourse(c['id'], c['name']);
                                        await load();
                                        widget.onChanged();
                                        if (context.mounted) {
                                          toast(context, 'تم حذف الدورة');
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                                  ],
                                ),
                              ),
                            );
                          },
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

// ============================================================
// المالية
// ============================================================
class FinancePage extends StatefulWidget {
  final VoidCallback onChanged;
  const FinancePage({super.key, required this.onChanged});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('التحصيل')),
                    ButtonSegment(value: 1, label: Text('المصروفات')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (s) => setState(() => tab = s.first),
                ),
              ),
              IconButton(
                tooltip: 'طباعة الكشف',
                icon: const Icon(Icons.print_outlined),
                onPressed: () => openPdf(
                  context,
                  tab == 0 ? 'كشف التحصيل' : 'كشف المصروفات',
                  () => tab == 0
                      ? PrintService.paymentsReport(null, null)
                      : PrintService.expensesReport(null, null),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tab == 0
              ? PaymentsList(onChanged: widget.onChanged)
              : ExpensesList(onChanged: widget.onChanged),
        ),
      ],
    );
  }
}

class PaymentsList extends StatefulWidget {
  final VoidCallback onChanged;
  const PaymentsList({super.key, required this.onChanged});

  @override
  State<PaymentsList> createState() => _PaymentsListState();
}

class _PaymentsListState extends State<PaymentsList> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    list = await AppDB.instance.payments();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentFormPage()),
          );
          if (ok == true) {
            await load();
            widget.onChanged();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('سند قبض'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: list.isEmpty
            ? const EmptyState(text: 'لا توجد عمليات تحصيل')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final x = list[i];
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      onTap: () => openPdf(context, 'سند قبض',
                          () => PrintService.receipt(x['id'])),
                      leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                      title: Text(
                        money(x['amount']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'المتدرب: ${x['studentName'] ?? 'غير معروف'}\n'
                        'التاريخ: ${x['date']}${(x['note'] ?? '').toString().isEmpty ? '' : '\n${x['note']}'}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'print') {
                            await openPdf(context, 'سند قبض',
                                () => PrintService.receipt(x['id']));
                          } else if (v == 'edit') {
                            final ok = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentFormPage(existing: x),
                              ),
                            );
                            if (ok == true) {
                              await load();
                              widget.onChanged();
                            }
                          } else if (v == 'delete') {
                            final sure = await confirmDialog(
                              context,
                              title: 'حذف سند القبض',
                              content: 'سيتم خصم المبلغ من رصيد المتدرب. هل أنت متأكد؟',
                            );
                            if (sure) {
                              await AppDB.instance.deletePayment(
                                x['id'],
                                x['studentId'],
                                (x['amount'] as num).toDouble(),
                              );
                              await load();
                              widget.onChanged();
                              if (context.mounted) toast(context, 'تم حذف السند');
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'print', child: Text('طباعة السند')),
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class PaymentFormPage extends StatefulWidget {
  final int? studentId;
  final Map<String, dynamic>? existing;

  const PaymentFormPage({super.key, this.studentId, this.existing});

  @override
  State<PaymentFormPage> createState() => _PaymentFormPageState();
}

class _PaymentFormPageState extends State<PaymentFormPage> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController amount;
  late TextEditingController note;
  int? studentId;
  String date = today();
  late final Future<List<Map<String, dynamic>>> studentsFuture =
      AppDB.instance.students();

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    studentId = widget.existing?['studentId'] ?? widget.studentId;
    date = widget.existing?['date'] ?? today();
    amount = TextEditingController(
      text: widget.existing == null ? '' : (widget.existing!['amount'] as num).toString(),
    );
    note = TextEditingController(text: widget.existing?['note'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل سند القبض' : 'سند قبض')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: studentsFuture,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(text: 'لا يوجد متدربون مسجلون بعد');
          }

          return Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                DropdownButtonFormField<int>(
                  value: studentId,
                  decoration: const InputDecoration(labelText: 'المتدرب *'),
                  items: list
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text(s['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => studentId = v),
                  validator: (v) => v == null ? 'اختر المتدرب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ *'),
                  validator: (v) {
                    final a = double.tryParse(v ?? '');
                    if (a == null || a <= 0) return 'أدخل مبلغاً صحيحاً';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await pickDateStr(context, initial: date);
                    if (d != null) setState(() => date = d);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text('تاريخ السند: $date'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'البيان / ملاحظة'),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final a = double.parse(amount.text);
                      int? savedId;

                      if (isEdit) {
                        await AppDB.instance.updatePayment(
                          widget.existing!['id'],
                          widget.existing!['studentId'],
                          (widget.existing!['amount'] as num).toDouble(),
                          {
                            'studentId': studentId,
                            'amount': a,
                            'date': date,
                            'note': note.text.trim(),
                          },
                        );
                      } else {
                        savedId = await AppDB.instance.addPayment({
                          'studentId': studentId,
                          'amount': a,
                          'date': date,
                          'note': note.text.trim(),
                        });
                      }

                      if (!mounted) return;
                      toast(context, isEdit ? 'تم تحديث السند' : 'تم حفظ سند القبض');
                      if (savedId != null) {
                        final printNow = await confirmAction(
                          context,
                          title: 'تم حفظ السند',
                          content: 'هل تريد طباعة سند القبض الآن؟',
                          okLabel: 'طباعة',
                          cancelLabel: 'لاحقاً',
                        );
                        if (printNow && mounted) {
                          final id = savedId;
                          await openPdf(context, 'سند قبض',
                              () => PrintService.receipt(id));
                        }
                      }
                      if (mounted) Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.save),
                    label: Text(isEdit ? 'حفظ التعديلات' : 'حفظ سند القبض'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ExpensesList extends StatefulWidget {
  final VoidCallback onChanged;
  const ExpensesList({super.key, required this.onChanged});

  @override
  State<ExpensesList> createState() => _ExpensesListState();
}

class _ExpensesListState extends State<ExpensesList> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    list = await AppDB.instance.expenses();
    if (mounted) setState(() => loading = false);
  }

  Future<void> openForm({Map<String, dynamic>? existing}) async {
    final title = TextEditingController(text: existing?['title'] ?? '');
    final amount = TextEditingController(
      text: existing == null ? '' : (existing['amount'] as num).toString(),
    );
    final note = TextEditingController(text: existing?['note'] ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'إضافة مصروف' : 'تعديل المصروف'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'بند المصروف *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ *'),
                  validator: (v) {
                    final a = double.tryParse(v ?? '');
                    if (a == null || a <= 0) return 'أدخل مبلغاً صحيحاً';
                    return null;
                  },
                ),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'ملاحظة'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final data = {
                'title': title.text.trim(),
                'amount': double.parse(amount.text),
                'date': existing?['date'] ?? today(),
                'note': note.text.trim(),
              };
              if (existing == null) {
                await AppDB.instance.addExpense(data);
              } else {
                await AppDB.instance.updateExpense(existing['id'], data);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    await load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: list.isEmpty
            ? EmptyState(text: 'لا توجد مصروفات', actionLabel: 'إضافة مصروف', onAction: () => openForm())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final x = list[i];
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      onTap: () => openForm(existing: x),
                      leading: const CircleAvatar(child: Icon(Icons.money_off)),
                      title: Text(
                        x['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${x['date']}${(x['note'] ?? '').toString().isEmpty ? '' : '\n${x['note']}'}',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            money(x['amount']),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            tooltip: 'طباعة سند صرف',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.print_outlined),
                            onPressed: () => openPdf(context, 'سند صرف',
                                () => PrintService.expenseVoucher(x['id'])),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final sure = await confirmDialog(
                                context,
                                title: 'حذف المصروف',
                                content: 'هل أنت متأكد من حذف "${x['title']}"؟',
                              );
                              if (sure) {
                                await AppDB.instance.deleteExpense(x['id']);
                                await load();
                                widget.onChanged();
                                if (context.mounted) toast(context, 'تم حذف المصروف');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

