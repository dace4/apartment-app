import 'package:flutter/material.dart';

import '../../../models/user_role.dart';
import '../../../view_models/auth_view_model.dart';
import '../../auth/widgets/role_checkboxes.dart';

/// US-06: the roles of the Profile page in a section that opens on tap.
/// Closed, it shows the saved roles.
class RolesCard extends StatelessWidget {
  const RolesCard({super.key, required this.viewModel});

  final AuthViewModel viewModel;

  Future<void> _save(BuildContext context) async {
    final saved = await viewModel.saveRoles();
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Roles saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = viewModel.user?.roles ?? const {};

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Your roles'),
        subtitle: Text(
          UserRole.values
              .where(saved.contains)
              .map((role) => role.label)
              .join(', '),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          RoleCheckboxes(
            selected: viewModel.selectedRoles,
            enabled: !viewModel.isSaving,
            onChanged: viewModel.setRole,
            showTitle: false,
          ),
          if (viewModel.actionError != null)
            Text(
              viewModel.actionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: viewModel.isSaving ? null : () => _save(context),
              child: Text(viewModel.isSaving ? 'Saving…' : 'Save roles'),
            ),
          ),
        ],
      ),
    );
  }
}
