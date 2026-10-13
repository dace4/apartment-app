import 'package:go_router/go_router.dart';

import '../view_models/auth_view_model.dart';

import '../view_models/apartments_view_model.dart';
import '../views/apartments/apartment_detail_view.dart';
import '../views/apartments/apartments_view.dart';
import '../views/apartments/compare_view.dart';
import '../views/apartments/filters_view.dart';
import '../views/applications/application_detail_view.dart';
import '../views/applications/applications_view.dart';
import '../views/applications/apply_view.dart';
import '../views/applications/edit_application_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/verify_email_view.dart';
import '../views/favourites/favourites_view.dart';
import '../views/messages/contact_advertiser_view.dart';
import '../views/profile/faq_view.dart';
import '../views/profile/notifications_view.dart';
import '../views/profile/profile_view.dart';
import '../views/services/contractors_view.dart';
import '../views/services/insurance_view.dart';
import '../views/services/maintenance_view.dart';
import '../views/services/market_trends_view.dart';
import '../views/services/mortgage_calculator_view.dart';
import '../views/services/services_view.dart';
import '../views/shared/widgets/scaffold_with_nav_bar.dart';
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
  required ApartmentsViewModel apartmentsViewModel,
}) {
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
                        builder: (context, state) =>
                            ApplyView(apartmentId: state.pathParameters['id']!),
                      ),
                      GoRoute(
                        path: 'contact',
                        builder: (context, state) => ContactAdvertiserView(
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
                builder: (context, state) => const FavouritesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.applications,
                builder: (context, state) => const ApplicationsView(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ApplicationDetailView(
                      applicationId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => EditApplicationView(
                          applicationId: state.pathParameters['id']!,
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
                builder: (context, state) => const ServicesView(),
                routes: [
                  GoRoute(
                    path: 'mortgage',
                    // ?price= comes from an apartment for sale (US-09).
                    builder: (context, state) => MortgageCalculatorView(
                      initialPrice: int.tryParse(
                        state.uri.queryParameters['price'] ?? '',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'maintenance',
                    builder: (context, state) => const MaintenanceView(),
                  ),
                  GoRoute(
                    path: 'insurance',
                    builder: (context, state) => const InsuranceView(),
                  ),
                  GoRoute(
                    path: 'contractors',
                    builder: (context, state) => const ContractorsView(),
                  ),
                  GoRoute(
                    path: 'market-trends',
                    builder: (context, state) => const MarketTrendsView(),
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
                    ProfileView(viewModel: authViewModel),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsView(),
                  ),
                  GoRoute(
                    path: 'faq',
                    builder: (context, state) => const FaqView(),
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
