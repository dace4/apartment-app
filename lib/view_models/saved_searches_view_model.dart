import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/apartment.dart';
import '../models/apartment_filter.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/notification_preferences.dart';
import '../models/saved_search.dart';
import '../services/apartment_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/saved_search_service.dart';
import '../utils/formatters.dart';

/// US 23: the user's saved searches and their new-offer alerts. Shared by the
/// apartment list (save a search) and the Saved searches page, and it checks
/// for new offers whatever the open tab while a verified user is signed in,
/// so it is created once in app.dart (see ARCHITECTURE.md §4).
class SavedSearchesViewModel extends ChangeNotifier {
  SavedSearchesViewModel({
    AuthService? authService,
    SavedSearchService? savedSearchService,
    ApartmentService? apartmentService,
    NotificationService? notificationService,
  }) : authService = authService ?? AuthService(),
       searchService = savedSearchService ?? SavedSearchService(),
       apartmentService = apartmentService ?? ApartmentService(),
       notificationService = notificationService ?? NotificationService() {
    _authSubscription = this.authService.userChanges().listen(_onUserChanged);
  }

  final AuthService authService;
  final SavedSearchService searchService;
  final ApartmentService apartmentService;
  final NotificationService notificationService;

  List<SavedSearch> searches = [];
  bool isLoading = false;
  String? errorMessage;
  String? actionError;

  List<Apartment> _apartments = [];
  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();

  bool _searchesLoaded = false;
  bool _apartmentsLoaded = false;
  bool _preferencesLoaded = false;

  bool _isChecking = false;
  bool _checkAgain = false;
  bool _checkFailed = false;

  String? _userId;
  StreamSubscription<AppUser?>? _authSubscription;
  final List<StreamSubscription> _subscriptions = [];

  bool get isFull => searches.length >= SavedSearch.maxPerUser;

  bool get newListingAlertsEnabled => _notificationPreferences.newListing;

  Future<bool> save(String name, ApartmentFilter filter) async {
    actionError = null;
    if (isFull) {
      actionError =
          'You can save up to ${SavedSearch.maxPerUser} searches. Delete one first.';
      notifyListeners();
      return false;
    }

    if (!_apartmentsLoaded) {
      actionError = 'The apartments are still loading. Please try again.';
      notifyListeners();
      return false;
    }

    try {
      await searchService.create(
        name: name,
        filter: filter,
        seenApartmentIds: [
          for (final apartment in _apartments)
            if (SavedSearch.isOffer(filter, apartment)) apartment.id,
        ],
      );
      return true;
    } catch (e) {
      actionError = 'Could not save the search. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> setAlertsEnabled(SavedSearch search, bool enabled) async {
    actionError = null;
    notifyListeners();
    try {
      await searchService.setAlertsEnabled(search.id, enabled);
    } catch (e) {
      actionError = 'Could not save your choice. Please try again.';
      notifyListeners();
    }
  }

  Future<void> delete(SavedSearch search) async {
    actionError = null;
    notifyListeners();
    try {
      await searchService.delete(search.id);
    } catch (e) {
      actionError = 'Could not delete the search. Please try again.';
      notifyListeners();
    }
  }

  void _onUserChanged(AppUser? user) {
    final userId = user != null && user.emailVerified ? user.id : null;
    if (userId == _userId) return;
    _userId = userId;
    _listen();
  }

  void _listen() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    searches = [];
    _apartments = [];
    _notificationPreferences = const NotificationPreferences();
    _searchesLoaded = false;
    _apartmentsLoaded = false;
    _preferencesLoaded = false;
    _checkFailed = false;
    errorMessage = null;
    actionError = null;
    isLoading = _userId != null;
    notifyListeners();

    if (_userId == null) return;

    _subscriptions.add(
      searchService.watchMySearches().listen(
        (value) {
          searches = value;
          _searchesLoaded = true;
          isLoading = false;
          notifyListeners();
          _checkNewOffers();
        },
        onError: (e) {
          errorMessage = 'Could not load your saved searches.';
          isLoading = false;
          notifyListeners();
        },
      ),
    );
    _subscriptions.add(
      apartmentService.watchApartments().listen((value) {
        _apartments = value;
        _apartmentsLoaded = true;
        _checkNewOffers();
      }, onError: (e) {}),
    );
    _subscriptions.add(
      notificationService.watchPreferences().listen((value) {
        _notificationPreferences = value;
        _preferencesLoaded = true;
        notifyListeners();
        _checkNewOffers();
      }, onError: (e) {}),
    );
  }

  /// US 23.3: looks for new offers in every saved search, then marks them as
  /// seen so they never alert twice. It alerts only when the search's switch
  /// and the "New listings" switch (US 18) are both on; otherwise the offers
  /// are only marked as seen, so switching back on brings no flood of alerts.
  Future<void> _checkNewOffers() async {
    if (!_searchesLoaded || !_apartmentsLoaded || !_preferencesLoaded) return;
    if (_checkFailed) return;
    // Our own writes send new snapshots: check again afterwards, never twice
    // at the same time.
    if (_isChecking) {
      _checkAgain = true;
      return;
    }

    _isChecking = true;
    try {
      for (final search in searches) {
        final newOffers = search.findNewOffers(_apartments);
        if (newOffers.isEmpty) continue;

        final notify =
            search.alertsEnabled && _notificationPreferences.newListing;
        await searchService.recordNewOffers(
          search,
          [for (final apartment in newOffers) apartment.id],
          [
            if (notify)
              for (final apartment in newOffers) _alertFor(search, apartment),
          ],
        );
      }
    } catch (e) {
      // Stop until the next sign-in instead of retrying in a loop. The seen
      // list and the fixed alert ids make the next try safe.
      _checkFailed = true;
    } finally {
      _isChecking = false;
      if (_checkAgain) {
        _checkAgain = false;
        _checkNewOffers();
      }
    }
  }

  AppNotification _alertFor(SavedSearch search, Apartment apartment) {
    return AppNotification(
      // One id per search and offer (the service adds the user id).
      id: '${search.id}_${apartment.id}',
      type: NotificationType.newListing,
      title: 'New offer: ${apartment.title}',
      body:
          '${search.name} · ${apartment.city} · '
          '${formatApartmentPrice(apartment)}',
      createdAt: DateTime.now(),
      apartmentId: apartment.id,
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _authSubscription?.cancel();
    super.dispose();
  }
}
