import '../../../models/recipe.dart';

/// Bundled demo recipe + pre-computed Healthify / Tailor results used by the
/// onboarding flow. Everything here is static so the onboarding demo feels
/// instant and never depends on the network, auth, or the Claude API.
///
/// The recipe mirrors https://pinchofyum.com/yum-yum-rice-bowls and is seeded
/// into the user's real library right after signup (see DemoSeedService) so it
/// becomes their first recipe.

/// Stable id for the in-onboarding preview (not the persisted row id).
const String kDemoRecipeId = 'demo-korean-bbq';
const String kDemoRecipeSourceUrl = 'https://pinchofyum.com/yum-yum-rice-bowls';

final Recipe kDemoRecipe = Recipe(
  id: kDemoRecipeId,
  userId: '',
  title: 'Korean BBQ Yum Yum Rice Bowls',
  description:
      'Easy marinated steak, spicy kimchi, poached egg, rice, and yum yum sauce. SO good and SO easy.',
  imageUrl: 'https://pinchofyum.com/tachyon/Korean-Bowls-2-2-Yoast.jpg',
  sourceUrl: kDemoRecipeSourceUrl,
  sourceType: 'link',
  servings: 4,
  tags: const ['korean bbq', 'yum yum sauce', 'yum yum bowl'],
  nutrition: const Nutrition(calories: 620, protein: 34, carbs: 58, fat: 27),
  ingredients: const [
    Ingredient(name: 'flank steak, thinly sliced', amount: 1, unit: 'lb'),
    Ingredient(name: 'soy sauce', amount: 0.25, unit: 'cup'),
    Ingredient(name: 'brown sugar', amount: 2, unit: 'tbsp'),
    Ingredient(name: 'sesame oil', amount: 1, unit: 'tbsp'),
    Ingredient(name: 'garlic, minced', amount: 3, unit: 'cloves'),
    Ingredient(name: 'cooked white rice', amount: 4, unit: 'cups'),
    Ingredient(name: 'kimchi', amount: 1, unit: 'cup'),
    Ingredient(name: 'eggs', amount: 4, unit: ''),
    Ingredient(name: 'green onions, sliced', amount: 4, unit: ''),
    Ingredient(name: 'mayonnaise', amount: 0.5, unit: 'cup'),
    Ingredient(name: 'sriracha', amount: 1, unit: 'tbsp'),
  ],
  steps: const [
    'Whisk the soy sauce, brown sugar, sesame oil, and garlic, then toss with the sliced steak and marinate for 15 minutes.',
    'Stir the mayonnaise and sriracha together to make the yum yum sauce.',
    'Sear the steak in a hot pan for 2 to 3 minutes until caramelised.',
    'Poach or fry the eggs to your liking.',
    'Build each bowl with rice, steak, kimchi, and a poached egg.',
    'Drizzle with yum yum sauce and finish with green onions.',
  ],
  // Placeholder; a real timestamp is set per-user when seeded.
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

/// A persistable copy of the demo recipe owned by [userId] with a fresh id.
Recipe demoRecipeForUser(String userId, {required String id}) => Recipe(
      id: id,
      userId: userId,
      title: kDemoRecipe.title,
      description: kDemoRecipe.description,
      imageUrl: kDemoRecipe.imageUrl,
      sourceUrl: kDemoRecipe.sourceUrl,
      sourceType: kDemoRecipe.sourceType,
      ingredients: kDemoRecipe.ingredients,
      steps: kDemoRecipe.steps,
      nutrition: kDemoRecipe.nutrition,
      tags: kDemoRecipe.tags,
      createdAt: DateTime.now(),
      servings: kDemoRecipe.servings,
    );

/// Pre-computed Healthify result. Shape mirrors ClaudeService.healthifyRecipe,
/// with extra fields the onboarding demo renders for a richer "wow" moment.
const Map<String, dynamic> kDemoHealthifyResult = {
  'caloriesSaved': 180,
  'healthScoreBefore': 62,
  'healthScoreAfter': 88,
  'nutritionBefore': {'calories': 620, 'protein': 34, 'carbs': 58, 'fat': 27},
  'nutritionAfter': {'calories': 440, 'protein': 38, 'carbs': 48, 'fat': 16},
  'benefits': [
    '11g less fat per serving',
    '4g more protein to keep you full',
    '6g more fibre from whole grains',
  ],
  'changes': [
    {
      'original': 'white rice',
      'replacement': 'brown rice',
      'reason': 'More fibre and a steadier release of energy.',
      'benefit': '+6g fibre',
    },
    {
      'original': 'mayonnaise',
      'replacement': 'greek yogurt',
      'reason': 'Cuts the fat while keeping the sauce creamy and tangy.',
      'benefit': '11g less fat',
    },
    {
      'original': 'brown sugar',
      'replacement': 'honey',
      'reason': 'Natural sweetness with a lower glycemic hit.',
      'benefit': 'Less refined sugar',
    },
    {
      'original': 'pan fried egg',
      'replacement': 'poached egg',
      'reason': 'Same rich yolk without the extra cooking oil.',
      'benefit': 'No added oil',
    },
  ],
};

/// Pre-computed Tailor result for the user's chosen diet. Shape mirrors
/// ClaudeService.tailorRecipe so the onboarding demo looks exactly like the
/// real feature. Canned per diet so the swaps actually make sense for the
/// Korean BBQ steak bowl the demo uses.
Map<String, dynamic> demoTailorResultFor(String diet) {
  final swaps = _tailorSwapsByDiet[diet] ?? _tailorSwapsByDiet['None']!;
  return {
    'tailoredRecipe': {
      'title': diet == 'None'
          ? kDemoRecipe.title
          : '${kDemoRecipe.title} ($diet)',
      'description': diet == 'None'
          ? 'A few light tweaks to keep this bowl balanced.'
          : 'The same crave worthy bowl, adjusted for your $diet diet without losing the flavour.',
    },
    'changes': swaps,
    'overallAssessment': diet == 'None'
        ? 'This recipe already fits a balanced diet. These small swaps keep it light.'
        : 'This recipe adapts to a $diet diet easily. Taste and texture stay true to the original.',
    'chefTip': _tailorTipByDiet[diet] ?? _tailorTipByDiet['None']!,
    'warnings': _tailorWarningsByDiet[diet] ?? const <String>[],
  };
}

const Map<String, String> _tailorTipByDiet = {
  'None': 'Toast the sesame oil for thirty seconds before adding the garlic to deepen the flavour.',
  'Vegan': 'Press the tofu for ten minutes first so it crisps up and soaks in more marinade.',
  'Vegetarian': 'Sear the mushrooms hard and do not crowd the pan so they brown instead of steam.',
  'Keto': 'Squeeze the cauliflower rice in a towel before frying so it stays light and fluffy.',
  'Paleo': 'Coconut aminos are sweeter than soy, so hold back a little of the honey.',
  'Gluten-Free': 'Double check your kimchi and chilli sauce labels, some brands sneak in wheat.',
};

const Map<String, List<String>> _tailorWarningsByDiet = {
  'Vegan': ['Tofu browns faster than steak, so keep an eye on the pan to avoid burning.'],
  'Keto': ['Cauliflower rice releases water, drain it well so the bowl does not go soggy.'],
};

/// Default Tailor result (no diet selected) used for cache priming fallback.
final Map<String, dynamic> kDemoTailorResult = demoTailorResultFor('None');

const Map<String, List<Map<String, String>>> _tailorSwapsByDiet = {
  'None': [
    {
      'original': 'white rice',
      'replacement': 'brown rice',
      'reason': 'More fibre and steadier energy.',
      'culinarySense': 'Cooks the same, nuttier flavour.',
      'outcomeImpact': 'Slightly chewier base.',
      'confidence': 'high',
    },
    {
      'original': 'mayonnaise',
      'replacement': 'greek yogurt',
      'reason': 'Lighter sauce with more protein.',
      'culinarySense': 'Stays creamy and tangy.',
      'outcomeImpact': 'A little lighter on the palate.',
      'confidence': 'high',
    },
  ],
  'Vegan': [
    {
      'original': 'flank steak',
      'replacement': 'marinated extra firm tofu',
      'reason': 'Plant based protein that soaks up the marinade.',
      'culinarySense': 'Sears well and carries the BBQ flavour.',
      'outcomeImpact': 'Lighter bite, same savoury glaze.',
      'confidence': 'high',
    },
    {
      'original': 'eggs',
      'replacement': 'crispy chickpeas',
      'reason': 'Keeps the protein and crunch without animal products.',
      'culinarySense': 'Great texture contrast.',
      'outcomeImpact': 'Adds a toasty, nutty note.',
      'confidence': 'medium',
    },
    {
      'original': 'mayonnaise',
      'replacement': 'vegan mayo',
      'reason': 'Makes the yum yum sauce fully plant based.',
      'culinarySense': 'Identical creaminess.',
      'outcomeImpact': 'No noticeable difference.',
      'confidence': 'high',
    },
  ],
  'Vegetarian': [
    {
      'original': 'flank steak',
      'replacement': 'king oyster mushrooms',
      'reason': 'Meaty texture without the meat.',
      'culinarySense': 'Caramelises beautifully in the marinade.',
      'outcomeImpact': 'Juicy, umami forward.',
      'confidence': 'high',
    },
  ],
  'Keto': [
    {
      'original': 'white rice',
      'replacement': 'cauliflower rice',
      'reason': 'Cuts the carbs to stay in ketosis.',
      'culinarySense': 'Light and fluffy, soaks up sauce.',
      'outcomeImpact': 'Lower carb, lighter base.',
      'confidence': 'high',
    },
    {
      'original': 'brown sugar',
      'replacement': 'monk fruit sweetener',
      'reason': 'Keeps the glaze sweet without the sugar.',
      'culinarySense': 'Caramelises close to sugar.',
      'outcomeImpact': 'Same sweet savoury balance.',
      'confidence': 'medium',
    },
  ],
  'Paleo': [
    {
      'original': 'soy sauce',
      'replacement': 'coconut aminos',
      'reason': 'Grain free and paleo friendly.',
      'culinarySense': 'Slightly sweeter, still savoury.',
      'outcomeImpact': 'A touch milder, very close.',
      'confidence': 'high',
    },
    {
      'original': 'white rice',
      'replacement': 'cauliflower rice',
      'reason': 'Replaces the grain with a veg base.',
      'culinarySense': 'Light and fluffy.',
      'outcomeImpact': 'Lower carb, fresh flavour.',
      'confidence': 'high',
    },
  ],
  'Gluten-Free': [
    {
      'original': 'soy sauce',
      'replacement': 'tamari',
      'reason': 'Gluten free while keeping that deep savoury base.',
      'culinarySense': 'Almost identical flavour.',
      'outcomeImpact': 'No noticeable difference.',
      'confidence': 'high',
    },
    {
      'original': 'sriracha',
      'replacement': 'gluten free chilli sauce',
      'reason': 'Some sriracha brands contain gluten additives.',
      'culinarySense': 'Same heat and tang.',
      'outcomeImpact': 'Sauce stays bright and spicy.',
      'confidence': 'high',
    },
  ],
  'Halal': [
    {
      'original': 'flank steak',
      'replacement': 'halal certified beef',
      'reason': 'Keeps the dish halal.',
      'culinarySense': 'Identical cut and cooking.',
      'outcomeImpact': 'No change to taste or texture.',
      'confidence': 'high',
    },
  ],
};
