class Member {
  final int id;
  final String name;
  final String role;
  final int documentCount;

  const Member({
    required this.id,
    required this.name,
    this.role = 'Member',
    this.documentCount = 0,
  });

  factory Member.fromMap(Map<String, dynamic> map, {int documentCount = 0}) {
    return Member(
      id: map['id'] as int,
      name: map['name'] as String,
      role: map['role'] as String? ?? 'Member',
      documentCount: documentCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }
}
