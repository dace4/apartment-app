import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

import 'listing_exception.dart';

/// US-24: selection and bounded JPEG normalization, outside the View.
class ListingImageService {
  Future<List<String>> pickImages() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (files.length > 6) {
      throw const ListingException('Choose at most 6 pictures.');
    }
    final photos = <String>[];
    for (final file in files) {
      final size = file.lengthSync() ?? await file.length();
      if (size == null || size > 10 * 1024 * 1024) {
        throw const ListingException(
          'Choose JPEG or PNG files up to 10 MiB each.',
        );
      }
      photos.add(
        await compute(normalizeListingImage, await file.readAsBytes()),
      );
    }
    return photos;
  }
}

/// Isolate work avoids freezing the form while images are decoded and resized.
String normalizeListingImage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw const ListingException('Choose a readable JPEG or PNG up to 10 MiB.');
  }
  final decoder = image.findDecoderForData(bytes);
  if (decoder is! image.JpegDecoder && decoder is! image.PngDecoder) {
    throw const ListingException('Only JPEG and PNG pictures are supported.');
  }
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 32000000) {
    throw const ListingException(
      'Choose a readable picture of at most 32 megapixels.',
    );
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) {
    throw const ListingException('This picture could not be read.');
  }
  var photo = image.bakeOrientation(decoded);
  for (final width in [1280, 960, 640, 400]) {
    if (photo.width > width || photo.height > width) {
      photo = image.copyResize(
        photo,
        width: photo.width >= photo.height ? width : null,
        height: photo.height > photo.width ? width : null,
      );
    }
    final jpeg = image.encodeJpg(photo, quality: 75);
    if (jpeg.length <= 96 * 1024) {
      return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
    }
  }
  throw const ListingException(
    'This picture is too large. Choose a smaller picture.',
  );
}
