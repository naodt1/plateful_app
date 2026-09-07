import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'referral_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/recipe.dart';
import '../../models/pantry_item.dart';
import '../../models/grocery_item.dart';
import '../../models/collection.dart';
import '../../models/meal_plan.dart';

/// Firebase-backed backend for Plateful (Auth + Cloud Firestore).
///
/// Data model — everything lives under the signed-in user, so ownership is
/// implied by the path and Security Rules stay trivial:
///
///   users/{uid}                        → profile (diet_mode, display_name, …)
///   users/{uid}/recipes/{id}
///   users/{uid}/collections/{id}       → { name, cover_image, recipe_ids: [] }
///   users/{uid}/pantry_items/{id}
///   users/{uid}/meal_plans/{yyyy-MM-dd} → doc id is the week start
///   users/{uid}/grocery_items/{id}
///
/// The many-to-many "collection_recipes" join from Postgres becomes a
/// `recipe_ids` array on each collection document.
class FirebaseService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Resolves once Firebase has finished restoring any persisted session.
  ///
  /// [currentUser] is null during that restore, so reading it synchronously on
  /// a cold start reports "signed out" for a user who is signed in. Anything
  /// that routes on auth state must await this first. Bounded so a network
  /// stall cannot hang the launch; on timeout we fall back to whatever the
  /// SDK currently has.
  static Future<User?> authReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    try {
      return await _auth.authStateChanges().first.timeout(timeout);
    } catch (_) {
      return _auth.currentUser;
    }
  }

  /// Root document for the signed-in user. Throws if not signed in.
  static DocumentReference<Map<String, dynamic>> get _userDoc {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('No signed-in user.');
    }
    return _db.collection('users').doc(uid);
  }

  static CollectionReference<Map<String, dynamic>> _col(String name) =>
      _userDoc.collection(name);

  /// Read a Firestore doc into the map shape our models expect: the document
  /// data plus its id injected under `id`.
  static Map<String, dynamic> _withId(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return {...data, 'id': doc.id};
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  // ─── Auth ──────────────────────────────────────────────────────────────────

  static Future<UserCredential> signUpWithEmail(
      String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await _ensureProfile(cred.user);
    return cred;
  }

  static Future<UserCredential> signInWithEmail(
          String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Native Google sign-in: get an ID token from Google, exchange it for a
  /// Firebase credential. Uses the google_sign_in v7 singleton API.
  static Future<void> signInWithGoogle() async {
    final webClientId = _googleWebClientId;
    if (webClientId.isEmpty) {
      throw FirebaseAuthException(
          code: 'missing-config',
          message:
              'Google sign-in is not configured (missing GOOGLE_WEB_CLIENT_ID).');
    }

    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: webClientId);

    final GoogleSignInAccount account;
    try {
      account = await signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
            code: 'canceled', message: 'Google sign-in was cancelled.');
      }
      throw FirebaseAuthException(
          code: e.code.name,
          message:
              'Google sign-in failed (${e.code.name}): ${e.description ?? ''}'
                  .trim());
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
          code: 'no-id-token',
          message: 'Google sign-in failed: no ID token returned.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    await _ensureProfile(result.user);
  }

  static String get _googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  /// Send a password-reset email to [email].
  static Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Turn an auth error into a short, human-friendly message. Returns null when
  /// the user simply cancelled (nothing to show).
  static String? authErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      // Keep the real code in the logs — the friendly text below deliberately
      // hides it, which makes field reports hard to diagnose otherwise.
      debugPrint('Auth error [${e.code}]: ${e.message}');
      switch (e.code) {
        case 'canceled':
        case 'web-context-canceled':
          return null; // user backed out of the flow
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password. Please try again.';
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support if that\'s a mistake.';
        case 'email-already-in-use':
          return 'An account with this email already exists — try signing in instead.';
        case 'weak-password':
          return 'Please pick a stronger password (at least 6 characters).';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'operation-not-allowed':
          return 'This sign-in method isn\'t available right now.';
        case 'account-exists-with-different-credential':
          return 'This email is already registered with a different sign-in method.';
        case 'missing-config':
        case 'no-id-token':
          return 'Google sign-in isn\'t available right now. Try email instead.';
        // google_sign_in surfaces platform failures through these codes. The
        // configuration ones mean this build's signing key has no OAuth client
        // registered — useless to the user, but say something actionable.
        case 'clientConfigurationError':
        case 'providerConfigurationError':
        case 'DEVELOPER_ERROR':
          return 'Google sign-in isn\'t set up for this version of the app. '
              'Please sign in with your email instead.';
        case 'uiUnavailable':
          return 'Google sign-in couldn\'t open. Please try again.';
        case 'interrupted':
          return 'Google sign-in was interrupted. Please try again.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    if (e.toString().toLowerCase().contains('cancel')) return null;
    return 'Something went wrong. Please try again.';
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Non-fatal — user may not have signed in with Google.
    }
    await _auth.signOut();
  }

  /// Create the profile document on first sign-in if it doesn't exist yet
  /// (replaces the Postgres `on_auth_user_created` trigger).
  static Future<void> _ensureProfile(User? user) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final fallbackName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName
        : (user.email?.split('@').first ?? 'Chef');
    // A creator code entered during onboarding is held locally until now,
    // because there is no profile to write it to before the account exists.
    final referral = await ReferralService.pending();

    await ref.set({
      'diet_mode': 'None',
      'display_name': fallbackName,
      'avatar_url': user.photoURL,
      'created_at': _nowIso(),
      if (referral != null) 'referral_code': referral,
    });

    if (referral != null) {
      await ReferralService.attachToRevenueCat(referral);
      await ReferralService.clearPending();
    }
  }

  /// Permanently delete the signed-in user's account and all their data.
  static Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    // 1. Delete every owned document across the user's subcollections.
    for (final name in const [
      'grocery_items',
      'pantry_items',
      'meal_plans',
      'recipes',
      'collections',
    ]) {
      final snap = await _col(name).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }
    await _userDoc.delete();

    // 2. Delete the auth user itself (may need a recent login).
    try {
      await user.delete();
    } catch (_) {
      // If it fails (requires-recent-login), data is already gone; sign out.
    }

    // 3. Sign out locally.
    await signOut();
  }

  // ─── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile() async {
    if (currentUserId == null) return null;
    final snap = await _userDoc.get();
    if (!snap.exists) return null;
    return _withId(snap);
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    await _userDoc.set(data, SetOptions(merge: true));
  }

  // ─── Recipes ───────────────────────────────────────────────────────────────

  static Future<List<Recipe>> getRecipes() async {
    if (currentUserId == null) return [];
    final snap =
        await _col('recipes').orderBy('created_at', descending: true).get();
    return snap.docs.map((d) => Recipe.fromJson(_withId(d))).toList();
  }

  static Future<Recipe?> getRecipe(String id) async {
    if (currentUserId == null) return null;
    final snap = await _col('recipes').doc(id).get();
    if (!snap.exists) return null;
    return Recipe.fromJson(_withId(snap));
  }

  static Future<String> saveRecipe(Recipe recipe) async {
    final data = recipe.toJson();
    data.remove('id');
    data['created_at'] = _nowIso();
    final ref = await _col('recipes').add(data);
    return ref.id;
  }

  static Future<void> updateRecipe(Recipe recipe) async {
    final data = recipe.toJson();
    data.remove('id');
    await _col('recipes').doc(recipe.id).update(data);
  }

  static Future<void> deleteRecipe(String id) async {
    await _col('recipes').doc(id).delete();
    // Also drop this recipe from any collection that referenced it.
    final cols =
        await _col('collections').where('recipe_ids', arrayContains: id).get();
    for (final c in cols.docs) {
      await c.reference.update({
        'recipe_ids': FieldValue.arrayRemove([id])
      });
    }
  }

  /// Set a recipe's favorite flag.
  static Future<void> setFavorite(String recipeId, bool value) async {
    if (currentUserId == null) return;
    await _col('recipes').doc(recipeId).update({'favorite': value});
  }

  // ─── Favorites (virtual default collection) ─────────────────────────────────
  //
  // "Favorites" is not a stored collection document: it is backed entirely by
  // the `favorite` flag on recipes, exposed through the collection APIs under
  // a sentinel id. That keeps the heart button and the collection permanently
  // in sync, makes Favorites exist for every user by default, and means it can
  // never be deleted or renamed.

  /// Sentinel id for the built-in Favorites collection.
  static const String favoritesCollectionId = '_favorites';

  static bool isFavoritesCollection(String id) => id == favoritesCollectionId;

  /// All recipes the user has hearted, newest first.
  static Future<List<Recipe>> getFavoriteRecipes() async {
    if (currentUserId == null) return [];
    final snap =
        await _col('recipes').where('favorite', isEqualTo: true).get();
    final recipes =
        snap.docs.map((d) => Recipe.fromJson(_withId(d))).toList();
    recipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recipes;
  }

  static Future<Collection> _favoritesAsCollection() async {
    int count = 0;
    try {
      final agg = await _col('recipes')
          .where('favorite', isEqualTo: true)
          .count()
          .get();
      count = agg.count ?? 0;
    } catch (_) {
      // Count is cosmetic; never let it break the collections list.
    }
    return Collection.fromJson({
      'id': favoritesCollectionId,
      'user_id': currentUserId,
      'name': 'Favorites',
      'recipe_count': count,
    });
  }

  // ─── Collections ───────────────────────────────────────────────────────────

  static Future<List<Collection>> getCollections() async {
    if (currentUserId == null) return [];
    final snap = await _col('collections')
        .orderBy('created_at', descending: true)
        .get();
    final stored = snap.docs.map((d) {
      final map = _withId(d);
      // Surface the join count the model expects.
      final ids = (map['recipe_ids'] as List?) ?? const [];
      map['recipe_count'] = ids.length;
      return Collection.fromJson(map);
    }).toList();
    // Favorites is always present, pinned first.
    return [await _favoritesAsCollection(), ...stored];
  }

  static Future<void> createCollection(String name) async {
    if (currentUserId == null) return;
    await _col('collections').add({
      'name': name,
      'cover_image': null,
      'recipe_ids': <String>[],
      'created_at': _nowIso(),
    });
  }

  static Future<void> addRecipeToCollection(
      String collectionId, String recipeId) async {
    if (isFavoritesCollection(collectionId)) {
      return setFavorite(recipeId, true);
    }
    await _col('collections').doc(collectionId).update({
      'recipe_ids': FieldValue.arrayUnion([recipeId])
    });
  }

  static Future<void> removeRecipeFromCollection(
      String collectionId, String recipeId) async {
    if (isFavoritesCollection(collectionId)) {
      return setFavorite(recipeId, false);
    }
    await _col('collections').doc(collectionId).update({
      'recipe_ids': FieldValue.arrayRemove([recipeId])
    });
  }

  static Future<List<Recipe>> getCollectionRecipes(String collectionId) async {
    if (isFavoritesCollection(collectionId)) return getFavoriteRecipes();
    final col = await _col('collections').doc(collectionId).get();
    if (!col.exists) return [];
    final ids = ((col.data()?['recipe_ids'] as List?) ?? const [])
        .cast<String>();
    if (ids.isEmpty) return [];
    // Firestore `whereIn` takes at most 10 values, so fetch in chunks.
    final recipes = <Recipe>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await _col('recipes')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      recipes.addAll(snap.docs.map((d) => Recipe.fromJson(_withId(d))));
    }
    return recipes;
  }

  static Future<List<String>> getRecipeCollectionIds(String recipeId) async {
    final snap = await _col('collections')
        .where('recipe_ids', arrayContains: recipeId)
        .get();
    final ids = snap.docs.map((d) => d.id).toList();
    // Include the virtual Favorites collection when the recipe is hearted.
    try {
      final recipe = await _col('recipes').doc(recipeId).get();
      if (recipe.data()?['favorite'] == true) {
        ids.insert(0, favoritesCollectionId);
      }
    } catch (_) {}
    return ids;
  }

  static Future<void> deleteCollection(String collectionId) async {
    if (isFavoritesCollection(collectionId)) return; // built-in, undeletable
    await _col('collections').doc(collectionId).delete();
  }

  // ─── Pantry ────────────────────────────────────────────────────────────────

  static Future<List<PantryItem>> getPantryItems() async {
    if (currentUserId == null) return [];
    final snap = await _col('pantry_items').orderBy('category').get();
    return snap.docs.map((d) => PantryItem.fromJson(_withId(d))).toList();
  }

  static Future<void> addPantryItem(PantryItem item) async {
    final data = item.toJson();
    data.remove('id');
    data['added_at'] = _nowIso();
    await _col('pantry_items').add(data);
  }

  static Future<void> deletePantryItem(String id) async {
    await _col('pantry_items').doc(id).delete();
  }

  // ─── Grocery ───────────────────────────────────────────────────────────────

  static Future<List<GroceryItem>> getGroceryItems() async {
    if (currentUserId == null) return [];
    final snap = await _col('grocery_items').orderBy('category').get();
    return snap.docs.map((d) => GroceryItem.fromJson(_withId(d))).toList();
  }

  static Future<void> addGroceryItem(GroceryItem item) async {
    final data = item.toJson();
    data.remove('id');
    data['created_at'] = _nowIso();
    await _col('grocery_items').add(data);
  }

  static Future<void> updateGroceryItem(GroceryItem item) async {
    await _col('grocery_items').doc(item.id).update({'checked': item.checked});
  }

  static Future<void> deleteGroceryItem(String id) async {
    await _col('grocery_items').doc(id).delete();
  }

  // ─── Meal Plans ────────────────────────────────────────────────────────────

  static Future<MealPlan?> getMealPlanForWeek(DateTime weekStart) async {
    if (currentUserId == null) return null;
    final dateStr = weekStart.toIso8601String().split('T').first;
    final snap = await _col('meal_plans').doc(dateStr).get();
    if (!snap.exists) return null;
    return MealPlan.fromJson(_withId(snap));
  }

  /// Upsert the week's plan. The document id is the week start date, so there's
  /// no lookup — a merge write creates or updates in one call.
  static Future<void> saveMealPlan(MealPlan plan) async {
    if (currentUserId == null) return;
    final dateStr = plan.weekStart.toIso8601String().split('T').first;
    final slotsJson = plan.toJson()['slots'];
    await _col('meal_plans').doc(dateStr).set({
      'week_start': dateStr,
      'slots': slotsJson,
      'created_at': _nowIso(),
    }, SetOptions(merge: true));
  }
}
