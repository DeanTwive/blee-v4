import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/tracking/presentation/tracking_screen.dart';
import '../../features/tracking/presentation/post_run_screen.dart';
import '../../features/tracking/presentation/activity_detail_screen.dart';
import '../../features/tracking/domain/run_summary_entity.dart';
import '../../features/tracking/domain/run_history_provider.dart';

// Route name constants — prevents magic strings
abstract final class Routes {
  static const login = '/login';
  static const home = '/home';
  static const onboarding = '/onboarding';
  static const tracking = '/tracking';
  static const postRun = '/post-run';
  static const activityDetail = '/activity-detail';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Listenable that rebuilds the router when auth state changes
  final authNotifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final profileAsync = ref.read(currentProfileProvider);

      // While auth is loading, stay put
      if (authAsync.isLoading) return null;

      final user = authAsync.value;
      final isLoggedIn = user != null;
      final isOnLoginPage = state.matchedLocation == Routes.login;

      // Not logged in → always to login
      if (!isLoggedIn) {
        return isOnLoginPage ? null : Routes.login;
      }

      // Logged in + on login → check onboarding completion
      if (isLoggedIn && isOnLoginPage) {
        final profile = profileAsync.value;
        if (profile != null && !profile.onboardingComplete) {
          return Routes.onboarding;
        }
        return Routes.home;
      }

      // Logged in, completed onboarding but somehow on onboarding
      if (state.matchedLocation == Routes.onboarding) {
        final profile = profileAsync.value;
        if (profile?.onboardingComplete == true) return Routes.home;
      }

      // Safe guards for web reload / direct navigation to post-run or activity-detail
      if (state.matchedLocation == Routes.postRun && state.extra == null) {
        final history = ref.read(runHistoryNotifierProvider);
        if (history.runs.isEmpty) {
          return Routes.home;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.tracking,
        name: 'tracking',
        builder: (context, state) => const TrackingScreen(),
      ),
      GoRoute(
        path: Routes.postRun,
        name: 'postRun',
        builder: (context, state) {
          RunSummaryEntity? summary;
          if (state.extra is RunSummaryEntity) {
            summary = state.extra as RunSummaryEntity;
          } else {
            final history = ref.read(runHistoryNotifierProvider);
            summary = history.runs.isNotEmpty ? history.runs.first : null;
          }

          if (summary == null) {
            return const HomeScreen();
          }
          return PostRunScreen(summary: summary);
        },
      ),
      GoRoute(
        path: Routes.activityDetail,
        name: 'activityDetail',
        builder: (context, state) {
          RunSummaryEntity? run;
          String runnerName = ref.read(currentProfileProvider).value?.displayName ?? 'Runner';

          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra as Map<String, dynamic>;
            if (extra['run'] is RunSummaryEntity) {
              run = extra['run'] as RunSummaryEntity;
            }
            if (extra['runnerName'] is String) {
              runnerName = extra['runnerName'] as String;
            }
          } else if (state.extra is RunSummaryEntity) {
            run = state.extra as RunSummaryEntity;
          } else {
            final runId = state.uri.queryParameters['id'];
            final history = ref.read(runHistoryNotifierProvider);
            if (runId != null && runId.isNotEmpty) {
              run = history.runs.where((r) => r.runId == runId).firstOrNull;
            }
            run ??= history.runs.firstOrNull;
          }

          if (run == null) {
            return const HomeScreen();
          }
          return ActivityDetailScreen(
            run: run,
            runnerName: runnerName,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => _ErrorPage(error: state.error.toString()),
  );
});

/// Makes GoRouter react to auth state changes via Riverpod.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (previous, next) => notifyListeners());
    ref.listen(currentProfileProvider, (previous, next) => notifyListeners());
  }
}

class _ErrorPage extends StatelessWidget {
  final String error;
  const _ErrorPage({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Navigation error: $error'),
      ),
    );
  }
}
