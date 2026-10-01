/// Every path in the app, so pages never hard-code URLs.
abstract final class AppRoutes {
  // Auth (outside the bottom navigation)
  static const login = '/login';
  static const register = '/register';

  // Tab 1: Search
  static const apartments = '/apartments';
  static const filters = '/apartments/filters';
  static const compare = '/apartments/compare';
  static String apartmentDetail(String id) => '/apartments/$id';
  static String apply(String id) => '/apartments/$id/apply';
  static String contactAdvertiser(String id) => '/apartments/$id/contact';

  // Tab 2: Favourites
  static const favourites = '/favourites';

  // Tab 3: Applications
  static const applications = '/applications';
  static String applicationDetail(String id) => '/applications/$id';

  // Tab 4: Services
  static const services = '/services';
  static const mortgage = '/services/mortgage';
  static const maintenance = '/services/maintenance';
  static const insurance = '/services/insurance';
  static const contractors = '/services/contractors';
  static const marketTrends = '/services/market-trends';

  // Tab 5: Profile
  static const profile = '/profile';
  static const notifications = '/profile/notifications';
  static const faq = '/profile/faq';
}
