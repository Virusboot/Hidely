// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void updateBrowserUrl(String path) {
  try {
    final current = html.window.location.pathname ?? '';
    final hash = html.window.location.hash;
    if (current == path || hash == '#$path') return;
    html.window.history.pushState(null, '', path);
  } catch (_) {}
}

String getBrowserCurrentPath() {
  try {
    final path = html.window.location.pathname ?? '';
    final search = html.window.location.search ?? '';
    final hash = html.window.location.hash;

    // Check for hash routing like /#/explore
    if (hash.isNotEmpty && hash.startsWith('#/')) {
      final sub = hash.substring(1);
      if (sub.isNotEmpty && sub != '/') return sub;
    }

    if (path.isNotEmpty && path != '/') {
      return '$path$search';
    }
    return '/';
  } catch (_) {
    return '/';
  }
}
