import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../utils/validators.dart';
import '../../view_models/login_view_model.dart';
import 'widgets/password_field.dart';

/// Welcome page and US-07: log in with email and password. Signed-out
/// users always land here; on success the router redirects to the home
/// page (see `redirect` in app_router.dart).
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final viewModel = LoginViewModel();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    viewModel.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (viewModel.isLoading || !_formKey.currentState!.validate()) return;
    viewModel.signIn(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final theme = Theme.of(context);

    // No app bar: this is the first page users see when signed out.
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.home_rounded,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome to HomeFlow',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find, compare and apply for apartments. '
                        'Log in or create an account to continue.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _passwordController,
                        label: 'Password',
                        validator: Validators.requiredPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (viewModel.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          viewModel.errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: viewModel.isLoading ? null : _submit,
                        child: viewModel.isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Log in'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.register),
                        child: const Text('No account yet? Create one'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
