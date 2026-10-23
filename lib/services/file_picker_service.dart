import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'document_exception.dart';
import 'document_service.dart';
import '../models/document_upload.dart';

/// US-15: native file selection outside Views and screen state.
class FilePickerService {
  Future<List<DocumentUpload>> pickDocuments(DocumentService service) async {
    final uid = service.userId;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'pdf'],
    );
    if (files.length > DocumentUpload.maxSelection) {
      throw const DocumentException('Choose at most 10 files at a time.');
    }
    final uploads = <DocumentUpload>[];
    for (final file in files) {
      try {
        final length = file.lengthSync() ?? await file.length();
        if (length == null || length > DocumentUpload.maxBytes) {
          throw const DocumentException(
            'Choose a readable file no larger than 700 KiB.',
          );
        }
        uploads.add(
          DocumentUpload(
            id: service.newDocumentId(),
            userId: uid,
            name: file.name,
            bytes: await file.readAsBytes(),
          ),
        );
      } catch (error) {
        uploads.add(
          DocumentUpload(
            id: service.newDocumentId(),
            userId: uid,
            name: file.name,
            bytes: Uint8List(0),
            selectionError: error is DocumentException
                ? error.message
                : 'Could not read this file. Select it again.',
          ),
        );
      }
    }
    return uploads;
  }
}
