import 'package:flutter/material.dart';
import '../../config/config.dart';

class FilterCategory {
  final String id;
  final String label;
  final IconData icon;

  const FilterCategory({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Modular category filter bar widget for MapScreen.
class MapFilterChips extends StatelessWidget {
  final List<FilterCategory> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const MapFilterChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final isSelected = cat.id == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(
                cat.icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.primaryDark,
              ),
              label: Text(
                cat.label,
                style: TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.primaryDark,
                ),
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 1,
                ),
              ),
              onSelected: (_) => onCategorySelected(cat.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}
