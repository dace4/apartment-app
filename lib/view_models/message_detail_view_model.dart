import 'package:flutter/foundation.dart';

import '../models/advertiser_message.dart';
import '../services/message_service.dart';

/// US 12: one message received by the owner or manager of an apartment.
class MessageDetailViewModel extends ChangeNotifier {
  MessageDetailViewModel({MessageService? service})
    : service = service ?? MessageService();

  final MessageService service;
  bool _disposed = false;

  /// null once loaded means the message does not exist.
  AdvertiserMessage? message;
  bool isLoading = false;
  String? errorMessage;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> fetchMessage(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      message = await service.getMessage(id);
    } catch (e) {
      errorMessage = 'Could not load the message.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
