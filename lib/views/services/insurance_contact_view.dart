import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/insurance_request.dart';
import '../../router/app_routes.dart';
import '../../utils/validators.dart';
import '../../view_models/insurance_contact_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-19: sends a request to a coverage's agent and shows a confirmation.
class InsuranceContactView extends StatefulWidget {
  const InsuranceContactView({super.key, required this.coverageId});

  final String coverageId;

  @override
  State<InsuranceContactView> createState() => _InsuranceContactViewState();
}

class _InsuranceContactViewState extends State<InsuranceContactView> {
  final viewModel = InsuranceContactViewModel();
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel.fetchCoverage(widget.coverageId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _send() {
    if (viewModel.isSending || !_formKey.currentState!.validate()) return;
    viewModel.send(phone: _phone.text, message: _message.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact agent')),
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
                onAction: () => viewModel.fetchCoverage(widget.coverageId),
              );
            }
            // 3. Not found
            if (viewModel.coverage == null) {
              return MessageView(
                icon: Icons.search_off,
                message: 'This coverage is no longer offered.',
                actionLabel: 'Back to insurance',
                onAction: () => context.go(AppRoutes.insurance),
              );
            }
            // 4. Data
            if (viewModel.sentRequestId != null) return _confirmation(context);
            return _form(context);
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final coverage = viewModel.coverage!;

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
                Text(coverage.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('To: ${coverage.agentName}'),
                const SizedBox(height: 24),
                Text(
                  'How should the agent answer?',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<ContactMethod>(
                  segments: [
                    for (final method in ContactMethod.values)
                      ButtonSegment(value: method, label: Text(method.label)),
                  ],
                  selected: {viewModel.contactMethod},
                  onSelectionChanged: viewModel.isSending
                      ? null
                      : (selection) =>
                            viewModel.selectContactMethod(selection.single),
                ),
                const SizedBox(height: 16),
                if (viewModel.contactMethod == ContactMethod.phone) ...[
                  TextFormField(
                    controller: _phone,
                    readOnly: viewModel.isSending,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: viewModel.validatePhone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _message,
                  readOnly: viewModel.isSending,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: Validators.bodyLimit,
                  keyboardType: TextInputType.multiline,
                  validator: viewModel.validateMessage,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText:
                        'For example: what you want to insure and what your '
                        'landlord requires.',
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
                    viewModel.isSending ? 'Sending…' : 'Send request',
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
    final coverage = viewModel.coverage!;
    final byPhone = viewModel.contactMethod == ContactMethod.phone;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Request sent to ${coverage.agentName}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Your request about ${coverage.name} has been saved for the '
            'agent, who will answer you by '
            '${byPhone ? 'phone at ${_phone.text.trim()}' : 'email'}.',
          ),
          const SizedBox(height: 16),
          Text('Reference: ${viewModel.sentRequestId}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(AppRoutes.insurance),
            child: const Text('Back to insurance'),
          ),
        ],
      ),
    );
  }
}
