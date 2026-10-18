import 'package:flutter/material.dart';

import '../../view_models/auth_view_model.dart';
import 'widgets/role_checkboxes.dart';

/// US-06: legacy onboarding also serves as the profile loading/error gate.
class ChooseRolesView extends StatelessWidget {
  const ChooseRolesView({super.key, required this.viewModel});
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your roles')),
    body: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final user = viewModel.user;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user?.rolesLoaded != true)
                    const Center(child: CircularProgressIndicator())
                  else if (user?.profileError != null) ...[
                    Text(user!.profileError!),
                    FilledButton(
                      onPressed: viewModel.retryProfile,
                      child: const Text('Retry'),
                    ),
                  ] else ...[
                    RoleCheckboxes(
                      selected: viewModel.selectedRoles,
                      enabled: !viewModel.isSaving,
                      onChanged: viewModel.setRole,
                    ),
                    if (viewModel.actionError != null)
                      Text(
                        viewModel.actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      onPressed: viewModel.isSaving
                          ? null
                          : viewModel.saveRoles,
                      child: Text(
                        viewModel.isSaving ? 'Saving…' : 'Save roles',
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: viewModel.signOut,
                    child: const Text('Log out'),
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
