import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

class ApplicationDetailPage extends StatelessWidget {
  const ApplicationDetailPage({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(title: 'Application $applicationId');
  }
}
