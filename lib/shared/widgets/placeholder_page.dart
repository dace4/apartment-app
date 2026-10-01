import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A link shown on a [PlaceholderPage] to reach another route.
class PageLink {
  const PageLink(this.label, this.location);

  final String label;
  final String location;
}

/// Empty page used until a feature is implemented. Lists links to the
/// pages reachable from here so the navigation can already be tested.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.links = const [],
  });

  final String title;
  final List<PageLink> links;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$title (coming soon)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          for (final link in links)
            Card(
              child: ListTile(
                title: Text(link.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(link.location),
              ),
            ),
        ],
      ),
    );
  }
}
