import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';
import '../models/expense_model.dart';
import '../models/sponsor_model.dart';
import 'database_helper.dart';

class FinanceProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late SharedPreferences _prefs;

  List<Map<String, dynamic>> _students = [];
  List<Expense> _expenses = [];
  List<Expense> _trashExpenses = [];
  List<Sponsor> _sponsors = [];
  List<Payment> _studentPayments = [];

  // Settings
  double _defaultBaseAmount = 30000.0;
  String _ceremonyName = 'GradCash';
  bool _isDarkMode = false;
  String _pinCode = '';
  bool _isLoggedIn = false; // PIN security session state
  String? _customLogoPath;
  String? _customIdentityPath;

  int _currentIndex = 4; // Default tab (Students)
  Map<String, dynamic>? _advancedStats;

  // Search & Filter state
  String _studentSearchQuery = '';
  String _studentFilterStatus = 'all'; // all, completed, partial, unpaid
  String _studentSortBy = 'name'; // name, required, paid, remaining, progress

  // Getters
  List<Map<String, dynamic>> get students => _students;
  List<Expense> get expenses => _expenses;
  List<Expense> get trashExpenses => _trashExpenses;
  List<Sponsor> get sponsors => _sponsors;
  List<Payment> get studentPayments => _studentPayments;

  int get currentIndex => _currentIndex;
  Map<String, dynamic>? get advancedStats => _advancedStats;

  double get defaultBaseAmount => _defaultBaseAmount;
  String get ceremonyName => _ceremonyName;
  bool get isDarkMode => _isDarkMode;
  String get pinCode => _pinCode;
  bool get isLoggedIn => _isLoggedIn;
  String? get customLogoPath => _customLogoPath;
  String? get customIdentityPath => _customIdentityPath;

  String get studentSearchQuery => _studentSearchQuery;
  String get studentFilterStatus => _studentFilterStatus;
  String get studentSortBy => _studentSortBy;

  // Initializing Provider
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _defaultBaseAmount = _prefs.getDouble('base_amount') ?? 30000.0;
    _ceremonyName = _prefs.getString('ceremony_name') ?? 'GradCash';
    _isDarkMode = _prefs.getBool('is_dark_mode') ?? false;
    _pinCode = _prefs.getString('pin_code') ?? '';
    _customLogoPath = _prefs.getString('custom_logo_path');
    _customIdentityPath = _prefs.getString('custom_identity_path');
    
    // Session state
    _isLoggedIn = _pinCode.isEmpty; // if no PIN, auto-logged in

    await refreshData();
  }

  // Refresh all lists from SQLite
  Future<void> refreshData() async {
    _students = await _dbHelper.getStudentsWithPayments();
    _expenses = await _dbHelper.getExpenses(getDeleted: false);
    _trashExpenses = await _dbHelper.getExpenses(getDeleted: true);
    _sponsors = await _dbHelper.getSponsors();
    
    // Refresh stats automatically
    _advancedStats = await getAdvancedStatistics();
    
    notifyListeners();
  }

  void setTabIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // --- Student operations ---
  Future<void> addStudent(Student student) async {
    await _dbHelper.insertStudent(student);
    await refreshData();
  }

  Future<void> updateStudent(Student student) async {
    await _dbHelper.updateStudent(student);
    await refreshData();
  }

  Future<void> deleteStudent(int id) async {
    await _dbHelper.deleteStudent(id);
    await refreshData();
  }

  // --- Payment operations ---
  Future<void> addPayment(Payment payment) async {
    await _dbHelper.insertPayment(payment);
    await refreshData();
  }

  Future<void> updatePayment(Payment payment) async {
    await _dbHelper.updatePayment(payment);
    await refreshData();
  }

  Future<void> deletePayment(int id) async {
    await _dbHelper.deletePayment(id);
    await refreshData();
  }

  Future<void> loadPaymentsForStudent(int studentId) async {
    _studentPayments = await _dbHelper.getPaymentsForStudent(studentId);
    notifyListeners();
  }

  // --- Expense operations ---
  Future<void> addExpense(Expense expense) async {
    await _dbHelper.insertExpense(expense);
    await refreshData();
  }

  Future<void> updateExpense(Expense expense) async {
    await _dbHelper.updateExpense(expense);
    await refreshData();
  }

  Future<void> trashExpense(int id) async {
    await _dbHelper.softDeleteExpense(id);
    await refreshData();
  }

  Future<void> restoreExpense(int id) async {
    await _dbHelper.restoreExpense(id);
    await refreshData();
  }

  Future<void> deleteExpensePermanently(int id) async {
    await _dbHelper.deleteExpensePermanently(id);
    await refreshData();
  }

  Future<void> clearTrash() async {
    for (var exp in _trashExpenses) {
      if (exp.id != null) {
        await _dbHelper.deleteExpensePermanently(exp.id!);
      }
    }
    await refreshData();
  }

  // --- Sponsor operations ---
  Future<void> addSponsor(Sponsor sponsor) async {
    await _dbHelper.insertSponsor(sponsor);
    await refreshData();
  }

  Future<void> updateSponsor(Sponsor sponsor) async {
    await _dbHelper.updateSponsor(sponsor);
    await refreshData();
  }

  Future<void> deleteSponsor(int id) async {
    await _dbHelper.deleteSponsor(id);
    await refreshData();
  }

  // --- Settings operations ---
  Future<void> setDefaultBaseAmount(double amount) async {
    _defaultBaseAmount = amount;
    await _prefs.setDouble('base_amount', amount);
    notifyListeners();
  }

  Future<void> setCeremonyName(String name) async {
    _ceremonyName = name;
    await _prefs.setString('ceremony_name', name);
    notifyListeners();
  }

  Future<void> toggleThemeMode(bool value) async {
    _isDarkMode = value;
    await _prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  Future<void> setPinCode(String pin) async {
    _pinCode = pin;
    await _prefs.setString('pin_code', pin);
    if (pin.isEmpty) {
      _isLoggedIn = true;
    } else {
      _isLoggedIn = false;
    }
    notifyListeners();
  }

  Future<void> setCustomLogoPath(String? path) async {
    _customLogoPath = path;
    if (path != null) {
      await _prefs.setString('custom_logo_path', path);
    } else {
      await _prefs.remove('custom_logo_path');
    }
    notifyListeners();
  }

  Future<void> setCustomIdentityPath(String? path) async {
    _customIdentityPath = path;
    if (path != null) {
      await _prefs.setString('custom_identity_path', path);
    } else {
      await _prefs.remove('custom_identity_path');
    }
    notifyListeners();
  }

  // Security Auth Session
  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    if (_pinCode.isNotEmpty) {
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  // Set Search & Filters
  void setStudentSearchQuery(String query) {
    _studentSearchQuery = query;
    notifyListeners();
  }

  void setStudentFilterStatus(String status) {
    _studentFilterStatus = status;
    notifyListeners();
  }

  void setStudentSortBy(String sortBy) {
    _studentSortBy = sortBy;
    notifyListeners();
  }

  // Filtered and Sorted Students list
  List<Map<String, dynamic>> getFilteredStudents() {
    List<Map<String, dynamic>> filteredList = List.from(_students);

    // Search Query filter
    if (_studentSearchQuery.isNotEmpty) {
      final query = _studentSearchQuery.toLowerCase();
      filteredList = filteredList.where((std) {
        final name = (std['name'] as String).toLowerCase();
        final uniId = (std['university_id'] as String).toLowerCase();
        final dept = (std['department'] as String).toLowerCase();
        return name.contains(query) || uniId.contains(query) || dept.contains(query);
      }).toList();
    }

    // Payment Status filter
    if (_studentFilterStatus != 'all') {
      filteredList = filteredList.where((std) {
        final req = (std['required_amount'] as num).toDouble();
        final paid = (std['paid_amount'] as num).toDouble();
        if (_studentFilterStatus == 'completed') {
          return paid >= req && req > 0;
        } else if (_studentFilterStatus == 'partial') {
          return paid > 0 && paid < req;
        } else if (_studentFilterStatus == 'unpaid') {
          return paid == 0;
        }
        return true;
      }).toList();
    }

    // Sort operations
    filteredList.sort((a, b) {
      if (_studentSortBy == 'name') {
        return (a['name'] as String).compareTo(b['name'] as String);
      } else if (_studentSortBy == 'required') {
        return (b['required_amount'] as num).compareTo(a['required_amount'] as num);
      } else if (_studentSortBy == 'paid') {
        return (b['paid_amount'] as num).compareTo(a['paid_amount'] as num);
      } else if (_studentSortBy == 'remaining') {
        final remA = (a['required_amount'] as num) - (a['paid_amount'] as num);
        final remB = (b['required_amount'] as num) - (b['paid_amount'] as num);
        return remB.compareTo(remA);
      } else if (_studentSortBy == 'progress') {
        final pctA = (a['required_amount'] as num) == 0 ? 0.0 : (a['paid_amount'] as num) / (a['required_amount'] as num);
        final pctB = (b['required_amount'] as num) == 0 ? 0.0 : (b['paid_amount'] as num) / (b['required_amount'] as num);
        return pctB.compareTo(pctA);
      }
      return 0;
    });

    return filteredList;
  }

  // --- Statistics calculations ---
  Map<String, dynamic> getStatistics() {
    double totalRequired = 0.0;
    double totalPaid = 0.0;
    double totalExpenses = 0.0;
    double totalSponsors = 0.0;

    int completedCount = 0;
    int remainingCount = 0;


    // Students loop
    for (var std in _students) {
      final req = (std['required_amount'] as num).toDouble();
      final paid = (std['paid_amount'] as num).toDouble();
      totalRequired += req;
      totalPaid += paid;

      if (paid >= req && req > 0) {
        completedCount++;
      } else {
        remainingCount++;
      }
    }

    // Fetch payment methods distribution directly from database later or calculate it
    // Wait, let's load all payments to compile these details
    // We can also run raw SQL queries for this in DatabaseHelper, or calculate it since we have all payments.
    // For stats, let's calculate them from payments. But we don't have all payments in memory in the provider unless we retrieve them.
    // Let's add a helper inside DatabaseHelper to get payment stats, or get all payments. Let's do raw query in DatabaseHelper.
    // Wait, let's look at DatabaseHelper. We have `getAllPaymentsWithStudentName` which returns all payments. Let's query them or let DatabaseHelper run a specific stats query.
    // Let's do a simple count/sum query in DatabaseHelper.

    // Let's calculate total expenses (only non-deleted)
    for (var exp in _expenses) {
      totalExpenses += exp.amount;
    }

    // Let's calculate total sponsor support
    for (var sp in _sponsors) {
      totalSponsors += sp.financialValue;
    }

    double netBalance = totalPaid + totalSponsors - totalExpenses;
    double totalRemaining = totalRequired - totalPaid;

    return {
      'totalRequired': totalRequired,
      'totalPaid': totalPaid,
      'totalRemaining': totalRemaining,
      'totalExpenses': totalExpenses,
      'totalSponsors': totalSponsors,
      'netBalance': netBalance,
      'completedCount': completedCount,
      'remainingCount': remainingCount,
    };
  }

  // Async stats fetching for advanced charts
  Future<Map<String, dynamic>> getAdvancedStatistics() async {
    final db = await _dbHelper.database;
    
    // Net Stats
    final basicStats = getStatistics();

    // Payments by method
    final methodResults = await db.rawQuery('''
      SELECT payment_method, SUM(amount) as total_amount, COUNT(id) as count
      FROM payments
      GROUP BY payment_method
    ''');

    Map<String, double> paymentMethodsAmount = {
      'كاش': 0.0,
      'محفظة جيب': 0.0,
      'ون كاش': 0.0,
      'الكريمي': 0.0,
      'حوالة': 0.0,
    };

    Map<String, int> paymentMethodsCount = {
      'كاش': 0,
      'محفظة جيب': 0,
      'ون كاش': 0,
      'الكريمي': 0,
      'حوالة': 0,
    };

    for (var row in methodResults) {
      final method = row['payment_method'] as String;
      final amount = (row['total_amount'] as num).toDouble();
      final count = row['count'] as int;

      if (paymentMethodsAmount.containsKey(method)) {
        paymentMethodsAmount[method] = amount;
        paymentMethodsCount[method] = count;
      }
    }

    // Most used payment method
    String mostUsedMethod = 'لا يوجد';
    int maxCount = 0;
    paymentMethodsCount.forEach((method, count) {
      if (count > maxCount) {
        maxCount = count;
        mostUsedMethod = method;
      }
    });

    // Expenses by category
    final expenseCatResults = await db.rawQuery('''
      SELECT category, SUM(amount) as total_amount
      FROM expenses
      WHERE is_deleted = 0
      GROUP BY category
    ''');

    Map<String, double> expensesByCategory = {};
    for (var row in expenseCatResults) {
      final cat = row['category'] as String;
      final amount = (row['total_amount'] as num).toDouble();
      expensesByCategory[cat] = amount;
    }

    // Daily payment history for line chart (last 7 days or all time)
    final dailyPayments = await db.rawQuery('''
      SELECT date, SUM(amount) as total_amount
      FROM payments
      GROUP BY date
      ORDER BY date DESC
      LIMIT 10
    ''');

    return {
      ...basicStats,
      'paymentMethodsAmount': paymentMethodsAmount,
      'paymentMethodsCount': paymentMethodsCount,
      'mostUsedMethod': mostUsedMethod,
      'expensesByCategory': expensesByCategory,
      'dailyPayments': dailyPayments,
    };
  }

  // Restore database raw backup
  Future<void> restoreFromMap(Map<String, dynamic> data) async {
    // Clear existing
    await _dbHelper.clearAllData();
    final db = await _dbHelper.database;

    // Restore students
    if (data['students'] != null) {
      for (var s in data['students']) {
        await db.insert('students', s);
      }
    }

    // Restore payments
    if (data['payments'] != null) {
      for (var p in data['payments']) {
        await db.insert('payments', p);
      }
    }

    // Restore expenses
    if (data['expenses'] != null) {
      for (var e in data['expenses']) {
        await db.insert('expenses', e);
      }
    }

    // Restore sponsors
    if (data['sponsors'] != null) {
      for (var sp in data['sponsors']) {
        await db.insert('sponsors', sp);
      }
    }

    await refreshData();
  }

  // Dump data to JSON map
  Future<Map<String, dynamic>> dumpData() async {
    final db = await _dbHelper.database;
    final studentsList = await db.query('students');
    final paymentsList = await db.query('payments');
    final expensesList = await db.query('expenses');
    final sponsorsList = await db.query('sponsors');

    return {
      'students': studentsList,
      'payments': paymentsList,
      'expenses': expensesList,
      'sponsors': sponsorsList,
    };
  }
}
