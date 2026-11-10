import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hidely_new/screens/creator_profile_screen.dart';
import 'package:hidely_new/screens/user_profile_screen.dart';
import 'package:hidely_new/services/auth_service.dart';

/// Renders text (captions or comments) with clickable, styled `@username` mentions,
/// safely managing and disposing all [TapGestureRecognizer] instances.
class MentionText extends StatefulWidget {
  final String text;
  final String? prefixUsername;
  final TextStyle? prefixStyle;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final VoidCallback? onPrefixTap;
  final ValueChanged<String>? onMentionTap;

  const MentionText({
    super.key,
    required this.text,
    this.prefixUsername,
    this.prefixStyle,
    this.style,
    this.mentionStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onPrefixTap,
    this.onMentionTap,
  });

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  static final RegExp _mentionRegex = RegExp(r'@([a-zA-Z0-9_.]{1,50})');
  static final RegExp _wordCharRegex = RegExp(r'[a-zA-Z0-9_.]');

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _handleDefaultProfileTap(String username) {
    final clean = username.trim().replaceFirst(RegExp(r'^@+'), '');
    if (clean.isEmpty) return;

    final currentUsername = AuthService().userUsername.trim();
    if (currentUsername.isNotEmpty &&
        clean.toLowerCase() == currentUsername.toLowerCase()) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserProfileScreen()),
      );
      return;
    }

    if (AuthService().isUserBlockedSync(clean)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This profile is unavailable.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorProfileScreen(
          username: clean,
          avatarPath: 'assets/images/nomad_nate_avatar.png',
          rank: 'Explorer',
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(
    TextStyle baseStyle,
    TextStyle prefixTextStyle,
    TextStyle highlightStyle,
  ) {
    _disposeRecognizers();
    final List<InlineSpan> spans = <InlineSpan>[];

    final prefix = widget.prefixUsername;
    if (prefix != null && prefix.isNotEmpty) {
      TapGestureRecognizer? prefixRecognizer;
      if (widget.onPrefixTap != null || widget.onMentionTap != null) {
        prefixRecognizer = TapGestureRecognizer()
          ..onTap = widget.onPrefixTap ??
              () => (widget.onMentionTap ?? _handleDefaultProfileTap)(prefix);
        _recognizers.add(prefixRecognizer);
      }
      spans.add(
        TextSpan(
          text: '$prefix  ',
          style: prefixTextStyle,
          recognizer: prefixRecognizer,
        ),
      );
    }

    final src = widget.text;
    if (src.isEmpty) return spans;

    int cursor = 0;
    for (final match in _mentionRegex.allMatches(src)) {
      // Ignore email addresses like name@domain.com
      if (match.start > 0 && _wordCharRegex.hasMatch(src[match.start - 1])) {
        continue;
      }

      String rawHandle = match.group(1) ?? '';
      // Strip trailing punctuation dots such as "@alice."
      final trimmedHandle = rawHandle.replaceFirst(RegExp(r'\.+$'), '');
      if (trimmedHandle.isEmpty) {
        continue;
      }

      final int handleEnd = match.start + 1 + trimmedHandle.length;
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: src.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final String tokenText = src.substring(match.start, handleEnd);
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          if (widget.onMentionTap != null) {
            widget.onMentionTap!(trimmedHandle);
          } else {
            _handleDefaultProfileTap(trimmedHandle);
          }
        };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: tokenText,
          style: highlightStyle,
          recognizer: recognizer,
        ),
      );

      cursor = handleEnd;
    }

    if (cursor < src.length) {
      spans.add(
        TextSpan(
          text: src.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        const TextStyle(
          color: Colors.black54,
          fontSize: 13.5,
          height: 1.25,
        );
    final prefixTextStyle = widget.prefixStyle ??
        const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 14,
        );
    final highlightStyle = widget.mentionStyle ??
        baseStyle.copyWith(
          color: const Color(0xff5D3EBC),
          fontWeight: FontWeight.w600,
        );

    final spans = _buildSpans(baseStyle, prefixTextStyle, highlightStyle);

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
