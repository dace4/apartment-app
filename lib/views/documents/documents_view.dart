import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../view_models/documents_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-11: documents remain discoverable through Profile without another tab.
class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key, this.viewModel});
  final DocumentsViewModel? viewModel;
  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  late final viewModel = widget.viewModel ?? DocumentsViewModel();
  @override
  void initState() {
    super.initState();
    viewModel.listenToDocuments();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My documents')),
    body: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (viewModel.errorMessage != null) {
          return MessageView(
            icon: Icons.cloud_off,
            message: viewModel.errorMessage!,
            actionLabel: 'Retry',
            onAction: viewModel.listenToDocuments,
          );
        }
        if (viewModel.documents.isEmpty) {
          return const MessageView(
            icon: Icons.description_outlined,
            message: 'No documents assigned yet. Documents sent to you will appear here.',
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: viewModel.documents.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final document = viewModel.documents[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(document.title),
                  subtitle: Text(
                    'Version ${document.version} · ${viewModel.statusLabel(document)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.go(AppRoutes.documentReview(document.id)),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}
