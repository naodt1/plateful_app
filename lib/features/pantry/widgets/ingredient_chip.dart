import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/pantry_item.dart';

class IngredientChip extends StatelessWidget {
  final PantryItem item;
  final VoidCallback? onDelete;

  const IngredientChip({super.key, required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      child: Chip(
        label: Text(
          item.name,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary),
        ),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDelete,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.border),
        deleteIconColor: colors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }
}
