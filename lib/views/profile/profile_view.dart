import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../view_models/auth_view_model.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.viewModel});

  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      // Rebuilds when the user logs in or out.
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final user = viewModel.user;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Signed-out users are redirected to the login page by the router.
              if (user != null) _SignedInCard(viewModel: viewModel),
              const SizedBox(height: 16),
              // US-11: entry point for document review and e-signatures.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('My documents'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.documents),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.notifications),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('FAQ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.faq),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.viewModel});

  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final user = viewModel.user!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.email),
              subtitle: Text(
                user.emailVerified ? 'Email verified' : 'Email not verified',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: viewModel.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
