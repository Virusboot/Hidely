import 'package:flutter/material.dart';
import 'package:hidely_new/models/gamification_models.dart';
import 'package:hidely_new/services/api_service.dart';

class BadgeDetailDialog extends StatefulWidget {
  final BadgeModel badge;
  final VoidCallback? onFeaturedChanged;

  const BadgeDetailDialog({
    super.key,
    required this.badge,
    this.onFeaturedChanged,
  });

  static Future<void> show(BuildContext context, BadgeModel badge, {VoidCallback? onFeaturedChanged}) {
    return showDialog(
      context: context,
      builder: (ctx) => BadgeDetailDialog(badge: badge, onFeaturedChanged: onFeaturedChanged),
    );
  }

  @override
  State<BadgeDetailDialog> createState() => _BadgeDetailDialogState();
}

class _BadgeDetailDialogState extends State<BadgeDetailDialog> {
  bool _isUpdating = false;
  late bool _isFeatured;

  @override
  void initState() {
    super.initState();
    _isFeatured = widget.badge.isFeatured;
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toUpperCase()) {
      case 'LEGENDARY':
        return const Color(0xffFFB800);
      case 'EPIC':
        return const Color(0xffA855F7);
      case 'RARE':
        return const Color(0xff3B82F6);
      case 'UNCOMMON':
        return const Color(0xff10B981);
      default:
        return const Color(0xff64748B);
    }
  }

  IconData _getBadgeIcon(String icon) {
    switch (icon.toLowerCase()) {
      case 'compass':
        return Icons.explore_rounded;
      case 'boot':
        return Icons.directions_walk_rounded;
      case 'map':
        return Icons.map_rounded;
      case 'globe':
        return Icons.public_rounded;
      case 'tent':
        return Icons.cabin_rounded;
      case 'mountain':
        return Icons.landscape_rounded;
      case 'search':
        return Icons.travel_explore_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'crown':
        return Icons.workspace_premium_rounded;
      case 'trophy':
        return Icons.emoji_events_rounded;
      case 'sparkles':
        return Icons.auto_awesome_rounded;
      case 'target':
        return Icons.gps_fixed_rounded;
      case 'camera':
        return Icons.photo_camera_rounded;
      case 'shield':
        return Icons.verified_user_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Future<void> _toggleFeatured() async {
    setState(() => _isUpdating = true);
    final targetBadgeId = _isFeatured ? null : widget.badge.id;
    final res = await ApiService().setFeaturedBadge(targetBadgeId);
    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (res.success) {
          _isFeatured = !_isFeatured;
        }
      });
      if (res.success) {
        widget.onFeaturedChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: const Color(0xff2B1564)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(widget.badge.rarity);
    final iconData = _getBadgeIcon(widget.badge.icon);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rarity Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: rarityColor.withOpacity(0.4), width: 1),
              ),
              child: Text(
                widget.badge.rarity.toUpperCase(),
                style: TextStyle(
                  color: rarityColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Badge Icon Circle with Glow
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [rarityColor.withOpacity(0.2), rarityColor.withOpacity(0.05)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 42,
                  color: widget.badge.isEarned ? rarityColor : Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Badge Name
            Text(
              widget.badge.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xff1C0D5A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Badge Description
            Text(
              widget.badge.description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xff64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Earned Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: widget.badge.isEarned ? const Color(0xffF0FDF4) : const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.badge.isEarned ? const Color(0xffBBF7D0) : const Color(0xffE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.badge.isEarned ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                    size: 18,
                    color: widget.badge.isEarned ? const Color(0xff166534) : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.badge.isEarned ? "Badge Unlocked & Earned!" : "Locked — Keep Exploring!",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.badge.isEarned ? const Color(0xff166534) : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Set as Featured Toggle Button
            if (widget.badge.isEarned)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _toggleFeatured,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFeatured ? const Color(0xffF1F5F9) : const Color(0xff2B1564),
                    foregroundColor: _isFeatured ? const Color(0xff1C0D5A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(_isFeatured ? Icons.star_rounded : Icons.star_border_rounded),
                  label: Text(
                    _isFeatured ? "Featured on Profile" : "Set as Featured Badge",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
