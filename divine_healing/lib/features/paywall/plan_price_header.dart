import 'package:flutter/material.dart';

import '../../theme.dart';

/// The price block on a plan card.
///
/// A free trial leads with the trial and "$0 today". The amount charged
/// after the trial, and the fact that the plan auto-renews, sit in
/// [disclosure] — Play and the App Store both require that next to the
/// offer, not behind a tap.
class PlanPriceHeader extends StatelessWidget {
  const PlanPriceHeader({
    super.key,
    this.headline,
    required this.price,
    this.period,
    required this.disclosure,
  });

  /// "Start your 7-day free trial", or null when the store offered no trial.
  final String? headline;

  /// "$0 today" during a trial, otherwise the store's formatted price.
  final String price;

  /// "/month" or "/year" beside [price]. Omitted for "$0 today", because
  /// that figure is not a billing period.
  final String? period;

  final String disclosure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headline != null && headline!.isNotEmpty) ...[
          Text(
            headline!,
            style: DHTypography.heading(size: 18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
        ],
        RichText(
          text: TextSpan(
            style: DHTypography.heading(size: 28, weight: FontWeight.w600),
            children: [
              TextSpan(text: price),
              if (period != null)
                TextSpan(
                  text: period,
                  style: DHTypography.body(size: 13, color: DHColors.secondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          disclosure,
          style: DHTypography.body(
            size: 12,
            color: DHColors.secondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
