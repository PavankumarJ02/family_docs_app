class CategoryItem {
  final int id;
  final int memberId;
  final String name;
  final int documentCount;

  const CategoryItem({
    required this.id,
    required this.memberId,
    required this.name,
    this.documentCount = 0,
  });

  factory CategoryItem.fromMap(
    Map<String, dynamic> map, {
    int documentCount = 0,
  }) {
    return CategoryItem(
      id: map['id'] as int,
      memberId: (map['member_id'] as int?) ?? 0,
      name: (map['name'] as String?) ?? 'Uncategorized',
      documentCount: documentCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'member_id': memberId, 'name': name};
  }
}
