import 'package:flutter/material.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/placeholder_page.dart';

class ApartmentListPage extends StatelessWidget {
  const ApartmentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Apartments',
      links: [
        const PageLink('Filters', AppRoutes.filters),
        const PageLink('Compare', AppRoutes.compare),
        PageLink('Sample apartment', AppRoutes.apartmentDetail('1')),
      ],
    );
  }
}
