class Student {
  final int? id;
  final String name;
  final String universityId;
  final String department;
  final String? photoPath;
  final double requiredAmount;

  Student({
    this.id,
    required this.name,
    required this.universityId,
    required this.department,
    this.photoPath,
    required this.requiredAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'university_id': universityId,
      'department': department,
      'photo_path': photoPath,
      'required_amount': requiredAmount,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      universityId: map['university_id'] as String,
      department: map['department'] as String,
      photoPath: map['photo_path'] as String?,
      requiredAmount: (map['required_amount'] as num).toDouble(),
    );
  }

  Student copyWith({
    int? id,
    String? name,
    String? universityId,
    String? department,
    String? photoPath,
    double? requiredAmount,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      universityId: universityId ?? this.universityId,
      department: department ?? this.department,
      photoPath: photoPath ?? this.photoPath,
      requiredAmount: requiredAmount ?? this.requiredAmount,
    );
  }
}
