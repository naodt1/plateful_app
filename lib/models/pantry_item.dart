class PantryItem {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String quantity;
  final DateTime addedAt;

  const PantryItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.addedAt,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        quantity: json['quantity'] as String? ?? '',
        addedAt: json['added_at'] != null
            ? DateTime.parse(json['added_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'quantity': quantity,
        'added_at': addedAt.toIso8601String(),
      };
}
