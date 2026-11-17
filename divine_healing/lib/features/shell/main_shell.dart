import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/subscription_providers.dart';
import '../../services/purchases_service.dart';
import '../../theme.dart';

/// Raised once per launch, so someone who has already subscribed, or who just
/// dismissed it, is not asked again until the next cold start.
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
  static const _tabs = [
    _NavTab(label: 'Home',    icon: Icons.home_outlined,    activeIcon: Icons.home,           path: '/'),
    _NavTab(label: 'Library', icon: Icons.book_outlined,    activeIcon: Icons.book,           path: '/library'),
    _NavTab(label: 'Profile', icon: Icons.person_outline,   activeIcon: Icons.person,         path: '/profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPaywall());
  }

  /// On the first launch of a session, once the subscription status is known,
  /// raise the dismissible paywall over the home screen for anyone without
  /// full access. Waiting for the real answer here — rather than racing the
  /// home navigation from the splash — is what makes it reliable on slow
  /// devices. The home screen is already up, so the wait blocks nothing.
  Future<void> _maybeShowPaywall() async {
    if (_launchPaywallShown || !PurchasesService.isAvailable) return;
    try {
      final status = await ref.read(subscriptionStatusProvider.future);
      if (!mounted || status.hasFullAccess) return;
      _launchPaywallShown = true;
      if (context.mounted) context.push('/paywall');
    } catch (_) {
      // No status, no paywall — never block the app on this.
    }
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
