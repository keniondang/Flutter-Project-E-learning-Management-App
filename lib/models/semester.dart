class Semester {
  final String id;
  final String code;
  final String name;
  final bool isCurrent;
  final DateTime createdAt;

  Semester({
    required this.id,
    required this.code,
    required this.name,
    required this.isCurrent,
    required this.createdAt,
  });

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      isCurrent: json['is_current'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'name': name, 'is_current': isCurrent};
  }
}
