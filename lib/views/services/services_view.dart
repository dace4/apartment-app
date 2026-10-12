import 'package:flutter/material.dart';

import '../../router/app_routes.dart';
import '../shared/widgets/placeholder_view.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Services',
      links: [
        PageLink('Mortgage calculator', AppRoutes.mortgage),
        PageLink('Repair & maintenance', AppRoutes.maintenance),
        PageLink('Insurance', AppRoutes.insurance),
        PageLink('Renovation contractors', AppRoutes.contractors),
        PageLink('Market trends', AppRoutes.marketTrends),
      ],
    );
  }
}
