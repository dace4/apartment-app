import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/rental_application.dart';
import '../../router/app_routes.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/message_view.dart';
import '../../view_models/apply_view_model.dart';
import 'widgets/application_form.dart';

/// Application form for one apartment. After submitting, the application
/// can be tracked on the My applications tab (US 16).
class ApplyView extends StatefulWidget {
  const ApplyView({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  State<ApplyView> createState() => _ApplyViewState();
}

class _ApplyViewState extends State<ApplyView> {
  final viewModel = ApplyViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchApartment(widget.apartmentId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit(ApplicationDetails details) async {
    final submitted = await viewModel.submit(details);
    if (submitted && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted.')));
      context.go(AppRoutes.applications);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // 1. Loading
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (viewModel.errorMessage != null) {
            return MessageView(
              icon: Icons.cloud_off,
              message: viewModel.errorMessage!,
              actionLabel: 'Retry',
              onAction: () => viewModel.fetchApartment(widget.apartmentId),
            );
          }

          // 3. Not found or not available
          final apartment = viewModel.apartment;
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

          // 4. Data
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
                      isSaving: viewModel.isSaving,
                      errorMessage: viewModel.saveError,
                      onSubmit: _submit,
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
