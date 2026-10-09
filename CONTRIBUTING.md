# Contributing to PaiPai

Thanks for helping. PaiPai is maintained by one person, so a little process keeps things moving.

## Reporting a missed or misread payment

This is the most useful contribution. [Open a "Missed payment" issue](../../issues/new/choose) with:

- the bank or app (and whether it came as an SMS, app notification or email),
- the message text, **with personal details changed**: account digits, your name, people's names, UPI IDs and reference numbers. Keep the shape (`XX1234`, a 12-digit ref) so the parser sees the same format,
- what PaiPai did (nothing, wrong amount, wrong shop, counted twice…).

## Pull requests

1. **Open an issue first** for anything bigger than a small fix, so we can agree on the approach before you spend time on it.
2. Fork the repo and create a branch from `main`.
3. Keep the change focused: one fix or feature per pull request.
4. Run these before pushing; CI runs them on every pull request and it must pass:
   ```bash
   flutter analyze
   flutter test
   ```
5. If you change parsing, add the message to `test/services/capture/payment_samples.dart` (anonymised) with what it should produce.
6. Update `progress.md` if your change finishes or adds a roadmap item.

All changes reach `main` only through a pull request reviewed and merged by the maintainer.

## Rules the code follows

The full list is in [`CLAUDE.md`](CLAUDE.md). The important ones:

- **Never file a payment without the user choosing.** Suggestions may be ordered by past choices, nothing more.
- **No network access.** Don't add the internet permission or any analytics, tracking or remote service.
- **Never lose user data.** Database changes bump the schema version with an idempotent migration, and old backup files must keep restoring.
- **Never change the application ID** (`com.expense.expense_tracker`); installed apps couldn't update.
- Amounts are shown only through `formatMoney`; colors, spacing and corners come from the theme (`lib/theme/app_theme.dart`).

## License

By contributing, you agree that your contribution is licensed under the [GPL-3.0](LICENSE), like the rest of the project.
