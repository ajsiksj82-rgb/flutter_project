part of 'main.dart';

// ============================================================
// النسخ الاحتياطي والتصدير
// ============================================================
class BackupPage extends StatelessWidget {
  final VoidCallback onChanged;
  const BackupPage({super.key, required this.onChanged});

  Future<void> _backup(BuildContext context) async {
    final path = await AppDB.instance.dbPath();
    try {
      await AppDB.instance.db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}
    final bytes = await File(path).readAsBytes();
    await shareBytes(bytes, 'smart_skills_backup_${today()}.db');
  }

  Future<void> _restore(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null || bytes.length < 100) {
      if (context.mounted) toast(context, 'الملف غير صالح', error: true);
      return;
    }
    final header = String.fromCharCodes(bytes.sublist(0, 15));
    if (header != 'SQLite format 3') {
      if (context.mounted) {
        toast(context, 'هذا ليس ملف نسخة احتياطية صالحاً', error: true);
      }
      return;
    }
    if (!context.mounted) return;
    final sure = await confirmAction(
      context,
      title: 'استعادة نسخة احتياطية',
      content:
          'سيتم استبدال كل البيانات الحالية بمحتوى النسخة المختارة. '
          'سيُحفظ نسخ تلقائي للبيانات الحالية قبل الاستبدال. هل تريد المتابعة؟',
      okLabel: 'استعادة',
    );
    if (!sure) return;

    final path = await AppDB.instance.dbPath();
    await AppDB.instance.closeDb();
    final current = File(path);
    if (await current.exists()) {
      await current.copy('$path.before_restore');
    }
    await File(path).writeAsBytes(bytes, flush: true);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final x = File('$path$suffix');
      if (await x.exists()) await x.delete();
    }
    await AppDB.instance.init();
    onChanged();
    if (context.mounted) toast(context, 'تمت استعادة البيانات بنجاح');
  }

  Widget _card(IconData icon, String title, String sub, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'البيانات محفوظة داخل الجهاز فقط. خذ نسخة احتياطية بانتظام '
              'وأرسلها إلى واتساب أو البريد أو Google Drive حتى لا تفقد بياناتك '
              'عند تغيير الجهاز أو حذف التطبيق.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        _card(Icons.upload_file, 'إنشاء نسخة احتياطية ومشاركتها',
            'ملف قاعدة البيانات الكامل (.db)',
            () => guarded(context, () => _backup(context))),
        _card(Icons.restore, 'استعادة نسخة احتياطية',
            'اختر ملف .db محفوظاً سابقاً',
            () => guarded(context, () => _restore(context))),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('تصدير إلى Excel', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        _card(Icons.people, 'تصدير المتدربين', 'ملف xlsx بكل بيانات المتدربين والمبالغ',
            () => guarded(context, XlsxTools.exportStudents)),
        _card(Icons.receipt_long, 'تصدير سندات القبض', 'ملف xlsx بكل السندات',
            () => guarded(context, XlsxTools.exportPayments)),
      ],
    );
  }
}

// ============================================================
// الإعدادات
// ============================================================
class SettingsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const SettingsPage({super.key, required this.onChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String instituteName = '';
  String manager = '';
  String phone = '';
  String address = '';
  String logoPath = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    instituteName = await AppDB.instance.getInfo('institute_name', '');
    manager = await AppDB.instance.getInfo('manager', '');
    phone = await AppDB.instance.getInfo('institute_phone', '');
    address = await AppDB.instance.getInfo('institute_address', '');
    logoPath = await AppDB.instance.getInfo('institute_logo', '');
    if (mounted) setState(() => loading = false);
  }

  Future<String?> _pickLogo(BuildContext dialogContext) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return null;

    final ext = (f.extension ?? 'png').toLowerCase();
    final dir = await getApplicationDocumentsDirectory();
    final savedPath = p.join(dir.path, 'institute_logo.$ext');
    await File(savedPath).writeAsBytes(bytes, flush: true);
    return savedPath;
  }

  Future<void> editInfo() async {
    final nameCtrl = TextEditingController(text: instituteName);
    final managerCtrl = TextEditingController(text: manager);
    final phoneCtrl = TextEditingController(text: phone);
    final addressCtrl = TextEditingController(text: address);
    String logo = logoPath;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تعديل بيانات المعهد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المعهد'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: logo.isNotEmpty && File(logo).existsSync()
                          ? FileImage(File(logo))
                          : null,
                      child: logo.isEmpty || !File(logo).existsSync()
                          ? const Icon(Icons.school, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickLogo(dialogContext);
                          if (picked != null) {
                            setDialogState(() => logo = picked);
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(logo.isEmpty ? 'اختيار شعار المعهد' : 'تغيير الشعار'),
                      ),
                    ),
                    if (logo.isNotEmpty)
                      IconButton(
                        tooltip: 'إزالة الشعار',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setDialogState(() => logo = ''),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: managerCtrl,
                  decoration: const InputDecoration(labelText: 'المدير / المدرب المسؤول'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'هاتف المعهد (يظهر في الطباعة)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان (يظهر في الطباعة)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                await AppDB.instance.setInfo('institute_name', nameCtrl.text.trim());
                await AppDB.instance.setInfo('institute_logo', logo);
                await AppDB.instance.setInfo('manager', managerCtrl.text.trim());
                await AppDB.instance.setInfo('institute_phone', phoneCtrl.text.trim());
                await AppDB.instance.setInfo('institute_address', addressCtrl.text.trim());
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

  Widget _contact(IconData icon, String value) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) toast(context, 'تم نسخ: $value');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: logoPath.isNotEmpty && File(logoPath).existsSync()
                      ? FileImage(File(logoPath))
                      : null,
                  child: logoPath.isEmpty || !File(logoPath).existsSync()
                      ? const Icon(Icons.school, size: 45)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  instituteName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('المدير / المدرب: $manager'),
                if (phone.isNotEmpty) Text('الهاتف: $phone'),
                if (address.isNotEmpty) Text('العنوان: $address'),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: editInfo,
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل بيانات المعهد'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('النسخ الاحتياطي والاستعادة'),
            subtitle: const Text('احفظ بياناتك أو استعدها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubPage(
                  title: 'النسخ الاحتياطي',
                  child: BackupPage(onChanged: widget.onChanged),
                ),
              ),
            ),
          ),
        ),
        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('قفل التطبيق برمز سري'),
            subtitle: const Text('حماية بيانات المعهد المالية والشخصية'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => openPinSettings(context, widget.onChanged),
          ),
        ),
        const Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(Icons.storage),
            title: Text('قاعدة البيانات'),
            subtitle: Text('SQLite محلية داخل الجهاز'),
          ),
        ),
        const Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(Icons.security),
            title: Text('الخصوصية'),
            subtitle: Text('البيانات محفوظة محلياً في التطبيق فقط'),
          ),
        ),
        const Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('إصدار النظام'),
            subtitle: Text(kAppVersion),
          ),
        ),
        const SizedBox(height: 6),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              children: [
                const Text(
                  'تطوير وبرمجة',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  'المطور: $kDevName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                _contact(Icons.phone_outlined, kDevPhone),
                _contact(Icons.email_outlined, kDevEmail),
                const Text(
                  'اضغط على الرقم أو البريد لنسخه',
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

