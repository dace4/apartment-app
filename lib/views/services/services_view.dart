import 'package:flutter/material.dart';

import '../../router/app_routes.dart';
import '../../view_models/auth_view_model.dart';
import '../shared/widgets/placeholder_view.dart';

class ServicesView extends StatelessWidget {
  const ServicesView({super.key, required this.viewModel});
  final AuthViewModel viewModel;
  @override
  Widget build(BuildContext context) => PlaceholderView(
    title: 'Services',
    comingSoon: false,
    links: [
      if (viewModel.canAccess(AppRoutes.mortgage))
        const PageLink('Mortgage calculator', AppRoutes.mortgage),
      if (viewModel.canAccess(AppRoutes.maintenance))
        const PageLink('Repair & maintenance', AppRoutes.maintenance),
      if (viewModel.canAccess(AppRoutes.insurance))
        const PageLink('Insurance', AppRoutes.insurance),
      if (viewModel.canAccess(AppRoutes.contractors))
        const PageLink('Renovation contractors', AppRoutes.contractors),
      if (viewModel.canAccess(AppRoutes.marketTrends))
        const PageLink('Market trends', AppRoutes.marketTrends),
    ],
  );
}
