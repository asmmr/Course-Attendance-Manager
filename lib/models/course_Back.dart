class Course {
  final int? id;
  final String code;
  final String name;
  final String semester;
  final String section;

  Course({
    this.id,
    required this.code,
    required this.name,
    required this.semester,
    required this.section,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'semester': semester,
      'section': section,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as int?,
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      semester: map['semester']?.toString() ?? '',
      section: map['section']?.toString() ?? '',
    );
  }
}
