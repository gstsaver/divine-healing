import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/content_session.dart';
import '../../providers/audio_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/engagement_store.dart';
import '../../services/purchases_service.dart';
import '../../theme.dart';
import '../paywall/open_paywall.dart';

/// Raised once per later launch, so someone who has already subscribed, or
/// who just dismissed it, is not asked again until the next cold start.
/// The first cold start does not raise it at all.
bool _launchPaywallShown = false;

/// Bottom-nav shell wrapping Home / Library / Profile.
/// Admin tab intentionally omitted — client manages content via Glide web admin.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StreamSubscription<ContentSession>? _completedSub;

  static const _tabs = [
    _NavTab(label: 'Home',    icon: Icons.home_outlined,    activeIcon: Icons.home,           path: '/'),
    _NavTab(label: 'Library', icon: Icons.book_outlined,    activeIcon: Icons.book,           path: '/library'),
    _NavTab(label: 'Profile', icon: Icons.person_outline,   activeIcon: Icons.person,         path: '/profile'),
  ];

  @override
  void initState() {
    super.initState();
    _completedSub = ref
        .read(audioHandlerProvider)
        .onSessionCompleted
        .listen(_onSessionCompleted);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPaywall());
  }

  @override
  void dispose() {
    _completedSub?.cancel();
    super.dispose();
  }

  /// A later cold start, once the subscription status is known, raises the
  /// dismissible paywall for anyone without full access. The first launch
  /// does not: the person has not heard anything yet, and a paywall over a
  /// blank home is what the uninstalls were doing. Waiting for the real
  /// answer here — rather than racing the home navigation from the splash —
  /// is what makes it reliable on slow devices.
  Future<void> _maybeShowPaywall() async {
    if (_launchPaywallShown || !PurchasesService.isAvailable) return;
    if (EngagementStore.coldStarts < 2) return;
    try {
      final status = await ref.read(subscriptionStatusProvider.future);
      if (!mounted || status.hasFullAccess) return;
      _launchPaywallShown = true;
      if (context.mounted) {
        openPaywall(context, source: 'later_launch', returnTo: '/');
      }
    } catch (_) {
      // No status, no paywall — never block the app on this.
    }
  }

  /// The first free session finishing is the other moment the paywall is
  /// allowed to appear, including on the first launch.
  Future<void> _onSessionCompleted(ContentSession session) async {
    AnalyticsService.instance.logSessionComplete(
      contentId: session.id.toString(),
      title: session.title,
      isPreview: session.isPreview,
    );
    if (!mounted || ref.read(hasFullAccessProvider) || !session.isPreview) {
      return;
    }
    final first = await EngagementStore.noteFreeCompletion();
    if (!first || !mounted) return;
    if (GoRouterState.of(context).uri.path == '/paywall') return;
    final returnTo = session.category == 'shadow_work'
        ? '/shadow-work/${session.id}'
        : '/content/${session.id}';
    openPaywall(
      context,
      source: 'first_free_session',
      returnTo: returnTo,
    );
  }

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/library')) return 1;
    if (loc.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: DHColors.sageMist,
        height: 60,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: DHColors.mossGreen, size: 22),
              selectedIcon:
                  Icon(t.activeIcon, color: DHColors.forestGreen, size: 22),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
}
