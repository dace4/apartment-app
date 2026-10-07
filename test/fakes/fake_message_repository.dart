import 'dart:async';

import 'package:appartment_app_group_2/features/messages/data/message_repository.dart';
import 'package:appartment_app_group_2/features/messages/models/advertiser_message.dart';

class FakeMessageRepository extends MessageRepository {
  final List<MessageDraft> submissions = [];
  MessageException? error;
  Completer<MessageReceipt>? pending;
  int createdIds = 0;
  @override
  String createMessageId() => 'message-${++createdIds}';
  @override
  Future<MessageReceipt> send(MessageDraft draft) async {
    submissions.add(draft);
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return MessageReceipt(draft.id);
  }
}
