import 'package:flutter/material.dart';

import '../../../models/user_role.dart';

/// US-06: the same accessible role inputs in registration and Profile.
class RoleCheckboxes extends StatelessWidget {
  const RoleCheckboxes({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.showTitle = true,
  });
  final Set<UserRole> selected;
  final void Function(UserRole, bool) onChanged;
  final bool enabled;

  /// False inside Profile's "Your roles" section, which has the title.
  final bool showTitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showTitle) ...[
        Text('Your roles', style: Theme.of(context).textTheme.titleMedium),
        const Text('Choose one or more. You can change them in Profile.'),
      ] else
        const Text('Choose one or more.'),
      if (selected.contains(UserRole.admin))
        const Text('You are an admin. This role is managed by the project.'),
      for (final role in UserRole.selectable)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(role.label),
          value: selected.contains(role),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: enabled
              ? (value) => onChanged(role, value ?? false)
              : null,
        ),
    ],
  );
}
