import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/error_messages.dart';
import '../../../models/collection.dart';

/// Bottom sheet to add/remove a recipe from collections. Reusable — used from
/// the import success screen and anywhere a quick "add to collection" is handy.
Future<void> showCollectionPicker(BuildContext context, String recipeId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CollectionPickerSheet(recipeId: recipeId),
  );
}

class CollectionPickerSheet extends StatefulWidget {
  final String recipeId;
  const CollectionPickerSheet({super.key, required this.recipeId});

  @override
  State<CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<CollectionPickerSheet> {
  List<Collection>? _collections;
  Set<String> _alreadyIn = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final collections = await FirebaseService.getCollections();
      final ids = await FirebaseService.getRecipeCollectionIds(widget.recipeId);
      if (mounted) {
        setState(() {
          _collections = collections;
          _alreadyIn = ids.toSet();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Collection col) async {
    final inCol = _alreadyIn.contains(col.id);
    setState(() =>
        inCol ? _alreadyIn.remove(col.id) : _alreadyIn.add(col.id));
    try {
      if (inCol) {
        await FirebaseService.removeRecipeFromCollection(col.id, widget.recipeId);
      } else {
        await FirebaseService.addRecipeToCollection(col.id, widget.recipeId);
      }
    } catch (e) {
      setState(() =>
          inCol ? _alreadyIn.add(col.id) : _alreadyIn.remove(col.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _createAndAdd() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Collection name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await FirebaseService.createCollection(name);
    await _load();
    final created = (_collections ?? []).where((c) => c.name == name).toList();
    if (created.isNotEmpty) await _toggle(created.last);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final collections = _collections ?? [];
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Add to collection', style: AppTextStyles.headingMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _createAndAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (collections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text('No collections yet — tap “New” to create one.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary)),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: collections.map((c) {
                  final inCol = _alreadyIn.contains(c.id);
                  final isFavorites =
                      FirebaseService.isFavoritesCollection(c.id);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _toggle(c),
                    leading: Icon(
                      inCol ? Icons.check_circle : Icons.circle_outlined,
                      color: inCol ? AppColors.primary : colors.textSecondary,
                    ),
                    title: Text(c.name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: colors.textPrimary)),
                    trailing: isFavorites
                        ? const Icon(Icons.favorite,
                            size: 16, color: Color(0xFFE5533D))
                        : null,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
