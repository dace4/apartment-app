import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/rental_application.dart';
import '../../router/app_routes.dart';
import '../shared/widgets/message_view.dart';
import '../../view_models/edit_application_view_model.dart';
import 'widgets/application_form.dart';

/// US 16: edit an application within 5 days of submitting it.
class EditApplicationView extends StatefulWidget {
  const EditApplicationView({super.key, required this.applicationId});

  final String applicationId;

  @override
  State<EditApplicationView> createState() => _EditApplicationViewState();
}

class _EditApplicationViewState extends State<EditApplicationView> {
  final viewModel = EditApplicationViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchApplication(widget.applicationId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _save(ApplicationDetails details) async {
    final saved = await viewModel.save(details);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Changes saved.')));
      context.go(AppRoutes.applicationDetail(widget.applicationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit application')),
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
              onAction: () => viewModel.fetchApplication(widget.applicationId),
            );
          }

          // 3. Not found or too late
          final application = viewModel.application;
          if (application == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This application does not exist.',
            );
          }
          if (!viewModel.canChange) {
            return const MessageView(
              icon: Icons.lock_clock,
              message:
                  'This application can no longer be edited. Applications '
                  'can only be changed within 5 days.',
            );
          }

          // 4. Data
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      application.apartmentTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    ApplicationForm(
                      initial: application.details,
                      submitLabel: 'Save changes',
                      isSaving: viewModel.isSaving,
                      errorMessage: viewModel.saveError,
                      onSubmit: _save,
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
