import 'package:flutter/foundation.dart';

/// Centralized Security Service providing data sanitization,
/// release-mode log stripping, and app hardening helpers.
class SecurityService {
  SecurityService._internal();
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;

  /// Secure logger that automatically suppresses sensitive output in production builds
  static void safeLog(String message, {bool isSensitive = false}) {
    if (kDebugMode && !isSensitive) {
      debugPrint('[SECURITY_LOG] $message');
    }
  }

  /// Sanitizes raw user input strings against XSS script injection and malicious characters
  static String sanitizeInput(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll(RegExp(r'<script.*?>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  /// Masks email addresses for privacy display (e.g. user@example.com -> u***@example.com)
  static String maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}@$domain';
  }

  /// Validates password strength (minimum 6 characters, non-trivial)
  static bool isStrongPassword(String password) {
    if (password.length < 6) return false;
    // Check if not simple sequence like 123456
    final weak = ['123456', 'password', 'qwerty', '12345678', '111111'];
    return !weak.contains(password.toLowerCase());
  }
}
