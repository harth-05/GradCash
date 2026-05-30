class Sponsor {
  final int? id;
  final String name;
  final String type; // مالي, خدمي
  final String amountOrService; // e.g. "50000" or "طباعة بنرات"
  final double financialValue; // numerical value for stats, e.g. 50000 or 0
  final String contactInfo;
  final String? notes;

  Sponsor({
    this.id,
    required this.name,
    required this.type,
    required this.amountOrService,
    required this.financialValue,
    required this.contactInfo,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount_or_service': amountOrService,
      'financial_value': financialValue,
      'contact_info': contactInfo,
      'notes': notes,
    };
  }

  factory Sponsor.fromMap(Map<String, dynamic> map) {
    return Sponsor(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      amountOrService: map['amount_or_service'] as String,
      financialValue: (map['financial_value'] as num).toDouble(),
      contactInfo: map['contact_info'] as String,
      notes: map['notes'] as String?,
    );
  }

  Sponsor copyWith({
    int? id,
    String? name,
    String? type,
    String? amountOrService,
    double? financialValue,
    String? contactInfo,
    String? notes,
  }) {
    return Sponsor(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amountOrService: amountOrService ?? this.amountOrService,
      financialValue: financialValue ?? this.financialValue,
      contactInfo: contactInfo ?? this.contactInfo,
      notes: notes ?? this.notes,
    );
  }
}
