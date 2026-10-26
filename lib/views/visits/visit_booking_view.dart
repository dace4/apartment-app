import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/visit.dart';
import '../../router/app_routes.dart';
import '../../router/tab_navigation.dart';
import '../../utils/formatters.dart';
import '../../view_models/visit_booking_view_model.dart';
import '../shared/widgets/message_view.dart';
import 'widgets/slot_status_dot.dart';

/// US-20: a calendar of the days that can be visited. Tapping a day shows
/// its two time slots with a green (free) or red (taken) dot.
class VisitBookingView extends StatefulWidget {
  const VisitBookingView({super.key, required this.apartmentId});

  final String apartmentId;

  @override
  State<VisitBookingView> createState() => _VisitBookingViewState();
}

class _VisitBookingViewState extends State<VisitBookingView> {
  final viewModel = VisitBookingViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.load(widget.apartmentId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirmAndBook() async {
    final slot = viewModel.selectedSlot!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book this visit?'),
        content: Text(
          '${viewModel.apartment!.title}\n'
          '${formatTimeSlot(slot, slot.add(Visit.slotLength))}\n\n'
          'The owner will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Book visit'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.book();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule a visit')),
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
              onAction: () => viewModel.load(widget.apartmentId),
            );
          }
          // 3. Not found
          if (viewModel.apartment == null) {
            return MessageView(
              icon: Icons.search_off,
              message:
                  'This apartment does not exist or is no longer '
                  'available.',
              actionLabel: 'Back to the list',
              onAction: () => context.go(AppRoutes.apartments),
            );
          }
          // 4. Booked: confirmation
          final booked = viewModel.bookedVisit;
          if (booked != null) return _Confirmation(visit: booked);
          // 5. Data
          return _BookingForm(viewModel: viewModel, onBook: _confirmAndBook);
        },
      ),
    );
  }
}

class _BookingForm extends StatelessWidget {
  const _BookingForm({required this.viewModel, required this.onBook});

  final VisitBookingViewModel viewModel;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apartment = viewModel.apartment!;
    final reason = viewModel.cannotBookReason;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(apartment.title, style: theme.textTheme.titleLarge),
        Text('${apartment.address}, ${apartment.city}'),
        if (reason != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(reason),
              trailing: viewModel.existingVisit == null
                  ? null
                  : TextButton(
                      onPressed: () => context.go(AppRoutes.visits),
                      child: const Text('My visits'),
                    ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Choose a day', style: theme.textTheme.titleMedium),
        Text(
          'Visits are possible Monday to Friday, from tomorrow up to 30 days '
          'ahead.',
          style: theme.textTheme.bodySmall,
        ),
        CalendarDatePicker(
          initialDate: viewModel.selectedDate!,
          firstDate: viewModel.firstDate,
          lastDate: viewModel.lastDate,
          selectableDayPredicate: viewModel.isSelectableDay,
          onDateChanged: viewModel.selectDate,
        ),
        Text(
          'Time slots on ${formatDate(viewModel.selectedDate!)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final slot in viewModel.slots)
          Card(
            child: ListTile(
              leading: SlotStatusDot(status: slot.status),
              title: Text(formatTimeRange(slot.start, slot.end)),
              subtitle: Text(slot.status.label),
              selected: viewModel.selectedSlot == slot.start,
              trailing: viewModel.selectedSlot == slot.start
                  ? const Icon(Icons.check_circle)
                  : null,
              enabled: viewModel.canBook && slot.status == SlotStatus.free,
              onTap: () => viewModel.selectSlot(slot.start),
            ),
          ),
        if (viewModel.actionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              viewModel.actionError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed:
              viewModel.canBook &&
                  viewModel.selectedSlot != null &&
                  !viewModel.isSaving
              ? onBook
              : null,
          icon: const Icon(Icons.event_available),
          label: Text(viewModel.isSaving ? 'Booking…' : 'Book visit'),
        ),
      ],
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
            const SizedBox(height: 16),
            Text(
              'Visit booked',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${visit.apartmentTitle}\n'
              '${formatTimeSlot(visit.slotStart, visit.slotEnd)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'The owner has been notified. You can cancel the visit in '
              'My visits until it starts.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              // The Home tab returns to the apartment, not to this page.
              onPressed: () => context.goToOtherTab(
                back: AppRoutes.apartmentDetail(visit.apartmentId),
                to: AppRoutes.visits,
              ),
              child: const Text('My visits'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  context.go(AppRoutes.apartmentDetail(visit.apartmentId)),
              child: const Text('Back to apartment'),
            ),
          ],
        ),
      ),
    );
  }
}
