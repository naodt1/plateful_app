class Ingredient {
  final String name;
  final double amount;
  final String unit;

  const Ingredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
      };

  Ingredient copyWith({double? amount}) =>
      Ingredient(name: name, amount: amount ?? this.amount, unit: unit);
}

class Nutrition {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

class Recipe {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? imageUrl;
  final String? sourceUrl;
  final String sourceType; // link | manual | share
  final List<Ingredient> ingredients;
  final List<String> steps;
  final Nutrition? nutrition;
  final List<String> tags;
  final DateTime createdAt;
  final int servings;
  final bool favorite;

  const Recipe({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.imageUrl,
    this.sourceUrl,
    required this.sourceType,
    required this.ingredients,
    required this.steps,
    this.nutrition,
    required this.tags,
    required this.createdAt,
    this.servings = 4,
    this.favorite = false,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredientsRaw = json['ingredients'];
    List<Ingredient> ingredients = [];
    if (ingredientsRaw is List) {
      ingredients = ingredientsRaw
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final stepsRaw = json['steps'];
    List<String> steps = [];
    if (stepsRaw is List) {
      steps = stepsRaw.map((e) => e.toString()).toList();
    }

    final nutritionRaw = json['nutrition'];
    Nutrition? nutrition;
    if (nutritionRaw is Map<String, dynamic>) {
      nutrition = Nutrition.fromJson(nutritionRaw);
    }

    final tagsRaw = json['tags'];
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    }

    return Recipe(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      sourceUrl: json['source_url'] as String?,
      sourceType: json['source_type'] as String? ?? 'manual',
      ingredients: ingredients,
      steps: steps,
      nutrition: nutrition,
      tags: tags,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      servings: (json['servings'] as num?)?.toInt() ?? 4,
      favorite: json['favorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'source_url': sourceUrl,
        'source_type': sourceType,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps,
        'nutrition': nutrition?.toJson(),
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
        'servings': servings,
        'favorite': favorite,
      };

  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    List<Ingredient>? ingredients,
    List<String>? steps,
    Nutrition? nutrition,
    List<String>? tags,
    int? servings,
    bool? favorite,
  }) =>
      Recipe(
        id: id ?? this.id,
        userId: userId,
        title: title ?? this.title,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        sourceUrl: sourceUrl,
        sourceType: sourceType,
        ingredients: ingredients ?? this.ingredients,
        steps: steps ?? this.steps,
        nutrition: nutrition ?? this.nutrition,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        servings: servings ?? this.servings,
        favorite: favorite ?? this.favorite,
      );
}
