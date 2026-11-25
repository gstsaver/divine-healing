import 'package:divine_healing/services/purchases_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// The card copy is built from Play's pricing phases, not from hard-coded
/// prices. These stand in for `divine_healing_monthly` / `divine_healing_annual`
/// and the `trial7d-then-half` offer: a free phase, then a finite discounted
/// phase, then the infinite renewal. RevenueCat's `freePhase` and `introPhase`
/// already skip that last phase, which is how the SDK hands them over.
void main() {
  group('Android trial followed by a discount', () {
    test('monthly names the trial, twelve half-price months, then full price',
        () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.day, 7, 'P7D'),
              cycles: 1),
          intro: _phase(
              r'$7.00', 7000000, const Period(PeriodUnit.month, 1, 'P1M'),
              cycles: 12),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.annual, isFalse);
      expect(offer.hasFreeTrial, isTrue);
      expect(offer.hasDiscount, isTrue);
      expect(offer.percentOff, 50);
      expect(offer.displayPrice, r'$7.00');
      expect(offer.displayPeriodLabel, '/month');
      expect(offer.buttonLabel, 'Start 7-day free trial');
      expect(offer.trialHeadline, 'Start your 7-day free trial');
      expect(offer.todayLabel, r'$0 today');
      expect(
        offer.termsLine,
        '7-day free trial, then \$7.00/month for 12 months, '
        'then \$13.99/month. Cancel anytime.',
      );
      expect(offer.disclosureLine, contains(r'$7.00/month for 12 months'));
      expect(offer.disclosureLine, contains(r'$13.99/month'));
      expect(offer.disclosureLine, contains('Auto-renews until you cancel'));
    });

    test('annual names the trial, two half-price years, then full price', () {
      final offer = _describe(
        'divine_healing_annual',
        r'$104.99',
        option: _option(
          productId: 'divine_healing_annual',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.day, 7, 'P7D'),
              cycles: 1),
          intro: _phase(
              r'$52.50', 52495000, const Period(PeriodUnit.year, 1, 'P1Y'),
              cycles: 2),
          full: _phase(
              r'$104.99', 104990000, const Period(PeriodUnit.year, 1, 'P1Y')),
        ),
      );

      expect(offer.annual, isTrue);
      expect(offer.percentOff, 50);
      expect(offer.displayPrice, r'$52.50');
      expect(offer.displayPeriodLabel, '/year');
      expect(offer.buttonLabel, 'Start 7-day free trial');
      expect(
        offer.termsLine,
        '7-day free trial, then \$52.50/year for 2 years, '
        'then \$104.99/year. Cancel anytime.',
      );
    });

    test('uses the store formatted price and the phase length, not a fixed 7',
        () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase('CA\$0.00', 0, const Period(PeriodUnit.day, 3, 'P3D'),
              cycles: 1),
          intro: _phase(
              'CA\$7.00', 7000000, const Period(PeriodUnit.month, 1, 'P1M'),
              cycles: 6),
          full: _phase(
              'CA\$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.buttonLabel, 'Start 3-day free trial');
      expect(offer.displayPrice, r'CA$7.00');
      expect(
        offer.termsLine,
        '3-day free trial, then CA\$7.00/month for 6 months, '
        'then CA\$13.99/month. Cancel anytime.',
      );
    });

    test(
        'a week-long trial is counted in days, and a multi-month phase adds up',
        () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.week, 1, 'P1W'),
              cycles: 1),
          intro: _phase(
              r'$7.00', 7000000, const Period(PeriodUnit.month, 3, 'P3M'),
              cycles: 4),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.freeTrialLabel, '7-day free trial');
      expect(offer.introPeriodLabel, '/3 months');
      expect(offer.displayPeriodLabel, '/3 months');
      expect(
        offer.termsLine,
        '7-day free trial, then \$7.00/3 months for 12 months, '
        'then \$13.99/month. Cancel anytime.',
      );
    });

    test('one discounted cycle reads as the first period', () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.day, 7, 'P7D'),
              cycles: 1),
          intro: _phase(
              r'$7.00', 7000000, const Period(PeriodUnit.month, 1, 'P1M'),
              cycles: null),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(
        offer.termsLine,
        '7-day free trial, then \$7.00/month for the first month, '
        'then \$13.99/month. Cancel anytime.',
      );
    });

    test('a phase that is not cheaper stays a trial, with no invented discount',
        () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.day, 7, 'P7D'),
              cycles: 1),
          intro: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M'),
              cycles: 12),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.hasDiscount, isFalse);
      expect(offer.percentOff, isNull);
      expect(offer.displayPrice, r'$13.99');
      expect(offer.buttonLabel, 'Start 7-day free trial');
      expect(
        offer.termsLine,
        r'7-day free trial, then $13.99/month. Cancel anytime.',
      );
    });

    test('an Android option is what gets described when both stores are set',
        () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.day, 7, 'P7D'),
              cycles: 1),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
        introductoryPrice: const IntroductoryPrice(
          7,
          r'$7.00',
          'P1M',
          12,
          PeriodUnit.month,
          1,
        ),
      );

      expect(offer.hasDiscount, isFalse);
      expect(offer.buttonLabel, 'Start 7-day free trial');
    });
  });

  group('Android trial only, discount only, and no offer', () {
    test('a trial with no intro phase renews at the full price', () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, const Period(PeriodUnit.day, 7, 'P7D'),
              cycles: 1),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.hasDiscount, isFalse);
      expect(offer.percentOff, isNull);
      expect(offer.displayPrice, r'$13.99');
      expect(offer.buttonLabel, 'Start 7-day free trial');
      expect(
        offer.termsLine,
        r'7-day free trial, then $13.99/month. Cancel anytime.',
      );
    });

    test('a missing trial length says free trial, not a made-up number of days',
        () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          free: _phase(r'$0.00', 0, null, cycles: 1),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.buttonLabel, 'Start Free trial');
      expect(
        offer.termsLine,
        r'Free trial, then $13.99/month. Cancel anytime.',
      );
    });

    test('a discount with no trial keeps the original wording and button', () {
      final offer = _describe(
        'divine_healing_annual',
        r'$104.99',
        option: _option(
          productId: 'divine_healing_annual',
          intro: _phase(
              r'$52.50', 52495000, const Period(PeriodUnit.year, 1, 'P1Y'),
              cycles: 2),
          full: _phase(
              r'$104.99', 104990000, const Period(PeriodUnit.year, 1, 'P1Y')),
        ),
      );

      expect(offer.hasFreeTrial, isFalse);
      expect(offer.percentOff, 50);
      expect(offer.displayPrice, r'$52.50');
      expect(offer.displayPeriodLabel, '/year');
      expect(offer.buttonLabel, 'Get 50% off');
      expect(
        offer.termsLine,
        r'for the first 2 years, then $104.99/year. Cancel anytime.',
      );
    });

    test('a single discounted cycle says for the first period', () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          intro: _phase(
              r'$7.00', 7000000, const Period(PeriodUnit.month, 1, 'P1M'),
              cycles: 1),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(offer.buttonLabel, 'Get 50% off');
      expect(
        offer.termsLine,
        r'for the first month, then $13.99/month. Cancel anytime.',
      );
    });

    test('twelve discounted months stay "for the first 12 months"', () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$13.99',
        option: _option(
          productId: 'divine_healing_monthly',
          intro: _phase(
              r'$7.00', 7000000, const Period(PeriodUnit.month, 1, 'P1M'),
              cycles: 12),
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
        ),
      );

      expect(
        offer.termsLine,
        r'for the first 12 months, then $13.99/month. Cancel anytime.',
      );
    });

    test('a base plan with no offer shows the renewal price and Subscribe', () {
      final offer = _describe(
        'divine_healing_monthly',
        r'$99.00',
        option: _option(
          productId: 'divine_healing_monthly',
          full: _phase(
              r'$13.99', 13990000, const Period(PeriodUnit.month, 1, 'P1M')),
          basePlan: true,
        ),
      );

      expect(offer.hasFreeTrial, isFalse);
      expect(offer.hasDiscount, isFalse);
      expect(offer.displayPrice, r'$13.99');
      expect(offer.buttonLabel, 'Subscribe');
      expect(offer.termsLine, 'Cancel anytime.');
    });
  });

  group('iOS introductory price, unchanged', () {
    test('a free introductory period is a trial and renews at full price', () {
      final offer = _describe(
        'com.divinehealing.app.monthly',
        r'$13.99',
        introductoryPrice: const IntroductoryPrice(
          0,
          r'$0.00',
          'P7D',
          1,
          PeriodUnit.day,
          7,
        ),
      );

      expect(offer.annual, isFalse);
      expect(offer.hasDiscount, isFalse);
      expect(offer.displayPrice, r'$13.99');
      expect(offer.buttonLabel, 'Start 7-day free trial');
      expect(
        offer.termsLine,
        r'7-day free trial, then $13.99/month. Cancel anytime.',
      );
    });

    test('a paid introductory price is a discount, with no trial', () {
      final offer = _describe(
        'com.divinehealing.app.annual',
        r'$104.99',
        price: 104.99,
        introductoryPrice: const IntroductoryPrice(
          52.495,
          r'$52.50',
          'P1Y',
          2,
          PeriodUnit.year,
          1,
        ),
      );

      expect(offer.annual, isTrue);
      expect(offer.hasFreeTrial, isFalse);
      expect(offer.percentOff, 50);
      expect(offer.displayPrice, r'$52.50');
      expect(offer.buttonLabel, 'Get 50% off');
      expect(
        offer.termsLine,
        r'for the first 2 years, then $104.99/year. Cancel anytime.',
      );
    });

    test('no introductory price is the plain renewal', () {
      final offer = _describe(
        'com.divinehealing.app.monthly',
        r'$13.99',
        price: 13.99,
      );

      expect(offer.buttonLabel, 'Subscribe');
      expect(offer.displayPrice, r'$13.99');
      expect(offer.termsLine, 'Cancel anytime.');
    });
  });

  test('a card with a discount but no percentage still subscribes plainly', () {
    const offer = PlanOffer(
      annual: false,
      renewalPrice: r'$13.99',
      periodLabel: '/month',
      introPrice: r'$7.00',
    );

    expect(offer.buttonLabel, 'Subscribe');
    expect(
      offer.termsLine,
      r'for a limited time, then $13.99/month. Cancel anytime.',
    );
  });
}

PlanOffer _describe(
  String identifier,
  String priceString, {
  double price = 0,
  SubscriptionOption? option,
  IntroductoryPrice? introductoryPrice,
}) {
  return PurchasesService.describeProduct(
    identifier: identifier,
    priceString: priceString,
    price: price,
    option: option,
    introductoryPrice: introductoryPrice,
  );
}

SubscriptionOption _option({
  required String productId,
  required PricingPhase full,
  PricingPhase? free,
  PricingPhase? intro,
  bool basePlan = false,
}) {
  return SubscriptionOption(
    basePlan ? 'monthly' : 'monthly:trial7d-then-half',
    '$productId:monthly',
    productId,
    [
      if (free != null) free,
      if (intro != null) intro,
      full,
    ],
    const [],
    basePlan,
    full.billingPeriod,
    false,
    full,
    free,
    intro,
    null,
    null,
  );
}

PricingPhase _phase(
  String formatted,
  int micros,
  Period? period, {
  int? cycles,
}) {
  return PricingPhase(
    period,
    cycles == null || cycles == 0
        ? RecurrenceMode.infiniteRecurring
        : RecurrenceMode.finiteRecurring,
    cycles,
    Price(formatted, micros, 'USD'),
    micros == 0
        ? OfferPaymentMode.freeTrial
        : OfferPaymentMode.discountedRecurringPayment,
  );
}
