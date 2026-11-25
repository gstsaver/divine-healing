import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// Sends GoRouter screen names to Firebase Analytics.
///
/// GoRouter puts each route's `name` on the [RouteSettings] the navigator
/// reports. Dialogs have no name and are ignored. Logging goes through
/// [AnalyticsService], so this is a no-op until Firebase is configured.
class AnalyticsRouteObserver extends NavigatorObserver {
  void _send(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    AnalyticsService.instance.logScreen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _send(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _send(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _send(previousRoute);
  }
}
