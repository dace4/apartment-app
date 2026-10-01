import 'package:flutter/material.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/placeholder_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Profile',
      links: [
        PageLink('Notifications', AppRoutes.notifications),
        PageLink('FAQ', AppRoutes.faq),
        PageLink('Log in', AppRoutes.login),
      ],
    );
  }
}
