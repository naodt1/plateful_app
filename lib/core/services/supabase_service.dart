/*
SQL Schema (run in Supabase SQL Editor):

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- profiles
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  diet_mode text default 'None',
  avatar_url text,
  display_name text,
  created_at timestamptz default now()
);

-- recipes
create table if not exists recipes (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  title text not null,
  description text default '',
  image_url text,
  source_url text,
  source_type text default 'manual',
  ingredients jsonb default '[]',
  steps jsonb default '[]',
  nutrition jsonb,
  tags text[] default '{}',
  servings int default 4,
  created_at timestamptz default now()
);

-- collections
create table if not exists collections (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  cover_image text,
  created_at timestamptz default now()
);

-- collection_recipes
create table if not exists collection_recipes (
  collection_id uuid references collections on delete cascade,
  recipe_id uuid references recipes on delete cascade,
  primary key (collection_id, recipe_id)
);

-- pantry_items
create table if not exists pantry_items (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  category text default 'Other',
  quantity text default '',
  added_at timestamptz default now()
);

-- meal_plans
create table if not exists meal_plans (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  week_start date not null,
  slots jsonb default '{}',
  created_at timestamptz default now()
);

-- grocery_items
create table if not exists grocery_items (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  category text default 'Other',
  quantity text default '',
  checked boolean default false,
  recipe_id uuid references recipes on delete set null,
  created_at timestamptz default now()
);

-- Enable RLS
alter table profiles enable row level security;
alter table recipes enable row level security;
alter table collections enable row level security;
alter table collection_recipes enable row level security;
alter table pantry_items enable row level security;
alter table meal_plans enable row level security;
alter table grocery_items enable row level security;

-- RLS policies
create policy "Users can manage own profile" on profiles for all using (auth.uid() = id);
create policy "Users can manage own recipes" on recipes for all using (auth.uid() = user_id);
create policy "Users can manage own collections" on collections for all using (auth.uid() = user_id);
create policy "Users can manage own collection recipes" on collection_recipes
  for all using (collection_id in (select id from collections where user_id = auth.uid()));
create policy "Users can manage own pantry" on pantry_items for all using (auth.uid() = user_id);
create policy "Users can manage own meal plans" on meal_plans for all using (auth.uid() = user_id);
create policy "Users can manage own grocery" on grocery_items for all using (auth.uid() = user_id);

-- Auto-create profile on signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
*/

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/recipe.dart';
import '../../models/pantry_item.dart';
import '../../models/grocery_item.dart';
import '../../models/collection.dart';
import '../../models/meal_plan.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;

  // ─── Auth ──────────────────────────────────────────────────────────────────

  static Future<AuthResponse> signUpWithEmail(String email, String password) =>
      client.auth.signUp(email: email, password: password);

  static Future<AuthResponse> signInWithEmail(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(OAuthProvider.google);
  }

  static Future<void> signOut() => client.auth.signOut();

  // ─── Profile ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final response = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await client.from('profiles').upsert({'id': userId, ...data});
  }

  // ─── Recipes ───────────────────────────────────────────────────────────────

  static Future<List<Recipe>> getRecipes() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await client
        .from('recipes')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Recipe.fromJson(e)).toList();
  }

  static Future<Recipe?> getRecipe(String id) async {
    final response =
        await client.from('recipes').select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return Recipe.fromJson(response);
  }

  static Future<String> saveRecipe(Recipe recipe) async {
    final data = recipe.toJson();
    data.remove('id');
    final response =
        await client.from('recipes').insert(data).select('id').single();
    return response['id'] as String;
  }

  static Future<void> updateRecipe(Recipe recipe) async {
    await client.from('recipes').update(recipe.toJson()).eq('id', recipe.id);
  }

  static Future<void> deleteRecipe(String id) async {
    await client.from('recipes').delete().eq('id', id);
  }

  // ─── Collections ───────────────────────────────────────────────────────────

  static Future<List<Collection>> getCollections() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await client
        .from('collections')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Collection.fromJson(e)).toList();
  }

  static Future<void> createCollection(String name) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await client.from('collections').insert({'user_id': userId, 'name': name});
  }

  static Future<void> addRecipeToCollection(
      String collectionId, String recipeId) async {
    await client.from('collection_recipes').upsert({
      'collection_id': collectionId,
      'recipe_id': recipeId,
    });
  }

  static Future<void> removeRecipeFromCollection(
      String collectionId, String recipeId) async {
    await client
        .from('collection_recipes')
        .delete()
        .eq('collection_id', collectionId)
        .eq('recipe_id', recipeId);
  }

  static Future<List<Recipe>> getCollectionRecipes(String collectionId) async {
    final response = await client
        .from('collection_recipes')
        .select('recipe_id, recipes(*)')
        .eq('collection_id', collectionId);
    return (response as List)
        .map((e) => Recipe.fromJson(e['recipes'] as Map<String, dynamic>))
        .toList();
  }

  static Future<List<String>> getRecipeCollectionIds(String recipeId) async {
    final response = await client
        .from('collection_recipes')
        .select('collection_id')
        .eq('recipe_id', recipeId);
    return (response as List)
        .map((e) => e['collection_id'] as String)
        .toList();
  }

  static Future<void> deleteCollection(String collectionId) async {
    await client.from('collections').delete().eq('id', collectionId);
  }

  // ─── Pantry ────────────────────────────────────────────────────────────────

  static Future<List<PantryItem>> getPantryItems() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await client
        .from('pantry_items')
        .select()
        .eq('user_id', userId)
        .order('category');
    return (response as List).map((e) => PantryItem.fromJson(e)).toList();
  }

  static Future<void> addPantryItem(PantryItem item) async {
    final data = item.toJson();
    data.remove('id');
    await client.from('pantry_items').insert(data);
  }

  static Future<void> deletePantryItem(String id) async {
    await client.from('pantry_items').delete().eq('id', id);
  }

  // ─── Grocery ───────────────────────────────────────────────────────────────

  static Future<List<GroceryItem>> getGroceryItems() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await client
        .from('grocery_items')
        .select()
        .eq('user_id', userId)
        .order('category');
    return (response as List).map((e) => GroceryItem.fromJson(e)).toList();
  }

  static Future<void> addGroceryItem(GroceryItem item) async {
    final data = item.toJson();
    data.remove('id');
    await client.from('grocery_items').insert(data);
  }

  static Future<void> updateGroceryItem(GroceryItem item) async {
    await client
        .from('grocery_items')
        .update({'checked': item.checked}).eq('id', item.id);
  }

  static Future<void> deleteGroceryItem(String id) async {
    await client.from('grocery_items').delete().eq('id', id);
  }

  // ─── Meal Plans ────────────────────────────────────────────────────────────

  static Future<MealPlan?> getMealPlanForWeek(DateTime weekStart) async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final dateStr = weekStart.toIso8601String().split('T').first;
    final response = await client
        .from('meal_plans')
        .select()
        .eq('user_id', userId)
        .eq('week_start', dateStr)
        .maybeSingle();
    if (response == null) return null;
    return MealPlan.fromJson(response);
  }

  /// Saves the week's plan. Looks up an existing row by (user_id, week_start)
  /// and updates it; otherwise inserts a fresh row (letting Postgres generate
  /// the uuid). This avoids sending a client-side non-uuid id.
  static Future<void> saveMealPlan(MealPlan plan) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final dateStr = plan.weekStart.toIso8601String().split('T').first;

    final slotsJson = plan.toJson()['slots'];

    final existing = await client
        .from('meal_plans')
        .select('id')
        .eq('user_id', userId)
        .eq('week_start', dateStr)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('meal_plans')
          .update({'slots': slotsJson})
          .eq('id', existing['id']);
    } else {
      await client.from('meal_plans').insert({
        'user_id': userId,
        'week_start': dateStr,
        'slots': slotsJson,
      });
    }
  }
}
