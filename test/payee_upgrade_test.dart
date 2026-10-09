import 'package:expense_tracker/models/payee_upgrade.dart';
import 'package:expense_tracker/services/backup/backup_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final captures = [
    {'created_expense_id': 1, 'merchant': 'Blinkit'},
    {'created_expense_id': 2, 'merchant': 'Swiggy'},
    {'created_expense_id': null, 'merchant': 'Ignored'},
  ];

  List<Map<String, Object?>> move(List<Map<String, Object?>> entries) =>
      movePayeesOutOfNotes(entries, captures, linkColumn: 'created_expense_id');

  test('a captured payee moves out of notes', () {
    final moved = move([{'id': 1, 'notes': 'Blinkit', 'payee': null}]);
    expect(moved.single['payee'], 'Blinkit');
    expect(moved.single['notes'], isNull);
  });

  test('a note the user typed over the payee is kept, and the payee comes back', () {
    final moved = move([{'id': 2, 'notes': 'Dinner with Riya', 'payee': null}]);
    expect(moved.single['payee'], 'Swiggy');
    expect(moved.single['notes'], 'Dinner with Riya');
  });

  test('manual entries and entries that already have a payee are untouched', () {
    final manual = {'id': 9, 'notes': 'Auto fare', 'payee': null};
    final done = {'id': 1, 'notes': 'x', 'payee': 'Blinkit'};
    final moved = move([manual, done]);
    expect(identical(moved[0], manual), isTrue);
    expect(identical(moved[1], done), isTrue);
  });

  test('restoring an older backup moves payees too', () {
    final text = BackupFile(schemaVersion: 8, createdAt: DateTime(2026, 10, 1), tables: {
      'expenses': [
        {'id': 1, 'amount': 120.0, 'category': 'Groceries', 'date': '2026-10-01T09:00:00.000', 'notes': 'Blinkit'},
      ],
      'income': [],
      'pending_transactions': captures,
    }).encode();
    final restored = BackupFile.decode(text,
        currentSchemaVersion: 9, requiredTables: ['expenses', 'income', 'pending_transactions']);
    expect(restored.tables['expenses']!.single['payee'], 'Blinkit');
    expect(restored.tables['expenses']!.single['notes'], isNull);
  });
}
