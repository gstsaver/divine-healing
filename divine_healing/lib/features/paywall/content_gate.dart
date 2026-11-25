import 'package:flutter/material.dart';

import '../../theme.dart';

/// Leading items of a section that stay readable without a subscription.
///
/// A taste in each section, then the same paywall as a locked meditation.
/// Existing preview sessions (Anxiety Release, Anxiety Release Short,
/// Introduction to Reiki) are a separate gate: they are marked `is_preview`
/// and are not counted here.
const int freeTasteCount = 2;

/// Multi-step exercises keep the first step open and lock the rest.
const int freeFirstStepCount = 1;

/// True when [index] is past the free taste and the person has not subscribed.
bool isTasteLocked({
  required bool hasFullAccess,
  required int index,
  int freeCount = freeTasteCount,
}) {
  if (hasFullAccess) return false;
  if (index < 0) return true;
  return index >= freeCount;
}

/// Lock icon plus a "Free trial" label, so a locked row is obvious before
/// the tap.
class FreeTrialBadge extends StatelessWidget {
  const FreeTrialBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DHColors.strawberryBlush.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline,
              size: 11, color: DHColors.strawberryBlush),
          const SizedBox(width: 3),
          Text(
            'FREE TRIAL',
            style: DHTypography.caption(color: DHColors.strawberryBlush)
                .copyWith(letterSpacing: 0.4, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
