import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/content_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/purchases_service.dart';
import '../../theme.dart';

/// A dismissible subscription page shown on launch to anyone who is not yet
/// subscribed (see [SplashScreen]). It mirrors the Profile paywall's plans and
/// purchase flow, but stands alone with a close button so free users — and the
/// app reviewers — can always get past it. A hard, un-closable paywall would
/// block the free tier and be rejected by both stores.
///
/// Mobile only: it reads the store's real prices and current offer through
/// RevenueCat ([storePlanOffersProvider]). On web, or when the store cannot be
/// reached, there are no offers to show and it simply closes.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionCount = ref.watch(sessionCountProvider);
    final offersAsync = ref.watch(storePlanOffersProvider);

    return Scaffold(
      backgroundColor: DHColors.sageMist,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
              children: [
                Text(
                  'Unlock the full library',
                  textAlign: TextAlign.center,
                  style: DHTypography.heading(size: 26, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Every guided session, all journaling and exercises, and all '
                  'future content.',
                  textAlign: TextAlign.center,
                  style: DHTypography.body(size: 14, color: DHColors.secondary),
                ),
                const SizedBox(height: 24),
                offersAsync.when(
                  data: (offers) {
                    if (offers.isEmpty) return _unavailable();
                    final sorted = _sorted(offers);
                    return Column(
                      children: [
                        for (var i = 0; i < sorted.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _offerCard(sorted[i], sessionCount),
                        ],
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                  error: (_, __) => _unavailable(),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: const Text('Restore purchases'),
                ),
                TextButton(
                  onPressed: _busy ? null : _close,
                  child: Text(
                    'Maybe later',
                    style: DHTypography.body(size: 13, color: DHColors.secondary),
                  ),
                ),
                const SizedBox(height: 4),
                // Apple 3.1.2 requires the subscription terms and functional
                // links to the Terms of Use and Privacy Policy on the paywall.
                Text(
                  'Subscriptions renew automatically until cancelled. Cancel '
                  'anytime in the App Store or Google Play at least 24 hours '
                  'before renewal.',
                  textAlign: TextAlign.center,
                  style: DHTypography.body(size: 11, color: DHColors.secondary),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/terms'),
                      child: Text('Terms',
                          style: DHTypography.body(
                              size: 12, color: DHColors.forestGreen)),
                    ),
                    Text('·',
                        style: DHTypography.body(
                            size: 12, color: DHColors.secondary)),
                    TextButton(
                      onPressed: () => context.push('/privacy'),
                      child: Text('Privacy',
                          style: DHTypography.body(
                              size: 12, color: DHColors.forestGreen)),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: DHColors.forestGreen),
                onPressed: _busy ? null : _close,
                tooltip: 'Close',
              ),
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<PlanOffer> _sorted(List<PlanOffer> offers) => [...offers]
    ..sort((a, b) => a.annual == b.annual ? 0 : (a.annual ? -1 : 1));

  Widget _unavailable() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'Subscriptions are not available right now. Please try again shortly.',
          textAlign: TextAlign.center,
          style: DHTypography.body(size: 13, color: DHColors.secondary),
        ),
      );

  Widget _offerCard(PlanOffer offer, int? sessionCount) {
    final highlighted = offer.annual;
    final tag = offer.annual ? 'ANNUAL · BEST VALUE' : 'MONTHLY';
    final bigPrice = offer.introPrice ?? offer.renewalPrice;

    String subline;
    if (offer.hasDiscount) {
      final phase = offer.introPhaseLabel ?? 'for a limited time';
      subline = '$phase, then ${offer.renewalPrice}${offer.periodLabel}. '
          'Cancel anytime.';
    } else if (offer.hasFreeTrial) {
      subline = '${offer.freeTrialLabel}, then ${offer.renewalPrice}'
          '${offer.periodLabel}. Cancel anytime.';
    } else {
      subline = 'Cancel anytime.';
    }

    final String buttonLabel;
    if (offer.hasDiscount && offer.percentOff != null) {
      buttonLabel = 'Get ${offer.percentOff}% off';
    } else if (offer.hasFreeTrial) {
      buttonLabel = 'Start ${offer.freeTrialLabel}';
    } else {
      buttonLabel = 'Subscribe';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DHRadius.card),
        border: Border.all(
          color: highlighted
              ? DHColors.sunlightGold
              : DHColors.sunlightGold.withOpacity(0.3),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: DHShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tag,
                    style: DHTypography.caption(color: DHColors.forestGreen)),
              ),
              if (offer.percentOff != null) _discountPill(offer.percentOff!),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: DHTypography.heading(size: 28, weight: FontWeight.w600),
              children: [
                TextSpan(text: bigPrice),
                TextSpan(
                  text: offer.periodLabel,
                  style: DHTypography.body(size: 13, color: DHColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(subline,
              style: DHTypography.body(size: 12, color: DHColors.secondary)),
          const SizedBox(height: 12),
          ..._benefits(sessionCount).map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: DHColors.mossGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b, style: DHTypography.body(size: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _buy(annual: offer.annual),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountPill(int percentOff) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: DHColors.strawberryBlush.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$percentOff% OFF',
            style: DHTypography.caption(color: DHColors.strawberryBlush)
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  static List<String> _benefits(int? sessionCount) => [
        sessionCount != null
            ? '$sessionCount guided sessions'
            : 'All guided sessions',
        'All journaling & exercises',
        'All future content',
      ];

  /// Hands RevenueCat the Supabase uid before buying, so the purchase attaches
  /// to the person (anonymous or signed in) rather than to the device — the
  /// same uid the webhook writes and Storage RLS checks.
  Future<bool> _ensureReady() async {
    final user = ref.read(authServiceProvider)?.currentUser;
    if (user == null) return false;
    await PurchasesService.instance.configure(userId: user.id, email: user.email);
    return true;
  }

  Future<void> _buy({required bool annual}) async {
    if (!PurchasesService.isAvailable) return;
    setState(() => _busy = true);
    try {
      if (!await _ensureReady()) {
        _say('Could not reach the server. Please check your connection and '
            'try again.');
        return;
      }
      final service = PurchasesService.instance;
      final packages = await service.plans();
      if (packages.isEmpty) {
        _say('Subscriptions are not available right now. Please try again '
            'shortly.');
        return;
      }
      // Match on the product id, not RevenueCat's package type: a dot-prefixed
      // match would fall through to the monthly package on Android.
      final wanted = annual ? 'annual' : 'monthly';
      final package = packages.firstWhere(
        (p) => p.storeProduct.identifier.contains(wanted),
        orElse: () => packages.first,
      );

      AnalyticsService.instance.logBeginCheckout(
        annual: annual,
        value: package.storeProduct.price,
        currency: package.storeProduct.currencyCode,
      );

      final outcome = await service.buy(package);
      if (!mounted) return;
      switch (outcome) {
        case PurchaseOutcome.purchased:
          AnalyticsService.instance.logSubscribed(
            annual: annual,
            value: package.storeProduct.price,
            currency: package.storeProduct.currencyCode,
            productId: package.storeProduct.identifier,
          );
          await _waitForEntitlementThenClose();
        case PurchaseOutcome.restored:
          await _waitForEntitlementThenClose();
        case PurchaseOutcome.cancelled:
          break;
        case PurchaseOutcome.nothingToRestore:
        case PurchaseOutcome.failed:
          _say(service.lastError ??
              'The purchase did not complete. You have not been charged.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (!PurchasesService.isAvailable) return;
    setState(() => _busy = true);
    try {
      if (!await _ensureReady()) {
        _say('Could not reach the server. Please try again.');
        return;
      }
      final service = PurchasesService.instance;
      final outcome = await service.restore();
      if (!mounted) return;
      switch (outcome) {
        case PurchaseOutcome.restored:
        case PurchaseOutcome.purchased:
          await _waitForEntitlementThenClose();
        case PurchaseOutcome.nothingToRestore:
          _say('No previous purchase found on this account.');
        case PurchaseOutcome.cancelled:
        case PurchaseOutcome.failed:
          _say(service.lastError ?? 'Could not restore purchases.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The store confirms instantly, but the entitlement only lands once
  /// RevenueCat's webhook has written `sh_subscribers`. Wait for it, then
  /// close the paywall so the person returns to an app that is already unlocked.
  Future<void> _waitForEntitlementThenClose() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      ref.invalidate(subscriptionStatusProvider);
      final status = await ref.read(subscriptionStatusProvider.future);
      if (status.hasFullAccess) {
        if (mounted) {
          _say('You are all set. Enjoy.');
          _close();
        }
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (mounted) {
      _say('Payment received. Your access will appear in a moment.');
      _close();
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
