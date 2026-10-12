import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/message_view.dart';
import '../../../services/apartment_service.dart';
import '../../../models/apartment.dart';
import '../data/application_repository.dart';
import '../models/rental_application.dart';
import '../widgets/application_form.dart';

/// Application form for one apartment. After submitting, the application
/// can be tracked on the My applications tab (US 16).
class ApplyPage extends StatefulWidget {
  const ApplyPage({
    super.key,
    required this.apartmentId,
    this.applicationRepository = const UnconfiguredApplicationRepository(),
  });

  final String apartmentId;
  final ApplicationRepository applicationRepository;

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  final _apartmentService = ApartmentService();
  late Future<Apartment?> _apartment;

  // Reused on every retry, so a submission whose response was lost is
  // confirmed instead of being stored twice.
  late final String _applicationId = widget.applicationRepository
      .createApplicationId();

  @override
  void initState() {
    super.initState();
    _apartment = _apartmentService.getApartment(widget.apartmentId);
  }

  void _reload() {
    setState(() {
      _apartment = _apartmentService.getApartment(widget.apartmentId);
    });
  }

  Future<String?> _submit(
    Apartment apartment,
    ApplicationDetails details,
  ) async {
    try {
      await widget.applicationRepository.submit(
        id: _applicationId,
        apartmentId: apartment.id,
        apartmentTitle: apartment.title,
        details: details,
      );
    } on ApplicationException catch (e) {
      return e.message;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted.')));
      context.go(AppRoutes.applicationDetail(_applicationId));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply')),
      body: FutureBuilder<Apartment?>(
        future: _apartment,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MessageView(
              icon: Icons.cloud_off,
              message: 'Could not load the apartment.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }
          final apartment = snapshot.data;
          if (apartment == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This apartment is no longer listed.',
            );
          }
          if (!apartment.canApply) {
            return const MessageView(
              icon: Icons.event_busy,
              message: 'This apartment is not available for applications.',
            );
          }

          final theme = Theme.of(context);
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(apartment.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${apartment.city} · ${formatChf(apartment.price)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ApplicationForm(
                      submitLabel: 'Submit application',
                      onSubmit: (details) => _submit(apartment, details),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
