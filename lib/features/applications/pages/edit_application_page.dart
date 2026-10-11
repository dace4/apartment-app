import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/message_view.dart';
import '../data/application_repository.dart';
import '../models/rental_application.dart';
import '../widgets/application_form.dart';

/// US 16: edit an application within 5 days of submitting it.
class EditApplicationPage extends StatefulWidget {
  const EditApplicationPage({
    super.key,
    required this.applicationId,
    this.repository = const UnconfiguredApplicationRepository(),
  });

  final String applicationId;
  final ApplicationRepository repository;

  @override
  State<EditApplicationPage> createState() => _EditApplicationPageState();
}

class _EditApplicationPageState extends State<EditApplicationPage> {
  // Loaded once: the form keeps the user's edits even if the stored
  // application changes meanwhile.
  late Future<RentalApplication?> _application;

  @override
  void initState() {
    super.initState();
    _application = _load();
  }

  Future<RentalApplication?> _load() =>
      widget.repository.fetchApplication(widget.applicationId);

  void _reload() => setState(() => _application = _load());

  Future<String?> _save(ApplicationDetails details) async {
    try {
      await widget.repository.update(widget.applicationId, details);
    } on ApplicationException catch (e) {
      return e.message;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Changes saved.')));
      context.go(AppRoutes.applicationDetail(widget.applicationId));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit application')),
      body: FutureBuilder<RentalApplication?>(
        future: _application,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return MessageView(
              icon: Icons.cloud_off,
              message: 'Could not load the application.',
              actionLabel: 'Retry',
              onAction: _reload,
            );
          }
          final application = snapshot.data;
          if (application == null) {
            return const MessageView(
              icon: Icons.search_off,
              message: 'This application does not exist.',
            );
          }
          if (!application.canChange(DateTime.now())) {
            return const MessageView(
              icon: Icons.lock_clock,
              message:
                  'This application can no longer be edited. Applications '
                  'can only be changed within 5 days.',
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      application.apartmentTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    ApplicationForm(
                      initial: application.details,
                      submitLabel: 'Save changes',
                      onSubmit: _save,
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
}
