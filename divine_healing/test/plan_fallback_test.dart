import 'package:divine_healing/config/plan_fallback.dart';
import 'package:divine_healing/services/purchases_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The locked-content prompts and the static paywall cards. A loaded store
/// offering is quoted verbatim; the CAD figures appear only when the store
/// returned nothing.
void main() {
  const trialThenHalf = PlanOffer(
    annual: false,
    renewalPrice: r'$13.99',
    periodLabel: '/month',
    introPrice: r'$7.00',
    introPhaseLabel: 'for 12 months',
    freeTrialLabel: '7-day free trial',
    percentOff: 50,
  );
  const annualTrialThenHalf = PlanOffer(
    annual: true,
    renewalPrice: r'$104.99',
    periodLabel: '/year',
    introPrice: r'$52.50',
    introPhaseLabel: 'for 2 years',
    freeTrialLabel: '7-day free trial',
    percentOff: 50,
  );

  test('fallback cards state the trial, the half-price period, and full price',
      () {
    expect(PlanFallback.monthlyFull, r'CAD $18.99');
    expect(PlanFallback.annualFull, r'CAD $149.99');
    expect(
      PlanFallback.monthlyTerms,
      '7-day free trial, then half price for 12 months, '
      r'then CAD $18.99/month. Cancel anytime.',
    );
    expect(
      PlanFallback.annualTerms,
      '7-day free trial, then half price for 2 years, '
      r'then CAD $149.99/year. Cancel anytime.',
    );
    expect(PlanFallback.buttonLabel, 'Start 7-day free trial, then half price');
    expect(PlanFallback.monthlyTerms, isNot(contains(r'$19')));
    expect(PlanFallback.annualTerms, isNot(contains(r'$149/')));
  });

  test('with no store offering the prompts use the CAD fallback', () {
    expect(PlanFallback.lockedButton(const []), PlanFallback.buttonLabel);
    final body = PlanFallback.unlockMessage(
      signedIn: true,
      access: '23 guided sessions',
      offers: const [],
    );
    expect(body, contains('7-day free trial, then half price'));
    expect(body, contains(r'CAD $18.99/month'));
    expect(body, contains(r'CAD $149.99/year'));
    expect(body, contains('12 months'));
    expect(body, contains('2 years'));
    expect(
      PlanFallback.playerCaption(const []),
      contains('7-day free trial, then half price'),
    );
  });

  test('a loaded offering is quoted instead of the CAD fallback', () {
    final offers = [trialThenHalf, annualTrialThenHalf];
    expect(PlanFallback.lockedButton(offers), PlanFallback.buttonLabel);
    final body = PlanFallback.unlockMessage(
      signedIn: true,
      access: '23 guided sessions',
      offers: offers,
    );
    expect(body, contains('7-day free trial, then half price'));
    expect(body, contains(trialThenHalf.termsLine));
    expect(body, contains(annualTrialThenHalf.termsLine));
    expect(body, isNot(contains(r'CAD $18.99')));
    expect(body, isNot(contains(r'CAD $149.99')));
    // Annual is listed first, matching the paywall cards.
    expect(body.indexOf('Annual:'), lessThan(body.indexOf('Monthly:')));
  });

  test('an ineligible customer is not promised a trial or a discount', () {
    const plain = PlanOffer(
      annual: false,
      renewalPrice: r'$13.99',
      periodLabel: '/month',
    );
    expect(PlanFallback.lockedButton(const [plain]), 'Subscribe');
    final body = PlanFallback.unlockMessage(
      signedIn: true,
      access: 'the library',
      offers: const [plain],
    );
    expect(body, contains(plain.termsLine));
    expect(body, isNot(contains('half price')));
    expect(body, isNot(contains('free trial')));
  });

  test('a trial with no discount does not invent a half-price period', () {
    const trialOnly = PlanOffer(
      annual: false,
      renewalPrice: r'$18.99',
      periodLabel: '/month',
      freeTrialLabel: '7-day free trial',
    );
    expect(
        PlanFallback.lockedButton(const [trialOnly]), 'Start 7-day free trial');
    final body = PlanFallback.unlockMessage(
      signedIn: false,
      access: 'the library',
      offers: const [trialOnly],
    );
    expect(body, contains('Sign in and start your 7-day free trial'));
    expect(body, isNot(contains('half price')));
    expect(body, contains(trialOnly.termsLine));
  });
}
