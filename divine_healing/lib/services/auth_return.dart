import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Where to send someone after sign-in.
///
/// OAuth and magic links leave the app and come back through a deep link.
/// The router used to drop that return on `/`, so a person who started from
/// a locked session landed on Home. The location is kept in memory for the
/// common case and in preferences for the case where the process is killed
/// while the browser is open.
class AuthReturn {
  AuthReturn._();

  static const _key = 'dh_auth_return';
  static String? _memory;

  /// A path we are willing to navigate to. Anything with a scheme, an auth
  /// callback, or the sign-in screen itself is refused so a redirect cannot
  /// loop.
  static String? sanitize(String? location) {
    if (location == null) return null;
    final trimmed = location.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('/') || trimmed.startsWith('//')) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.hasScheme) return null;
    const blocked = {'/sign-in', '/splash', '/login-callback'};
    if (blocked.contains(uri.path)) return null;
    final params = uri.queryParameters;
    if (params.containsKey('code') ||
        params.containsKey('error') ||
        params.containsKey('auth_error')) {
      return null;
    }
    return trimmed;
  }

  /// Remembers [location] and waits until it is written. Call this before
  /// opening a browser, so a killed process can still come back here.
  static Future<void> remember(String? location) async {
    _memory = sanitize(location);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_memory == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, _memory!);
      }
    } catch (_) {
      // The in-memory value still covers a sign-in that never leaves the app.
    }
  }

  /// Same as [remember], without waiting. Enough for a tap that only pushes
  /// the sign-in screen — the write finishes while that screen is open.
  static void rememberNow(String? location) {
    unawaited(remember(location));
  }

  /// Reads and clears the saved location. The router calls this once, when
  /// an auth callback arrives.
  static Future<String?> take() async {
    var value = _memory;
    _memory = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      value ??= prefs.getString(_key);
      await prefs.remove(_key);
    } catch (_) {}
    return sanitize(value);
  }

  static Future<void> clear() async {
    _memory = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
