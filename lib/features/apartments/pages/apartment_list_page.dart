import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/message_view.dart';
import '../data/apartment_repository.dart';
import '../models/apartment.dart';
import '../widgets/apartment_card.dart';

class ApartmentListPage extends StatefulWidget {
  const ApartmentListPage({
    super.key,
    this.repository = const ApartmentRepository(),
  });

  final ApartmentRepository repository;

  @override
  State<ApartmentListPage> createState() => _ApartmentListPageState();
}

class _ApartmentListPageState extends State<ApartmentListPage> {
  // Started once in initState, not in build, so rebuilding the page
  // does not download the listings again.
  late Future<List<Apartment>> _apartments;

  @override
  void initState() {
    super.initState();
    _apartments = widget.repository.fetchApartments();
  }

  void _reload() {
    setState(() {
      _apartments = widget.repository.fetchApartments();
    });
  }

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
      body: FutureBuilder<List<Apartment>>(
        future: _apartments,
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (snapshot.hasError) {
            return MessageView(
              icon: Icons.cloud_off,
              message: 'Could not load the apartments.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }

          // 3. Empty
          final apartments = snapshot.requireData;
          if (apartments.isEmpty) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'No apartments available right now.',
            );
          }

          // 4. Data
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: apartments.length,
            itemBuilder: (context, index) {
              final apartment = apartments[index];
              return ApartmentCard(
                apartment: apartment,
                onTap: () =>
                    context.go(AppRoutes.apartmentDetail(apartment.id)),
              );
            },
          );
        },
      ),
    );
  }
}
