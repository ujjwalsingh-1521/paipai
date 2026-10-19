import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/activity_screen.dart';
import 'screens/auto_capture_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/quick_pick_app.dart';
import 'screens/settings_screen.dart';
import 'services/backup/backup_service.dart';
import 'services/capture/capture_channel.dart';
import 'services/capture/capture_service.dart';
import 'services/budgets/budget_check.dart';
import 'services/widgets/widget_sync.dart';
import 'providers/balance_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/pending_transaction_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/income_provider.dart';
import 'widgets/add_entry_sheet.dart';
import 'widgets/balance_sheet.dart';
import 'widgets/payment_review_sheet.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: ExpenseTrackerApp()));
}

/// Entry point of the headless engine that Android starts for payment
/// notifications (see CaptureEngine.kt). Runs even while the app is closed.
@pragma('vm:entry-point')
Future<void> paymentCaptureMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CaptureChannel.startBackground(CaptureService(alerts: NativeCaptureAlerts()));
}

/// Entry point of the card that More on a payment alert opens over the
/// current app (see QuickPickActivity.kt).
@pragma('vm:entry-point')
void quickPickMain() {
  runApp(const ProviderScope(child: QuickPickApp()));
}

class ExpenseTrackerApp extends ConsumerWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PaiPai',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      scrollBehavior: const CalmScrollBehavior(),
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BackupService().runAutoBackupIfDue();
    CaptureChannel.listenInApp(
      onOpenPending: (id) => _reviewPayments(startWith: id),
      onOpenSetup: _openCaptureSetup,
      onDataChanged: _refreshProviders,
      onOpenScreen: _openScreen,
    );
    WidgetSync.push();
    CaptureChannel.requestSmsScan();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reviewOnOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Data only changes while the app is in use, so backing up on the way
    // out (at most once a day) captures everything without a background job.
    if (state == AppLifecycleState.paused) {
      BackupService().runAutoBackupIfDue();
    }
    if (state == AppLifecycleState.resumed) {
      // Payments captured while the app was in the background, and bank
      // SMS that came while PaiPai couldn't run.
      CaptureChannel.requestSmsScan();
      _refreshProviders();
      _reviewOnOpen();
    }
  }

  /// Asks "What was this?" for payments not yet labelled, starting with the
  /// one a notification opened the app for.
  Future<void> _reviewOnOpen() async {
    if (await CaptureChannel.takeLaunchSetup()) return _openCaptureSetup();
    final screen = await CaptureChannel.takeLaunchScreen();
    if (screen != null) return _openScreen(screen);
    await _askBalanceOnce();
    final launchId = await CaptureChannel.takeLaunchPendingId();
    // Ask only on the main screens, not on top of setup or another screen;
    // a tapped notification (launchId) always opens its payment.
    final onMainScreen = mounted && (ModalRoute.of(context)?.isCurrent ?? true);
    if (launchId == null && !onMainScreen) return;
    // Unasked, only recent ones: imported old SMS wait on Home instead.
    await _reviewPayments(startWith: launchId, recentOnly: true);
  }

  Future<void> _reviewPayments({int? startWith, bool recentOnly = false}) async {
    if (!mounted) return;
    await reviewPendingPayments(context, ref, startWith: startWith, recentOnly: recentOnly);
  }

  /// First open: "What's your current bank balance?" (skippable, asked once).
  Future<void> _askBalanceOnce() async {
    final shouldAsk = await ref.read(balanceStartProvider.notifier).shouldPrompt();
    if (!shouldAsk || !mounted) return;
    await showBalanceSheet(context, firstTime: true);
  }

  /// From a home-screen widget (the pace and category widgets).
  void _openScreen(String screen) {
    if (!mounted || screen != 'insights') return;
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsScreen()));
  }

  void _openCaptureSetup() {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoCaptureScreen()));
  }

  void _refreshProviders() {
    ref.invalidate(pendingTransactionProvider);
    ref.invalidate(expenseProvider);
    ref.invalidate(incomeProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Widgets show these, so any change (edit, delete, rename) refreshes
    // them; spending changes can also cross a budget's warning level.
    ref.listen(expenseProvider, (_, _) {
      WidgetSync.push();
      BudgetCheck.run();
    });
    ref.listen(budgetProvider, (_, _) {
      WidgetSync.push();
      BudgetCheck.run();
    });
    ref.listen(categoryProvider, (_, _) => WidgetSync.push());
    ref.listen(pendingTransactionProvider, (_, _) => WidgetSync.push());
    final onHome = _currentIndex == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(onHome ? _greeting() : 'Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: onHome
          ? HomeScreen(onSeeAll: () => setState(() => _currentIndex = 1))
          : const ActivityScreen(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add an expense or income',
        onPressed: () => showAddEntrySheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
