import 'package:flutter/material.dart';

import 'apartment_image.dart';

/// US-24: swipe gallery with accessible previous/next controls and position.
class ApartmentGallery extends StatefulWidget {
  const ApartmentGallery({super.key, required this.imageUrls});
  final List<String> imageUrls;
  @override
  State<ApartmentGallery> createState() => _ApartmentGalleryState();
}

class _ApartmentGalleryState extends State<ApartmentGallery> {
  final _controller = PageController();
  int _index = 0;
  @override
  void didUpdateWidget(covariant ApartmentGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.join() != widget.imageUrls.join()) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const ApartmentImage(imageUrl: '');
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => Semantics(
              label:
                  'Apartment picture ${index + 1} of ${widget.imageUrls.length}',
              child: ApartmentImage(imageUrl: widget.imageUrls[index]),
            ),
          ),
        ),
        if (widget.imageUrls.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous picture',
                icon: const Icon(Icons.chevron_left),
                onPressed: _index == 0
                    ? null
                    : () => _controller.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
              ),
              Text('${_index + 1} / ${widget.imageUrls.length}'),
              IconButton(
                tooltip: 'Next picture',
                icon: const Icon(Icons.chevron_right),
                onPressed: _index == widget.imageUrls.length - 1
                    ? null
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
              ),
            ],
          ),
      ],
    );
  }
}
