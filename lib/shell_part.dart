part of 'main.dart';

// ============================================================
// التطبيق
// ============================================================
class SmartSkillsApp extends StatelessWidget {
  const SmartSkillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سمارت سكلز للتدريب والتأهيل',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AppGate(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int refreshTick = 0;

  final titles = const [
    'لوحة التحكم',
    'المتدربون',
    'الدورات التدريبية',
    'المالية',
    'المزيد',
  ];

  void refreshAll() => setState(() => refreshTick++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('dash$refreshTick')),
      StudentsPage(key: ValueKey('stu$refreshTick'), onChanged: refreshAll),
      CoursesPage(key: ValueKey('crs$refreshTick'), onChanged: refreshAll),
      FinancePage(key: ValueKey('fin$refreshTick'), onChanged: refreshAll),
      MorePage(key: ValueKey('more$refreshTick'), onChanged: refreshAll),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'المتدربون',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'الدورات',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'المالية',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}

/// إطار موحّد للصفحات الفرعية (الحضور، الدرجات، التقارير ...).
class SubPage extends StatelessWidget {
  final String title;
  final Widget child;
  const SubPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: child,
    );
  }
}

class MorePage extends StatelessWidget {
  final VoidCallback onChanged;
  const MorePage({super.key, required this.onChanged});

  void _open(BuildContext context, String title, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubPage(title: title, child: page)),
    ).then((_) => onChanged());
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub,
      Color color, Widget Function() page) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open(context, title, page()),
      child: Card(
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            _tile(context, Icons.groups_outlined, 'المدربون',
                'بيانات المدربين وربطهم بالدورات', Colors.deepPurple,
                () => InstructorsPage(onChanged: onChanged)),
            _tile(context, Icons.fact_check, 'الحضور والغياب',
                'تسجيل وطباعة الحضور', Colors.teal, () => const AttendancePage()),
            _tile(context, Icons.grade, 'الدرجات',
                'إدخال، استيراد Excel، طباعة', Colors.orange, () => const GradesPage()),
            _tile(context, Icons.print, 'التقارير والطباعة',
                'كل التقارير بصيغة PDF', Colors.indigo, () => const ReportsPage()),
            _tile(context, Icons.backup, 'النسخ الاحتياطي',
                'حفظ واستعادة البيانات', Colors.green,
                () => BackupPage(onChanged: onChanged)),
            _tile(context, Icons.settings, 'الإعدادات', 'بيانات المعهد والمطور',
                Colors.blueGrey, () => SettingsPage(onChanged: onChanged)),
          ],
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(kAppVersion,
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      ],
    );
  }
}

