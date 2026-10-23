import 'package:flutter/material.dart';

import '../../../view_models/visit_booking_view_model.dart';

/// US-20: green dot for a free slot, red for a taken one, the theme colour
/// for the user's own visit. Always shown next to the status text, so the
/// colour is not the only signal.
class SlotStatusDot extends StatelessWidget {
  const SlotStatusDot({super.key, required this.status});

  final SlotStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SlotStatus.free => Colors.green.shade600,
      SlotStatus.taken => Colors.red.shade600,
      SlotStatus.yours => Theme.of(context).colorScheme.primary,
    };
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
