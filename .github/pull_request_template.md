## What and why

<!-- What does this change, and which issue does it address? (Fixes #123) -->

## Checklist

- [ ] `flutter analyze` is clean and `flutter test` passes
- [ ] Parsing changes come with anonymised samples in `test/services/capture/payment_samples.dart`
- [ ] No personal data (real account numbers, names, UPI IDs, references) in code, tests or screenshots
- [ ] No new permissions, network access or analytics
- [ ] Database changes bump the schema with an idempotent migration, and old backups still restore
