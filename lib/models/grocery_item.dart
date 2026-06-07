class GroceryItem {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String quantity;
  final bool checked;
  final String? recipeId;
  final DateTime createdAt;

  const GroceryItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.checked,
    this.recipeId,
    required this.createdAt,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Other',
        quantity: json['quantity'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
        recipeId: json['recipe_id'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'category': category,
        'quantity': quantity,
        'checked': checked,
        'recipe_id': recipeId,
        'created_at': createdAt.toIso8601String(),
      };

  GroceryItem copyWith({bool? checked, String? name, String? quantity}) =>
      GroceryItem(
        id: id,
        userId: userId,
        name: name ?? this.name,
        category: category,
        quantity: quantity ?? this.quantity,
        checked: checked ?? this.checked,
        recipeId: recipeId,
        createdAt: createdAt,
      );
}
