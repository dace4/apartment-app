import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../view_models/document_review_view_model.dart';
import '../../router/app_routes.dart';
import '../shared/widgets/message_view.dart';

/// US-15: view original file bytes; the viewer never rewrites the document.
class DocumentReviewView extends StatefulWidget {
  const DocumentReviewView({
    super.key,
    required this.documentId,
    this.viewModel,
  });
  final String documentId;
  final DocumentReviewViewModel? viewModel;
  @override
  State<DocumentReviewView> createState() => _DocumentReviewViewState();
}

class _DocumentReviewViewState extends State<DocumentReviewView> {
  late final viewModel = widget.viewModel ?? DocumentReviewViewModel();
  @override
  void initState() {
    super.initState();
    viewModel.load(widget.documentId);
  }

  @override
  void dispose() {
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove document?'),
        content: const Text('This permanently removes this unused document.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && await viewModel.delete() && mounted) {
      context.go(AppRoutes.documents);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Document')),
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
            onAction: () => viewModel.load(widget.documentId),
          );
        }
        final document = viewModel.document;
        if (document == null) {
          return const MessageView(
            icon: Icons.search_off,
            message: 'This document is no longer available.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    document.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('${document.sizeLabel} · ${document.statusLabel}'),
                ],
              ),
            ),
            Expanded(
              child: document.isPdf
                  ? PdfViewer.data(
                      document.bytes,
                      sourceName: document.id,
                      params: const PdfViewerParams(
                        textSelectionParams: PdfTextSelectionParams(
                          enabled: false,
                        ),
                      ),
                    )
                  : InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          document.bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Text('This image cannot be displayed.'),
                        ),
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (viewModel.actionError != null)
                      Text(
                        viewModel.actionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (document.canDelete)
                      OutlinedButton.icon(
                        onPressed: viewModel.isSaving ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove document'),
                      )
                    else
                      const Text(
                        'Signed documents and application attachments cannot be removed.',
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
