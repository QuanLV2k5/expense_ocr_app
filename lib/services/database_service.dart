import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Future<Database>? _database;

  Future<Database> get database async {
    final pending = _database ??= _initDatabase();
    try {
      return await pending;
    } catch (_) {
      if (identical(_database, pending)) {
        _database = null;
      }
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final dbPath = p.join(databasePath, 'expense_ocr.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant TEXT NOT NULL,
        amount INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        category TEXT NOT NULL,
        receipt_image_path TEXT,
        raw_ocr_text TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migration sẽ được thêm khi database thay đổi version.
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;

    return db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Expense>> getExpenses() async {
    final db = await database;

    final result = await db.query('expenses', orderBy: 'transaction_date DESC');

    return result.map((map) => Expense.fromMap(map)).toList();
  }

  Future<Expense?> getExpenseById(int id) async {
    final db = await database;

    final result = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return Expense.fromMap(result.first);
  }

  Future<int> updateExpense(Expense expense) async {
    if (expense.id == null) {
      throw ArgumentError('Không thể cập nhật Expense chưa có id.');
    }

    final db = await database;

    return db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;

    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
