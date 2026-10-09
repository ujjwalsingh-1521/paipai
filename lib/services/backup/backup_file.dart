import 'dart:convert';

import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/category_symbol.dart';
import '../../models/income.dart';
import '../../models/payee_upgrade.dart';

/// Thrown when a file can't be used as a backup; [message] is shown to the user.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// A full snapshot of the app's data: every table as JSON rows, plus the
/// metadata needed to validate it before restoring.
class BackupFile {
  static const format = 'paipai-backup';
  static const formatVersion = 1;

  /// Oldest data version that can be restored. Schema changes since v6
  /// only added columns with defaults, except v8 (category symbols) and v9
  /// (payee moved out of notes), which [decode] converts. A non-additive change must convert old rows there,
  /// or raise this.
  static const minSupportedSchema = 6;

  /// Tables added after [minSupportedSchema], with the data version that
  /// added them: an older backup without one restores with it empty.
  static const addedIn = {'budgets': 11};

  final int schemaVersion;
  final DateTime createdAt;
  final Map<String, List<Map<String, Object?>>> tables;

  const BackupFile({
    required this.schemaVersion,
    required this.createdAt,
    required this.tables,
  });

  int countOf(String table) => tables[table]?.length ?? 0;

  String encode() => jsonEncode({
        'format': format,
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'tables': tables,
      });

  /// Parses and validates [text]. Throws [BackupException] if it isn't a
  /// complete PaiPai backup for [currentSchemaVersion].
  static BackupFile decode(
    String text, {
    required int currentSchemaVersion,
    required List<String> requiredTables,
  }) {
    final json = _parseJsonObject(text);
    if (json['format'] != format) {
      throw const BackupException('This is not a PaiPai backup file.');
    }
    final schema = json['schemaVersion'];
    if (schema is! int || schema < minSupportedSchema) {
      throw const BackupException('This backup is too old to restore.');
    }
    if (schema > currentSchemaVersion) {
      throw BackupException('This backup is from a newer app version '
          '(data v$schema, this app uses v$currentSchemaVersion). '
          'Update PaiPai first.');
    }
    final tables = _parseTables(json['tables'], requiredTables, schema);
    if (schema < 8) _upgradeSymbols(tables);
    if (schema < 9) _movePayees(tables);
    return BackupFile(
      schemaVersion: schema,
      createdAt: _parseDate(json['createdAt']),
      tables: tables,
    );
  }

  static void _upgradeSymbols(Map<String, List<Map<String, Object?>>> tables) {
    final categories = tables['categories'];
    final sources = tables['income_sources'];
    if (categories != null) tables['categories'] = upgradeSymbolRows(categories, defaultCategoryData);
    if (sources != null) tables['income_sources'] = upgradeSymbolRows(sources, defaultIncomeSourceData);
  }

  static void _movePayees(Map<String, List<Map<String, Object?>>> tables) {
    final captures = tables['pending_transactions'] ?? const [];
    for (final (table, link) in [('expenses', 'created_expense_id'), ('income', 'created_income_id')]) {
      final rows = tables[table];
      if (rows != null) tables[table] = movePayeesOutOfNotes(rows, captures, linkColumn: link);
    }
  }

  static Map<String, dynamic> _parseJsonObject(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through to the user-facing error below.
    }
    throw const BackupException('This file is damaged or not a backup.');
  }

  static DateTime _parseDate(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null) {
      throw const BackupException('The backup is missing its date.');
    }
    return date;
  }

  static Map<String, List<Map<String, Object?>>> _parseTables(
      Object? value, List<String> requiredTables, int schema) {
    if (value is! Map) {
      throw const BackupException('The backup contains no data.');
    }
    return {
      for (final table in requiredTables)
        table: value[table] == null && schema < (addedIn[table] ?? 0) ? [] : _parseRows(value[table], table),
    };
  }

  static List<Map<String, Object?>> _parseRows(Object? rows, String table) {
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw BackupException('The backup is incomplete (missing "$table").');
    }
    return [for (final row in rows) Map<String, Object?>.from(row as Map)];
  }
}

/// File names; dates sort correctly as text, which pruning relies on.
class BackupNames {
  static const dailyPrefix = 'paipai-auto-';
  static final _day = DateFormat('yyyy-MM-dd');
  static final _minute = DateFormat('yyyy-MM-dd_HHmm');

  static String daily(DateTime at) => '$dailyPrefix${_day.format(at)}.json';
  static String manual(DateTime at) =>
      'paipai-backup-${_minute.format(at)}.json';
  static String beforeRestore(DateTime at) =>
      'paipai-before-restore-${_minute.format(at)}.json';
}
