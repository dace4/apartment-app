import 'package:flutter/material.dart';

import '../../view_models/auth_view_model.dart';
import '../shared/widgets/message_view.dart';

/// Shown to everyone but admins while an app maintenance window runs. The
/// router leaves this page by itself when the window ends.
class AppMaintenanceView extends StatelessWidget {
  const AppMaintenanceView({super.key, required this.authViewModel});

  final AuthViewModel authViewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MessageView(
        icon: Icons.construction,
        message:
            'The app is under maintenance.\n'
            'Please come back when it ends.',
        actionLabel: 'Log out',
        onAction: authViewModel.signOut,
      ),
    );
  }
}
