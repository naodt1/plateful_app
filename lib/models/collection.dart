class Collection {
  final String id;
  final String userId;
  final String name;
  final String? coverImage;
  final int recipeCount;

  const Collection({
    required this.id,
    required this.userId,
    required this.name,
    this.coverImage,
    this.recipeCount = 0,
  });

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        id: json['id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        coverImage: json['cover_image'] as String?,
        recipeCount: (json['recipe_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'cover_image': coverImage,
      };
}
