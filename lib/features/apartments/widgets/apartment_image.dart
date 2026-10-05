import 'package:flutter/material.dart';

/// Apartment photo in 16:9, with a grey background while it loads and an
/// icon if it cannot be loaded.
class ApartmentImage extends StatelessWidget {
  const ApartmentImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Icon(Icons.home_outlined, size: 48)),
        ),
      ),
    );
  }
}
