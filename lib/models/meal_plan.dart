class MealSlot {
  final String mealType; // breakfast | lunch | dinner | snack
  final String? recipeId;
  final String? recipeTitle;
  final String? recipeImage;

  const MealSlot({
    required this.mealType,
    this.recipeId,
    this.recipeTitle,
    this.recipeImage,
  });

  factory MealSlot.fromJson(Map<String, dynamic> json) => MealSlot(
        mealType: json['meal_type'] as String? ?? 'lunch',
        recipeId: json['recipe_id'] as String?,
        recipeTitle: json['recipe_title'] as String?,
        recipeImage: json['recipe_image'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'meal_type': mealType,
        'recipe_id': recipeId,
        'recipe_title': recipeTitle,
        'recipe_image': recipeImage,
      };
}

class MealPlan {
  final String id;
  final String userId;
  final DateTime weekStart;
  final Map<String, Map<String, MealSlot>> slots;

  const MealPlan({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.slots,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final slotsRaw = json['slots'] as Map<String, dynamic>? ?? {};
    final slots = slotsRaw.map((date, mealsRaw) {
      final mealsMap = mealsRaw as Map<String, dynamic>? ?? {};
      return MapEntry(
        date,
        mealsMap.map((mealType, slotRaw) {
          return MapEntry(
            mealType,
            MealSlot.fromJson(slotRaw as Map<String, dynamic>),
          );
        }),
      );
    });

    return MealPlan(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      weekStart: json['week_start'] != null
          ? DateTime.parse(json['week_start'] as String)
          : DateTime.now(),
      slots: slots,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'week_start': weekStart.toIso8601String().split('T').first,
        'slots': slots.map((date, meals) => MapEntry(
              date,
              meals.map((mealType, slot) => MapEntry(mealType, slot.toJson())),
            )),
      };
}
