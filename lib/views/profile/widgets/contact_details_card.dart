import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../utils/validators.dart';
import '../../../view_models/contact_details_view_model.dart';

/// US-06: add or change the name and phone that pre-fill the forms, in a
/// section that opens on tap. Closed, it shows the saved details.
class ContactDetailsCard extends StatefulWidget {
  const ContactDetailsCard({super.key, required this.user, this.viewModel});

  final AppUser user;

  /// Tests pass one with a fake service.
  final ContactDetailsViewModel? viewModel;

  @override
  State<ContactDetailsCard> createState() => _ContactDetailsCardState();
}

class _ContactDetailsCardState extends State<ContactDetailsCard> {
  late final viewModel = widget.viewModel ?? ContactDetailsViewModel();
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);

  @override
  void dispose() {
    viewModel.dispose();
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (viewModel.isSaving || !_formKey.currentState!.validate()) return;
    final saved = await viewModel.save(_fullName.text, _phone.text);
    if (saved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact details saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('Contact details'),
        subtitle: Text(
          user.hasContactDetails
              ? '${user.fullName} · ${user.phone}'
              : 'Not added yet: add them to fill in forms faster',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [_buildForm(theme)],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _fullName,
              readOnly: viewModel.isSaving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              maxLength: Validators.nameLimit,
              validator: Validators.fullName,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              readOnly: viewModel.isSaving,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: Validators.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            if (viewModel.actionError != null)
              Text(
                viewModel.actionError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: viewModel.isSaving ? null : _save,
              child: Text(
                viewModel.isSaving ? 'Saving…' : 'Save contact details',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
