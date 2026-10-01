import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

/// Application form: personal details, document upload and e-signature.
class ApplyPage extends StatelessWidget {
  const ApplyPage({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(title: 'Apply for apartment $apartmentId');
  }
}
