import '../services/purchases_service.dart';

/// Subscription copy for the places that cannot read a live store price.
///
/// The paywall cards use [PlanOffer], which is whatever Google or Apple
/// returned. These strings are the fallback for web, for a store that did
/// not answer, and for short prompts elsewhere. The figures are the Play
/// base prices — the full price after the introductory discount — in CAD,
/// which is the currency the rest of the fallback already used.
///
/// Offer `trial7d-then-half`: 7 days free, then 50% off for 12 monthly
/// payments or for 2 years on the annual plan, then this full price.
/// Cancel anytime. A half-price dollar amount is not hardcoded: 50% of
/// these prices is not a price the store has published as a string, and
/// the live card already shows that figure when the store is reachable.
class PlanFallback {
  static const monthlyFull = 'CAD \$18.99';
  static const annualFull = 'CAD \$149.99';

  static const monthlyTerms =
      '7-day free trial, then half price for 12 months, '
      'then CAD \$18.99/month. Cancel anytime.';

  static const annualTerms = '7-day free trial, then half price for 2 years, '
      'then CAD \$149.99/year. Cancel anytime.';

  /// Button when the store did not return an offer to describe instead.
  static const buttonLabel = 'Start 7-day free trial, then half price';

  /// [terms] plus the auto-renewal the stores require next to the price.
  /// The static strings keep their original wording; this is what the card
  /// prints under "$0 today".
  static String disclose(String terms) {
    const renew =
        'Auto-renews until you cancel. Cancel anytime in Google Play or the App Store.';
    if (terms.contains('Auto-renews')) return terms;
    if (terms.contains('Cancel anytime.')) {
      return terms.replaceFirst('Cancel anytime.', renew);
    }
    return '$terms $renew';
  }

  /// Short list under a plan. The last line is the reassurance, not a feature.
  static List<String> benefits(int? sessionCount) => [
        sessionCount == null
            ? 'Every guided meditation'
            : '$sessionCount guided meditations',
        'Chakras, breathing, affirmations and journaling',
        'New sessions as they are published',
        'Cancel anytime in Google Play or the App Store',
      ];

  /// Locked-content button. A loaded offering wins, so someone the store
  /// has already decided is not eligible for the trial is not promised one.
  static String lockedButton(List<PlanOffer> offers) {
    if (offers.isEmpty) return buttonLabel;
    final both = offers.where((o) => o.hasFreeTrial && o.hasDiscount);
    if (both.isNotEmpty) {
      final pct = both.first.percentOff;
      if (pct == null || pct == 50) return buttonLabel;
      return 'Start 7-day free trial, then $pct% off';
    }
    final trial = offers.where((o) => o.hasFreeTrial);
    if (trial.isNotEmpty) return 'Start ${trial.first.freeTrialLabel}';
    final discount = offers.where((o) => o.hasDiscount && o.percentOff != null);
    if (discount.isNotEmpty) return 'Get ${discount.first.percentOff}% off';
    return 'Subscribe';
  }

  /// One line under a locked player. Live offers contribute the store's own
  /// terms, which name every phase and the real full price. With nothing
  /// from the store, the CAD fallback does.
  static String playerCaption(List<PlanOffer> offers) {
    if (offers.isEmpty) {
      return '7-day free trial, then half price, then $monthlyFull/month '
          'or $annualFull/year. Cancel anytime.';
    }
    final sorted = _sorted(offers);
    return sorted.map((o) => o.termsLine).join('\n');
  }

  /// Dialog shown when a locked session is tapped.
  ///
  /// [access] is the thing being unlocked ("23 guided sessions", "this
  /// session"). [aside] is an extra sentence that is not about price, such
  /// as the shadow-work note that the writing stays available.
  static String unlockMessage({
    required bool signedIn,
    required String access,
    required List<PlanOffer> offers,
    String? aside,
  }) {
    final extra = (aside == null || aside.isEmpty) ? '' : ' $aside';
    if (offers.isNotEmpty) {
      final lines = _sorted(offers).map((o) {
        final name = o.annual ? 'Annual' : 'Monthly';
        return '$name: ${o.termsLine}';
      }).join('\n');
      return '${_lead(signedIn, access, offers)}$extra\n\n$lines';
    }
    if (!signedIn) {
      return 'Sign in and start your 7-day free trial, then half price, '
          'to access $access.$extra';
    }
    return 'Start your 7-day free trial, then half price, to access $access. '
        'Monthly is half price for 12 months, then $monthlyFull/month. '
        'Annual is half price for 2 years, then $annualFull/year. '
        'Cancel any time before the trial ends and you won’t be charged.$extra';
  }

  static String _lead(bool signedIn, String access, List<PlanOffer> offers) {
    final both = offers.any((o) => o.hasFreeTrial && o.hasDiscount);
    final trial = offers.where((o) => o.hasFreeTrial);
    // An account is not required to start the trial. Saying "sign in" here
    // was the step that sent guests away from the purchase.
    if (!signedIn) {
      if (both) {
        return 'Start your 7-day free trial, then half price, '
            'to access $access. No account is required.';
      }
      if (trial.isNotEmpty) {
        return 'Start your ${trial.first.freeTrialLabel} '
            'to access $access. No account is required.';
      }
      return 'Subscribe to access $access. No account is required.';
    }
    if (both) {
      return 'Start your 7-day free trial, then half price, to access $access.';
    }
    if (trial.isNotEmpty) {
      return 'Start your ${trial.first.freeTrialLabel} to access $access. '
          'Cancel any time before the trial ends and you won’t be charged.';
    }
    return 'Subscribe to access $access.';
  }

  static List<PlanOffer> _sorted(List<PlanOffer> offers) => [...offers]
    ..sort((a, b) => a.annual == b.annual ? 0 : (a.annual ? -1 : 1));
}
