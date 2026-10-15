import 'package:flutter/material.dart';

import '../../../utils/validators.dart';

/// US 23.2: asks for the name of the search to save. Closes with the name,
/// or with null when cancelled.
class SaveSearchDialog extends StatefulWidget {
  const SaveSearchDialog({super.key, required this.description});

  /// Summary of the criteria being saved.
  final String description;

  @override
  State<SaveSearchDialog> createState() => _SaveSearchDialogState();
}

class _SaveSearchDialogState extends State<SaveSearchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save this search'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: Validators.savedSearchNameLimit,
              validator: Validators.savedSearchName,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. 3 rooms in Sion',
                border: OutlineInputBorder(),
              ),
            ),
            const Text('New matching offers will alert you.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
