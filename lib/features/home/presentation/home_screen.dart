import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/geo_math.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../../auth/domain/profile_entity.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../run_receipt/presentation/run_receipt_widget.dart';
import '../../tracking/domain/run_history_provider.dart';
import '../../tracking/domain/run_summary_entity.dart';
import '../../tracking/domain/tracking_preferences_provider.dart';
import '../domain/clubs_provider.dart';
import '../domain/community_events_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(currentProfileProvider).value;

    final displayName = profile?.displayName ??
        user?.displayName ??
        (user?.isAnonymous == true ? 'Guest Runner' : 'Runner');

    final tierLabel = profile?.tierLabel ?? 'PACER';
    final tierColor = switch (profile?.tier ?? 'pacer') {
      'strider' => AppColors.primary,
      'elite' => AppColors.safetyOrange,
      _ => AppColors.electricCobalt,
    };

    final titles = ['Dashboard', 'Track', 'Clubs', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Text(
                '🐝 BLEE',
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(titles[_selectedIndex], style: AppTypography.titleMedium),
          ],
        ),
        actions: [
          if (_selectedIndex == 3)
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _DashboardTab(
              displayName: displayName,
              tierLabel: tierLabel,
              tierColor: tierColor,
              profile: profile,
              onNavigateToProfile: () => setState(() => _selectedIndex = 3),
            ),
            _TrackTab(
              tierLabel: tierLabel,
              tierColor: tierColor,
            ),
            const _ClubsTab(),
            _ProfileTab(
              displayName: displayName,
              tierLabel: tierLabel,
              tierColor: tierColor,
              profile: profile,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_run_outlined),
              selectedIcon: Icon(Icons.directions_run_rounded),
              label: 'Track',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Clubs',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 0: Dashboard ──────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  final String displayName;
  final String tierLabel;
  final Color tierColor;
  final ProfileEntity? profile;
  final VoidCallback onNavigateToProfile;

  const _DashboardTab({
    required this.displayName,
    required this.tierLabel,
    required this.tierColor,
    required this.profile,
    required this.onNavigateToProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runHistory = ref.watch(runHistoryNotifierProvider);
    final events = ref.watch(communityEventsProvider);
    final event = events.first;

    final weeklyKm = runHistory.weeklyDistanceKm;
    final weeklyRunsCount = runHistory.weeklyRunsCount;
    final rhythmTarget = profile?.weeklyRhythmTarget ?? 3;
    final rhythmProgress = (weeklyRunsCount / rhythmTarget).clamp(0.0, 1.0);

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        // Runner Identity Card
        BouncyPressable(
          onTap: onNavigateToProfile,
          child: Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceElevated,
                  tierColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: tierColor.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [tierColor.withValues(alpha: 0.3), tierColor.withValues(alpha: 0.1)],
                        ),
                        border: Border.all(color: tierColor.withValues(alpha: 0.5), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🏃', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: AppTypography.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tierColor.withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusSm),
                                ),
                                child: Text(
                                  tierLabel,
                                  style: AppTypography.badge.copyWith(
                                    color: tierColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text('• BGC Cluster', style: AppTypography.caption),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary, size: 20),
                  ],
                ),
                if (profile != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(color: AppColors.surfaceBorder, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Weekly Rhythm', style: AppTypography.bodyMedium),
                      Text(
                        '$weeklyRunsCount of $rhythmTarget runs this week',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: rhythmProgress,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rhythmProgress >= 1.0 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Running Conditions Glance Chip (Interactive Atmospheric Sheet)
        BouncyPressable(
          onTap: () => _showRunningConditionsSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'BGC · 24°C · Ideal Running Humidity · 6:00 AM Sunrise',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'OPTIMAL',
                    style: AppTypography.badge.copyWith(color: AppColors.success, fontSize: 9),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Start Run CTA Card (Live Distance from Run History)
        Container(
          padding: AppSpacing.paddingXl,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E232E), AppColors.surfaceBase],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.surfaceBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'READY TO RUN',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                weeklyKm > 0 ? weeklyKm.toStringAsFixed(2) : '0.00',
                style: AppTypography.metricLarge,
              ),
              Text(
                'KILOMETERS',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              BouncyPressable(
                onTap: () => context.push(Routes.tracking),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text('START RUN'),
                  onPressed: () => context.push(Routes.tracking),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Community Event Card (Interactive RSVP & Details)
        BouncyPressable(
          onTap: () => _showEventDetailsSheet(context, event, ref),
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: event.isRsvp
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'COMMUNITY EVENT',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (event.isRsvp)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Text(
                          'CONFIRMED ✓',
                          style: AppTypography.badge.copyWith(color: AppColors.onPrimary, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(event.title, style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${event.dateSchedule} · ${event.location}',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${event.attendeesCount} Runners RSVP\'d', style: AppTypography.caption),
                    BouncyPressable(
                      onTap: () {
                        ref.read(communityEventsProvider.notifier).toggleRsvp(event.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !event.isRsvp
                                  ? 'RSVP confirmed for ${event.title}! 🐝'
                                  : 'RSVP cancelled for ${event.title}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: event.isRsvp
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                minimumSize: const Size(100, 36),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('GOING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              onPressed: () {
                                ref.read(communityEventsProvider.notifier).toggleRsvp(event.id);
                              },
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(100, 36),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              ),
                              onPressed: () {
                                ref.read(communityEventsProvider.notifier).toggleRsvp(event.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('RSVP confirmed for ${event.title}! 🐝'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Text('RSVP', style: TextStyle(fontSize: 13)),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Recent Activity Feed
        if (runHistory.recentRuns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT ACTIVITIES', style: AppTypography.badge),
              Text(
                '${runHistory.runs.length} Total Runs',
                style: AppTypography.caption.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final run in runHistory.recentRuns.take(3))
            _RecentRunCard(
              run: run,
              onTap: () => _showRunReceiptModal(context, run),
            ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // Systems Status (Interactive Diagnostics)
        BouncyPressable(
          onTap: () => _showSystemsDiagnosticsSheet(context),
          child: Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blee Systems Online',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Firebase · Supabase · GPS Ready (Tap for Diagnostics)',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.textTertiary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Recent Run Card ──────────────────────────────────────────────────────────

class _RecentRunCard extends StatelessWidget {
  final RunSummaryEntity run;
  final VoidCallback onTap;

  const _RecentRunCard({required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: BouncyPressable(
        onTap: onTap,
        child: Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.directions_run_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${run.distanceKm.toStringAsFixed(2)} km',
                          style: AppTypography.titleMedium.copyWith(fontSize: 16),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorder,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            'RPE ${run.rpe ?? 5}',
                            style: AppTypography.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${GeoMath.formatDuration(run.durationSeconds)} · ${GeoMath.formatPace(run.avgPaceSecondsPerKm)} /km',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Track Launchpad ────────────────────────────────────────────────────

class _TrackTab extends ConsumerWidget {
  final String tierLabel;
  final Color tierColor;

  const _TrackTab({
    required this.tierLabel,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(trackingPreferencesProvider);

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Container(
          padding: AppSpacing.paddingXl,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.surfaceElevated, AppColors.surfaceBase],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed_rounded,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'GPS READY · < 3ms LATENCY',
                      style: AppTypography.badge.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('RECORD ACTIVITY', style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Identity > Telemetry. Hit start whenever you are ready.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              BouncyPressable(
                onTap: () => context.push(Routes.tracking),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 32),
                  label: const Text(
                    'LAUNCH GPS TRACKER',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => context.push(Routes.tracking),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TRACKING PREFERENCES', style: AppTypography.badge),
              const SizedBox(height: AppSpacing.md),
              _preferenceRow(
                icon: Icons.speed_rounded,
                title: 'Pace Tier',
                value: tierLabel,
                valueColor: tierColor,
              ),
              const Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.pause_circle_outline_rounded,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-Pause', style: AppTypography.bodyMedium),
                        Text('Stops clock when speed < 0.8 m/s', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: prefs.autoPauseEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      ref
                          .read(trackingPreferencesProvider.notifier)
                          .toggleAutoPause(val);
                    },
                  ),
                ],
              ),
              const Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.shield_rounded,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Beacon Safety', style: AppTypography.bodyMedium),
                        Text('Share real-time coordinates with emergency contacts',
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: prefs.liveBeaconEnabled,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      ref
                          .read(trackingPreferencesProvider.notifier)
                          .toggleLiveBeacon(val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preferenceRow({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: AppTypography.bodyMedium)),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Clubs & Community ──────────────────────────────────────────────────

class _ClubsTab extends ConsumerWidget {
  const _ClubsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(clubsProvider);

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Local Clubs', style: AppTypography.titleLarge),
                Text('Taguig & BGC Community', style: AppTypography.caption),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.electricCobalt.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                'SPRINT 2 HUB',
                style: AppTypography.badge.copyWith(color: AppColors.electricCobalt),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final club in clubs) ...[
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: club.isJoined
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.surfaceBase,
                      child: Text(club.icon, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(club.name, style: AppTypography.titleMedium),
                          Text(club.neighborhood, style: AppTypography.caption),
                        ],
                      ),
                    ),
                    BouncyPressable(
                      onTap: () {
                        ref.read(clubsProvider.notifier).toggleJoin(club.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !club.isJoined
                                  ? 'Joined ${club.name}! 🐝'
                                  : 'Left ${club.name}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: club.isJoined
                          ? ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                minimumSize: const Size(88, 32),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 14),
                              label: const Text('JOINED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              onPressed: () {
                                ref.read(clubsProvider.notifier).toggleJoin(club.id);
                              },
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(72, 32),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              ),
                              onPressed: () {
                                ref.read(clubsProvider.notifier).toggleJoin(club.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Joined ${club.name}! 🐝'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Text('JOIN', style: TextStyle(fontSize: 12)),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  club.description,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded,
                            color: AppColors.textTertiary, size: 14),
                        const SizedBox(width: AppSpacing.xxs),
                        Text('${club.members} active runners',
                            style: AppTypography.caption),
                      ],
                    ),
                    Text(
                      club.schedule,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

// ── Tab 3: Runner Profile ─────────────────────────────────────────────────────

class _ProfileTab extends ConsumerWidget {
  final String displayName;
  final String tierLabel;
  final Color tierColor;
  final ProfileEntity? profile;

  const _ProfileTab({
    required this.displayName,
    required this.tierLabel,
    required this.tierColor,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        // Profile Header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryMuted,
                child: const Text('🏃', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(displayName, style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                user?.email ?? 'anonymous@blee.app',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  tierLabel,
                  style: AppTypography.badge.copyWith(
                    color: tierColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Identity Commitment
        Container(
          padding: AppSpacing.paddingLg,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IDENTITY COMMITMENT', style: AppTypography.badge),
              const SizedBox(height: AppSpacing.md),
              _detailRow('Motivation Anchor',
                  profile?.identityGoal ?? 'Mental clarity & fitness'),
              const Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              _detailRow('Weekly Rhythm Target',
                  '${profile?.weeklyRhythmTarget ?? 3} runs per week'),
              const Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              _detailRow('Community Cluster', 'Bonifacio Global City (BGC)'),
              const Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              _detailRow('Onboarding Status', 'Complete ✓'),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Edit Profile & Goals Button
        BouncyPressable(
          onTap: () => _showEditProfileModal(context, profile, ref),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.primary),
            label: const Text('EDIT PROFILE & GOALS'),
            onPressed: () => _showEditProfileModal(context, profile, ref),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Sign Out Button
        BouncyPressable(
          onTap: () async {
            await ref.read(authNotifierProvider.notifier).signOut();
          },
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('SIGN OUT'),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Interactive Modal Bottom Sheets ───────────────────────────────────────────

void _showRunningConditionsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) {
      return Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Atmospheric Telemetry', style: AppTypography.titleMedium),
                    Text('Bonifacio Global City Microclimate', style: AppTypography.caption),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text('OPTIMAL', style: AppTypography.badge.copyWith(color: AppColors.success)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  _telemetryRow('Surface Temperature', '24°C (Feels 25°C)', Icons.thermostat_rounded, AppColors.warning),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Relative Humidity', '74% (Optimal Vapor Pressure)', Icons.water_drop_rounded, AppColors.electricCobalt),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Air Quality Index', 'AQI 28 · EXCELLENT', Icons.air_rounded, AppColors.success),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Wind Vectors', '9 km/h NE (Gentle Tail-breeze)', Icons.navigation_rounded, AppColors.textSecondary),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Solar Cadence', 'Sunrise 6:02 AM · Sunset 5:58 PM', Icons.wb_sunny_rounded, AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '💡 Coach Recommendation: Prime atmospheric window for aerobic tempo intervals or continuous endurance volume.',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Telemetry refreshed with live BGC sensor grid! ☀️'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('REFRESH SENSOR TELEMETRY'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      );
    },
  );
}

void _showSystemsDiagnosticsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) {
      return Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blee Systems Diagnostics', style: AppTypography.titleMedium),
            Text('Real-time infrastructure and sensor status', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  _telemetryRow('GPS Telemetry Engine', 'ONLINE (< 3ms write latency)', Icons.gps_fixed_rounded, AppColors.success),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Cloud Database (Supabase)', 'CONNECTED (Realtime active)', Icons.cloud_done_rounded, AppColors.success),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Identity Guard (Firebase)', 'AUTHENTICATED (JWT valid)', Icons.security_rounded, AppColors.success),
                  const Divider(color: AppColors.surfaceBorder, height: AppSpacing.md),
                  _telemetryRow('Media Edge (Cloudflare R2)', 'ONLINE (Receipt CDN ready)', Icons.speed_rounded, AppColors.success),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.network_ping_rounded, size: 18),
                label: const Text('RUN EDGE PING TEST'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ping roundtrip: 38ms · All subsystems operational! 🚀'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      );
    },
  );
}

void _showEventDetailsSheet(BuildContext context, CommunityEvent event, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) {
      return Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: AppTypography.titleMedium),
                      Text('Organized by ${event.organizer}', style: AppTypography.caption),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(event.distance, style: AppTypography.badge.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${event.dateSchedule} · ${event.location}',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(event.routeDescription, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            Text('PACE GROUPS', style: AppTypography.badge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: event.paceGroups
                  .map((g) => Chip(
                        label: Text(g, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceBase,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: event.isRsvp ? AppColors.surfaceBase : AppColors.primary,
                  foregroundColor: event.isRsvp ? AppColors.danger : AppColors.onPrimary,
                  side: event.isRsvp ? const BorderSide(color: AppColors.danger) : null,
                ),
                icon: Icon(event.isRsvp ? Icons.close_rounded : Icons.check_rounded),
                label: Text(event.isRsvp ? 'CANCEL MY RSVP' : 'CONFIRM RSVP FOR EVENT'),
                onPressed: () {
                  ref.read(communityEventsProvider.notifier).toggleRsvp(event.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        !event.isRsvp
                            ? 'RSVP confirmed! See you at ${event.location}! 🐝'
                            : 'RSVP removed for ${event.title}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      );
    },
  );
}

void _showRunReceiptModal(BuildContext context, RunSummaryEntity run) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RunReceiptWidget(summary: run),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded),
                label: const Text('CLOSE RECEIPT'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showEditProfileModal(BuildContext context, ProfileEntity? profile, WidgetRef ref) {
  final nameCtrl = TextEditingController(text: profile?.displayName ?? '');
  int selectedTarget = profile?.weeklyRhythmTarget ?? 3;
  String selectedMotivation = profile?.identityGoal ?? 'Mental clarity & fitness';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Runner Profile & Goals', style: AppTypography.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Runner Display Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('WEEKLY RHYTHM GOAL ($selectedTarget RUNS/WEEK)', style: AppTypography.badge),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [2, 3, 4, 5, 6].map((target) {
                      final isSel = selectedTarget == target;
                      return ChoiceChip(
                        label: Text('$target runs'),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.onPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          setModalState(() => selectedTarget = target);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('MOTIVATION ANCHOR', style: AppTypography.badge),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      'Mental clarity & fitness',
                      'Aerobic endurance',
                      'Sub-4 Marathon chase',
                      'Social community runs',
                    ].map((m) {
                      final isSel = selectedMotivation == m;
                      return ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.onPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          setModalState(() => selectedMotivation = m);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = ref.read(authStateProvider).value;
                        if (user != null) {
                          await ref.read(profileRepositoryProvider).updateProfile(
                                uid: user.id,
                                displayName: nameCtrl.text.trim(),
                                weeklyRhythmTarget: selectedTarget,
                                identityGoal: selectedMotivation,
                              );
                        }
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile & weekly rhythm target updated! 🐝'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('SAVE CHANGES'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _telemetryRow(String label, String value, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(label, style: AppTypography.bodyMedium.copyWith(fontSize: 13))),
      Text(
        value,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

