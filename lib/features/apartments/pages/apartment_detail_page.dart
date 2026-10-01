import 'package:flutter/material.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/placeholder_page.dart';

class ApartmentDetailPage extends StatelessWidget {
  const ApartmentDetailPage({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Apartment $apartmentId',
      links: [
        PageLink('Apply', AppRoutes.apply(apartmentId)),
        PageLink(
          'Contact advertiser',
          AppRoutes.contactAdvertiser(apartmentId),
        ),
        const PageLink('Mortgage calculator', AppRoutes.mortgage),
      ],
    );
  }
}
