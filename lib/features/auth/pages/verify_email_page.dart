import 'package:flutter/material.dart';

import '../data/auth_repository.dart';

/// Shown to signed-in users whose email is not verified yet (US-06).
/// Once verified, the router redirects to the home page.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _loading = false;

  /// Runs [action] and shows [successMessage] or the error in a snackbar.
  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);
    String? message = successMessage;
    try {
      await action();
    } on AuthException catch (e) {
      message = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted && message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _checkVerified() async {
    await _run(widget.authRepository.reloadUser);
    final user = widget.authRepository.currentUser;
    // When verified, the router has already left this page.
    if (mounted && user != null && !user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your email is not verified yet. Open the link in the email first.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = widget.authRepository.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We sent a confirmation email to $email. Open the link '
                    'in the email to verify your account, then come back here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _checkVerified,
                    child: const Text('I have verified my email'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            widget.authRepository.sendEmailVerification,
                            successMessage: 'Confirmation email sent again.',
                          ),
                    child: const Text('Resend email'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _run(widget.authRepository.signOut),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
