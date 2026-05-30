import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';
import '../models/expense_model.dart';
import '../models/sponsor_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gradcash.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        university_id TEXT NOT NULL,
        department TEXT NOT NULL,
        photo_path TEXT,
        required_amount REAL NOT NULL
      )
    ''');

    // Payments table
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        recipient TEXT NOT NULL,
        item TEXT NOT NULL,
        details TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        receipt_path TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Sponsors table
    await db.execute('''
      CREATE TABLE sponsors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        amount_or_service TEXT NOT NULL,
        financial_value REAL NOT NULL,
        contact_info TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  // --- Student Operations ---
  Future<int> insertStudent(Student student) async {
    final db = await instance.database;
    return await db.insert('students', student.toMap());
  }

  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Fetches students with their paid amounts aggregated
  Future<List<Map<String, dynamic>>> getStudentsWithPayments() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.*, COALESCE(SUM(p.amount), 0) as paid_amount 
      FROM students s 
      LEFT JOIN payments p ON s.id = p.student_id 
      GROUP BY s.id
    ''');
  }

  Future<Map<String, dynamic>?> getStudentWithPayments(int studentId) async {
    final db = await instance.database;
    final results = await db.rawQuery('''
      SELECT s.*, COALESCE(SUM(p.amount), 0) as paid_amount 
      FROM students s 
      LEFT JOIN payments p ON s.id = p.student_id 
      WHERE s.id = ?
      GROUP BY s.id
    ''', [studentId]);
    return results.isNotEmpty ? results.first : null;
  }

  // --- Payment Operations ---
  Future<int> insertPayment(Payment payment) async {
    final db = await instance.database;
    return await db.insert('payments', payment.toMap());
  }

  Future<int> updatePayment(Payment payment) async {
    final db = await instance.database;
    return await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deletePayment(int id) async {
    final db = await instance.database;
    return await db.delete(
      'payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Payment>> getPaymentsForStudent(int studentId) async {
    final db = await instance.database;
    final maps = await db.query(
      'payments',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC, time DESC',
    );
    return maps.map((map) => Payment.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllPaymentsWithStudentName() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.*, s.name as student_name, s.department as student_department
      FROM payments p
      JOIN students s ON p.student_id = s.id
      ORDER BY p.date DESC, p.time DESC
    ''');
  }

  // --- Expense Operations ---
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> softDeleteExpense(int id) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreExpense(int id) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      {'is_deleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpensePermanently(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Expense>> getExpenses({bool getDeleted = false}) async {
    final db = await instance.database;
    final maps = await db.query(
      'expenses',
      where: 'is_deleted = ?',
      whereArgs: [getDeleted ? 1 : 0],
      orderBy: 'date DESC, time DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  // --- Sponsor Operations ---
  Future<int> insertSponsor(Sponsor sponsor) async {
    final db = await instance.database;
    return await db.insert('sponsors', sponsor.toMap());
  }

  Future<int> updateSponsor(Sponsor sponsor) async {
    final db = await instance.database;
    return await db.update(
      'sponsors',
      sponsor.toMap(),
      where: 'id = ?',
      whereArgs: [sponsor.id],
    );
  }

  Future<int> deleteSponsor(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sponsors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Sponsor>> getSponsors() async {
    final db = await instance.database;
    final maps = await db.query('sponsors', orderBy: 'financial_value DESC');
    return maps.map((map) => Sponsor.fromMap(map)).toList();
  }

  // --- Clear Database (except settings / not used directly in UI as requested) ---
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('payments');
    await db.delete('students');
    await db.delete('expenses');
    await db.delete('sponsors');
  }

  // --- Export/Import Database raw helper ---
  Future<String> getDatabasePath() async {
    final dbPath = await getApplicationDocumentsDirectory();
    return join(dbPath.path, 'gradcash.db');
  }
}
