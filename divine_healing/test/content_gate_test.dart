import 'package:divine_healing/features/paywall/content_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the first items of a section stay free', () {
    expect(isTasteLocked(hasFullAccess: false, index: 0), isFalse);
    expect(isTasteLocked(hasFullAccess: false, index: 1), isFalse);
    expect(isTasteLocked(hasFullAccess: false, index: 2), isTrue);
  });

  test('a subscriber is never locked', () {
    expect(isTasteLocked(hasFullAccess: true, index: 6), isFalse);
  });

  test('a multi-step exercise keeps only the first step', () {
    expect(
      isTasteLocked(
        hasFullAccess: false,
        index: 0,
        freeCount: freeFirstStepCount,
      ),
      isFalse,
    );
    expect(
      isTasteLocked(
        hasFullAccess: false,
        index: 1,
        freeCount: freeFirstStepCount,
      ),
      isTrue,
    );
  });
}
