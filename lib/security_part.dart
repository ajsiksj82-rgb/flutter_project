part of 'main.dart';

// ============================================================
// قفل التطبيق برمز سري (اختياري)
// ============================================================

/// يُعرض عند بدء التطبيق: يتحقق إن كان هناك رمز محفوظ، وإن وُجد
/// يعرض شاشة القفل قبل الدخول إلى التطبيق.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool? locked;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final has = await AppDB.instance.hasPin();
    if (mounted) setState(() => locked = has);
  }

  @override
  Widget build(BuildContext context) {
    if (locked == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (locked == false) {
      return const MainShell();
    }
    return LockScreen(onUnlocked: () => setState(() => locked = false));
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String entered = '';
  String? error;
  bool checking = false;

  Future<void> _submit() async {
    setState(() => checking = true);
    final ok = await AppDB.instance.verifyPin(entered);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        error = 'رمز غير صحيح';
        entered = '';
        checking = false;
      });
    }
  }

  void _tap(String d) {
    if (checking || entered.length >= 6) return;
    setState(() {
      error = null;
      entered += d;
    });
    if (entered.length >= 4) {
      // نسمح بطول 4 إلى 6 أرقام؛ نحاول التحقق تلقائياً بعد كل رقم إضافي
      // بدءاً من الرقم الرابع.
      _submit();
    }
  }

  void _backspace() {
    if (entered.isEmpty) return;
    setState(() => entered = entered.substring(0, entered.length - 1));
  }

  Widget _dot(int i) {
    final filled = i < entered.length;
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.blue : Colors.grey.shade300,
      ),
    );
  }

  Widget _key(String label, {VoidCallback? onTap, Widget? child}) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
        ),
        child: child ??
            Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.lock_outline, size: 46, color: Colors.blue),
              const SizedBox(height: 14),
              const Text('أدخل الرمز السري للدخول',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, _dot),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 20,
                child: Text(
                  error ?? '',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
              const Spacer(),
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final d in row) ...[
                        _key(d, onTap: () => _tap(d)),
                        const SizedBox(width: 18),
                      ],
                    ]..removeLast(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 68),
                    const SizedBox(width: 18),
                    _key('0', onTap: () => _tap('0')),
                    const SizedBox(width: 18),
                    _key('', onTap: _backspace, child: const Icon(Icons.backspace_outlined)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- إدارة الرمز من الإعدادات ----------
Future<void> openPinSettings(BuildContext context, VoidCallback onChanged) async {
  final hasPin = await AppDB.instance.hasPin();
  if (!context.mounted) return;

  if (hasPin) {
    final sure = await confirmAction(
      context,
      title: 'قفل التطبيق',
      content: 'يوجد رمز سري مفعّل حالياً. ماذا تريد أن تفعل؟',
      okLabel: 'تغيير الرمز',
      cancelLabel: 'إلغاء',
    );
    if (!sure) return;
  }
  if (!context.mounted) return;
  await _setPinDialog(context);
  onChanged();
}

Future<void> _setPinDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final ctrl2 = TextEditingController();
  String? error;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('تعيين رمز سري (4 أرقام على الأقل)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'الرمز السري'),
            ),
            TextField(
              controller: ctrl2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'تأكيد الرمز'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppDB.instance.clearPin();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('إلغاء القفل', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().length < 4) {
                setDialogState(() => error = 'الرمز يجب أن يكون 4 أرقام على الأقل');
                return;
              }
              if (ctrl.text.trim() != ctrl2.text.trim()) {
                setDialogState(() => error = 'الرمزان غير متطابقين');
                return;
              }
              await AppDB.instance.setPin(ctrl.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}
