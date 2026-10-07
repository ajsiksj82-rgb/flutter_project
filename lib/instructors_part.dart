part of 'main.dart';

// ============================================================
// المدربون
// ============================================================
class InstructorsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const InstructorsPage({super.key, required this.onChanged});

  @override
  State<InstructorsPage> createState() => _InstructorsPageState();
}

class _InstructorsPageState extends State<InstructorsPage> {
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
    all = await AppDB.instance.instructors();
    if (mounted) setState(() => loading = false);
  }

  Future<void> openForm({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name'] ?? '');
    final phone = TextEditingController(text: existing?['phone'] ?? '');
    final email = TextEditingController(text: existing?['email'] ?? '');
    final specialty = TextEditingController(text: existing?['specialty'] ?? '');
    final notes = TextEditingController(text: existing?['notes'] ?? '');
    String status = existing?['status'] ?? 'نشط';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة مدرب' : 'تعديل بيانات المدرب'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم المدرب *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                  ),
                  TextFormField(
                    controller: specialty,
                    decoration: const InputDecoration(labelText: 'التخصص'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: ['نشط', 'غير نشط']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => status = v!),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
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
                  'phone': phone.text.trim(),
                  'email': email.text.trim(),
                  'specialty': specialty.text.trim(),
                  'notes': notes.text.trim(),
                  'status': status,
                };
                if (existing == null) {
                  await AppDB.instance.addInstructor(data);
                } else {
                  await AppDB.instance.updateInstructor(existing['id'], data);
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

    final list = all.where((i) {
      final text = '${i['name']} ${i['specialty']} ${i['phone']}'.toLowerCase();
      return text.contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('مدرب جديد'),
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
                  hintText: 'بحث بالاسم أو التخصص أو الهاتف',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      text: all.isEmpty ? 'لا يوجد مدربون مسجلون' : 'لا توجد نتائج مطابقة',
                      actionLabel: all.isEmpty ? 'إضافة مدرب' : null,
                      onAction: all.isEmpty ? () => openForm() : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final ins = list[i];
                        return FutureBuilder<int>(
                          future: AppDB.instance
                              .courseCountForInstructor(ins['name']),
                          builder: (_, snap) {
                            final count = snap.data ?? 0;
                            final active = (ins['status'] ?? 'نشط') == 'نشط';
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                onTap: () => openForm(existing: ins),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      (active ? Colors.blue : Colors.grey)
                                          .withOpacity(.12),
                                  child: Icon(Icons.school,
                                      color: active ? Colors.blue : Colors.grey),
                                ),
                                title: Text(
                                  ins['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${ins['specialty']?.toString().isNotEmpty == true ? ins['specialty'] : 'بدون تخصص محدد'}\n'
                                  '${ins['phone'] ?? '-'} • الدورات: $count • الحالة: ${ins['status'] ?? '-'}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      openForm(existing: ins);
                                    } else if (v == 'delete') {
                                      final sure = await confirmDialog(
                                        context,
                                        title: 'حذف المدرب',
                                        content: count > 0
                                            ? 'يقوم هذا المدرب بتدريس $count دورة. سيتم إبقاء الدورات وإزالة ربطها به فقط. هل تريد المتابعة؟'
                                            : 'هل أنت متأكد من حذف "${ins['name']}"؟',
                                      );
                                      if (sure) {
                                        await AppDB.instance
                                            .deleteInstructor(ins['id'], ins['name']);
                                        await load();
                                        widget.onChanged();
                                        if (context.mounted) {
                                          toast(context, 'تم حذف المدرب');
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
