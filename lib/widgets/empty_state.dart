import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  /// Factory for Error State with Retry Button
  factory EmptyStateWidget.error({
    Key? key,
    String title = "Connection Error",
    String description = "Failed to load content. Please check your connection and try again.",
    required VoidCallback onRetry,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.wifi_off_rounded,
      title: title,
      description: description,
      actionLabel: "Tap to Retry",
      onAction: onRetry,
      isError: true,
    );
  }

  /// Factory for Centered Loading UI
  factory EmptyStateWidget.loading({
    Key? key,
    String message = "Loading...",
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.sync_rounded,
      title: message,
      description: "Please wait a moment while we fetch your content.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isError ? Colors.redAccent : const Color(0xff1C0D5A);
    final buttonBg = isError ? const Color(0xFFDC2626) : const Color(0xff2B1564);

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isError ? Colors.red.shade50 : primaryColor.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: isError ? Colors.redAccent : primaryColor.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor.withOpacity(0.6),
                fontSize: 13,
                height: 1.3,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(
                  isError ? Icons.refresh_rounded : Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
