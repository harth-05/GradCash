class Payment {
  final int? id;
  final int studentId;
  final double amount;
  final String paymentMethod; // كاش, محفظة جيب, ون كاش, الكريمي, حوالة
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final String? notes;

  Payment({
    this.id,
    required this.studentId,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.time,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'amount': amount,
      'payment_method': paymentMethod,
      'date': date,
      'time': time,
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      notes: map['notes'] as String?,
    );
  }

  Payment copyWith({
    int? id,
    int? studentId,
    double? amount,
    String? paymentMethod,
    String? date,
    String? time,
    String? notes,
  }) {
    return Payment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      time: time ?? this.time,
      notes: notes ?? this.notes,
    );
  }
}
