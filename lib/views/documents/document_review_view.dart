import '../../view_models/auth_view_model.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../view_models/document_review_view_model.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../shared/widgets/message_view.dart';

/// US-15: view original file bytes; the viewer never rewrites the document.
class DocumentReviewView extends StatefulWidget {
  final AuthViewModel? authViewModel;
  const DocumentReviewView({
    this.authViewModel,
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
  late final viewModel =
      widget.viewModel ??
      DocumentReviewViewModel(
        canAccess: () =>
            widget.authViewModel?.canAccess(AppRoutes.documents) == true,
      );
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

  Future<void> _manageSignature() async {
    await context.push(AppRoutes.signature);
    if (mounted) await viewModel.load(widget.documentId);
  }

  Future<void> _bind() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bind your signature?'),
        scrollable: true,
        content: Text(
          'I confirm that I reviewed "${viewModel.document!.name}" and agree to bind '
          'my saved signature to this document electronically. The original file will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm and sign'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.bind();
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
    appBar: AppBar(
      title: const Text('Document'),
      actions: [
        ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => IconButton(
            tooltip: 'Reload document',
            icon: const Icon(Icons.refresh),
            onPressed: viewModel.isSaving || viewModel.isLoading
                ? null
                : () => viewModel.load(widget.documentId),
          ),
        ),
      ],
    ),
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
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        document.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        semanticsLabel: document.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('${document.sizeLabel} · ${document.statusLabel}'),
                    ],
                  ),
                ),
                SizedBox(
                  height: (constraints.maxHeight - 320).clamp(240.0, 900.0),
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
                        if (document.isSigned) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Signed',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (document.signedAt != null)
                            Text(
                              'Signature bound on ${formatSigningTime(document.signedAt!)}',
                            ),
                          const SizedBox(height: 8),
                          // US-11: persisted signing state also survives reopening.
                          const Text(
                            'This signed document is certified and cannot be changed after it has been signed.',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                        ] else ...[
                          if (viewModel.signatureError != null)
                            Text(viewModel.signatureError!),
                          if (!viewModel.hasSignature)
                            TextButton(
                              onPressed: viewModel.isSaving
                                  ? null
                                  : _manageSignature,
                              child: const Text(
                                'Set up My Signature before signing',
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: viewModel.canBind ? _bind : null,
                            icon: viewModel.isSaving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.draw_outlined),
                            label: Text(
                              viewModel.isSaving ? 'Saving…' : 'Bind signature',
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
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
            ),
          ),
        );
      },
    ),
  );
}
