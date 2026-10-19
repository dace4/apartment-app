import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../../view_models/message_detail_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US 12: one message received about the user's apartment.
class MessageDetailView extends StatefulWidget {
  const MessageDetailView({super.key, required this.messageId});

  final String messageId;

  @override
  State<MessageDetailView> createState() => _MessageDetailViewState();
}

class _MessageDetailViewState extends State<MessageDetailView> {
  final viewModel = MessageDetailViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchMessage(widget.messageId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // 1. Loading
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (viewModel.errorMessage != null) {
            return MessageView(
              icon: Icons.cloud_off,
              message: viewModel.errorMessage!,
              actionLabel: 'Retry',
              onAction: () => viewModel.fetchMessage(widget.messageId),
            );
          }

          // 3. Not found
          final message = viewModel.message;
          if (message == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This message does not exist.',
            );
          }

          // 4. Data
          final theme = Theme.of(context);
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(message.subject, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('From ${message.senderEmail}'),
                    if (message.createdAt != null)
                      Text(formatDate(message.createdAt!)),
                    const SizedBox(height: 16),
                    SelectableText(message.body),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
