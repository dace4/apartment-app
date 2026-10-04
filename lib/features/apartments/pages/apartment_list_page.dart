import 'package:appartment_app_group_2/features/apartments/data/sample_apartments.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../widgets/apartment_card.dart';

class ApartmentListPage extends StatelessWidget {
  const ApartmentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apartments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Filters',
            onPressed: () => context.go(AppRoutes.filters),
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare',
            onPressed: () => context.go(AppRoutes.compare),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: sampleApartments.length,
        itemBuilder: (context, index) {
          final apartment = sampleApartments[index];
          return ApartmentCard(
            apartment: apartment,
            onTap: () => context.go(AppRoutes.apartmentDetail(apartment.id)),
          );
        },
      ),
    );
  }
}
