import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_page.dart';

class ContactAdvertiserPage extends StatelessWidget {
  const ContactAdvertiserPage({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(title: 'Contact advertiser ($apartmentId)');
  }
}
