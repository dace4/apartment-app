import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../view_models/app_maintenance_view_model.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/compare_view_model.dart';
import '../view_models/apartments_view_model.dart';
import '../view_models/favourites_view_model.dart';
import '../view_models/notifications_view_model.dart';
import '../view_models/saved_searches_view_model.dart';
import '../views/apartments/apartment_detail_view.dart';
import '../views/apartments/apartments_view.dart';
import '../views/apartments/compare_view.dart';
import '../views/apartments/filters_view.dart';
import '../views/apartments/create_apartment_view.dart';
import '../views/applications/application_detail_view.dart';
import '../views/applications/applications_view.dart';
import '../views/applications/apply_view.dart';
import '../views/applications/edit_application_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/choose_roles_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/verify_email_view.dart';
import '../views/favourites/favourites_view.dart';
import '../views/maintenance/app_maintenance_view.dart';
import '../views/documents/documents_view.dart';
import '../views/documents/document_review_view.dart';
import '../views/signatures/signature_view.dart';
import '../views/messages/contact_advertiser_view.dart';
import '../views/profile/faq_view.dart';
import '../views/profile/inbox_view.dart';
import '../views/profile/message_detail_view.dart';
import '../views/profile/review_application_view.dart';
import '../views/profile/notifications_view.dart';
import '../views/profile/profile_view.dart';
import '../views/profile/saved_searches_view.dart';
import '../views/services/contractors_view.dart';
import '../views/services/insurance_contact_view.dart';
import '../views/services/insurance_coverage_view.dart';
import '../views/services/insurance_view.dart';
import '../views/services/maintenance_view.dart';
import '../views/services/market_trends_view.dart';
import '../views/services/mortgage_calculator_view.dart';
import '../views/services/services_view.dart';
import '../views/shared/widgets/scaffold_with_nav_bar.dart';
import '../views/visits/my_visits_view.dart';
import '../views/visits/visit_booking_view.dart';
import '../views/visits/visit_detail_view.dart';
import 'app_routes.dart';

GoRouter createAppRouter({
  required AuthViewModel authViewModel,
  required ApartmentsViewModel apartmentsViewModel,
  required CompareViewModel compareViewModel,
  required FavouritesViewModel favouritesViewModel,
  required AppMaintenanceViewModel appMaintenanceViewModel,
  required SavedSearchesViewModel savedSearchesViewModel,
  required NotificationsViewModel notificationsViewModel,
}) {
  return GoRouter(
    initialLocation: AppRoutes.apartments,
    // Re-runs the redirect whenever the signed-in user or the app
    // maintenance window changes.
    refreshListenable: Listenable.merge([
      authViewModel,
      appMaintenanceViewModel,
    ]),
    redirect: (context, state) => authViewModel.redirectFor(
      state.matchedLocation,
      appDown: appMaintenanceViewModel.isActive,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.appMaintenance,
        builder: (context, state) =>
            AppMaintenanceView(authViewModel: authViewModel),
      ),
      GoRoute(
        path: AppRoutes.chooseRoles,
        builder: (context, state) => ChooseRolesView(viewModel: authViewModel),
      ),
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
        builder: (context, state, navigationShell) => ScaffoldWithNavBar(
          navigationShell: navigationShell,
          notificationsViewModel: notificationsViewModel,
          authViewModel: authViewModel,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.apartments,
                builder: (context, state) => ApartmentsView(
                  viewModel: apartmentsViewModel,
                  compareViewModel: compareViewModel,
                  favouritesViewModel: favouritesViewModel,
                  savedSearchesViewModel: savedSearchesViewModel,
                  authViewModel: authViewModel,
                ),
                routes: [
                  // Static paths must come before ':id' to be matched first.
                  GoRoute(
                    path: 'new',
                    builder: (context, state) =>
                        CreateApartmentView(authViewModel: authViewModel),
                  ),
                  GoRoute(
                    path: 'filters',
                    builder: (context, state) =>
                        FiltersView(viewModel: apartmentsViewModel),
                  ),
                  GoRoute(
                    path: 'compare',
                    builder: (context, state) =>
                        CompareView(viewModel: compareViewModel),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ApartmentDetailView(
                      apartmentId: state.pathParameters['id']!,
                      authViewModel: authViewModel,
                      compareViewModel: compareViewModel,
                      favouritesViewModel: favouritesViewModel,
                    ),
                    routes: [
                      GoRoute(
                        path: 'apply',
                        builder: (context, state) => ApplyView(
                          authViewModel: authViewModel,
                          apartmentId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'apply-immediately',
                        builder: (context, state) => ApplyView(
                          authViewModel: authViewModel,
                          apartmentId: state.pathParameters['id']!,
                          applyImmediately: true,
                        ),
                      ),
                      GoRoute(
                        path: 'contact',
                        builder: (context, state) => ContactAdvertiserView(
                          authViewModel: authViewModel,
                          apartmentId: state.pathParameters['id']!,
                        ),
                      ),
                      // US-20: renters and buyers only (canAccess).
                      GoRoute(
                        path: 'visit',
                        builder: (context, state) => VisitBookingView(
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
                builder: (context, state) => FavouritesView(
                  viewModel: favouritesViewModel,
                  compareViewModel: compareViewModel,
                ),
                routes: [
                  GoRoute(
                    path: 'filters',
                    builder: (context, state) =>
                        FiltersView(viewModel: favouritesViewModel),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.applications,
                builder: (context, state) =>
                    ApplicationsView(authViewModel: authViewModel),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ApplicationDetailView(
                      authViewModel: authViewModel,
                      applicationId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => EditApplicationView(
                          authViewModel: authViewModel,
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
                builder: (context, state) =>
                    ServicesView(viewModel: authViewModel),
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
                  // Admins only (canAccess).
                  GoRoute(
                    path: 'maintenance',
                    builder: (context, state) => MaintenanceView(
                      appMaintenanceViewModel: appMaintenanceViewModel,
                    ),
                  ),
                  GoRoute(
                    path: 'insurance',
                    builder: (context, state) => const InsuranceView(),
                    routes: [
                      // US-19: renters only (canAccess).
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => InsuranceCoverageView(
                          coverageId: state.pathParameters['id']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'contact',
                            builder: (context, state) => InsuranceContactView(
                              coverageId: state.pathParameters['id']!,
                              authViewModel: authViewModel,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                builder: (context, state) => ProfileView(
                  viewModel: authViewModel,
                  notificationsViewModel: notificationsViewModel,
                ),
                routes: [
                  GoRoute(
                    path: 'signature',
                    builder: (context, state) =>
                        SignatureView(authViewModel: authViewModel),
                  ),
                  // US-15/11 inherit the existing verified-email redirect.
                  GoRoute(
                    path: 'documents',
                    builder: (context, state) =>
                        DocumentsView(authViewModel: authViewModel),
                    routes: [
                      GoRoute(
                        path: ':documentId',
                        builder: (context, state) => DocumentReviewView(
                          authViewModel: authViewModel,
                          documentId: state.pathParameters['documentId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) =>
                        NotificationsView(viewModel: notificationsViewModel),
                  ),
                  // US-20: renters and buyers only (canAccess).
                  GoRoute(
                    path: 'visits',
                    builder: (context, state) => const MyVisitsView(),
                  ),
                  GoRoute(
                    path: 'saved-searches',
                    builder: (context, state) => SavedSearchesView(
                      viewModel: savedSearchesViewModel,
                      apartmentsViewModel: apartmentsViewModel,
                    ),
                  ),
                  GoRoute(
                    path: 'inbox',
                    builder: (context, state) =>
                        InboxView(authViewModel: authViewModel),
                    routes: [
                      GoRoute(
                        path: 'applications/:id',
                        builder: (context, state) => ReviewApplicationView(
                          applicationId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'messages/:id',
                        builder: (context, state) => MessageDetailView(
                          messageId: state.pathParameters['id']!,
                        ),
                      ),
                      GoRoute(
                        path: 'visits/:id',
                        builder: (context, state) => VisitDetailView(
                          visitId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'faq',
                    // US 14: ?apartment= comes from an apartment's page.
                    builder: (context, state) => FaqView(
                      // A new page when the apartment changes, even if the
                      // FAQ is already open in the Profile tab.
                      key: ValueKey(state.uri.toString()),
                      canAccess: authViewModel.canAccess,
                      apartmentId: state.uri.queryParameters['apartment'],
                    ),
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
