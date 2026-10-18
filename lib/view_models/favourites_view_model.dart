import 'dart:async';

import '../models/apartment.dart';
import '../services/favourite_service.dart';
import '../services/auth_service.dart';
import 'apartments_view_model.dart';

/// US 22: the apartment list constrained to the current user's favourites.
class FavouritesViewModel extends ApartmentsViewModel {
  FavouritesViewModel({
    FavouriteService? favouriteService,
    AuthService? authService,
  }) : _favourites = favouriteService ?? FavouriteService(),
       _auth = authService ?? AuthService() {
    _authSubscription = _auth.userChanges().listen((user) {
      _subscription?.cancel();
      _subscription = null;
      _favouriteIds = {};
      apartments = [];
      _allowed = user?.isReady == true && user!.isConsumer;
      if (user?.isReady == true && user!.isConsumer) {
        _subscription = _favourites.watchFavouriteIds().listen(
          (ids) {
            _favouriteIds = ids;
            Future.microtask(notifyListeners);
          },
          onError: (Object error) {
            _favouriteIds = {};
            notifyListeners();
          },
        );
      }
      Future.microtask(notifyListeners);
    });
  }

  final FavouriteService _favourites;
  final AuthService _auth;
  StreamSubscription<Set<String>>? _subscription;
  StreamSubscription<dynamic>? _authSubscription;
  Set<String> _favouriteIds = {};

  bool get canUseFavourites => _allowed;
  bool _allowed = false;

  bool isFavorite(String apartmentId) => _favouriteIds.contains(apartmentId);

  @override
  Future<void> fetchApartments() async {
    if (!_allowed) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      _favouriteIds = await _favourites.getFavouriteIds();
      apartments = await service.getApartments();
      final apartmentIds = apartments.map((apartment) => apartment.id).toSet();
      final missing = _favouriteIds.difference(apartmentIds);
      if (missing.isNotEmpty) {
        throw StateError(
          'Favourite apartment not found: ${missing.join(', ')}',
        );
      }
    } catch (e) {
      errorMessage = e is StateError
          ? e.message
          : 'Could not load your favourites.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  List<Apartment> get visibleApartments => super.visibleApartments
      .where((apartment) => _favouriteIds.contains(apartment.id))
      .toList();

  Future<void> toggleFavorite(Apartment apartment) async {
    if (!_allowed) return;
    if (isFavorite(apartment.id)) {
      await _favourites.remove(apartment.id);
    } else {
      await _favourites.add(apartment.id);
    }
  }

  @override
  void dispose() {
    _allowed = false;
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
