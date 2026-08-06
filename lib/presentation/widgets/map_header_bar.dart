import 'package:flutter/material.dart';
import '../../config/config.dart';

/// Modular search header and mode selector for MapScreen.
class MapHeaderBar extends StatelessWidget {
  final TextEditingController searchController;
  final bool isListening;
  final String searchPlaceholder;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onVoicePressed;
  final VoidCallback? onBackPressed;
  final bool isPushed;

  const MapHeaderBar({
    super.key,
    required this.searchController,
    required this.isListening,
    required this.searchPlaceholder,
    required this.onSearchSubmitted,
    required this.onVoicePressed,
    this.onBackPressed,
    this.isPushed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isPushed)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryDark, size: 18),
              onPressed: onBackPressed ?? () => Navigator.maybePop(context),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(Icons.search_rounded, color: AppColors.primaryDark),
            ),
          Expanded(
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  onSearchSubmitted(value.trim());
                }
              },
              style: const TextStyle(
                fontFamily: 'PublicSans',
                color: AppColors.primaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: searchPlaceholder,
                hintStyle: TextStyle(
                  fontFamily: 'PublicSans',
                  color: AppColors.textMuted.withOpacity(0.8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none_rounded,
              color: isListening ? AppColors.error : AppColors.primaryDark,
            ),
            onPressed: onVoicePressed,
          ),
        ],
      ),
    );
  }
}
