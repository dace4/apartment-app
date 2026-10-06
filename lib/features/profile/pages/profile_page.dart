import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../auth/data/auth_repository.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      // Rebuilds when the user logs in or out.
      body: ListenableBuilder(
        listenable: authRepository,
        builder: (context, _) {
          final user = authRepository.currentUser;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Signed-out users are redirected to the login page by the router.
              if (user != null)
                _SignedInCard(user: user, authRepository: authRepository),
              const SizedBox(height: 16),
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

class _SignedInCard extends StatefulWidget {
  const _SignedInCard({required this.user, required this.authRepository});

  final AppUser user;
  final AuthRepository authRepository;

  @override
  State<_SignedInCard> createState() => _SignedInCardState();
}

class _SignedInCardState extends State<_SignedInCard> {
  bool _loggingOut = false;

  Future<void> _logOut() async {
    setState(() => _loggingOut = true);
    try {
      await widget.authRepository.signOut();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(widget.user.email),
              subtitle: Text(
                widget.user.emailVerified
                    ? 'Email verified'
                    : 'Email not verified',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loggingOut ? null : _logOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
