import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_routes.dart';
import '../../../shared/widgets/message_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/contact_listing_repository.dart';
import '../data/message_repository.dart';
import '../models/advertiser_message.dart';
import '../utils/message_validators.dart';

/// US 12: loads the property's advertiser, submits an enquiry and shows a receipt.
class ContactAdvertiserPage extends StatefulWidget {
  const ContactAdvertiserPage({
    super.key,
    required this.apartmentId,
    required this.authRepository,
    this.listingRepository = const SampleContactListingRepository(),
    this.messageRepository = const UnconfiguredMessageRepository(),
    this.submissionTimeout = const Duration(seconds: 15),
  });

  final String apartmentId;
  final AuthRepository authRepository;
  final ContactListingRepository listingRepository;
  final MessageRepository messageRepository;
  final Duration submissionTimeout;

  @override
  State<ContactAdvertiserPage> createState() => _ContactAdvertiserPageState();
}

class _ContactAdvertiserPageState extends State<ContactAdvertiserPage> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController(text: 'Apartment enquiry');
  final _body = TextEditingController();
  late Stream<ContactListing?> _listing;
  bool _sending = false;
  String? _error;
  // Pending means the server outcome is unknown; sent means a receipt arrived.
  // Keep separate drafts so confirmation always describes the submitted content.
  MessageDraft? _pendingDraft;
  MessageDraft? _sentDraft;
  MessageReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _listing = widget.listingRepository.watchListing(widget.apartmentId);
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _listing = widget.listingRepository.watchListing(widget.apartmentId);
    _error = null;
  });

  Future<void> _send(ContactListing listing) async {
    // Block duplicate taps and prevent a second send after confirmed success.
    if (_sending || _receipt != null) return;
    if (_pendingDraft == null && !_formKey.currentState!.validate()) return;
    final user = widget.authRepository.currentUser;
    if (user == null || !user.emailVerified) return;
    // New enquiries get a new reference. Confirmation retries reuse the original
    // frozen content and recipient, even if fields or listing data have changed.
    final draft =
        _pendingDraft ??
        MessageDraft(
          id: widget.messageRepository.createMessageId(),
          listing: listing,
          subject: _subject.text.trim(),
          body: _body.text.trim(),
        );
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final receipt = await widget.messageRepository
          .send(draft)
          .timeout(widget.submissionTimeout);
      // The user can leave the page before the server responds.
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _sentDraft = draft;
        _pendingDraft = null;
      });
    } on TimeoutException {
      // timeout() stops waiting, but does not cancel the underlying submission.
      // Freeze the draft because the server may still complete the write.
      if (mounted) {
        setState(() {
          _pendingDraft = draft;
          _error = 'Delivery has not been confirmed yet. Check confirmation before sending another message.';
        });
      }
    } on MessageException catch (error) {
      // Definitive errors allow correction; uncertain errors require confirming
      // the existing reference before another enquiry can be created.
      if (mounted) {
        setState(() {
          // A failed confirmation retry cannot prove that the original send
          // failed. Keep its reference locked even after a permission error.
          _pendingDraft = _pendingDraft != null || error.confirmationPending
              ? draft
              : null;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingDraft = draft;
          _error = 'Could not confirm delivery. Please check confirmation.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contact advertiser')),
    body: SafeArea(
      child: AnimatedBuilder(
        // React immediately to logout or verification changes while this page is
        // open, in addition to the router's existing authentication redirect.
        animation: widget.authRepository,
        builder: (context, _) {
          final user = widget.authRepository.currentUser;
          if (user == null || !user.emailVerified) {
            return const MessageView(
              icon: Icons.lock_outline,
              message: 'Log in with a verified email to contact advertisers.',
            );
          }
          if (_receipt != null) return _confirmation(context);
          return StreamBuilder<ContactListing?>(
            stream: _listing,
            builder: (context, snapshot) {
              // A pending submission can still be confirmed after a listing is
              // removed or its owner changes, using its original frozen draft.
              if (_pendingDraft != null) {
                return _form(context, _pendingDraft!.listing, user);
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return MessageView(
                  icon: Icons.cloud_off,
                  message: 'Could not load the advertiser.',
                  actionLabel: 'Retry',
                  onAction: _reload,
                );
              }
              final listing = snapshot.data;
              if (listing == null) {
                return const MessageView(
                  icon: Icons.search_off,
                  message: 'This apartment is no longer listed.',
                );
              }
              if (!listing.canContact) {
                return const MessageView(
                  icon: Icons.person_off_outlined,
                  message:
                      'No advertiser contact is available for this apartment.',
                );
              }
              return _form(context, listing, user);
            },
          );
        },
      ),
    ),
  );

  Widget _form(BuildContext context, ContactListing listing, AppUser user) {
    final theme = Theme.of(context);
    // Editing an uncertain draft would prevent a safe, identical confirmation retry.
    final locked = _sending || _pendingDraft != null;
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
                Text(listing.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('To: ${listing.advertiserName}'),
                Text('From: ${user.email}'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _subject,
                  readOnly: locked,
                  maxLength: MessageValidators.subjectLimit,
                  textInputAction: TextInputAction.next,
                  validator: MessageValidators.subject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  readOnly: locked,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: MessageValidators.bodyLimit,
                  keyboardType: TextInputType.multiline,
                  validator: MessageValidators.body,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Ask a question about this apartment.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _sending ? null : () => _send(listing),
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _sending
                        ? 'Sending…'
                        : _pendingDraft != null
                        ? 'Check confirmation'
                        : 'Send message',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A receipt acknowledges server storage; it is not an advertiser read receipt.
  Widget _confirmation(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 56),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            'Message sent',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your message to ${_sentDraft!.listing.advertiserName} about '
          '${_sentDraft!.listing.title} has been saved and is available to the advertiser.',
        ),
        const SizedBox(height: 16),
        Text('Reference: ${_receipt!.id}'),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () =>
              context.go(AppRoutes.apartmentDetail(widget.apartmentId)),
          child: const Text('Back to apartment'),
        ),
      ],
    ),
  );
}
