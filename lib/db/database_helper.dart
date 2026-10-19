import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/category.dart';
import '../models/category_symbol.dart';
import '../models/payee_upgrade.dart';
import '../models/split_part.dart';
import '../utils/money.dart';
import '../models/pending_transaction.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// Bump on every schema change (and teach BackupFile how to read older backups).
  static const schemaVersion = 11;

  /// Every table, included in backups and replaced on restore.
  static const backupTables = [
    'categories',
    'income_sources',
    'expenses',
    'income',
    'salary_history',
    'settings',
    'merchant_mappings', // unused since 1.3.0; kept so older backups restore
    'pending_transactions',
    'processed_sms_hashes',
    'budgets', // v11; older backups have none (BackupFile.addedIn)
  ];

  /// Tests point this at their own file so test files can run in parallel.
  @visibleForTesting
  static String fileName = 'expenses.db';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            payee TEXT,
            split_id INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            emoji TEXT NOT NULL,
            color INTEGER NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE income(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            source TEXT NOT NULL,
            date TEXT NOT NULL,
            notes TEXT,
            payee TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE income_sources(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            emoji TEXT NOT NULL,
            color INTEGER NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE salary_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            effective_from TEXT NOT NULL UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            type TEXT NOT NULL,
            merchant TEXT,
            upi_ref TEXT,
            account_tail TEXT,
            category TEXT,
            source TEXT,
            raw_message TEXT NOT NULL,
            sender TEXT NOT NULL,
            confidence INTEGER NOT NULL,
            detected_at TEXT NOT NULL,
            is_processed INTEGER NOT NULL DEFAULT 0,
            created_expense_id INTEGER,
            created_income_id INTEGER,
            source_app TEXT,
            seen_count INTEGER NOT NULL DEFAULT 1,
            maybe_multiple INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE merchant_mappings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant_normalized TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL,
            use_count INTEGER NOT NULL DEFAULT 1,
            last_used TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE processed_sms_hashes(
            hash TEXT PRIMARY KEY,
            processed_at TEXT NOT NULL
          )
        ''');
        await db.execute(_budgetsTable);
        await _seedCategories(db);
        await _seedIncomeSources(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              emoji TEXT NOT NULL,
              color INTEGER NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await _seedCategories(db);
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS income(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              source TEXT NOT NULL,
              date TEXT NOT NULL,
              notes TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS income_sources(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              emoji TEXT NOT NULL,
              color INTEGER NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await _seedIncomeSources(db);
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS salary_history(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              effective_from TEXT NOT NULL UNIQUE
            )
          ''');
          // Salary history is kept for old backups but no longer used: income
          // is now captured as it arrives (no copying of old salary, which
          // used to backdate it to 2020).
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              type TEXT NOT NULL,
              merchant TEXT,
              upi_ref TEXT,
              account_tail TEXT,
              category TEXT,
              source TEXT,
              raw_message TEXT NOT NULL,
              sender TEXT NOT NULL,
              confidence INTEGER NOT NULL,
              detected_at TEXT NOT NULL,
              is_processed INTEGER NOT NULL DEFAULT 0,
              created_expense_id INTEGER,
              created_income_id INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS merchant_mappings(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              merchant_normalized TEXT NOT NULL UNIQUE,
              category TEXT NOT NULL,
              use_count INTEGER NOT NULL DEFAULT 1,
              last_used TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS processed_sms_hashes(
              hash TEXT PRIMARY KEY,
              processed_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 7) {
          // Notification capture: merge info for the same payment seen in several alerts.
          await _addColumnIfMissing(db, 'pending_transactions', 'source_app', 'TEXT');
          await _addColumnIfMissing(
              db, 'pending_transactions', 'seen_count', 'INTEGER NOT NULL DEFAULT 1');
          await _addColumnIfMissing(
              db, 'pending_transactions', 'maybe_multiple', 'INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 8) {
          // Symbols become `icon:` names (or a typed emoji); adds Groceries.
          await _upgradeSymbols(db, 'categories', defaultCategoryData);
          await _upgradeSymbols(db, 'income_sources', defaultIncomeSourceData);
          await _seedCategories(db);
        }
        if (oldVersion < 9) {
          // Payee gets its own column instead of living in notes.
          await _addColumnIfMissing(db, 'expenses', 'payee', 'TEXT');
          await _addColumnIfMissing(db, 'income', 'payee', 'TEXT');
          await _movePayees(db, 'expenses', 'created_expense_id');
          await _movePayees(db, 'income', 'created_income_id');
        }
        if (oldVersion < 10) {
          // Split payments: every part points at its first part.
          await _addColumnIfMissing(db, 'expenses', 'split_id', 'INTEGER');
        }
        if (oldVersion < 11) {
          await db.execute(_budgetsTable);
        }
      },
    );
  }

  /// Budgets: '' is the monthly (overall) budget, otherwise a category
  /// name. Each row applies from its month on; a NULL amount removes it.
  static const _budgetsTable = '''
          CREATE TABLE IF NOT EXISTS budgets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            amount REAL,
            from_month TEXT NOT NULL,
            UNIQUE(category, from_month)
          )
  ''';

  /// Safe to re-run: entries that already have a payee are left alone.
  static Future<void> _movePayees(Database db, String table, String linkColumn) async {
    final entries = await db.query(table, columns: ['id', 'notes', 'payee']);
    final captures = await db.query('pending_transactions', columns: [linkColumn, 'merchant']);
    final moved = movePayeesOutOfNotes(entries, captures, linkColumn: linkColumn);
    for (var i = 0; i < moved.length; i++) {
      if (identical(moved[i], entries[i])) continue;
      await db.update(table, {'payee': moved[i]['payee'], 'notes': moved[i]['notes']},
          where: 'id = ?', whereArgs: [moved[i]['id']]);
    }
  }

  /// Safe to re-run: upgraded symbols are no longer legacy emoji.
  static Future<void> _upgradeSymbols(
      Database db, String table, List<Map<String, dynamic>> defaults) async {
    final rows = await db.query(table, columns: ['id', 'name', 'emoji']);
    for (final row in upgradeSymbolRows(rows, defaults)) {
      await db.update(table, {'emoji': row['emoji']}, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  /// Lets an upgrade step run again safely (e.g. after a failed attempt).
  static Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((c) => c['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _seedCategories(Database db) async {
    for (final cat in defaultCategoryData) {
      await db.insert(
        'categories',
        {'name': cat['name'], 'emoji': cat['emoji'], 'color': cat['color'], 'is_default': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _seedIncomeSources(Database db) async {
    for (final src in defaultIncomeSourceData) {
      await db.insert(
        'income_sources',
        {'name': src['name'], 'emoji': src['emoji'], 'color': src['color'], 'is_default': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // --- Expenses ---

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final maps = await db.query('expenses', orderBy: 'date DESC');
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return db.update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // --- Categories ---

  Future<int> insertCategory(ExpenseCategory category) async {
    final db = await database;
    return db.insert('categories', category.toMap());
  }

  Future<List<ExpenseCategory>> getAllCategories() async {
    final db = await database;
    final maps =
        await db.query('categories', orderBy: 'is_default DESC, name ASC');
    return maps.map((map) => ExpenseCategory.fromMap(map)).toList();
  }

  Future<void> updateCategory(
      ExpenseCategory category, String oldName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('categories', category.toMap(),
          where: 'id = ?', whereArgs: [category.id]);
      if (category.name != oldName) {
        await _moveExpenses(txn, oldName, category.name);
        await txn.update('budgets', {'category': category.name},
            where: 'category = ?', whereArgs: [oldName]);
      }
    });
  }

  /// Deletes a custom category, moving its expenses to [moveTo] so nothing is left pointing at a missing category.
  Future<void> deleteCategoryMovingTo(ExpenseCategory category, String moveTo) async {
    final db = await database;
    await db.transaction((txn) async {
      await _moveExpenses(txn, category.name, moveTo);
      await txn.delete('budgets', where: 'category = ?', whereArgs: [category.name]);
      await txn.delete('categories',
          where: 'id = ? AND is_default = 0', whereArgs: [category.id]);
    });
  }

  static Future<void> _moveExpenses(Transaction txn, String from, String to) async {
    await txn.update('expenses', {'category': to},
        where: 'category = ?', whereArgs: [from]);
  }

  Future<int> countExpensesIn(String category) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM expenses WHERE category = ?', [category]);
    return rows.first['n'] as int;
  }


  // --- Income ---

  Future<int> insertIncome(Income income) async {
    final db = await database;
    return db.insert('income', income.toMap());
  }

  Future<List<Income>> getAllIncome() async {
    final db = await database;
    final maps = await db.query('income', orderBy: 'date DESC');
    return maps.map((map) => Income.fromMap(map)).toList();
  }

  Future<int> updateIncome(Income income) async {
    final db = await database;
    return db.update('income', income.toMap(),
        where: 'id = ?', whereArgs: [income.id]);
  }

  Future<int> deleteIncome(int id) async {
    final db = await database;
    return db.delete('income', where: 'id = ?', whereArgs: [id]);
  }

  // --- Income Sources ---

  Future<int> insertIncomeSource(ExpenseCategory source) async {
    final db = await database;
    return db.insert('income_sources', source.toMap());
  }

  Future<List<ExpenseCategory>> getAllIncomeSources() async {
    final db = await database;
    final maps = await db.query('income_sources',
        orderBy: 'is_default DESC, name ASC');
    return maps.map((map) => ExpenseCategory.fromMap(map)).toList();
  }

  Future<void> updateIncomeSource(
      ExpenseCategory source, String oldName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('income_sources', source.toMap(),
          where: 'id = ?', whereArgs: [source.id]);
      if (source.name != oldName) {
        await _moveIncome(txn, oldName, source.name);
      }
    });
  }

  /// Deletes a custom income source, moving its entries and learned payers
  /// to [moveTo].
  Future<void> deleteIncomeSourceMovingTo(ExpenseCategory source, String moveTo) async {
    final db = await database;
    await db.transaction((txn) async {
      await _moveIncome(txn, source.name, moveTo);
      await txn.delete('income_sources',
          where: 'id = ? AND is_default = 0', whereArgs: [source.id]);
    });
  }

  static Future<void> _moveIncome(Transaction txn, String from, String to) async {
    await txn.update('income', {'source': to},
        where: 'source = ?', whereArgs: [from]);
  }

  Future<int> countIncomeFrom(String source) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM income WHERE source = ?', [source]);
    return rows.first['n'] as int;
  }


  /// 0 for an empty table.
  Future<int> maxId(String table) async {
    final db = await database;
    final rows = await db.rawQuery('SELECT MAX(id) AS id FROM $table');
    return rows.first['id'] as int? ?? 0;
  }

  // --- Budgets ---

  Future<List<Budget>> getBudgets() async {
    final db = await database;
    final rows = await db.query('budgets', orderBy: 'from_month ASC');
    return rows.map(Budget.fromMap).toList();
  }

  /// Sets (or with a null [amount], removes) a budget from [month] on.
  /// Earlier months keep the amount they had.
  Future<void> setBudget(String category, double? amount, DateTime month) async {
    final db = await database;
    await db.insert(
      'budgets',
      {'category': category, 'amount': amount == null ? null : roundMoney(amount), 'from_month': Budget.monthKey(month)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Settings ---

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Pending Transactions ---

  Future<int> insertPendingTransaction(PendingTransaction tx) async {
    final db = await database;
    return db.insert('pending_transactions', tx.toMap());
  }

  Future<List<PendingTransaction>> getAllPendingTransactions(
      {bool unprocessedOnly = true}) async {
    final db = await database;
    final maps = await db.query(
      'pending_transactions',
      where: unprocessedOnly ? 'is_processed = 0' : null,
      orderBy: 'detected_at DESC',
    );
    return maps.map((m) => PendingTransaction.fromMap(m)).toList();
  }

  Future<void> markTransactionProcessed(int id,
      {int? expenseId, int? incomeId}) async {
    final db = await database;
    await db.update(
      'pending_transactions',
      {
        'is_processed': 1,
        'created_expense_id': expenseId,
        'created_income_id': incomeId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Entries saved from captured payments that happened before [moment].
  Future<({Set<int> expenseIds, Set<int> incomeIds})> entriesCapturedBefore(DateTime moment) async {
    final db = await database;
    final rows = await db.query('pending_transactions',
        columns: ['created_expense_id', 'created_income_id'],
        where: 'is_processed = 1 AND detected_at < ?',
        whereArgs: [moment.toIso8601String()]);
    return (
      expenseIds: {for (final row in rows) if (row['created_expense_id'] != null) row['created_expense_id'] as int},
      incomeIds: {for (final row in rows) if (row['created_income_id'] != null) row['created_income_id'] as int},
    );
  }

  /// Saves a captured payment's entry and marks the payment handled in one
  /// transaction. False if it was already handled: two taps (or the More card
  /// and the capture engine) can race, and only the first may save.
  Future<bool> saveCapturedEntry(int pendingId, {Expense? expense, Income? income}) async {
    final db = await database;
    return db.transaction((txn) async {
      if (!await _claimPending(txn, pendingId)) return false;
      final expenseId = expense == null ? null : await txn.insert('expenses', expense.toMap());
      final incomeId = income == null ? null : await txn.insert('income', income.toMap());
      await _linkPending(txn, pendingId, expenseId: expenseId, incomeId: incomeId);
      return true;
    });
  }

  /// [saveSplit] for a captured payment, claimed like [saveCapturedEntry].
  Future<bool> saveCapturedSplit(int pendingId, Expense payment, List<SplitPart> parts) async {
    final db = await database;
    return db.transaction((txn) async {
      if (!await _claimPending(txn, pendingId)) return false;
      final leadId = await txn.insert('expenses', _partRow(payment, parts.first, null));
      await txn.update('expenses', {'split_id': leadId}, where: 'id = ?', whereArgs: [leadId]);
      for (final part in parts.skip(1)) {
        await txn.insert('expenses', _partRow(payment, part, leadId));
      }
      await _linkPending(txn, pendingId, expenseId: leadId);
      return true;
    });
  }

  static Future<bool> _claimPending(Transaction txn, int pendingId) async =>
      await txn.update('pending_transactions', {'is_processed': 1},
          where: 'id = ? AND is_processed = 0', whereArgs: [pendingId]) ==
      1;

  static Future<void> _linkPending(Transaction txn, int pendingId, {int? expenseId, int? incomeId}) =>
      txn.update('pending_transactions', {'created_expense_id': expenseId, 'created_income_id': incomeId},
          where: 'id = ?', whereArgs: [pendingId]);

  Future<int> deletePendingTransaction(int id) async {
    final db = await database;
    return db.delete('pending_transactions',
        where: 'id = ?', whereArgs: [id]);
  }

  /// Category (or income source) of every captured payment that was saved,
  /// with its payee, newest first. Read from the saved entry, so later edits
  /// in History count too.
  Future<List<({String merchant, String category})>> capturedChoices(
      {required bool income}) async {
    final db = await database;
    final table = income ? 'income' : 'expenses';
    final column = income ? 'source' : 'category';
    final link = income ? 'created_income_id' : 'created_expense_id';
    final rows = await db.rawQuery(
      'SELECT p.merchant AS merchant, t.$column AS category '
      // A split payment's parts all count (they share the first part's id).
      'FROM pending_transactions p JOIN $table t ON t.id = p.$link'
      '${income ? '' : ' OR t.split_id = p.$link'} '
      'WHERE p.merchant IS NOT NULL ORDER BY p.detected_at DESC',
    );
    return [
      for (final row in rows)
        (merchant: row['merchant'] as String, category: row['category'] as String),
    ];
  }

  // --- SMS Dedup ---

  Future<bool> isSmsProcessed(String hash) async {
    final db = await database;
    final maps = await db.query('processed_sms_hashes',
        where: 'hash = ?', whereArgs: [hash]);
    return maps.isNotEmpty;
  }

  Future<void> markSmsProcessed(String hash) async {
    final db = await database;
    await db.insert(
      'processed_sms_hashes',
      {'hash': hash, 'processed_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> pruneProcessedHashes(DateTime olderThan) async {
    final db = await database;
    await db.delete('processed_sms_hashes',
        where: 'processed_at < ?', whereArgs: [olderThan.toIso8601String()]);
  }

  // --- Payment capture ---

  Future<PendingTransaction?> getPendingTransaction(int id) async {
    final db = await database;
    final maps = await db.query('pending_transactions',
        where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : PendingTransaction.fromMap(maps.first);
  }

  /// Captures (handled or not) detected between [from] and [until]; used to
  /// merge alerts for the same payment that arrive through different apps.
  /// Bounded on both sides so importing old SMS stays fast.
  Future<List<PendingTransaction>> getCapturesBetween(DateTime from, DateTime until) async {
    final db = await database;
    final maps = await db.query('pending_transactions',
        where: 'detected_at >= ? AND detected_at <= ?',
        whereArgs: [from.toIso8601String(), until.toIso8601String()],
        orderBy: 'detected_at DESC');
    return maps.map(PendingTransaction.fromMap).toList();
  }

  // --- Split payments ---

  /// Saves [parts] as one split payment with [payment]'s date and payee.
  /// Splitting an existing payment keeps its id for the first part (so a
  /// captured payment stays linked) and replaces any earlier parts.
  /// Returns the first part's id, which every part stores as `split_id`.
  Future<int> saveSplit(Expense payment, List<SplitPart> parts) async {
    final db = await database;
    return db.transaction((txn) async {
      final leadId = payment.id ?? await txn.insert('expenses', _partRow(payment, parts.first, null));
      await txn.delete('expenses', where: 'split_id = ? AND id != ?', whereArgs: [leadId, leadId]);
      await txn.update('expenses', _partRow(payment, parts.first, leadId),
          where: 'id = ?', whereArgs: [leadId]);
      for (final part in parts.skip(1)) {
        await txn.insert('expenses', _partRow(payment, part, leadId));
      }
      return leadId;
    });
  }

  static Map<String, Object?> _partRow(Expense payment, SplitPart part, int? splitId) => Expense(
        amount: part.amount,
        category: part.category,
        date: payment.date,
        payee: payment.payee,
        notes: part.note,
        splitId: splitId,
      ).toMap()
        ..remove('id');

  /// Every part of a split, first part first.
  Future<List<Expense>> getSplitParts(int splitId) async {
    final db = await database;
    final maps = await db.query('expenses', where: 'split_id = ?', whereArgs: [splitId], orderBy: 'id');
    return maps.map(Expense.fromMap).toList();
  }

  /// Back to one payment: the first part takes the whole amount.
  Future<void> unsplit(int splitId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('expenses', columns: ['amount'], where: 'split_id = ?', whereArgs: [splitId]);
      final total = sumMoney(rows.map((r) => (r['amount'] as num).toDouble()));
      await txn.delete('expenses', where: 'split_id = ? AND id != ?', whereArgs: [splitId, splitId]);
      await txn.update('expenses', {'amount': total, 'split_id': null}, where: 'id = ?', whereArgs: [splitId]);
    });
  }

  /// Deletes every part; returns them so Undo can put them back.
  Future<List<Expense>> deleteSplit(int splitId) async {
    final parts = await getSplitParts(splitId);
    final db = await database;
    await db.delete('expenses', where: 'split_id = ?', whereArgs: [splitId]);
    return parts;
  }

  /// The captured payment an entry was saved from, if any.
  Future<PendingTransaction?> getCaptureFor({int? expenseId, int? incomeId}) async {
    final db = await database;
    final column = expenseId != null ? 'created_expense_id' : 'created_income_id';
    final maps = await db.query('pending_transactions',
        where: '$column = ?', whereArgs: [expenseId ?? incomeId], limit: 1);
    return maps.isEmpty ? null : PendingTransaction.fromMap(maps.first);
  }

  Future<void> updatePendingTransaction(PendingTransaction tx) async {
    final db = await database;
    await db.update('pending_transactions', tx.toMap(),
        where: 'id = ?', whereArgs: [tx.id]);
  }

  /// Most-used expense categories (or income sources) since [since].
  Future<List<String>> topCategoryNames(
      {required bool income, required DateTime since, int limit = 2}) async {
    final db = await database;
    final table = income ? 'income' : 'expenses';
    final column = income ? 'source' : 'category';
    final rows = await db.rawQuery(
      'SELECT $column AS name, COUNT(*) AS uses FROM $table '
      'WHERE date >= ? GROUP BY $column ORDER BY uses DESC LIMIT ?',
      [since.toIso8601String(), limit],
    );
    return [for (final row in rows) row['name'] as String];
  }

  // --- Backup / Restore ---

  Future<Map<String, List<Map<String, Object?>>>> dumpTables() async {
    final db = await database;
    return {for (final table in backupTables) table: await db.query(table)};
  }

  /// Replaces all rows of every table in one transaction: any failure
  /// rolls back, so the existing data is never left half-replaced.
  Future<void> replaceAllTables(
      Map<String, List<Map<String, Object?>>> tables) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in backupTables) {
        await txn.delete(table);
        final batch = txn.batch();
        for (final row in tables[table] ?? const []) {
          batch.insert(table, row);
        }
        await batch.commit(noResult: true);
      }
    });
  }
}
