import '../models/advertiser_message.dart';

class MessageException implements Exception {
  const MessageException(this.message, {this.confirmationPending = false});
  final String message;

  /// An uncertain outcome requires retrying the same draft and ID; generating
  /// a new message could duplicate a submission already stored by the server.
  final bool confirmationPending;
}

abstract class MessageRepository {
  const MessageRepository();

  /// Allocate a reference before sending so it can be reused after a timeout.
  String createMessageId();

  /// Confirm storage or report an error; a queued offline write is not success.
  Future<MessageReceipt> send(MessageDraft draft);
}

/// Never simulates successful delivery when no backend has been configured.
class UnconfiguredMessageRepository extends MessageRepository {
  const UnconfiguredMessageRepository();
  @override
  String createMessageId() => 'unconfigured';
  @override
  Future<MessageReceipt> send(MessageDraft draft) async =>
      throw const MessageException(
        'The message service is unavailable. Please try again later.',
      );
}
