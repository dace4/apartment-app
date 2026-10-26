import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/apartment.dart';
import '../../models/maintenance_request.dart';
import '../../router/app_routes.dart';
import '../../utils/formatters.dart';
import '../../view_models/maintenance_booking_view_model.dart';
import '../shared/widgets/message_view.dart';

/// US-17: book a repair or maintenance service in a time slot, or
/// reschedule one when [rescheduleId] is given.
class MaintenanceBookingView extends StatefulWidget {
  const MaintenanceBookingView({super.key, this.rescheduleId});

  final String? rescheduleId;

  @override
  State<MaintenanceBookingView> createState() => _MaintenanceBookingViewState();
}

class _MaintenanceBookingViewState extends State<MaintenanceBookingView> {
  final viewModel = MaintenanceBookingViewModel();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel.load(rescheduleId: widget.rescheduleId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.pickerInitialDate,
      firstDate: viewModel.firstDate,
      lastDate: viewModel.lastDate,
      selectableDayPredicate: viewModel.isSelectableDay,
      helpText: 'Service date',
    );
    if (picked != null) viewModel.selectDate(picked);
  }

  Future<void> _save() async {
    viewModel.markSubmitted();
    if (!_formKey.currentState!.validate()) return;
    final saved = viewModel.isRescheduling
        ? await viewModel.reschedule()
        : await viewModel.book(_descriptionController.text);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.isRescheduling
                ? 'Service rescheduled.'
                : 'Service booked.',
          ),
        ),
      );
      context.go(AppRoutes.maintenanceDetail(viewModel.savedId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.rescheduleId == null ? 'Schedule service' : 'Reschedule',
        ),
      ),
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
              onAction: () => viewModel.load(rescheduleId: widget.rescheduleId),
            );
          }

          // 3. Empty: nothing to book for (US-17.1: only the properties the
          // user owns or is assigned to manage can be chosen).
          if (!viewModel.isRescheduling && viewModel.apartments.isEmpty) {
            return const MessageView(
              icon: Icons.home_work_outlined,
              message:
                  'You do not own or manage any property yet. Homeowners '
                  'can book for the apartments they published; property '
                  'managers for the apartments they are assigned to.',
            );
          }

          // 4. Form
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final existing = viewModel.existing;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (existing != null) ...[
                  Text(
                    '${existing.category.label} · ${existing.apartmentTitle}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Currently: '
                    '${formatTimeSlot(existing.slotStart, existing.slotEnd)}',
                  ),
                ] else ...[
                  DropdownButtonFormField<Apartment>(
                    initialValue: viewModel.apartment,
                    isExpanded: true,
                    validator: viewModel.validateApartment,
                    onChanged: viewModel.selectApartment,
                    decoration: const InputDecoration(
                      labelText: 'Apartment',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final apartment in viewModel.apartments)
                        DropdownMenuItem(
                          value: apartment,
                          child: Text(
                            apartment.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<MaintenanceCategory>(
                    initialValue: viewModel.category,
                    validator: viewModel.validateCategory,
                    onChanged: viewModel.selectCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final category in MaintenanceCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    keyboardType: TextInputType.multiline,
                    validator: viewModel.validateDescription,
                    decoration: const InputDecoration(
                      labelText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Remind me', style: theme.textTheme.titleSmall),
                for (final reminder in MaintenanceReminder.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(reminder.label),
                    value: viewModel.reminders.contains(reminder),
                    onChanged: viewModel.isSaving
                        ? null
                        : (selected) =>
                              viewModel.setReminder(reminder, selected == true),
                  ),
                if (viewModel.reminderError != null)
                  _ErrorText(viewModel.reminderError!),
                const SizedBox(height: 16),
                Text('When', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: viewModel.isSaving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    viewModel.date == null
                        ? 'Choose a date'
                        : formatDate(viewModel.date!),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTimeWheel(),
                if (viewModel.actionError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorText(viewModel.actionError!),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: viewModel.isSaving ? null : _save,
                  child: viewModel.isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          viewModel.isRescheduling
                              ? 'Reschedule'
                              : 'Book service',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// US-17.2: the free times of the chosen date on a scrolling wheel. Only
  /// valid slots are on it (booked, too-soon and past times are left out),
  /// and the time in the middle is the selected one.
  Widget _buildTimeWheel() {
    final slots = viewModel.availableSlots;
    final selected = viewModel.slot;
    final selectedIndex = selected == null ? -1 : slots.indexOf(selected);
    final enabled = slots.isNotEmpty && !viewModel.isSaving;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Time',
        border: const OutlineInputBorder(),
        errorText: viewModel.slotError,
      ),
      child: slots.isEmpty
          ? Text(
              viewModel.date == null
                  ? 'Choose a date first'
                  : 'No free times on this day. Choose another date.',
            )
          : SizedBox(
              height: 150,
              child: IgnorePointer(
                ignoring: !enabled,
                child: CupertinoPicker(
                  // A new wheel for each date, starting on its selected time.
                  key: ValueKey(viewModel.date),
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex < 0 ? 0 : selectedIndex,
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) =>
                      viewModel.selectSlot(slots[index]),
                  children: [
                    for (final slot in slots)
                      Center(
                        child: Text(
                          _timeRange(slot),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  /// "10:00–10:30": the time slot without the date, which is shown above.
  String _timeRange(DateTime slot) => formatTimeSlot(
    slot,
    slot.add(MaintenanceRequest.slotLength),
  ).split(', ').last;
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
