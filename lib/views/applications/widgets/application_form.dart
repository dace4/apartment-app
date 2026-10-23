import 'package:flutter/material.dart';

import '../../../models/rental_application.dart';
import '../../../utils/formatters.dart';
import '../../../utils/validators.dart';

/// The application fields, used to apply and to edit an application.
class ApplicationForm extends StatefulWidget {
  const ApplicationForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.isSaving,
    required this.errorMessage,
    required this.onSubmit,
  });

  /// Pre-fills the form when editing.
  final ApplicationDetails? initial;
  final String submitLabel;

  /// Both come from the screen's ViewModel.
  final bool isSaving;
  final String? errorMessage;

  /// Called with the filled-in details once the form is valid.
  final void Function(ApplicationDetails details) onSubmit;

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

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _occupants.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickMoveInDate(FormFieldState<DateTime> field) async {
    final today = Validators.dateOnly(DateTime.now());
    final current = field.value;
    // The picker requires initialDate >= firstDate.
    final firstDate = current != null && current.isBefore(today)
        ? Validators.dateOnly(current)
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

  void _submit() {
    if (widget.isSaving || !_formKey.currentState!.validate()) return;

    widget.onSubmit(
      ApplicationDetails(
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        moveInDate: _moveInDate!,
        occupants: int.parse(_occupants.text.trim()),
        message: _message.text.trim(),
      ),
    );
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
            readOnly: widget.isSaving,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
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
            readOnly: widget.isSaving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: Validators.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormField<DateTime>(
            initialValue: _moveInDate,
            validator: (value) => Validators.moveInDate(
              value,
              initial: widget.initial?.moveInDate,
            ),
            builder: (field) => InkWell(
              onTap: widget.isSaving ? null : () => _pickMoveInDate(field),
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
            readOnly: widget.isSaving,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: Validators.occupants,
            decoration: const InputDecoration(
              labelText: 'Number of occupants',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _message,
            readOnly: widget.isSaving,
            minLines: 3,
            maxLines: 6,
            maxLength: Validators.messageLimit,
            keyboardType: TextInputType.multiline,
            validator: Validators.applicationMessage,
            decoration: const InputDecoration(
              labelText: 'Message to the advertiser (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                widget.errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.isSaving ? null : _submit,
            child: widget.isSaving
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
