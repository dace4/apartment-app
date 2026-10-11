import 'package:flutter/material.dart';

import '../../../shared/utils/formatters.dart';
import '../models/rental_application.dart';
import '../utils/application_validators.dart';

/// The application fields, used to apply and to edit an application.
class ApplicationForm extends StatefulWidget {
  const ApplicationForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  /// Pre-fills the form when editing.
  final ApplicationDetails? initial;
  final String submitLabel;

  /// Saves the details and returns an error message, or null on success.
  final Future<String?> Function(ApplicationDetails details) onSubmit;

  @override
  State<ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.initial?.fullName);
  late final _phone = TextEditingController(text: widget.initial?.phone);
  late final _occupants = TextEditingController(
    text: widget.initial?.occupants.toString(),
  );
  late final _message = TextEditingController(text: widget.initial?.message);
  late DateTime? _moveInDate = widget.initial?.moveInDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _occupants.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _validateMoveInDate(DateTime? value) {
    final initial = widget.initial?.moveInDate;
    // A date kept from the original application may lie in the past by now.
    if (value != null &&
        initial != null &&
        ApplicationValidators.dateOnly(value) ==
            ApplicationValidators.dateOnly(initial)) {
      return null;
    }
    return ApplicationValidators.moveInDate(value, DateTime.now());
  }

  Future<void> _pickMoveInDate(FormFieldState<DateTime> field) async {
    final today = ApplicationValidators.dateOnly(DateTime.now());
    final current = field.value;
    // The picker requires initialDate >= firstDate.
    final firstDate = current != null && current.isBefore(today)
        ? ApplicationValidators.dateOnly(current)
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 2 * 365)),
      helpText: 'Move-in date',
    );
    if (picked == null) return;
    setState(() => _moveInDate = picked);
    field.didChange(picked);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      ApplicationDetails(
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        moveInDate: _moveInDate!,
        occupants: int.parse(_occupants.text.trim()),
        message: _message.text.trim(),
      ),
    );
    if (mounted) {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _fullName,
            readOnly: _saving,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            maxLength: ApplicationValidators.nameLimit,
            validator: ApplicationValidators.fullName,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phone,
            readOnly: _saving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: ApplicationValidators.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormField<DateTime>(
            initialValue: _moveInDate,
            validator: _validateMoveInDate,
            builder: (field) => InkWell(
              onTap: _saving ? null : () => _pickMoveInDate(field),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Move-in date',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                  errorText: field.errorText,
                ),
                child: Text(
                  field.value == null
                      ? 'Choose a date'
                      : formatDate(field.value!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _occupants,
            readOnly: _saving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: ApplicationValidators.occupants,
            decoration: const InputDecoration(
              labelText: 'Number of occupants',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _message,
            readOnly: _saving,
            minLines: 3,
            maxLines: 6,
            maxLength: ApplicationValidators.messageLimit,
            keyboardType: TextInputType.multiline,
            validator: ApplicationValidators.message,
            decoration: const InputDecoration(
              labelText: 'Message to the advertiser (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
