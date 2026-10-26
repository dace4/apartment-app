import 'package:flutter/material.dart';

import '../../view_models/app_maintenance_view_model.dart';
import '../../view_models/maintenance_view_model.dart';

/// Admins only: schedule an app maintenance window. Every user sees a
/// banner as soon as it is saved; during the window only admins can use
/// the app.
class MaintenanceView extends StatefulWidget {
  const MaintenanceView({super.key, required this.appMaintenanceViewModel});

  /// The current window, shared with the banner and the router.
  final AppMaintenanceViewModel appMaintenanceViewModel;

  @override
  State<MaintenanceView> createState() => _MaintenanceViewState();
}

class _MaintenanceViewState extends State<MaintenanceView> {
  final viewModel = MaintenanceViewModel();

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  /// A date, then a time on the clock dial.
  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final initial = current == null || current.isBefore(now) ? now : current;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(viewModel.start);
    if (picked != null) viewModel.setStart(picked);
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(viewModel.end);
    if (picked != null) viewModel.setEnd(picked);
  }

  Future<void> _schedule() async {
    final saved = await viewModel.schedule();
    if (saved && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maintenance scheduled.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.appMaintenanceViewModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Repair & maintenance')),
      body: ListenableBuilder(
        listenable: Listenable.merge([viewModel, current]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Current maintenance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  current.isActive ? Icons.construction : Icons.event,
                ),
                title: Text(
                  current.bannerMessage ?? 'No maintenance scheduled.',
                ),
                trailing: current.bannerMessage == null
                    ? null
                    : TextButton(
                        onPressed: viewModel.isSaving ? null : viewModel.endNow,
                        child: Text(current.isActive ? 'End now' : 'Cancel'),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Schedule maintenance', style: theme.textTheme.titleMedium),
            const Text(
              'Every user sees a banner as soon as you save. From the start '
              'until the end, only admins can use the app.',
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('From'),
              subtitle: Text(viewModel.startLabel),
              onTap: viewModel.isSaving ? null : _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.update),
              title: const Text('Till'),
              subtitle: Text(viewModel.endLabel),
              onTap: viewModel.isSaving ? null : _pickEnd,
            ),
            if (viewModel.actionError != null) ...[
              const SizedBox(height: 8),
              Text(
                viewModel.actionError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: viewModel.isSaving ? null : _schedule,
              icon: const Icon(Icons.construction),
              label: Text(
                viewModel.isSaving ? 'Saving…' : 'Schedule maintenance',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
