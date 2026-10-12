import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hidely_new/services/api_service.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;
  final double? fontSize;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.radius = 20,
    this.fontSize,
    this.backgroundColor,
    this.textColor,
  });

  static final List<List<Color>> _avatarGradients = [
    [const Color(0xff6366F1), const Color(0xff8B5CF6)], // Indigo - Purple
    [const Color(0xffEC4899), const Color(0xffF43F5E)], // Pink - Rose
    [const Color(0xff3B82F6), const Color(0xff06B6D4)], // Blue - Cyan
    [const Color(0xff10B981), const Color(0xff059669)], // Emerald - Green
    [const Color(0xffF59E0B), const Color(0xffD97706)], // Amber - Orange
    [const Color(0xff8B5CF6), const Color(0xffD946EF)], // Purple - Fuchsia
    [const Color(0xff14B8A6), const Color(0xff0D9488)], // Teal
    [const Color(0xffF97316), const Color(0xffEA580C)], // Orange
  ];

  static String _extractInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final f = parts[0].isNotEmpty ? parts[0][0] : '';
      final s = parts[1].isNotEmpty ? parts[1][0] : '';
      return '$f$s'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final double diameter = radius * 2;

    // Stylish colorful gradient initials fallback
    final int colorIndex = displayName.hashCode.abs() % _avatarGradients.length;
    final gradient = _avatarGradients[colorIndex];
    final initials = _extractInitials(displayName);

    Widget fallbackChild = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize ?? (radius * 0.76),
          fontWeight: FontWeight.bold,
          fontFamily: 'PublicSans',
        ),
      ),
    );

    if (!hasImage) {
      return ClipOval(child: fallbackChild);
    }

    final String trimmedUrl = avatarUrl!.trim();
    String resolvedUrl = trimmedUrl;
    if (trimmedUrl.startsWith('http')) {
      if (trimmedUrl.contains('localhost') || trimmedUrl.contains('127.0.0.1')) {
        try {
          final uri = Uri.parse(trimmedUrl);
          final baseUri = Uri.parse(ApiService().baseUrl);
          resolvedUrl = uri.replace(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : null,
          ).toString();
        } catch (_) {}
      }
    } else {
      resolvedUrl = '${ApiService().baseUrl}/${trimmedUrl.startsWith('/') ? trimmedUrl.substring(1) : trimmedUrl}';
    }

    // On Flutter Web, use Image.network to prevent CanvasKit black texture rendering bugs
    if (kIsWeb) {
      return ClipOval(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Image.network(
            resolvedUrl,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) => fallbackChild,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(color: const Color(0xffE2E8F0));
            },
          ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CachedNetworkImage(
          imageUrl: resolvedUrl,
          fit: BoxFit.cover,
          memCacheWidth: (diameter * 2.5).clamp(60, 300).toInt(),
          alignment: Alignment.center,
          placeholder: (context, url) => Container(color: const Color(0xffE2E8F0)),
          errorWidget: (context, url, error) => fallbackChild,
        ),
      ),
    );
  }
}
