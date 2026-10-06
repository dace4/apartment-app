import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';

import '../features/apartments/pages/apartment_detail_page.dart';
import '../features/apartments/pages/apartment_list_page.dart';
import '../features/apartments/pages/compare_page.dart';
import '../features/apartments/pages/filters_page.dart';
import '../features/applications/pages/application_detail_page.dart';
import '../features/applications/pages/applications_page.dart';
import '../features/applications/pages/apply_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/pages/verify_email_page.dart';
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
String? _authRedirect(AuthRepository authRepository, GoRouterState state) {
  final user = authRepository.currentUser;
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

GoRouter createAppRouter({required AuthRepository authRepository}) => GoRouter(
  initialLocation: AppRoutes.apartments,
  // Re-runs the redirect whenever the signed-in user changes.
  refreshListenable: authRepository,
  redirect: (context, state) => _authRedirect(authRepository, state),
  routes: [
    // Full-screen pages without the bottom navigation bar.
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => LoginPage(authRepository: authRepository),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => RegisterPage(authRepository: authRepository),
    ),
    GoRoute(
      path: AppRoutes.verifyEmail,
      builder: (context, state) =>
          VerifyEmailPage(authRepository: authRepository),
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
              builder: (context, state) => const ApartmentListPage(),
              routes: [
                // Static paths must come before ':id' to be matched first.
                GoRoute(
                  path: 'filters',
                  builder: (context, state) => const FiltersPage(),
                ),
                GoRoute(
                  path: 'compare',
                  builder: (context, state) => const ComparePage(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ApartmentDetailPage(
                    apartmentId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'apply',
                      builder: (context, state) =>
                          ApplyPage(apartmentId: state.pathParameters['id']!),
                    ),
                    GoRoute(
                      path: 'contact',
                      builder: (context, state) => ContactAdvertiserPage(
                        apartmentId: state.pathParameters['id']!,
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
              builder: (context, state) => const ApplicationsPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ApplicationDetailPage(
                    applicationId: state.pathParameters['id']!,
                  ),
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
                  ProfilePage(authRepository: authRepository),
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
