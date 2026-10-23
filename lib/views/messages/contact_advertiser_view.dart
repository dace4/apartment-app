import '../../view_models/auth_view_model.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../shared/widgets/message_view.dart';
import '../../utils/validators.dart';
import '../../view_models/contact_advertiser_view_model.dart';

/// US 12: sends a question to the advertiser of an apartment and shows a
/// confirmation.
class ContactAdvertiserView extends StatefulWidget {
  final AuthViewModel? authViewModel;
  const ContactAdvertiserView({
    this.authViewModel,
    super.key,
    required this.apartmentId,
  });

  final String apartmentId;

  @override
  State<ContactAdvertiserView> createState() => _ContactAdvertiserViewState();
}

class _ContactAdvertiserViewState extends State<ContactAdvertiserView> {
  late final viewModel = ContactAdvertiserViewModel(
    canAccess: () =>
        widget.authViewModel?.canAccess(AppRoutes.applications) == true,
  );
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController(text: 'Apartment enquiry');
  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel.fetchContact(widget.apartmentId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _send() {
    if (viewModel.isSending || !_formKey.currentState!.validate()) return;
    viewModel.send(_subject.text, _body.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact advertiser')),
      body: SafeArea(
        child: ListenableBuilder(
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
                onAction: () => viewModel.fetchContact(widget.apartmentId),
              );
            }

            // 3. Not found
            if (viewModel.apartment == null) {
              return const MessageView(
                icon: Icons.search_off,
                message: 'This apartment is no longer listed.',
              );
            }
            if (viewModel.contact == null) {
              return const MessageView(
                icon: Icons.person_off_outlined,
                message:
                    'No advertiser contact is available for this apartment.',
              );
            }

            // 4. Data
            if (viewModel.sentMessageId != null) return _confirmation(context);
            return _form(context);
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  viewModel.apartment!.title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('To: ${viewModel.contact!.advertiserName}'),
                Text('From: ${viewModel.senderEmail}'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _subject,
                  readOnly: viewModel.isSending,
                  maxLength: Validators.subjectLimit,
                  textInputAction: TextInputAction.next,
                  validator: Validators.messageSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  readOnly: viewModel.isSending,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: Validators.bodyLimit,
                  keyboardType: TextInputType.multiline,
                  validator: Validators.messageBody,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Ask a question about this apartment.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (viewModel.actionError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    viewModel.actionError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: viewModel.isSending ? null : _send,
                  icon: viewModel.isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    viewModel.isSending ? 'Sending…' : 'Send message',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmation(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline, size: 56),
          const SizedBox(height: 16),
          Text(
            'Message sent',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your message to ${viewModel.contact!.advertiserName} about '
            '${viewModel.apartment!.title} has been saved and is available '
            'to the advertiser.',
          ),
          const SizedBox(height: 16),
          Text('Reference: ${viewModel.sentMessageId}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                context.go(AppRoutes.apartmentDetail(widget.apartmentId)),
            child: const Text('Back to apartment'),
          ),
        ],
      ),
    );
  }
}
