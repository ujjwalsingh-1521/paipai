# PaiPai — Progress

Tick items off (`[x]`) in the same commit that completes them, and move finished work into **Done**.
The full audit these items come from was done on 2026-10-03; file:line references are as of that date.

## Next up (in order)

1. [ ] **Try auto-capture on the real phone** and send me any payment message it misses or misreads (with account numbers hidden), so it can go into the test library
   - 2026-10-05: the user's own phone ran smoothly all weekend (1.4.0)
   - 2026-10-05: checked the phone's notifications and the captured payments in its backup. All 20 payments were caught, each once: Google Pay and Paytm don't notify for payments you make, but every UPI payment brings a Kotak 811 app alert and a Kotak SMS, which merge by UPI ref. Still wanted: a real Paytm or GPay *payment* notification if one ever shows up (e.g. money received)
2. [ ] **Investigate: bugs seen on a second tester's phone 1.4.0**. Proof (screenshots, bank statement) still to come from the user; verify against their bank statement and the app's entries before changing code
   - **Balance doesn't match their bank**: the in-app balance differs from their real one. Find which entries cause the gap: a missed payment, an extra or duplicated one, or something dated before the balance was set. A duplicate (below) would explain at least part of it
   - **₹250 counted twice** (likely fixed in 1.9.0: a late alert without a ref now merges within 90 min on the same account; confirm with their data): the user sent them ₹250 on WhatsApp Pay; their bank SMS arrived about 30 minutes later, and the app seems to have recorded it twice. Suspicion: the two alerts didn't share a reference number, and duplicate merging only merges by amount and direction within 10 minutes (3 h only when an email is involved), so an alert 30 min apart becomes a second payment. WhatsApp Pay alerts are meant to be ignored, so also check which app produced the first entry. Needs their logs or the entries' source apps to confirm
3. [ ] **Delivery (later, when the app feels finished)**: Play Store *internal testing* ($25 one-time developer account, up to 100 invited testers, auto-updates). Upload the existing keystore as the app-signing key so the sideloaded install updates in place. Replaces the GitHub Actions + Obtainium idea: a sideloaded install hits Play Protect's fraud block (India) and "Restricted settings" because of Notification access, and Obtainium installs are still sideloads
   - Until then: updates over USB (`adb install -r`), which avoids the Play Protect block; or temporarily turn off Play Protect scanning for a Drive install

## Backlog

### Open source
- [ ] CI housekeeping: bump `actions/checkout` to a Node 24 version, and check the run still passes once `ubuntu-latest` moves to Ubuntu 26 (from 2026-10-19)

### Promo video
- [ ] **Promo video idea (2026-10-06)**, now that the repo is public. Pitch: local-first (no account, no server, no internet permission), one-tap labelling from notifications and widgets, Indian bank/UPI formats with 140 real-world samples. Reference: Kharcha's 20 s launch video (problem → SMS becomes an entry → charts/budget → "no account" ticks → open-source end card); its structure works but it looks plain: elements just appear. PaiPai's should have rich motion and ambience where every element does something (the notification card travels into the widget, the tap ripples into the entry, the budget bar fills and the 80% alert drops in) and show the real app, which does more than Kharcha's video claims. Likely built as code-based animation rendered to MP4 (16:9 for X/LinkedIn, maybe 9:16), mixing designed scenes with emulator recordings
  - Decided: **same content and script beats as Kharcha's video** (adapted to PaiPai's features); the difference is taste and design (richer motion, ambience, every element with a role) **plus sound design synced to the picture**, like theirs (checked its waveform/spectrogram: pings that speed up as the SMS pile up, a riser into the logo reveal with a hard cut, a beat with hits on the scene changes and the ✓ ticks, a soft held tone on the end card). Ours: accelerating pings for alerts piling up, riser → drop on the logo, a click + ripple on the tap, a coin when the entry lands, a rising tone as the budget bar fills, a chime on the 80% alert, an accent per trust tick on the beat, a calm pad on the end card; cuts timed to the beat

### Data safety
- [ ] Later (optional): automatic backup to Google Drive, which also covers a lost phone

### Payment auto-capture
- [ ] **Idea: transfers between the user's own accounts.** A move from account A to B shows up as a debit (A's alert) and a credit (B's alert), so it's offered as an expense and an income, inflating both. Detect the pair (same amount, opposite directions, two different own account tails, close in time, often the same ref) and mark it as a transfer that counts as neither
- [ ] Cheap catch-up without new permissions: on listener reconnect, read `getActiveNotifications()` for payments still in the shade; a "capture is off" banner when Notification access is lost; Share/paste a message into PaiPai
- [ ] **Bug (low priority, found 2026-10-05): forwarded bank messages are captured.** Partly fixed in 1.9.0: SMS from phone numbers are ignored (`SmsSender`); forwards through chat apps remain. The user forwarded their Kotak "Sent Rs.506.00 … UPI Ref …" SMS from a friend's phone by SMS and WhatsApp: with the same ref it merged into the real payment (no harm), but with the ref changed by one digit it was offered as a new payment to label. Cause: `_hasFinancialEvidence` in payment_parser.dart accepts any message with an a/c tail or UPI ref, before looking at who sent it. Fix: ignore chat apps (WhatsApp, Telegram, Instagram…) for capture entirely, and ignore SMS whose sender is a phone number or a contact name rather than a bank sender ID (`AX-KOTAKB-S`, short codes); add forwarded-message samples as "must ignore". Nothing is ever filed without the user, so the worst case is one extra card to dismiss
- [ ] UPI-app notification formats (Google Pay, PhonePe, Paytm, CRED…) in the test library are reconstructions; replace them with real ones
- [ ] Android 15+ hides some bank SMS from PaiPai (it mistakes them for OTPs). The setup screen explains the two one-time fixes; check how often it happens on real phones
- [ ] WhatsApp Pay alerts are ignored on purpose (they look like chat messages); the bank SMS for them is still captured
- [ ] Idea, skipped for now: floating bubble for new payments (Android Bubbles API)

### App bugs
- [ ] Money is stored as `REAL`. Amounts are now rounded to paise on every save and in totals (no visible drift); a full switch to integer paise is only worth it if a real problem shows up
- [ ] Two notifiers (expense categories, income sources) are still near-copies; fine for now

### Ideas discussed (2026-10-05, not started)
- [ ] Widgets: optional "hide amounts" setting for privacy
- [ ] From the Kharcha comparison (2026-10-06): **CSV export** (all entries, for a spreadsheet or tax time) and a **Dismissed list** (payments marked "Not a payment", with a way to restore one tapped by mistake). Share/paste a message is listed under Payment auto-capture

## Done

- [x] **2026-10-19** **1.9.0: bank SMS as the main source.** PaiPai reads bank SMS itself (RECEIVE_SMS/READ_SMS; `SmsCapture.kt`, `sms_inbox.dart`): new SMS at once, also while the app is closed; a catch-up scan of the inbox on app open and after a restart, for SMS that came while the phone was off or PaiPai couldn't run; and an Import of older SMS from a date the user picks (no alerts; they wait on Home, which opens the list when more than 5 wait). Payments that happened before the balance was set never move it. With SMS on, notification access is optional ("Also read payment app notifications", off by default) and SMS apps' notifications are skipped; without SMS it works as before. Setup screen reworked (SMS first, restricted-settings help, import card). Also:
  - **"Stuck" taps fixed.** Each category tap held PaiPai's broadcast queue for a fixed 8 s, so 3 quick taps took 24 s and looked frozen; the receiver now finishes when the save does (0.4 s for 3 taps on the emulator). Saving claims the payment in one transaction, so two taps (or the More card and the alert) never save it twice; the More card always closes, and Save recovers from an error.
  - **Note and original messages before saving**: the review sheet and the More card have a Note field and show "Seen in" plus every original message.
  - **Late bank-app alerts merge.** The Kotak 811 app alerts 14 to 40 min after the SMS, without a reference: from another app on the same account, such alerts now merge within 90 min (similar payee names within 3 h), joining the closest payment, and the fuller payee name wins. From the user's backup (13 to 17 Oct): ₹150, ₹60 and ₹220 had each been recorded twice.
  - **Ads ignored.** SMS from -P (promotional) senders and phone numbers, and loan offers ("Get a personal loan of Rs. 5,500 … Check your offer"), which had been saved as a ₹5,500 expense.
  - Balance: for anyone whose payments were captured before they set the balance and labelled after, the shown balance changes once with this update (those used to be counted twice). The user's own phone isn't affected (balance set 3 Oct 06:55, first capture 06:57)
  - Known gaps: bank SMS from 10 to 13 digit phone numbers (rare: Indian banks use registered headers) are ignored as forwards, and bank alerts sent as RCS chat messages never reach the SMS inbox; turning on app notifications covers RCS
  - Tested on the emulator: live SMS, the Messages notification not counted again, catch-up after a missed SMS and after a restart, Import (no alerts, no duplicates), the balance rule, taps, the More card with a note.
- [x] **2026-10-13** **New logo (1.8.1)**: twin lowercase "p" (the doubled "Pai Pai") with a gold dot on brand blue `#2563EB`; the back p is light blue and cut away around the front one. Fredoka SemiBold outlined to paths. The launcher, adaptive, themed (monochrome) and status-bar icons all come from `branding/generate_icons.js`; the status-bar icon is now a PNG per density. Checked on the emulator: the launcher and the payment alert
- [x] **2026-10-13** **Open source** (GPL-3.0) at `github.com/ujjwalsingh-1521/paipai`, public, with release v1.8.0 carrying the signed APK and its SHA-256. Before publishing: personal data removed (the second tester named neutrally, real shop names and area in the samples replaced, LINKEDIN_CONTEXT.md and `notes/` gitignored), and the history squashed to one commit (the old history stays private in `expense-tracker-archive` and in `PaiPai-history-backup-2026-10-09.bundle`). Added a README, LICENSE, CONTRIBUTING, SECURITY, issue and PR templates, CODEOWNERS, and CI (analyze and test on every PR and on every push to `main`). `main` is protected: changes need a pull request with passing CI and the owner's review, and force-pushes and deletion are blocked (the owner can still push directly). Also on: private vulnerability reporting, secret scanning with push protection, Dependabot alerts, and approval before CI runs on outside contributors' PRs
- [x] **2026-10-09** Restoring a backup now reloads budgets too (the budget card used to appear only after restarting the app)
- [x] **2026-10-06** **Budgets** (spec: docs/superpowers/specs/2026-10-06-budgets-design.md): a monthly budget and optional category budgets in Settings → Budgets; one alert setting for all (on by default, warnings at 80% and 90%, changeable, plus "over"). Each alert comes once per budget per month, one per payment even when it jumps several levels, and again if spending drops back below and crosses again. Home: budget card (left / over, bar with today's even-pace mark, "29% used · 26 days left · on track", "₹X ahead of pace", "+ ₹750 waiting to be labelled"), or a dismissible "Set a monthly budget" card. Insights: the month's budget card and "₹1,080 of ₹1,500" bars on budgeted categories. Widgets: "₹2,877 left of ₹12,000" on This month; "₹1,080 / ₹1.5K" on a wide Where it went. Splits count per part; income never lowers spending. Data v11 (`budgets`); older backups restore without budgets. Tested on the emulator: upgrade from 1.7.0, alerts from the widget, the notification, the More card and the + sheet, light and dark
- [x] **2026-10-06** **Label widget answers at once**: tapping a category hides that payment and shows the next one immediately, with a "Saved ₹500 · Bigbasket to Groceries" message, instead of seconds later (the save needs the background engine, which starts slowly when the app was closed; the redraw used to wait behind it). Widget data is written to storage immediately, so a stopped process can't bring back an old copy
- [x] **2026-10-05** **Order receipt emails read correctly** (from the user's phone): a Swiggy/Toing "order delivered" email was captured as "₹80 paid to issue an invoice directly" (the ₹80 was a saving). Emails now use the labelled total ("Paid Via Bank ₹506", "Grand Total") and the sender as the shop, and "₹80 saved" / "₹100 off" amounts are never taken as the payment. Kotak 811 shows by name in payment details. 7 real samples from the phone added to the test library
- [x] **2026-10-03** Project audit (native + Dart); findings recorded above
- [x] **2026-10-03** Git repo created and pushed to `ujjwalsingh-1521/expense-tracker` (private) with a repo-local personal identity
- [x] **2026-10-03** Permanent release signing key: updates now install over the existing app and keep its data
- [x] **2026-10-03** Renamed the app to **PaiPai** (launcher label, app title, notification title)
- [x] **2026-10-03** New logo: a twin-coin ₹ adaptive icon (with themed-icon monochrome layer), legacy icons, and a white ₹ notification icon; masters in `branding/`
- [x] **2026-10-03** `CLAUDE.md` + `progress.md`
- [x] **2026-10-03** **Backup & Restore** (top-bar cloud icon):
  - "Create backup" opens the share menu with one JSON file
  - Daily automatic backup to `Downloads/PaiPai` (survives uninstall; keeps the last 7 days; runs on app open/leave, at most once a day)
  - Restore replaces everything after a confirm dialog and saves a `before-restore` safety copy first
  - Tested on an Android 15 emulator: uninstall → reinstall → restore brought all data back
- [x] **2026-10-03** Undo snackbar on swipe-delete and on delete from the edit sheets
- [x] **2026-10-03** **Payment auto-capture rebuilt on notifications** (replaces SMS reading, the floating window and the background service):
  - Reads bank SMS (via the Messages app), UPI-app, bank-app and email notifications. Android keeps the listener running, including after reboots and force-stops
  - Generic parser for any bank or UPI app: amount, direction, payee, reference, account digits; ignores OTPs, failed payments, requests, mandates, reminders, offers and chats. 140-message test library (84 verbatim templates, 7 from the user's own phone)
  - Duplicate merging: same reference → one payment; otherwise same amount + direction within 10 min (3 h when an email is involved); different references, directions or accounts stay separate; same-app fuzzy merges offer "Split"
  - Alert: "₹250 paid · Shop" with 2 category buttons + Other (opens that payment). Category taps save without opening the app (replaced by suggestions + More in 1.3.0)
  - "What was this?" asks for each unlabelled payment when the app opens
  - Learned merchants: auto-filed after the same category is picked twice (removed in 1.3.0)
  - Setup screen: 2 permissions with green ticks, restricted-settings help, Android 15 hidden-SMS fixes, test payment
  - Permissions down to one manifest permission (notifications) plus Notification access
  - 168 unit tests; tested end to end on an Android 15 emulator

- [x] **2026-10-03** **Bank balance instead of automatic salary**: the monthly salary feature is removed (salary arrives as captured income like everything else). First open asks "What's your current bank balance?"; Home shows a live balance (that amount + income − expenses recorded since); tap the card to correct it
- [x] **2026-10-03** Bug fixes:
  - Salary no longer counted twice, Home no longer opens without salary, no 2020 salary backdating (all gone with the salary feature)
  - Category rename updates existing entries and learned merchants immediately
  - Duplicate names ("Food"/"food") are refused with a message
  - Deleting a category moves its entries (and learned merchants) to one you pick, default Other
  - Save buttons can't save twice on a double tap
  - Income vs Expense chart handles months with no data
  - Analytics row no longer overflows on narrower (~390dp) phones
  - Money rounded to paise on save and in totals
- [x] **2026-10-03** **Suggestions instead of auto-filing**: PaiPai never files a payment by itself any more (a shop like Blinkit can be groceries one day and a charger the next). The alert's 2 buttons are what you usually pick for that shop (most picked, then most recent), else your most-used categories; "Other" only when it's the usual. Suggestions come from saved entries, so fixing one in History improves the next. In the app, the usual category comes pre-selected
- [x] **2026-10-03** **"More" card**: More on an alert opens a small card with every category over whatever app is open (no extra permission, since it opens on tap); it closes after Save and you're back where you were
- [x] **2026-10-03** **Redesign (Material You)**: Material 3 colors from the brand blue, bundled Roboto Flex with even-width digits, one spacing scale, no stretch on scroll, Phone/Light/Dark theme
  - Home: bank balance, "payments to label" banner, "October so far vs September" chart (opens Insights), last 5 entries
  - Insights: pace vs last month, every category with amount and share, spending calendar (tap a day for its entries)
  - Activity tab (replaces History): month switcher, All/Spent/Received, category filter, grouped by day with day totals
  - + button opens one Add sheet (Expense/Income switch); the separate Add screens are gone
  - Settings screen holds balance, categories, auto-capture, backup and theme (the 4 top-bar icons are gone)
  - Category emoji drawn as consistent Material icons on tinted circles; all sheets and secondary screens restyled
- [x] **2026-10-03** **Category icons**: ~110 meaningful icons in groups (Food, Groceries, Transport, Travel, Bills, Shopping, Health, Fun, Learning, Money, Life), or any emoji typed by the user. New defaults: Food 🍴, Groceries 🛒 (added), Transport (commute), Travel (luggage), Health (medical kit), Other (⋯). The editor opens at the current icon. Data v8 converts existing symbols on upgrade and when restoring older backups
- [x] **2026-10-05** **Home-screen widgets** (Settings → Home-screen widgets has an Add button for each):
  - **Label payments**: the next unlabelled payment with its two suggested categories (tap = saved) and More (the same card as the notification's More, with Split); "1/3 ›" steps through all waiting; "✓ All payments labelled" when done
  - **This month so far**: spent, pace chart vs last month with an amount scale (₹0 / half / a round top like ₹10K, with faint gridlines) and dates (1 Oct · 16 · 31 Oct), the comparison sentence; tap = Insights
  - **Where it went**: share bar plus categories with amount and %, as many rows as fit (the rest folded into "N more"); tap = Insights
  - **Quick add**: opens the + sheet over the home screen
  - Compact: all four fit on one screen with room for a row of apps (Label 3×1 next to Quick add, a small "+" tile; This month and Where it went 2×2 side by side). On a 2-column-wide Where it went the % column hides so names and amounts stay readable
  - Material You colors (follow the wallpaper on Android 12+), light and dark; refreshed whenever anything changes, and every few hours for a new day/month
- [x] **2026-10-05** **Split one payment across categories** (DMart ₹3,000 = groceries + snacks + toys): "Split across categories" in the What-was-this card (also behind the notification's More), on any expense's edit screen, and in the + sheet. Tap the categories; the first one takes whatever is left, so only the smaller parts are typed; Save only when it adds up. Each part can have a note. Activity/Home show one row with a proportion bar; Insights counts each part in its category; a category filter counts only that part; the balance moves once. Unsplit and Delete work on the whole payment (with Undo). Data v10 (`split_id`). The old "these were 2 payments" button is now called "Separate"
- [x] **2026-10-05** **Payment details on each captured entry**: transaction ID and UPI ID (with copy buttons), account, which app it was seen in (and how many alerts), capture time, and every original message. When two alerts merge into one payment, the second message is now kept too (it used to be dropped), which also helps check duplicates like the second tester's ₹250
- [x] **2026-10-05** **Payee separate from note**: entries have their own "Paid to" / "Received from" field, so a note no longer replaces who was paid. Lists show the payee as the title and the note underneath. Data v9 puts the payee back on existing captured entries (from the original capture) and keeps any note the user typed; older backups are converted on restore. Tested on the emulator by reproducing the bug in 1.4.0, then upgrading
- [x] **2026-10-03** Behind the scenes: database upgrade steps are safe to re-run; the app test works again (179 tests); duplicated code merged (one category sheet, one chip, one edit sheet, one Manage tab); Home and Add screens split into small parts

## Version log

| Version | Date | Notes |
|---|---|---|
| 1.8.0+13 | 2026-10-06 | Budgets with alerts; Label widget answers at once |
| 1.7.0+12 | 2026-10-05 | Home-screen widgets (compact sizes, chart axis), order-receipt email fix. Installed on the phone over USB; the daily-use version for now |
| 1.6.0+11 | 2026-10-05 | Split payments across categories, DB v10; includes 1.5.0 (not yet installed) |
| 1.5.0+10 | 2026-10-05 | Payee separate from note (DB v9); payment details (transaction/UPI ID, original messages) (not yet installed) |
| 1.4.0+8 | 2026-10-03 | Material You redesign: Home/Activity/Insights/Settings, Roboto Flex; icon catalog + custom emoji, DB v8 (not yet installed) |
| 1.3.0+6 | 2026-10-03 | No auto-filing; per-shop suggestions; More card (committed a8734db; never installed) |
| 1.2.0+5 | 2026-10-03 | Bank balance replaces automatic salary; bug fixes; code cleanup (committed a8cc636; never installed) |
| 1.1.0+4 | 2026-10-03 | Payment auto-capture via notifications, DB v7 (committed d6c6c81; never installed) |
| 1.0.2+3 | 2026-10-03 | Backup & Restore, undo on delete (never installed; superseded) |
| 1.0.1+2 | 2026-10-03 | Permanent signing key, PaiPai name and logo (never installed; superseded) |
| 1.0.0+1 | 2026-06-09 | Last debug-key build; SMS auto-tracking WIP |
