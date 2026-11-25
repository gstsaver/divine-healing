// GoRouter config — routes match Glide URL structure 1:1 for continuity.
//
// Shell (bottom nav) wraps Home / Library / Profile.
// Other screens push above the shell.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/splash/splash_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/chakras/chakras_screen.dart';
import 'features/reiki/reiki_screen.dart';
import 'features/breathing/breathing_screen.dart';
import 'features/affirmations/affirmations_screen.dart';
import 'features/spiritual_awakening/spiritual_awakening_screen.dart';
import 'features/manifestation/manifestation_screen.dart';
import 'features/content_detail/content_detail_screen.dart';
import 'features/shadow_work/shadow_work_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/legal/delete_account_screen.dart';
import 'features/legal/privacy_policy_screen.dart';
import 'features/legal/terms_of_service_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'services/analytics_route_observer.dart';
import 'services/auth_return.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    observers: [AnalyticsRouteObserver()],
    // Supabase auth redirects (success `?code=` and error `?error=`). The
    // SDK reads the code itself. On success we return to the screen the
    // person was on when they tapped Sign in, which [AuthReturn] saved
    // before the browser opened. A callback with nowhere to go still lands
    // on Home.
    redirect: (context, state) async {
      final params = state.uri.queryParameters;
      if (!params.containsKey('code') && !params.containsKey('error')) {
        return null;
      }
      final err = params['error_description'] ?? params['error'];
      if (err != null && err.isNotEmpty) {
        return '/sign-in?auth_error=${Uri.encodeComponent(err)}';
      }
      final back = await AuthReturn.take();
      return back ?? '/';
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Page not found'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => GoRouter.of(context).go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign_in',
        builder: (_, state) => SignInScreen(
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      // Dismissible, and above the shell, so the free tier stays reachable.
      // Raised from a locked tap, the first finished free session, or a
      // later launch — not from the first cold start. See MainShell.
      GoRoute(
        path: '/paywall',
        name: 'paywall',
        builder: (_, state) => PaywallScreen(
          source: state.uri.queryParameters['source'] ?? 'direct',
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),

      // ==================== Shell (bottom nav) ====================
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/library',
            name: 'library',
            builder: (_, state) => LibraryScreen(
              category: state.uri.queryParameters['category'],
            ),
            routes: [
              GoRoute(
                path: ':category',
                name: 'library_category',
                builder: (_, state) => LibraryScreen(
                  category: state.pathParameters['category'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ==================== Above-shell routes ====================
      GoRoute(
        path: '/content/:id',
        name: 'content_detail',
        builder: (_, state) => ContentDetailScreen(
          contentId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/chakras',
        name: 'chakras',
        builder: (_, __) => const ChakrasScreen(),
      ),
      GoRoute(
        path: '/reiki',
        name: 'reiki',
        builder: (_, __) => const ReikiScreen(),
      ),
      GoRoute(
        path: '/affirmations',
        name: 'affirmations',
        builder: (_, __) => const AffirmationsScreen(),
      ),
      GoRoute(
        path: '/breathing',
        name: 'breathing',
        builder: (_, __) => const BreathingScreen(),
      ),
      GoRoute(
        path: '/manifestation',
        name: 'manifestation',
        builder: (_, __) => const ManifestationScreen(),
      ),
      GoRoute(
        path: '/spiritual-awakening',
        name: 'spiritual_awakening',
        builder: (_, __) => const SpiritualAwakeningScreen(),
      ),
      GoRoute(
        path: '/shadow-work/:id',
        name: 'shadow_work',
        builder: (_, state) => ShadowWorkScreen(
          contentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/booking',
        name: 'booking',
        builder: (_, __) => const BookingScreen(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (_, __) => const TermsOfServiceScreen(),
      ),
      // Outside the shell and outside any sign-in check, on purpose: Play
      // requires an address that works for someone who has already
      // uninstalled the app.
      GoRoute(
        path: '/delete-account',
        name: 'delete_account',
        builder: (_, __) => const DeleteAccountScreen(),
      ),
    ],
  );
}
