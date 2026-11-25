import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_return.dart';

/// Opens the dismissible paywall. Sign-in is not on this path: a guest can
/// start the trial, and an account is offered only after the purchase.
///
/// [returnTo] is where a completed trial sends them — the session they
/// tapped, not Home. Dismissing the paywall pops back to wherever they were.
void openPaywall(
  BuildContext context, {
  required String source,
  String? returnTo,
}) {
  final here = GoRouterState.of(context).uri;
  if (here.path == '/paywall') return;
  final back = AuthReturn.sanitize(returnTo) ?? _here(here);
  final uri = Uri(
    path: '/paywall',
    queryParameters: {
      'source': source,
      if (back != null) 'returnTo': back,
    },
  );
  context.push(uri.toString());
}

/// Pushes sign-in and remembers [returnTo] so OAuth, which leaves the app,
/// can come back to the same screen.
void openSignIn(BuildContext context, {String? returnTo}) {
  final dest = AuthReturn.sanitize(returnTo) ?? _here(GoRouterState.of(context).uri);
  AuthReturn.rememberNow(dest);
  final uri = Uri(
    path: '/sign-in',
    queryParameters: {
      if (dest != null) 'returnTo': dest,
    },
  );
  context.push(uri.toString());
}

String? _here(Uri uri) {
  if (uri.path == '/sign-in' || uri.path == '/paywall') return null;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  return AuthReturn.sanitize('${uri.path}$query');
}
