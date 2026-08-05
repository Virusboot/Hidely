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

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final bg = backgroundColor ?? const Color(0xffEFEFEF); // Light grey like instagram
    final tc = textColor ?? const Color(0xff9E9E9E); // Grey icon
    
    final double diameter = radius * 2;
    final double iconSize = fontSize ?? (radius * 1.2);

    Widget fallbackChild = Container(
      width: diameter,
      height: diameter,
      color: bg,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: tc,
        size: iconSize,
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

    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("Error loading avatar image ($resolvedUrl): $error");
            return fallbackChild;
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xffCBD5E1),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
