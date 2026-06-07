import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/diet_mode_screen.dart';
import '../../features/onboarding/screens/signup_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/recipe/screens/recipe_detail_screen.dart';
import '../../features/recipe/screens/add_recipe_screen.dart';
import '../../features/recipe/screens/import_recipe_screen.dart';
import '../../features/recipe/screens/all_recipes_screen.dart';
import '../../features/pantry/screens/pantry_screen.dart';
import '../../features/meal_plan/screens/meal_plan_screen.dart';
import '../../features/grocery/screens/grocery_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/collections_screen.dart';
import '../../features/profile/screens/collection_detail_screen.dart';
import '../shell/main_shell.dart';
import '../../models/recipe.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = _buildRouter();

  static GoRouter _buildRouter() => GoRouter(
        navigatorKey: _rootNavigatorKey,
        initialLocation: '/splash',
        redirect: (context, state) {
          final user = Supabase.instance.client.auth.currentUser;
          final isAuth = user != null;
          final isSplash = state.matchedLocation == '/splash';
          final isOnboarding = state.matchedLocation.startsWith('/onboarding');
          final isSignup = state.matchedLocation == '/signup';

          // Let the splash handle its own navigation
          if (isSplash) return null;

          if (!isAuth && !isOnboarding && !isSignup) {
            return '/onboarding';
          }
          if (isAuth && isOnboarding) {
            return '/home';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/splash',
            builder: (_, __) => const SplashScreen(),
          ),
          GoRoute(
            path: '/',
            redirect: (_, __) => '/home',
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/onboarding/diet',
            builder: (_, __) => const DietModeScreen(),
          ),
          GoRoute(
            path: '/signup',
            builder: (_, __) => const SignupScreen(),
          ),
          ShellRoute(
            navigatorKey: _shellNavigatorKey,
            builder: (context, state, child) => MainShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomeScreen(),
              ),
              GoRoute(
                path: '/pantry',
                builder: (_, __) => const PantryScreen(),
              ),
              GoRoute(
                path: '/meal-plan',
                builder: (_, __) => const MealPlanScreen(),
              ),
              GoRoute(
                path: '/grocery',
                builder: (_, __) => const GroceryScreen(),
              ),
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/recipe/add',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final prefillUrl = extra?['url'] as String?;
              return AddRecipeScreen(prefillUrl: prefillUrl);
            },
          ),
          GoRoute(
            path: '/recipe/import',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final url = extra?['url'] as String? ?? '';
              return ImportRecipeScreen(sharedUrl: url);
            },
          ),
          GoRoute(
            path: '/recipe/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              final initial = state.extra is Recipe ? state.extra as Recipe : null;
              return CustomTransitionPage(
                key: state.pageKey,
                child: RecipeDetailScreen(recipeId: id, initialRecipe: initial),
                transitionDuration: const Duration(milliseconds: 380),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder: (context, animation, _, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  // Fade + gentle upward slide; the Hero handles the image.
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/recipes',
            builder: (_, __) => const AllRecipesScreen(),
          ),
          GoRoute(
            path: '/collections',
            builder: (_, __) => const CollectionsScreen(),
          ),
          GoRoute(
            path: '/collections/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final name = state.uri.queryParameters['name'] ?? 'Collection';
              return CollectionDetailScreen(
                  collectionId: id, collectionName: name);
            },
          ),
        ],
      );
}
