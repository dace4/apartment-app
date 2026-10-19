/// Every path in the app, so pages never hard-code URLs.
abstract final class AppRoutes {
  // Auth (outside the bottom navigation)
  static const login = '/login';
  static const register = '/register';
  static const chooseRoles = '/choose-roles';
  static const verifyEmail = '/verify-email';

  // Tab 1: Home
  static const apartments = '/apartments';
  static const createApartment = '/apartments/new';
  static const filters = '/apartments/filters';
  static const compare = '/apartments/compare';
  static String apartmentDetail(String id) => '/apartments/$id';
  static String apply(String id) => '/apartments/$id/apply';
  static String applyImmediately(String id) =>
      '/apartments/$id/apply-immediately';
  static String contactAdvertiser(String id) => '/apartments/$id/contact';

  // Tab 2: Favourites
  static const favourites = '/favourites';
  static const favouriteFilters = '/favourites/filters';

  // Tab 3: Applications
  static const applications = '/applications';
  static String applicationDetail(String id) => '/applications/$id';
  static String editApplication(String id) => '/applications/$id/edit';

  // Tab 4: Services
  static const services = '/services';
  static const mortgage = '/services/mortgage';
  // US-09: opens the calculator with the apartment's price filled in.
  static String mortgageForPrice(int price) => '$mortgage?price=$price';
  static const maintenance = '/services/maintenance';
  // US-17: book, view and reschedule repair and maintenance services.
  static const maintenanceNew = '$maintenance/new';
  static String maintenanceDetail(String id) => '$maintenance/$id';
  static String maintenanceReschedule(String id) =>
      '$maintenance/$id/reschedule';
  static const insurance = '/services/insurance';
  static const contractors = '/services/contractors';
  static const marketTrends = '/services/market-trends';

  // Tab 5: Profile
  static const profile = '/profile';
  // US-15 library and US-11 reusable signature.
  static const signature = '/profile/signature';
  static const documents = '/profile/documents';
  static String documentReview(String id) =>
      '$documents/${Uri.encodeComponent(id)}';
  static const notifications = '/profile/notifications';
  // US-23: saved searches and their new-offer alerts.
  static const savedSearches = '/profile/saved-searches';
  // US 16: applications received by owners and managers.
  static const inbox = '/profile/inbox';
  static String inboxApplication(String id) => '$inbox/applications/$id';
  static const faq = '/profile/faq';
}
