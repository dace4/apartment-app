import 'package:flutter/material.dart';

import '../../models/signing_consent.dart';
import '../../view_models/document_review_view_model.dart';
import '../../utils/formatters.dart';
import '../shared/widgets/message_view.dart';
import 'widgets/signature_pad.dart';

/// US-11: full text precedes review acknowledgement, signature, and consent.
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
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel.load(widget.documentId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  void _reload() {
    _nameController.clear();
    viewModel.load(widget.documentId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Review document'),
      actions: [
        ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => IconButton(
            tooltip: 'Reload document',
            onPressed: viewModel.isSaving || viewModel.isLoading
                ? null
                : _reload,
            icon: const Icon(Icons.refresh),
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
            onAction: _reload,
          );
        }
        final document = viewModel.document;
        if (document == null) {
          return const MessageView(
            icon: Icons.search_off,
            message: 'This document is no longer available.',
          );
        }
        final theme = Theme.of(context);
        final record = viewModel.signedRecord;
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(document.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Version ${document.version} · ${viewModel.statusLabel}',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 24),
                  SelectableText(
                    document.body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (record != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Signed and saved',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Signed by ${record.signerName} (${record.signerEmail})',
                    ),
                    Text('Signed on ${formatSigningTime(record.signedAt!)}'),
                    const SizedBox(height: 16),
                    SignaturePad(drawing: record.signature, enabled: false),
                    const SizedBox(height: 16),
                    Text(record.consentText),
                    const SizedBox(height: 8),
                    Text('Record ID: ${record.id}'),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Record details'),
                      children: [
                        SelectableText(
                          'Document SHA-256: ${record.documentHash}\n'
                          'Signed record SHA-256: ${record.recordHash}\n'
                          'Consent version: ${record.consentVersion}',
                        ),
                      ],
                    ),
                  ] else if (viewModel.canSign || viewModel.isSaving) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I have reviewed the full document above.',
                      ),
                      value: viewModel.reviewed,
                      onChanged: viewModel.isSaving
                          ? null
                          : (value) => viewModel.setReviewed(value ?? false),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      maxLength: 100,
                      enabled: !viewModel.isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Your full name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: viewModel.setSignerName,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Draw your signature',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('Use your finger or stylus in the box below.'),
                    const SizedBox(height: 12),
                    SignaturePad(
                      drawing: viewModel.signature,
                      enabled: !viewModel.isSaving,
                      onStart: viewModel.startStroke,
                      onUpdate: viewModel.addPoint,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: viewModel.isSaving
                            ? null
                            : viewModel.clearSignature,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear signature'),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(SigningConsent.text),
                      value: viewModel.consented,
                      onChanged: viewModel.isSaving || !viewModel.reviewed
                          ? null
                          : (value) => viewModel.setConsented(value ?? false),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: viewModel.canSubmit ? viewModel.sign : null,
                      icon: viewModel.isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.draw_outlined),
                      label: Text(
                        viewModel.isSaving
                            ? 'Saving signature…'
                            : 'Sign and save',
                      ),
                    ),
                    if (viewModel.actionError != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          viewModel.actionError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ] else
                    const Text(
                      'This document is unavailable for signing. Contact the sender.',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
