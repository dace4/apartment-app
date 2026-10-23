import 'dart:convert';

import 'package:flutter/material.dart';

/// Legacy network images and US-24 compressed inline photos share a fallback.
class ApartmentImage extends StatelessWidget {
  const ApartmentImage({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        const Center(child: Icon(Icons.home_outlined, size: 48));
    Widget photo;
    try {
      photo = imageUrl.startsWith('data:image/jpeg;base64,')
          ? Image.memory(
              base64Decode(imageUrl.substring(23)),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            )
          : imageUrl.isEmpty
          ? fallback()
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            );
    } catch (_) {
      photo = fallback();
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: photo,
      ),
    );
  }
}
