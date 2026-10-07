import 'package:flutter/material.dart';

import '../models/apartment.dart';

/// US 8: shared status display for cards and details. Text and icons communicate
/// the status without relying on color.
class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({super.key, required this.apartment});
  final Apartment apartment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = switch (apartment.availability) {
      ApartmentAvailability.available => Icons.check_circle_outline,
      ApartmentAvailability.reserved => Icons.schedule,
      ApartmentAvailability.unavailable => Icons.block,
    };
    return Chip(
      avatar: Icon(icon, size: 18),
      backgroundColor: apartment.canApply
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      label: Text(apartment.availability.label),
    );
  }
}
