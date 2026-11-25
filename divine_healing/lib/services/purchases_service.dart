/// In-app purchases, through RevenueCat.
///
/// The Profile screen used to open a Stripe payment link in the browser.
/// Both stores forbid that for digital goods sold inside an app, so on iOS
/// and Android this replaces it. Stripe still handles the web build, where
/// no store takes a cut and the links are legitimate.
///
/// `sh_subscribers` stays the single source of truth. RevenueCat's webhook
/// writes to it exactly as the Stripe webhook does, so the audio paywall in
/// Storage RLS keeps working without knowing which store paid.
///
/// Needs REVENUECAT_IOS_KEY / REVENUECAT_ANDROID_KEY at build time. Without
/// them [isAvailable] is false and the UI falls back to saying so, rather
/// than showing a button that cannot work.
library;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';
import 'analytics_service.dart';

/// What a purchase attempt did, so the UI can tell the three apart.
enum PurchaseOutcome {
  /// Entitlement is active. The webhook writes the row; the UI refreshes.
  purchased,

  /// The sheet was dismissed. Not an error, and not worth a red banner.
  cancelled,

  /// Nothing was bought, but an earlier purchase was found and restored.
  restored,

  /// Nothing to restore. Distinct from failure: the call worked.
  nothingToRestore,

  /// The store or the network refused. [PurchasesService.lastError] says why.
  failed,
}

/// What to show for one plan on the paywall, read from the store so the
/// price, the current offer and the renewal terms are always what the person
/// will actually be charged — never hard-coded.
///
/// The store returns prices already formatted for the person's country and
/// currency (CA$149.99, A$149.99, …), so [renewalPrice] and [introPrice] are
/// shown as-is, with no currency prefix of our own. [percentOff], the free
/// trial and the intro phase come straight from the offer Google or Apple
/// returned, so an ineligible customer — who the store gives no offer — sees
/// the plain renewal price with nothing to undo.
///
/// A Play offer can carry both a free trial and a discounted phase
/// (`trial7d-then-half`). [hasFreeTrial] and [hasDiscount] are then both
/// true, and [termsLine] states every phase rather than stopping at the
/// trial.
class PlanOffer {
  const PlanOffer({
    required this.annual,
    required this.renewalPrice,
    required this.periodLabel,
    this.introPrice,
    this.introPeriodLabel,
    this.introPhaseLabel,
    this.freeTrialLabel,
    this.percentOff,
  });

  /// True for the yearly plan, false for the monthly one.
  final bool annual;

  /// The ongoing price the plan renews at, e.g. "CA$149.99".
  final String renewalPrice;

  /// "/year" or "/month", the plan's own renewal period.
  final String periodLabel;

  /// The discounted price during the offer, e.g. "CA$74.99", or null when the
  /// person gets no discount.
  final String? introPrice;

  /// Billing-period suffix for [introPrice] when that phase does not bill on
  /// [periodLabel] — "/3 months" for a phase of three months. Null when the
  /// discount uses the plan's own period, which is the ordinary case.
  final String? introPeriodLabel;

  /// How long the discount lasts.
  ///
  /// A discount on its own reads "for the first 2 years". A discount that
  /// follows a free trial reads "for 12 months", because [termsLine] places
  /// the price in front of it: "then $7.00/month for 12 months".
  final String? introPhaseLabel;

  /// "7-day free trial" when the offer starts with a free trial. A following
  /// discount, when there is one, is [introPrice] rather than a replacement
  /// for this.
  final String? freeTrialLabel;

  /// The discount as a percentage, e.g. 50, for the badge. Null when there is
  /// no discount.
  final int? percentOff;

  bool get hasFreeTrial => freeTrialLabel != null;
  bool get hasDiscount => introPrice != null;

  /// The large figure on the card. A discount shows the discounted price,
  /// which is also the price charged once a leading free trial ends. A trial
  /// with no discount shows the renewal price, the same as no offer at all.
  String get displayPrice => introPrice ?? renewalPrice;

  /// The period printed beside [displayPrice].
  String get displayPeriodLabel =>
      hasDiscount && introPeriodLabel != null ? introPeriodLabel! : periodLabel;

  /// The purchase button. A free trial is what begins today, so it wins over
  /// a discount that only starts once the trial ends. A discount with no
  /// trial keeps "Get 50% off".
  String get buttonLabel {
    if (hasFreeTrial) return 'Start $freeTrialLabel';
    if (hasDiscount && percentOff != null) return 'Get $percentOff% off';
    return 'Subscribe';
  }

  /// The line under the price. Every phase the store will actually charge is
  /// named: the trial, the discounted run, and the price it renews at.
  String get termsLine {
    final renewal = '$renewalPrice$periodLabel';
    if (hasFreeTrial && hasDiscount) {
      final phase = introPhaseLabel ?? 'for a limited time';
      final introPeriod = introPeriodLabel ?? periodLabel;
      return '$freeTrialLabel, then $introPrice$introPeriod $phase, '
          'then $renewal. Cancel anytime.';
    }
    if (hasDiscount) {
      final phase = introPhaseLabel ?? 'for a limited time';
      return '$phase, then $renewal. Cancel anytime.';
    }
    if (hasFreeTrial) {
      return '$freeTrialLabel, then $renewal. Cancel anytime.';
    }
    return 'Cancel anytime.';
  }

  /// The line above the price when a free trial is what starts today.
  ///
  /// The store's "7-day free trial" becomes "Start your 7-day free trial".
  String? get trialHeadline =>
      hasFreeTrial ? 'Start your $freeTrialLabel' : null;

  /// What the person pays today. A trial charges nothing, in every currency,
  /// so this is not a store-formatted price. The amounts they will be
  /// charged are [disclosureLine].
  String get todayLabel => hasFreeTrial ? '\$0 today' : displayPrice;

  /// [termsLine] plus the auto-renewal both stores require beside the price.
  String get disclosureLine {
    const renew =
        'Auto-renews until you cancel. Cancel anytime in Google Play or the App Store.';
    if (termsLine.contains('Auto-renews')) return termsLine;
    if (termsLine.contains('Cancel anytime.')) {
      return termsLine.replaceFirst('Cancel anytime.', renew);
    }
    return '$termsLine $renew';
  }
}

class PurchasesService {
  PurchasesService._();

  static final instance = PurchasesService._();

  /// The entitlement configured in RevenueCat. One entitlement covers both
  /// plans, because the app only asks "may this person hear the audio".
  static const entitlement = 'full_access';

  bool _configured = false;
  String? lastError;

  /// RevenueCat's error name (`networkError`, `storeProblemError`, …) from
  /// the last failed purchase. Null after a cancel, which is not a failure.
  String? lastErrorCode;

  /// Whether purchases can run at all here: a mobile build with a key.
  static bool get isAvailable {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Env.revenueCatKeyIos.isNotEmpty;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Env.revenueCatKeyAndroid.isNotEmpty;
    }
    return false;
  }

  static String get _apiKey => defaultTargetPlatform == TargetPlatform.iOS
      ? Env.revenueCatKeyIos
      : Env.revenueCatKeyAndroid;

  /// Ties purchases to the Supabase session, account or not.
  ///
  /// [userId] is the Supabase user id rather than the email: RevenueCat's
  /// app user id is permanent and public-ish, and an email is neither. The
  /// webhook keys the `sh_subscribers` row on this id.
  ///
  /// [email] is absent for a guest, who has an anonymous session and no
  /// address. That is the ordinary case rather than an error — Apple's
  /// guideline 5.1.1(v) requires that buying works without registering — and
  /// the webhook writes a synthetic address for those rows. Passing one when
  /// it is known still helps: it is how a purchase reconciles with an
  /// account someone made later.
  Future<void> configure({
    required String userId,
    String? email,
  }) async {
    if (!isAvailable) return;
    if (!_configured) {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(
        PurchasesConfiguration(_apiKey)..appUserID = userId,
      );
      _configured = true;
    } else {
      // A second account on the same device. Without this the new purchase
      // would attach to whoever signed in first.
      await Purchases.logIn(userId);
    }
    if (email != null && email.isNotEmpty) await Purchases.setEmail(email);
  }

  /// Called on sign-out so the next person starts clean.
  Future<void> signOut() async {
    if (!isAvailable || !_configured) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Logging out an anonymous user throws, and there is nothing to do
      // about it — the state we wanted is the state we have.
    }
  }

  /// The plans to show, in the order RevenueCat's current offering lists.
  /// Empty when the offering has not been set up on RevenueCat's side.
  Future<List<Package>> plans() async {
    if (!isAvailable) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? const [];
    } on PlatformException catch (e) {
      lastError = e.message;
      return const [];
    }
  }

  /// Each plan's real price and current offer, read from the store, in the
  /// order the offering lists them. Empty when the store is unavailable (web,
  /// or not configured), where the UI falls back to its static cards.
  Future<List<PlanOffer>> planOffers() async {
    final packages = await plans();
    return packages.map(_describe).toList();
  }

  /// Reads one package's pricing. Android exposes offers through the
  /// subscription option RevenueCat will actually buy ([defaultOption], whose
  /// phases Google has already filtered by eligibility); iOS through
  /// [introductoryPrice]. Reading what the store will charge means an
  /// ineligible customer, who gets no offer, shows the plain renewal price.
  PlanOffer _describe(Package p) {
    final product = p.storeProduct;
    return describeProduct(
      identifier: product.identifier,
      priceString: product.priceString,
      price: product.price,
      option: product.defaultOption,
      introductoryPrice: product.introductoryPrice,
    );
  }

  /// Turns a store product into the card copy. Public so the phase mapping
  /// can be tested without a live store; the paywall calls it through
  /// [planOffers].
  ///
  /// On Android, [SubscriptionOption.freePhase] is the first non-final phase
  /// priced at zero and [SubscriptionOption.introPhase] is the first non-final
  /// phase priced above zero. A trial on its own therefore has no intro
  /// phase — the renewal price is the final phase, and both helpers skip it.
  /// A trial followed by a discounted run has both, and the card has to say
  /// so. Stopping at the free phase would advertise "7 days free, then the
  /// full price" for an offer that charges half price for a year or two
  /// first.
  @visibleForTesting
  static PlanOffer describeProduct({
    required String identifier,
    required String priceString,
    double price = 0,
    SubscriptionOption? option,
    IntroductoryPrice? introductoryPrice,
  }) {
    final annual = identifier.toLowerCase().contains('annual');
    final period = annual ? '/year' : '/month';

    if (option != null) {
      // Android.
      final renewal = option.fullPricePhase?.price.formatted ?? priceString;
      final fullMicros = option.fullPricePhase?.price.amountMicros;
      final free = option.freePhase;
      final intro = option.introPhase;
      if (free != null) {
        final trial = _trialLabel(_periodDays(free.billingPeriod));
        // An intro phase that is not actually cheaper is not a discount.
        // Treat the offer as a trial alone, which is what a trial-only
        // option already is — its intro phase is null.
        final percent = intro == null
            ? null
            : _percentOff(intro.price.amountMicros, fullMicros);
        if (intro != null && percent != null && percent > 0) {
          final introSuffix = _phasePeriodSuffix(intro.billingPeriod);
          return PlanOffer(
            annual: annual,
            renewalPrice: renewal,
            periodLabel: period,
            introPrice: intro.price.formatted,
            introPeriodLabel: introSuffix != null && introSuffix != period
                ? introSuffix
                : null,
            introPhaseLabel:
                _forSpan(intro.billingCycleCount ?? 1, intro.billingPeriod),
            freeTrialLabel: trial,
            percentOff: percent,
          );
        }
        return PlanOffer(
          annual: annual,
          renewalPrice: renewal,
          periodLabel: period,
          freeTrialLabel: trial,
        );
      }
      if (intro != null) {
        return PlanOffer(
          annual: annual,
          renewalPrice: renewal,
          periodLabel: period,
          introPrice: intro.price.formatted,
          introPhaseLabel: _firstLabel(
              intro.billingCycleCount ?? 1, intro.billingPeriod?.unit),
          percentOff: _percentOff(intro.price.amountMicros, fullMicros),
        );
      }
      return PlanOffer(
          annual: annual, renewalPrice: renewal, periodLabel: period);
    }

    // iOS / StoreKit. One introductory offer, either a trial or a discount.
    final intro = introductoryPrice;
    if (intro != null) {
      if (intro.price == 0) {
        return PlanOffer(
          annual: annual,
          renewalPrice: priceString,
          periodLabel: period,
          freeTrialLabel: _trialLabel(
              _unitDays(intro.periodUnit, intro.periodNumberOfUnits)),
        );
      }
      return PlanOffer(
        annual: annual,
        renewalPrice: priceString,
        periodLabel: period,
        introPrice: intro.priceString,
        introPhaseLabel: _firstLabel(intro.cycles, intro.periodUnit),
        percentOff:
            _percentOff((intro.price * 1e6).round(), (price * 1e6).round()),
      );
    }
    return PlanOffer(
        annual: annual, renewalPrice: priceString, periodLabel: period);
  }

  /// The discount as a whole percentage, or null when there is none.
  static int? _percentOff(int introMicros, int? fullMicros) {
    if (fullMicros == null || fullMicros <= 0 || introMicros >= fullMicros) {
      return null;
    }
    return ((1 - introMicros / fullMicros) * 100).round();
  }

  static String _trialLabel(int? days) =>
      days != null ? '$days-day free trial' : 'Free trial';

  /// "for the first year", "for the first 2 years", and so on.
  ///
  /// Uses the cycle count and the unit only, which is how a discount on its
  /// own has always been phrased. A trial-then-discount offer uses [_forSpan]
  /// instead, because that sentence also has to carry the phase's period
  /// length (four cycles of three months is twelve months, not four).
  static String _firstLabel(int cycles, PeriodUnit? unit) {
    final noun = _unitNoun(unit);
    if (noun == null) return 'for a limited time';
    if (cycles <= 1) return 'for the first $noun';
    return 'for the first $cycles ${noun}s';
  }

  /// "for 12 months", "for 2 years", "for the first month".
  ///
  /// [cycles] is the phase's billing cycle count and [period] is that phase's
  /// own billing period, so the words match what Play will bill.
  static String _forSpan(int cycles, Period? period) {
    final noun = _unitNoun(period?.unit);
    if (noun == null) return 'for a limited time';
    final perCycle = period!.value < 1 ? 1 : period.value;
    final safeCycles = cycles < 1 ? 1 : cycles;
    final total = safeCycles * perCycle;
    if (total <= 1) return 'for the first $noun';
    return 'for $total ${noun}s';
  }

  /// "/month", "/year", or "/3 months" when a phase bills for more than one
  /// unit at a time. Null when the period is missing or not a known unit, so
  /// the caller keeps the plan's own [PlanOffer.periodLabel].
  static String? _phasePeriodSuffix(Period? period) {
    if (period == null || period.value < 1) return null;
    final n = period.value;
    switch (period.unit) {
      case PeriodUnit.day:
        return n == 1 ? '/day' : '/$n days';
      case PeriodUnit.week:
        return n == 1 ? '/week' : '/$n weeks';
      case PeriodUnit.month:
        return n == 1 ? '/month' : '/$n months';
      case PeriodUnit.year:
        return n == 1 ? '/year' : '/$n years';
      case PeriodUnit.unknown:
        return null;
    }
  }

  static String? _unitNoun(PeriodUnit? unit) {
    switch (unit) {
      case PeriodUnit.day:
        return 'day';
      case PeriodUnit.week:
        return 'week';
      case PeriodUnit.month:
        return 'month';
      case PeriodUnit.year:
        return 'year';
      default:
        return null;
    }
  }

  static int? _periodDays(Period? p) =>
      p == null ? null : _unitDays(p.unit, p.value);

  static int? _unitDays(PeriodUnit unit, int value) {
    switch (unit) {
      case PeriodUnit.day:
        return value;
      case PeriodUnit.week:
        return value * 7;
      case PeriodUnit.month:
        return value * 30;
      case PeriodUnit.year:
        return value * 365;
      default:
        return null;
    }
  }

  Future<PurchaseOutcome> buy(
    Package package, {
    bool hasTrial = false,
  }) async {
    lastError = null;
    lastErrorCode = null;
    final productId = package.storeProduct.identifier;
    final annual = productId.toLowerCase().contains('annual');
    if (!isAvailable) {
      AnalyticsService.instance.logPurchaseFailed(
        errorCode: 'unavailable',
        productId: productId,
      );
      return PurchaseOutcome.failed;
    }
    // begin_checkout is logged by the screen that resolved the plan. These
    // two are the explicit trial / purchase-start steps beside it.
    AnalyticsService.instance.logPurchaseStart(
      annual: annual,
      productId: productId,
      hasTrial: hasTrial,
    );
    if (hasTrial) {
      AnalyticsService.instance.logTrialStart(
        annual: annual,
        productId: productId,
      );
    }
    try {
      // purchase(PurchaseParams) replaced purchasePackage in 10.x, and
      // returns the transaction alongside the customer info rather than the
      // info on its own.
      final result = await Purchases.purchase(PurchaseParams.package(package));
      if (_entitled(result.customerInfo)) return PurchaseOutcome.purchased;
      lastErrorCode = 'entitlement_missing';
      AnalyticsService.instance.logPurchaseFailed(
        errorCode: 'entitlement_missing',
        productId: productId,
      );
      return PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        AnalyticsService.instance.logPurchaseCancelled(productId: productId);
        return PurchaseOutcome.cancelled;
      }
      lastErrorCode = code.name;
      lastError = e.message;
      AnalyticsService.instance.logPurchaseFailed(
        errorCode: code.name,
        productId: productId,
      );
      return PurchaseOutcome.failed;
    }
  }

  /// Apple requires a way to restore purchases; someone reinstalling the app
  /// or switching devices has already paid and must not be asked again.
  Future<PurchaseOutcome> restore() async {
    lastError = null;
    if (!isAvailable) return PurchaseOutcome.failed;
    try {
      final info = await Purchases.restorePurchases();
      return _entitled(info)
          ? PurchaseOutcome.restored
          : PurchaseOutcome.nothingToRestore;
    } on PlatformException catch (e) {
      lastError = e.message;
      return PurchaseOutcome.failed;
    }
  }

  bool _entitled(CustomerInfo info) =>
      info.entitlements.active.containsKey(entitlement);
}
