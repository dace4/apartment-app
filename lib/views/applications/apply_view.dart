import '../../view_models/auth_view_model.dart';

import 'package:flutter/material.dart';

import '../../models/rental_application.dart';
import '../../router/app_routes.dart';
import '../../router/tab_navigation.dart';
import '../../utils/formatters.dart';
import '../shared/widgets/message_view.dart';
import '../../view_models/apply_view_model.dart';
import 'widgets/application_form.dart';

/// Application form for one apartment. After submitting, the application
/// can be tracked on the My applications tab (US 16).
class ApplyView extends StatefulWidget {
  final AuthViewModel? authViewModel;
  const ApplyView({
    this.authViewModel,
    super.key,
    required this.apartmentId,
    this.applyImmediately = false,
  });

  final String apartmentId;
  final bool applyImmediately;

  @override
  State<ApplyView> createState() => _ApplyViewState();
}

class _ApplyViewState extends State<ApplyView> {
  late final viewModel = ApplyViewModel(
    canApplyImmediately: () =>
        widget.authViewModel?.canAccess(
          AppRoutes.applyImmediately(widget.apartmentId),
        ) ==
        true,
    canAccess: () =>
        widget.authViewModel?.canAccess(AppRoutes.applications) == true,
  );

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
    final submitted = await viewModel.submit(
      details,
      immediately: widget.applyImmediately,
    );
    if (submitted && mounted) {
      // US 10: submitting never reserves the apartment.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application submitted. The apartment is not reserved '
            'until the owner accepts an application.',
          ),
        ),
      );
      // The Home tab returns to the apartment, not to the sent form.
      context.goToOtherTab(
        back: AppRoutes.apartmentDetail(widget.apartmentId),
        to: AppRoutes.applications,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.applyImmediately ? 'Apply immediately' : 'Apply'),
      ),
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
                    if (widget.applyImmediately) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Your application is sent to the owner right away. '
                        'It does not reserve the apartment.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    // US-15: optional reusable documents; no signing prerequisite.
                    Text(
                      'Attachments (optional, up to 5)',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (viewModel.attachmentError != null) ...[
                      Text(viewModel.attachmentError!),
                      TextButton(
                        onPressed: viewModel.isSaving
                            ? null
                            : () =>
                                  viewModel.fetchApartment(widget.apartmentId),
                        child: const Text('Retry attachments'),
                      ),
                    ],
                    if (viewModel.documents.isEmpty &&
                        viewModel.attachmentError == null)
                      const Text(
                        'Upload files in Profile → My documents to attach them here.',
                      ),
                    for (final document in viewModel.documents)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(document.name),
                        subtitle: Text(document.statusLabel),
                        value: viewModel.selectedDocumentIds.contains(
                          document.id,
                        ),
                        onChanged: viewModel.isSaving
                            ? null
                            : (selected) => viewModel.selectDocument(
                                document.id,
                                selected ?? false,
                              ),
                      ),
                    const SizedBox(height: 24),
                    ApplicationForm(
                      // US-06: pre-filled from the profile, still editable.
                      defaultFullName: widget.authViewModel?.user?.fullName,
                      defaultPhone: widget.authViewModel?.user?.phone,
                      submitLabel: widget.applyImmediately
                          ? 'Apply immediately'
                          : 'Submit application',
                      isSaving: viewModel.isSaving,
                      errorMessage: viewModel.actionError,
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
