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
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final bg = backgroundColor ?? const Color(0xff2B1564); // Theme primary dark purple
    final tc = textColor ?? Colors.white;

    return CircleAvatar(
      radius: radius,
      backgroundColor: hasImage ? const Color(0xffCBD5E1) : bg,
      backgroundImage: hasImage
          ? NetworkImage(avatarUrl!.trim().startsWith('http') ? avatarUrl!.trim() : '${ApiService().baseUrl}/${avatarUrl!.trim()}') as ImageProvider
          : null,
      child: !hasImage
          ? Text(
              initial,
              style: TextStyle(
                color: tc,
                fontSize: fontSize ?? (radius * 0.75),
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}
