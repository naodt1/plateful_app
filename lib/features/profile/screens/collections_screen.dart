import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/collection.dart';

final _collectionsDetailProvider = FutureProvider.autoDispose<List<Collection>>((ref) {
  return SupabaseService.getCollections();
});

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(_collectionsDetailProvider);

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        title: Text('Collections', style: AppTextStyles.headingMedium),
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No collections yet',
              subtitle: 'Organize your saved recipes into collections.',
              ctaLabel: 'Create Collection',
              onCta: () => _showCreateDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final col = collections[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.of(context).border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  onTap: () => context.push(
                      '/collections/${col.id}?name=${Uri.encodeComponent(col.name)}'),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.collections_bookmark,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(col.name,
                      style: TextStyle(
                          color: AppColors.of(context).textPrimary, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.arrow_forward_ios,
                      color: AppColors.of(context).textSecondary, size: 14),
                ),
              );
            },
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonLoader(
                width: double.infinity, height: 70, borderRadius: 16),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.bodySmall),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('New Collection', style: AppTextStyles.headingMedium),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Collection name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await SupabaseService.createCollection(controller.text.trim());
                ref.invalidate(_collectionsDetailProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
