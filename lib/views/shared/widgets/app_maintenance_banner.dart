import 'package:flutter/material.dart';

import '../../../view_models/app_maintenance_view_model.dart';

/// The planned or running app maintenance, above every page (log in
/// included). [child] is the page; it keeps its place in the tree whether
/// the banner is shown or not.
class AppMaintenanceBanner extends StatelessWidget {
  const AppMaintenanceBanner({
    super.key,
    required this.viewModel,
    required this.child,
  });

  final AppMaintenanceViewModel viewModel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final message = viewModel.bannerMessage;
        return Column(
          children: [
            if (message != null)
              Material(
                color: viewModel.isActive
                    ? colors.errorContainer
                    : colors.tertiaryContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.construction, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(message)),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              // The banner already covers the status bar.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: message != null,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
