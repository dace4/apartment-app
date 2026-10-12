import 'package:flutter/material.dart';

import '../../view_models/auth_view_model.dart';

/// Shown to signed-in users whose email is not verified yet (US-06).
/// Once verified, the router redirects to the home page.
class VerifyEmailView extends StatelessWidget {
  const VerifyEmailView({super.key, required this.viewModel});

  /// Shared with the router and the Profile page.
  final AuthViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) {
                  final email = viewModel.user?.email ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We sent a confirmation email to $email. Open the '
                        'link in the email to verify your account, then come '
                        'back here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : viewModel.checkEmailVerified,
                        child: const Text('I have verified my email'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : viewModel.resendVerificationEmail,
                        child: const Text('Resend email'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: viewModel.isLoading
                            ? null
                            : viewModel.signOut,
                        child: const Text('Log out'),
                      ),
                      if (viewModel.message != null) ...[
                        const SizedBox(height: 16),
                        Text(viewModel.message!, textAlign: TextAlign.center),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
