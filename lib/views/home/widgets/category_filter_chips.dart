import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/pdf_tool_item.dart';

class CategoryFilterChips extends StatelessWidget {
  final ToolCategory selectedCategory;
  final ValueChanged<ToolCategory> onSelected;

  const CategoryFilterChips({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: ToolCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = ToolCategory.values[index];
          final isSelected = selectedCategory == cat;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              cat.icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            label: Text(
              cat.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            backgroundColor: Colors.white,
            selectedColor: AppColors.primaryRed,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.primaryRed : AppColors.cardBorder,
              ),
            ),
            onSelected: (_) => onSelected(cat),
          );
        },
      ),
    );
  }
}
