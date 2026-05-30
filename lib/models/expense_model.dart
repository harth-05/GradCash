class Expense {
  final int? id;
  final double amount;
  final String recipient;
  final String item;
  final String details;
  final String category; // قاعة, ضيافة, تصوير, دروع وشهادات, أخرى
  final String date;
  final String time;
  final String? receiptPath;
  final bool isDeleted; // soft delete for recycle bin

  Expense({
    this.id,
    required this.amount,
    required this.recipient,
    required this.item,
    required this.details,
    required this.category,
    required this.date,
    required this.time,
    this.receiptPath,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'recipient': recipient,
      'item': item,
      'details': details,
      'category': category,
      'date': date,
      'time': time,
      'receipt_path': receiptPath,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      recipient: map['recipient'] as String,
      item: map['item'] as String,
      details: map['details'] as String,
      category: map['category'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      receiptPath: map['receipt_path'] as String?,
      isDeleted: (map['is_deleted'] as int?) == 1,
    );
  }

  Expense copyWith({
    int? id,
    double? amount,
    String? recipient,
    String? item,
    String? details,
    String? category,
    String? date,
    String? time,
    String? receiptPath,
    bool? isDeleted,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      recipient: recipient ?? this.recipient,
      item: item ?? this.item,
      details: details ?? this.details,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      receiptPath: receiptPath ?? this.receiptPath,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
