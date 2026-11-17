import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/subscription_providers.dart';
import '../../services/purchases_service.dart';
import '../../theme.dart';

/// Shown once per launch, so someone who has already subscribed, or who just
/// dismissed it, is not asked again until the next cold start.
bool _paywallShownThisLaunch = false;

/// Splash — near-white blush background so the tree-of-life logo (which is
/// designed on a white ground) reads clearly. A soft fade + gentle scale
/// on the logo gives a moment of stillness before the app opens.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _openApp();
  }

  /// After the splash pause, open the app. If this is a mobile store build and
  /// the person is not subscribed, raise the dismissible paywall over the home
  /// screen — once per launch. A failure to read the status, or a slow network,
  /// just skips the paywall rather than holding the splash open.
  Future<void> _openApp() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    var showPaywall = false;
    if (PurchasesService.isAvailable && !_paywallShownThisLaunch) {
      try {
        final status = await ref
            .read(subscriptionStatusProvider.future)
            .timeout(const Duration(seconds: 3));
        showPaywall = !status.hasFullAccess;
      } catch (_) {
        showPaywall = false;
      }
    }
    if (!mounted) return;

    // Capture the router before navigating: go('/') replaces this splash, so
    // its own context may be defunct by the time we push the paywall.
    final router = GoRouter.of(context);
    router.go('/');
    if (showPaywall) {
      _paywallShownThisLaunch = true;
      router.push('/paywall');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DHColors.sageMist,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Colors.white, DHColors.sageMist],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Image.asset(
                  'assets/logo/client_logo.png',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
