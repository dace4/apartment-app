import 'dart:typed_data';

/// US-15: selected bytes and stable upload ID, independent of screen state.
class DocumentUpload {
  DocumentUpload({
    required this.id,
    required this.userId,
    required this.name,
    required Uint8List bytes,
    this.selectionError,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  static const maxBytes = 700 * 1024;
  static const maxSelection = 10;
  static const maxAttachments = 5;
  final String id;
  final String userId;
  final String name;
  final Uint8List bytes;
  final String? selectionError;
  String get extension => name.split('.').last.toLowerCase();
  String get mimeType => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'pdf' => 'application/pdf',
    _ => '',
  };
}
