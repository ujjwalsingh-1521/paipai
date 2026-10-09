# PaiPai — personal expense tracker

Local-first Android app (Flutter) for tracking expenses and income. All data lives in on-device SQLite. Payment notifications (bank SMS via the Messages app, UPI apps, bank apps, email alerts) are parsed so each payment can be categorised in one tap. Built for personal use, sideloaded as an APK. The Play Store is a possible future target: payment capture uses notification access (allowed for a core feature), and Play also permits SMS access for budget apps after a permissions declaration.

**Status and roadmap live in [`progress.md`](progress.md). Read it at the start of every session, and update it in the same change as any feature or fix.**

## Stack

- Flutter, targeting Android only (minSdk 23, targetSdk 36), Material 3
- State: `flutter_riverpod` (AsyncNotifiers)
- Storage: `sqflite`, singleton `DatabaseHelper`, schema **v11** (`DatabaseHelper.schemaVersion`), migrations in `onUpgrade`
- Charts: `fl_chart`
- Native Kotlin: a `NotificationListenerService` plus a **headless Flutter engine** (`paymentCaptureMain` in `main.dart`) that runs the Dart capture code while the app is closed; MethodChannel `com.expense.expense_tracker/capture`

## Commands

```bash
flutter analyze                    # must be clean before any build
flutter test
flutter build apk --release        # -> build/app/outputs/flutter-apk/app-release.apk
node branding/generate_icons.js    # regenerate launcher/notification icons (see branding/)
```

## Layout

```
lib/
  db/database_helper.dart   all SQL, schema, migrations
  models/                   plain data classes (toMap/fromMap)
  providers/                Riverpod notifiers, one per table/feature
  screens/ widgets/         UI. Navigation: Home · Activity tabs, + opens add_entry_sheet, Home's chart
                            opens insights_screen, the gear opens settings_screen (categories, capture,
                            backup, balance, theme). widgets/charts/: pace, category breakdown, calendar
  theme/app_theme.dart      Material 3 from one seed (brand blue). Use context.colors / context.text /
                            context.money, Space.* and Corners.* only; no hardcoded colors, sizes or
                            borders. Roboto Flex is bundled (assets/fonts, see branding/README.md)
  models/category_symbol.dart a category's symbol (column `emoji`) is `icon:<name>` from the grouped icon
                            catalog, or any emoji the user typed. Never rename an icon name (it's stored)
  services/capture/         payment_parser (generic, any bank/UPI app), payment_matcher (duplicate
                            merging), capture_service (save/alert/categorize), capture_channel (native bridge)
  services/widgets/         WidgetSnapshot (pure, tested) + WidgetSync.push(): call after any data change
  services/budgets/         BudgetCheck.run(): call next to WidgetSync.push after any spending change; alerts each
                            warning level once per budget per month (level reached kept in settings)
  models/budget.dart, utils/budgets.dart  budget rows are a history ('' = monthly budget, NULL amount = removed
                            from that month); budgetsIn() picks the ones in force; BudgetStatus/budgetLevel are pure
  services/backup/          backup file format (pure, unit-tested), share/pick/restore, daily auto-backup
  utils/analytics.dart      pure aggregation functions for charts
  utils/money.dart          roundMoney/sumMoney: every stored amount and total is rounded to paise
  models/balance_start.dart the user's bank balance + the last entry ids at that moment; Home's balance
                            = that amount + entries added after (by id, not date)
  widgets/                  shared pieces: entry_row, ui (SectionHeader, GroupCard, EmptyNote), category_chip,
                            category_sheet, edit_entry_sheet, entry_fields, month_switcher
android/app/src/main/kotlin/com/expense/expense_tracker/
  PaymentNotificationListener  receives notifications; forwards only ones mentioning money
  CaptureEngine                starts/holds the headless engine, queues events until Dart is ready
  AlertNotifier                "₹250 paid · Shop [Cat][Cat][More]" alerts; AlertActionReceiver for buttons
  QuickPickActivity            the "More" card: see-through FlutterActivity running `quickPickMain`
                               (lib/screens/quick_pick_app.dart) over the current app
  AppChannel                   app-engine side: permissions, open-payment intents, refresh signals
  PaiPaiWidgets                the 4 home-screen widgets (Label payments, This month, Where it went, Quick
                               add). They only draw a snapshot that lib/services/widgets/ builds and
                               pushes ("updateWidgets") after every change; buttons reuse AlertActionReceiver
                               and QuickPickActivity (mode "add" = the + sheet). A tapped category hides that
                               payment and redraws the Label widget at once (markHandled), before the capture
                               engine starts; widget prefs use commit(). Sized so all four fit on one
                               4-column screen: Label 3×1 + Quick add 1×1, This month 2×2 + Where it went 2×2
  CaptureHealth                Android 15+ hidden-notification detection and one-time warning
  BackupChannelHandler         writes Downloads/PaiPai via MediaStore (Android 10+)
test/services/capture/payment_samples.dart   140 real-world message samples; add every missed message here
branding/                   master SVGs + icon generator
```

## Testing capture on the emulator

```bash
export MSYS_NO_PATHCONV=1   # Git Bash rewrites /sdcard paths otherwise
P=com.expense.expense_tracker
adb shell cmd notification allow_listener $P/$P.PaymentNotificationListener   # re-run after each install
adb shell pm grant $P android.permission.POST_NOTIFICATIONS
# Quote the whole command, or adb splits the text at the first space:
adb shell "cmd notification post -S bigtext -t 'AX-HDFCBK' tag1 'Rs.250.00 debited from A/c XX1234 to SHOP. UPI Ref 412345678901'"
adb logcat -d | grep PaiPaiCapture
```

- Run the emulator with `-no-window` (the user may be using the PC).
- Android 15 replaces many bank-SMS texts with "Sensitive notification content hidden" for PaiPai. To test parsing, run `adb shell cmd appops set --user 0 $P RECEIVE_SENSITIVE_NOTIFICATIONS allow` and re-toggle the listener, or turn off Settings → Notifications → Enhanced notifications.
- Flutter widgets aren't visible to `uiautomator` text search; tap them by coordinates (screenshots are 1080×2400).

## Rules that protect the user's data

- **Never change `applicationId` / package `com.expense.expense_tracker`.** The display name is "PaiPai"; the ID stays the same. Changing it makes Android treat the build as a new app, and the user's data stays behind in the old one.
- **Release signing:** `android/key.properties` (gitignored) points to the release keystore, which lives outside the repo. Every release must be signed with this key so it installs over the existing app and keeps its data. The Gradle build fails on purpose if the file is missing. Never regenerate or replace the key.
- **Bump `version: x.y.z+N` in `pubspec.yaml` once per release (a new feature batch), not for every rebuild.** Fixes to a version that isn't committed yet keep its number: Android installs an APK with the same version over the existing app and keeps the data.
- **Never file a payment without the user choosing.** Past choices only order the suggestions (`Suggestions.rank` in capture_service.dart, read from saved entries via `capturedChoices`). The `merchant_mappings` table is unused since 1.3.0 and kept only so old backups restore.
- **Split payments** are ordinary expense rows sharing `split_id` = the first part's id (the row a capture links to). Always save, change, unsplit and delete them as a whole (`DatabaseHelper.saveSplit/unsplit/deleteSplit`). Lists group them via `LedgerEntry.merge`; the bank balance counts parts by `Expense.recordedId`; never compute the balance from `LedgerEntry` rows (a split row holds only its first part's `Expense`).
- **Payee and note are separate.** Expenses/income have `payee` (who was paid; set from captured payments) and `notes` (the user's own text). Never store a payee in `notes`.
- **Amounts are shown only via `formatMoney`** (₹1,23,450, paise only when present). Expenses are plain text; green only for money in; red only for destructive actions and errors.
- **No automatic salary.** Salary is ordinary income (captured or added). The `salary_history` table stays only so old backups restore; nothing reads it.
- **Tests:** `test/widget_test.dart` drives the real app on an ffi database; wait with real time (`runAsync`), never `pumpAndSettle` (loading spinners never settle).
- **DB changes:** bump `DatabaseHelper.schemaVersion`, add an `onUpgrade` step and update `onCreate` to match. Make migrations idempotent (`IF NOT EXISTS`). Never drop user data.
- **Backups follow the schema.** A new table goes into `DatabaseHelper.backupTables`. Older backups restore as-is while every change since v6 only *adds* columns with defaults (`BackupFile.minSupportedSchema`), except v8 (category symbols) and v9 (payee moved out of `notes`), which `BackupFile.decode` converts for older backups. A new table also goes into `BackupFile.addedIn`, so older backups without it still restore (budgets, v11). A rename/drop must convert old rows in `BackupFile.decode`, or the user's existing backup files stop restoring.

## Working agreement

- **Don't commit or push unless the user explicitly says so.** When committing, tick off the finished items in `progress.md` in the same commit.
- **Git identity is repo-local** (personal account `ujjwalsingh-1521`, noreply email). Never use the global or office identity. The remote is `github.com/ujjwalsingh-1521/paipai` (public, GPL-3.0; the old private `expense-tracker-archive` keeps the pre-2026-10-09 history). `main` is protected: outside changes arrive only as pull requests with passing CI. Never commit personal data; anonymise real messages before adding them as samples; private notes go in the gitignored `notes/`. For `gh` commands: `GH_TOKEN=$(gh auth token --user ujjwalsingh-1521) gh ...`
- **Batch work, build once.** Every APK means a manual install for the user (Drive → phone). Finish a batch of changes, then run `flutter analyze` and `flutter test`, build once, and only then hand over the APK.
- The user prefers going one feature at a time, with a check-in before starting the next.
