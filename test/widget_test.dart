import 'package:expense_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Android-only channels the app calls on start; answer as a phone with
/// nothing set up would.
void _mockNativeChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.expense.expense_tracker/capture'),
    (call) async => switch (call.method) {
      'takeLaunchSetup' || 'hasNotificationAccess' || 'canPostNotifications' => false,
      _ => null,
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.expense.expense_tracker/backup'),
    (call) async => call.method == 'isSupported' ? false : null,
  );
}

/// Lets real database work run until [finder] shows up (pumpAndSettle
/// would wait forever on the loading spinner).
Future<void> _waitFor(WidgetTester tester, Finder finder, {bool gone = false}) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty != gone; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.deleteDatabase(p.join(await getDatabasesPath(), 'expenses.db'));
  });

  setUp(_mockNativeChannels);

  // One flow on purpose: the app's database is a single shared instance.
  testWidgets('first open asks for the bank balance, then Home shows it', (tester) async {
    // A Pixel-sized screen, as the app is phone-only.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: ExpenseTrackerApp()));

    final prompt = find.text("What's your current bank balance?");
    await _waitFor(tester, prompt);
    await tester.pump(const Duration(seconds: 1)); // let the sheet finish sliding up
    expect(prompt, findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '25000');
    await tester.tap(find.text('Save'));
    await _waitFor(tester, prompt, gone: true);

    expect(prompt, findsNothing);
    expect(find.text('₹25,000'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.byTooltip('Add an expense or income'), findsOneWidget);
  });
}
