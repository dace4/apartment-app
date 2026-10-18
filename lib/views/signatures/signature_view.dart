import '../../router/app_routes.dart';
import '../../view_models/auth_view_model.dart';

import 'package:flutter/material.dart';

import '../../view_models/signature_view_model.dart';
import '../shared/widgets/message_view.dart';
import 'widgets/signature_pad.dart';

/// US-11: a reusable signature managed from Profile, separate from files.
class SignatureView extends StatefulWidget {
  final AuthViewModel? authViewModel;
  const SignatureView({this.authViewModel, super.key, this.viewModel});
  final SignatureViewModel? viewModel;
  @override
  State<SignatureView> createState() => _SignatureViewState();
}

class _SignatureViewState extends State<SignatureView> {
  late final viewModel =
      widget.viewModel ??
      SignatureViewModel(
        canAccess: () =>
            widget.authViewModel?.canAccess(AppRoutes.signature) == true,
      );
  @override
  void initState() {
    super.initState();
    viewModel.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Signature')),
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
            onAction: viewModel.load,
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    viewModel.savedSignature == null
                        ? 'Create your signature'
                        : 'Your saved signature',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Draw with your finger or stylus. Save it once, then bind it to your documents.',
                  ),
                  const SizedBox(height: 24),
                  SignaturePad(
                    drawing: viewModel.drawing,
                    enabled: !viewModel.isSaving,
                    onStart: viewModel.startStroke,
                    onUpdate: viewModel.addPoint,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: viewModel.isSaving ? null : viewModel.clear,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear drawing'),
                    ),
                  ),
                  if (viewModel.savedSignature != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Saving a replacement keeps the same signature ID. Documents already bound remain Signed.',
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: viewModel.canSave ? viewModel.save : null,
                    icon: viewModel.isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      viewModel.isSaving
                          ? 'Saving…'
                          : viewModel.savedSignature == null
                          ? 'Save signature'
                          : 'Replace signature',
                    ),
                  ),
                  if (viewModel.saved)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text('Signature saved.'),
                      ),
                    ),
                  if (viewModel.actionError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          viewModel.actionError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
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
