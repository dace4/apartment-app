import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';
import '../../view_models/documents_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-15: multi-file upload queue and the user's saved JPEG/PDF library.
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
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Upload JPEG or PDF files, then preview or attach them to an application.',
                ),
                const SizedBox(height: 8),
                const Text('Up to 700 KiB per file · 10 files per selection'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      viewModel.isPicking || viewModel.uploadingIds.isNotEmpty
                      ? null
                      : viewModel.pickAndUpload,
                  icon: viewModel.isPicking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    viewModel.isPicking
                        ? 'Uploading files…'
                        : 'Upload documents',
                  ),
                ),
                if (viewModel.actionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      viewModel.actionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final upload in viewModel.uploads)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(upload.name),
                    subtitle: Semantics(
                      liveRegion: true,
                      child: Text(viewModel.uploadLabel(upload)),
                    ),
                    trailing: viewModel.uploadErrors.containsKey(upload.id)
                        ? Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Retry upload',
                                icon: const Icon(Icons.refresh),
                                onPressed: () => viewModel.retryUpload(upload),
                              ),
                              IconButton(
                                tooltip: 'Dismiss failed upload',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    viewModel.dismissUpload(upload),
                              ),
                            ],
                          )
                        : null,
                  ),
                const SizedBox(height: 24),
                if (viewModel.documents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No documents uploaded yet.'),
                  ),
                for (final document in viewModel.documents) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: document.isPdf
                        ? const Icon(Icons.picture_as_pdf_outlined)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              document.bytes,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                    title: Text(document.name),
                    subtitle: Text(
                      '${document.sizeLabel} · ${document.statusLabel}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(AppRoutes.documentReview(document.id)),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
