import 'package:go_router/go_router.dart';

import '../view_models/auth_view_model.dart';
import '../features/applications/data/application_repository.dart';
import '../features/messages/data/contact_listing_repository.dart';
import '../features/messages/data/message_repository.dart';

import '../view_models/apartments_view_model.dart';
import '../views/apartments/apartment_detail_view.dart';
import '../views/apartments/apartments_view.dart';
import '../views/apartments/compare_view.dart';
import '../views/apartments/filters_view.dart';
import '../features/applications/pages/application_detail_page.dart';
import '../features/applications/pages/applications_page.dart';
import '../features/applications/pages/apply_page.dart';
import '../features/applications/pages/edit_application_page.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/verify_email_view.dart';
import '../features/favourites/pages/favourites_page.dart';
import '../features/messages/pages/contact_advertiser_page.dart';
import '../features/profile/pages/faq_page.dart';
import '../features/profile/pages/notifications_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/services/pages/contractors_page.dart';
import '../features/services/pages/insurance_page.dart';
import '../features/services/pages/maintenance_page.dart';
import '../features/services/pages/market_trends_page.dart';
import '../features/services/pages/mortgage_calculator_page.dart';
import '../features/services/pages/services_page.dart';
import '../shared/widgets/scaffold_with_nav_bar.dart';
import 'app_routes.dart';

/// The app is only usable after logging in with a verified email:
/// - signed out: only Log in and Create account are reachable,
/// - email not verified: only the Verify email page is reachable,
/// - verified: every page except the auth pages.
String? _authRedirect(AuthViewModel authViewModel, GoRouterState state) {
  final user = authViewModel.user;
  final location = state.matchedLocation;
  final onAuthPage =
      location == AppRoutes.login || location == AppRoutes.register;
  final onVerifyPage = location == AppRoutes.verifyEmail;

  if (user == null) {
    return onAuthPage ? null : AppRoutes.login;
  }
  if (!user.emailVerified) {
    return onVerifyPage ? null : AppRoutes.verifyEmail;
  }
  // US-07: a successful log in leads to the home page.
  return onAuthPage || onVerifyPage ? AppRoutes.apartments : null;
}

GoRouter createAppRouter({
  required AuthViewModel authViewModel,
  ContactListingRepository contactListingRepository =
      const SampleContactListingRepository(),
  MessageRepository messageRepository = const UnconfiguredMessageRepository(),
  ApplicationRepository applicationRepository =
      const UnconfiguredApplicationRepository(),
}) {
  // Shared by the apartment list and the Filters page (ARCHITECTURE.md §4).
  final apartmentsViewModel = ApartmentsViewModel();

  return GoRouter(
    initialLocation: AppRoutes.apartments,
    // Re-runs the redirect whenever the signed-in user changes.
    refreshListenable: authViewModel,
    redirect: (context, state) => _authRedirect(authViewModel, state),
    routes: [
      // Full-screen pages without the bottom navigation bar.
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterView(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => VerifyEmailView(viewModel: authViewModel),
      ),

      // One branch per bottom-navigation tab, in the same order as the tabs.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.apartments,
                builder: (context, state) =>
                    ApartmentsView(viewModel: apartmentsViewModel),
                routes: [
                  // Static paths must come before ':id' to be matched first.
                  GoRoute(
                    path: 'filters',
                    builder: (context, state) =>
                        FiltersView(viewModel: apartmentsViewModel),
                  ),
                  GoRoute(
                    path: 'compare',
                    builder: (context, state) => const CompareView(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ApartmentDetailView(
                      apartmentId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'apply',
                        builder: (context, state) => ApplyPage(
                          apartmentId: state.pathParameters['id']!,
                          applicationRepository: applicationRepository,
                        ),
                      ),
                      GoRoute(
                        path: 'contact',
                        builder: (context, state) => ContactAdvertiserPage(
                          apartmentId: state.pathParameters['id']!,
                          authViewModel: authViewModel,
                          listingRepository: contactListingRepository,
                          messageRepository: messageRepository,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.favourites,
                builder: (context, state) => const FavouritesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.applications,
                builder: (context, state) =>
                    ApplicationsPage(repository: applicationRepository),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ApplicationDetailPage(
                      applicationId: state.pathParameters['id']!,
                      repository: applicationRepository,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => EditApplicationPage(
                          applicationId: state.pathParameters['id']!,
                          repository: applicationRepository,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.services,
                builder: (context, state) => const ServicesPage(),
                routes: [
                  GoRoute(
                    path: 'mortgage',
                    builder: (context, state) => const MortgageCalculatorPage(),
                  ),
                  GoRoute(
                    path: 'maintenance',
                    builder: (context, state) => const MaintenancePage(),
                  ),
                  GoRoute(
                    path: 'insurance',
                    builder: (context, state) => const InsurancePage(),
                  ),
                  GoRoute(
                    path: 'contractors',
                    builder: (context, state) => const ContractorsPage(),
                  ),
                  GoRoute(
                    path: 'market-trends',
                    builder: (context, state) => const MarketTrendsPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) =>
                    ProfilePage(viewModel: authViewModel),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsPage(),
                  ),
                  GoRoute(
                    path: 'faq',
                    builder: (context, state) => const FaqPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
