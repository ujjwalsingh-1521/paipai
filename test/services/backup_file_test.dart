import 'dart:convert';

import 'package:expense_tracker/services/backup/backup_file.dart';
import 'package:flutter_test/flutter_test.dart';

const _tables = ['expenses', 'settings'];

BackupFile _sample() => BackupFile(
      schemaVersion: 6,
      createdAt: DateTime(2026, 10, 3, 14, 30),
      tables: {
        'expenses': [
          {'id': 1, 'amount': 250.5, 'category': 'Food', 'date': '2026-10-01T00:00:00.000', 'notes': null},
          {'id': 7, 'amount': 99.0, 'category': 'Transport', 'date': '2026-10-02T00:00:00.000', 'notes': 'auto'},
        ],
        'settings': [
          {'key': 'theme_mode', 'value': 'dark'},
        ],
      },
    );

BackupFile _decode(String text) =>
    BackupFile.decode(text, currentSchemaVersion: 9, requiredTables: _tables);

Matcher _rejectedWith(String fragment) => throwsA(isA<BackupException>()
    .having((e) => e.message, 'message', contains(fragment)));

String _sampleJsonWith(void Function(Map<String, dynamic> json) change) {
  final json = jsonDecode(_sample().encode()) as Map<String, dynamic>;
  change(json);
  return jsonEncode(json);
}

void main() {
  group('BackupFile round trip', () {
    test('keeps every row, id and the creation time', () {
      final restored = _decode(_sample().encode());

      expect(restored.createdAt, DateTime(2026, 10, 3, 14, 30));
      expect(restored.tables, _sample().tables);
      expect(restored.countOf('expenses'), 2);
      expect(restored.countOf('unknown'), 0);
    });

    test('restores a backup from the previous data version', () {
      // _sample() is v6; this app is v7 and only added columns since.
      expect(_decode(_sample().encode()).schemaVersion, 6);
    });

    test('accepts an empty table', () {
      final text = _sampleJsonWith((json) => json['tables']['settings'] = []);
      expect(_decode(text).countOf('settings'), 0);
    });
  });

  group('BackupFile rejects', () {
    test('text that is not JSON', () {
      expect(() => _decode('hello'), _rejectedWith('damaged'));
    });

    test('JSON that is not an object', () {
      expect(() => _decode('[1, 2]'), _rejectedWith('damaged'));
    });

    test('a file from another app', () {
      final text = _sampleJsonWith((json) => json['format'] = 'other-app');
      expect(() => _decode(text), _rejectedWith('not a PaiPai backup'));
    });

    test('a backup from a newer app version', () {
      final text = _sampleJsonWith((json) => json['schemaVersion'] = 10);
      expect(() => _decode(text), _rejectedWith('newer app version'));
    });

    test('a table added later (budgets, v11) may be missing from an older backup', () {
      final old = BackupFile.decode(_sample().encode(),
          currentSchemaVersion: 11, requiredTables: [..._tables, 'budgets']);
      expect(old.tables['budgets'], isEmpty);
      final newer = _sampleJsonWith((json) => json['schemaVersion'] = 11);
      expect(() => BackupFile.decode(newer, currentSchemaVersion: 11, requiredTables: [..._tables, 'budgets']),
          _rejectedWith('missing "budgets"'));
    });

    test('a backup older than the oldest supported version', () {
      final text = _sampleJsonWith((json) => json['schemaVersion'] = 5);
      expect(() => _decode(text), _rejectedWith('too old'));
    });

    test('a missing table', () {
      final text = _sampleJsonWith((json) => json['tables'].remove('settings'));
      expect(() => _decode(text), _rejectedWith('missing "settings"'));
    });

    test('rows that are not objects', () {
      final text = _sampleJsonWith((json) => json['tables']['expenses'] = [1]);
      expect(() => _decode(text), _rejectedWith('missing "expenses"'));
    });

    test('a missing date', () {
      final text = _sampleJsonWith((json) => json.remove('createdAt'));
      expect(() => _decode(text), _rejectedWith('date'));
    });
  });

  group('BackupNames', () {
    test('daily names sort oldest to newest, so pruning keeps the newest', () {
      final names = [
        BackupNames.daily(DateTime(2026, 12, 1)),
        BackupNames.daily(DateTime(2026, 9, 30)),
        BackupNames.daily(DateTime(2027, 1, 2)),
      ]..sort();

      expect(names, [
        'paipai-auto-2026-09-30.json',
        'paipai-auto-2026-12-01.json',
        'paipai-auto-2027-01-02.json',
      ]);
    });

    test('daily names share the prefix used for pruning', () {
      expect(BackupNames.daily(DateTime(2026, 10, 3)),
          startsWith(BackupNames.dailyPrefix));
      expect(BackupNames.manual(DateTime(2026, 10, 3, 9, 5)),
          'paipai-backup-2026-10-03_0905.json');
    });
  });

  group('category symbols (data v8)', () {
    String backupWith(int schema, List<Map<String, Object?>> categories, List<Map<String, Object?>> sources) =>
        BackupFile(
          schemaVersion: schema,
          createdAt: DateTime(2026, 9, 1),
          tables: {'expenses': [], 'settings': [], 'categories': categories, 'income_sources': sources},
        ).encode();

    BackupFile decodeAll(String text) => BackupFile.decode(text,
        currentSchemaVersion: 9, requiredTables: ['expenses', 'settings', 'categories', 'income_sources']);

    test('older backups get icon symbols; defaults get their new icon', () {
      final restored = decodeAll(backupWith(7, [
        {'id': 1, 'name': 'Food', 'emoji': '🍔', 'color': 1, 'is_default': 1},
        {'id': 2, 'name': 'Gym', 'emoji': '💪', 'color': 2, 'is_default': 0},
        {'id': 3, 'name': 'Groceries', 'emoji': '🍔', 'color': 3, 'is_default': 1},
      ], [
        {'id': 1, 'name': 'Other', 'emoji': '✨', 'color': 4, 'is_default': 1},
      ]));
      expect(restored.tables['categories']!.map((r) => r['emoji']),
          ['icon:restaurant', 'icon:fitness_center', 'icon:local_grocery_store']);
      expect(restored.tables['categories']![1]['color'], 2);
      expect(restored.tables['income_sources']!.single['emoji'], 'icon:more_horiz');
    });

    test('emoji chosen in a current backup stay emoji', () {
      final restored = decodeAll(backupWith(8, [
        {'id': 2, 'name': 'Snacks', 'emoji': '🍔', 'color': 2, 'is_default': 0},
      ], []));
      expect(restored.tables['categories']!.single['emoji'], '🍔');
    });
  });
}
