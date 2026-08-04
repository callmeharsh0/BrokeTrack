import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'expense_model.dart'; // Make sure this file exists

class DatabaseHelper {
  // --- Singleton Pattern ---
  // This ensures we only have one instance of this database helper.
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // --- Initialize Database ---
  // This opens the database (or creates it if it doesn't exist).
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'expense_tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate, // Runs this function when the DB is first created
    );
  }

  // --- Create Table (The "Blueprint") ---
  // This SQL command runs ONLY when the app is first installed.
  // This is the final, correct schema with all our columns.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      date INTEGER NOT NULL,
      category TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'debit',
      bankName TEXT NOT NULL DEFAULT 'Unknown'
    )
    ''');
  }

  // --- Insert an Expense ---
  // This function adds a new expense to the table.
  // It includes the CRITICAL duplicate-checking logic.
  Future<bool> insertExpense(Expense expense) async {
    final db = await instance.database;

    // Check if this exact transaction (based on title, amount, and date)
    // already exists in the database. This prevents duplicates.
    var existing = await db.query(
      'expenses',
      where: 'title = ? AND amount = ? AND date = ?',
      whereArgs: [
        expense.title,
        expense.amount,
        expense.date.millisecondsSinceEpoch,
      ],
    );

    // If no existing record is found, insert the new one
    if (existing.isEmpty) {
      await db.insert('expenses', expense.toMap());
      print('DatabaseHelper: Inserted new expense: ${expense.title}');
      return true; // Indicates a new expense was added
    } else {
      print(
        'DatabaseHelper: Duplicate expense found, skipping: ${expense.title}',
      );
      return false; // Indicates a duplicate was found
    }
  }

  // --- Get All Expenses ---
  // This fetches all expenses from the database.
  // It sorts them by date, with the newest expenses first.
  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      orderBy: 'date DESC', // Newest expenses first
    );

    return result.map((map) => Expense.fromMap(map)).toList();
  }

  // --- (Optional) Update an Expense ---
  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // --- (Optional) Delete an Expense ---
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // --- Delete All Expenses ---
  Future<int> deleteAllExpenses() async {
    final db = await instance.database;
    return await db.delete('expenses');
  }
}
