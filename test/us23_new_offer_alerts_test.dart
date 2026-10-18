import 'package:appartment_app_group_2/models/user_role.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:appartment_app_group_2/models/apartment.dart';
import 'package:appartment_app_group_2/models/apartment_filter.dart';
import 'package:appartment_app_group_2/models/app_notification.dart';
import 'package:appartment_app_group_2/models/app_user.dart';
import 'package:appartment_app_group_2/models/notification_preferences.dart';
import 'package:appartment_app_group_2/models/saved_search.dart';
import 'package:appartment_app_group_2/services/apartment_service.dart';
import 'package:appartment_app_group_2/services/auth_service.dart';
import 'package:appartment_app_group_2/services/notification_service.dart';
import 'package:appartment_app_group_2/services/saved_search_service.dart';
import 'package:appartment_app_group_2/view_models/saved_searches_view_model.dart';

class FakeAuthService extends Fake implements AuthService {
  final users = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> userChanges() => users.stream;
}

class FakeApartmentService extends Fake implements ApartmentService {
  final apartments = StreamController<List<Apartment>>.broadcast();

  @override
  Stream<List<Apartment>> watchApartments() => apartments.stream;
}

class FakeNotificationService extends Fake implements NotificationService {
  final preferences = StreamController<NotificationPreferences>.broadcast();

  @override
  Stream<NotificationPreferences> watchPreferences() => preferences.stream;
}

/// Replaces Firestore: records what is written and sends the updated
/// searches back, like a real snapshot.
class FakeSavedSearchService extends Fake implements SavedSearchService {
  final searches = StreamController<List<SavedSearch>>.broadcast();
  List<SavedSearch> current = [];
  final alerts = <AppNotification>[];
  List<String>? seenWhenCreated;

  void emit(List<SavedSearch> value) {
    current = value;
    searches.add(value);
  }

  @override
  Stream<List<SavedSearch>> watchMySearches() => searches.stream;

  @override
  Future<void> create({
    required String name,
    required ApartmentFilter filter,
    required List<String> seenApartmentIds,
  }) async {
    seenWhenCreated = seenApartmentIds;
  }

  @override
  Future<void> recordNewOffers(
    SavedSearch search,
    List<String> apartmentIds,
    List<AppNotification> newAlerts,
  ) async {
    alerts.addAll(newAlerts);
    emit([
      for (final item in current)
        item.id == search.id
            ? _search(
                seen: {...item.seenApartmentIds, ...apartmentIds},
                alertsEnabled: item.alertsEnabled,
              )
            : item,
    ]);
  }
}

const _filter = ApartmentFilter(location: 'Sion', maxPrice: 2000);

SavedSearch _search({Set<String> seen = const {}, bool alertsEnabled = true}) =>
    SavedSearch(
      id: 's1',
      name: 'Sion',
      filter: _filter,
      alertsEnabled: alertsEnabled,
      seenApartmentIds: seen,
      createdAt: DateTime(2026, 10, 1),
    );

Apartment _apartment(
  String id, {
  int price = 1500,
  String city = '1950 Sion',
  ApartmentAvailability availability = ApartmentAvailability.available,
}) => Apartment(
  id: id,
  title: 'Apartment $id',
  address: 'Rue $id',
  city: city,
  listingType: ListingType.rent,
  price: price,
  rooms: 3,
  surface: 70,
  imageUrl: '',
  description: '',
  availability: availability,
);

/// Lets the streams deliver their events.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('US-23.1 matching rules', () {
    test('a new offer is available, matches every criterion and is unseen', () {
      final offers = _search(seen: {'a1'}).findNewOffers([
        _apartment('a1'), // already seen
        _apartment('a2'), // new offer
        _apartment('a3', price: 2500), // too expensive
        _apartment('a4', availability: ApartmentAvailability.reserved),
        _apartment('a5', city: '1003 Lausanne'), // wrong place
      ]);

      expect(offers.map((apartment) => apartment.id), ['a2']);
    });

    test('a saved filter keeps its criteria through toMap / fromMap', () {
      const filter = ApartmentFilter(
        location: 'Sion',
        listingType: ListingType.rent,
        minPrice: 1000,
        maxPrice: 2000,
        minRooms: 2,
        minSurface: 50,
        amenities: {Amenity.balcony, Amenity.parking},
      );

      final copy = ApartmentFilter.fromMap(filter.toMap());

      expect(copy.location, filter.location);
      expect(copy.listingType, filter.listingType);
      expect(copy.minPrice, filter.minPrice);
      expect(copy.maxPrice, filter.maxPrice);
      expect(copy.minRooms, filter.minRooms);
      expect(copy.minSurface, filter.minSurface);
      expect(copy.amenities, filter.amenities);
    });
  });

  group('US-23.3 / 23.4 alerts', () {
    late FakeAuthService auth;
    late FakeApartmentService apartments;
    late FakeNotificationService notifications;
    late FakeSavedSearchService searches;
    late SavedSearchesViewModel viewModel;

    setUp(() {
      auth = FakeAuthService();
      apartments = FakeApartmentService();
      notifications = FakeNotificationService();
      searches = FakeSavedSearchService();
      viewModel = SavedSearchesViewModel(
        authService: auth,
        savedSearchService: searches,
        apartmentService: apartments,
        notificationService: notifications,
      );
    });

    tearDown(() => viewModel.dispose());

    /// Signs a verified user in, with one search and one known offer (a1).
    Future<void> signIn({
      required SavedSearch search,
      NotificationPreferences preferences = const NotificationPreferences(),
    }) async {
      auth.users.add(
        const AppUser(
          id: 'u1',
          email: 'u1@example.ch',
          emailVerified: true,
          roles: {UserRole.renter},
        ),
      );
      await _settle();
      searches.emit([search]);
      notifications.preferences.add(preferences);
      apartments.apartments.add([_apartment('a1')]);
      await _settle();
    }

    test('alerts once for a new matching offer, never twice', () async {
      await signIn(search: _search(seen: {'a1'}));
      expect(searches.alerts, isEmpty);

      apartments.apartments.add([_apartment('a1'), _apartment('a2')]);
      await _settle();
      expect(searches.alerts.map((alert) => alert.id), ['s1_a2']);
      expect(searches.alerts.single.type, NotificationType.newListing);
      expect(searches.alerts.single.apartmentId, 'a2');

      // The same listings arrive again: no duplicate alert.
      apartments.apartments.add([_apartment('a1'), _apartment('a2')]);
      await _settle();
      expect(searches.alerts, hasLength(1));
    });

    test('an offer that does not match never alerts', () async {
      await signIn(search: _search(seen: {'a1'}));

      apartments.apartments.add([
        _apartment('a1'),
        _apartment('a3', price: 2500),
        _apartment('a5', city: '1003 Lausanne'),
      ]);
      await _settle();
      expect(searches.alerts, isEmpty);
    });

    test('search switch off: the offer is marked seen, no alert', () async {
      await signIn(search: _search(seen: {'a1'}, alertsEnabled: false));

      apartments.apartments.add([_apartment('a1'), _apartment('a2')]);
      await _settle();
      expect(searches.alerts, isEmpty);
      // Switching back on later will not alert this old offer.
      expect(searches.current.single.seenApartmentIds, contains('a2'));
    });

    test('"New listings" switched off (US-18): no alert', () async {
      await signIn(
        search: _search(seen: {'a1'}),
        preferences: const NotificationPreferences(newListing: false),
      );

      apartments.apartments.add([_apartment('a1'), _apartment('a2')]);
      await _settle();
      expect(searches.alerts, isEmpty);
    });

    test('saving a search does not alert the offers that exist', () async {
      await signIn(search: _search(seen: {'a1'}));
      apartments.apartments.add([
        _apartment('a1'),
        _apartment('a9', availability: ApartmentAvailability.reserved),
      ]);
      await _settle();

      final saved = await viewModel.save('Sion', _filter);

      expect(saved, isTrue);
      // a1 is an offer now; a9 is reserved, so it can still alert later.
      expect(searches.seenWhenCreated, ['a1']);
    });

    test('a 6th saved search is refused', () async {
      await signIn(search: _search());
      searches.emit([
        for (var i = 0; i < SavedSearch.maxPerUser; i++)
          SavedSearch(
            id: 's$i',
            name: 'Search $i',
            filter: _filter,
            alertsEnabled: true,
            seenApartmentIds: const {'a1'},
            createdAt: DateTime(2026, 10, 1),
          ),
      ]);
      await _settle();

      final saved = await viewModel.save('One more', _filter);

      expect(saved, isFalse);
      expect(viewModel.actionError, isNotNull);
      expect(searches.seenWhenCreated, isNull);
    });
  });
}
