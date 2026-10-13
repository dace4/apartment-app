import 'package:flutter/material.dart';

import '../../router/app_routes.dart';
import '../../view_models/favourites_view_model.dart';
import '../../view_models/compare_view_model.dart';
import '../apartments/apartments_view.dart';

class FavouritesView extends StatelessWidget {
  const FavouritesView({
    super.key,
    required this.viewModel,
    required this.compareViewModel,
  });

  final FavouritesViewModel viewModel;
  final CompareViewModel compareViewModel;

  @override
  Widget build(BuildContext context) {
    return ApartmentsView(
      viewModel: viewModel,
      compareViewModel: compareViewModel,
      favouritesViewModel: viewModel,
    );
  }
}
