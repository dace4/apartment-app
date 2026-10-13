import 'dart:convert';
import 'dart:math';

import 'signature_point.dart';

/// US-11: vector strokes, stored without a public image URL or file upload.
class SignatureDrawing {
  SignatureDrawing(Iterable<Iterable<SignaturePoint>> strokes)
    : strokes = List.unmodifiable(
        strokes.map((s) => List<SignaturePoint>.unmodifiable(s)),
      );

  static const maxPoints = 2000;
  static const maxEncodedLength = 100000;
  final List<List<SignaturePoint>> strokes;

  int get pointCount => strokes.fold(0, (count, s) => count + s.length);

  bool get hasInk {
    if (pointCount > maxPoints ||
        strokes.isEmpty ||
        strokes.any((s) => s.isEmpty || s.any((p) => !p.isValid))) {
      return false;
    }
    double distance = 0;
    for (final stroke in strokes) {
      for (var i = 1; i < stroke.length; i++) {
        final a = stroke[i - 1];
        final b = stroke[i];
        distance += sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2));
      }
    }
    return distance >= .02 && encode().length <= maxEncodedLength;
  }

  String encode() => jsonEncode(
    strokes.map((s) => s.map((p) => p.toList()).toList()).toList(),
  );

  factory SignatureDrawing.decode(String encoded) {
    if (encoded.length > maxEncodedLength) {
      throw const FormatException('Signature is too large.');
    }
    final data = jsonDecode(encoded) as List;
    final drawing = SignatureDrawing(
      data.map(
        (s) => (s as List).map((p) {
          final pair = p as List;
          if (pair.length != 2) throw const FormatException('Invalid point.');
          return SignaturePoint(
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          );
        }),
      ),
    );
    if (!drawing.hasInk) throw const FormatException('Invalid signature.');
    return drawing;
  }
}
