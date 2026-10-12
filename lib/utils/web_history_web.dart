// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void updateBrowserUrl(String path) {
  try {
    html.window.localStorage['hidely_active_route'] = path;
    html.window.sessionStorage['hidely_active_route'] = path;
    
    final current = html.window.location.pathname ?? '';
    final search = html.window.location.search ?? '';
    final fullCurrent = '$current$search';
    final hash = html.window.location.hash;
    
    if (fullCurrent == path || hash == '#$path') return;
    html.window.history.pushState(null, '', path);
  } catch (_) {}
}

String getBrowserCurrentPath() {
  try {
    String path = html.window.location.pathname ?? '';
    final search = html.window.location.search ?? '';
    final hash = html.window.location.hash;

    // Check for hash routing like /#/explore
    if (hash.isNotEmpty && hash.startsWith('#/')) {
      final sub = hash.substring(1);
      if (sub.isNotEmpty && sub != '/') return _cleanPath(sub);
    }

    if (path.isNotEmpty && path != '/') {
      return _cleanPath('$path$search');
    }

    // Fallback to localStorage or sessionStorage if browser pathname is root
    final sessionPath = html.window.sessionStorage['hidely_active_route'];
    if (sessionPath != null && sessionPath.isNotEmpty && sessionPath != '/') {
      return _cleanPath(sessionPath);
    }

    final localPath = html.window.localStorage['hidely_active_route'];
    if (localPath != null && localPath.isNotEmpty && localPath != '/') {
      return _cleanPath(localPath);
    }

    return '/';
  } catch (_) {
    return '/';
  }
}

String _cleanPath(String p) {
  var trimmed = p.trim();
  // Strip trailing slash if present unless it is just '/'
  if (trimmed.length > 1 && trimmed.endsWith('/') && !trimmed.contains('?')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

void listenToPopState(void Function(String path) onRouteChanged) {
  try {
    html.window.onPopState.listen((event) {
      final current = getBrowserCurrentPath();
      onRouteChanged(current);
    });
  } catch (_) {}
}
