import 'package:flutter/material.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/placeholder_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Log in',
      links: [
        PageLink('Create an account', AppRoutes.register),
        PageLink('Continue without account', AppRoutes.apartments),
      ],
    );
  }
}
