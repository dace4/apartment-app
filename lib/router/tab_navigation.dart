import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Each bottom-navigation tab keeps the page it was left on. After a
/// one-time page (a sent form, a booking confirmation) opens a page of
/// another tab, coming back to its tab must not show that page again.
extension TabNavigation on BuildContext {
  /// Moves this tab back to [back], then opens [to] in its own tab. The two
  /// steps happen one frame apart: in the same frame only [to] would count,
  /// and this tab would keep the finished page.
  void goToOtherTab({required String back, required String to}) {
    final router = GoRouter.of(this);
    router.go(back);
    WidgetsBinding.instance.addPostFrameCallback((_) => router.go(to));
  }
}
