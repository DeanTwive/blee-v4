import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../../auth/domain/profile_entity.dart';
import '../../auth/presentation/auth_providers.dart';

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

class _DashboardTab extends StatelessWidget {
  final String displayName;
  final String tierLabel;
  final Color tierColor;
  final ProfileEntity? profile;

  const _DashboardTab({
    required this.displayName,
    required this.tierLabel,
    required this.tierColor,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        // Runner Identity Card
        Container(
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
                      '0 of ${profile!.weeklyRhythmTarget} runs this week',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Running Conditions Glance Chip
        Container(
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
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Start Run CTA Card
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
              const Text('0.00', style: AppTypography.metricLarge),
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

        // Community Event Card
        Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: AppSpacing.xs),
              const Text('BGC Saturday Sunrise Run',
                  style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Saturday, 6:00 AM · Bonifacio High Street Amphitheater',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('42 Runners RSVP\'d', style: AppTypography.caption),
                  BouncyPressable(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('RSVP confirmed for BGC Saturday Sunrise Run! 🐝'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 36),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('RSVP confirmed for BGC Saturday Sunrise Run! 🐝'),
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

        const SizedBox(height: AppSpacing.lg),

        // Systems Status
        Container(
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
                      'Firebase · Supabase · GPS Ready',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Track Launchpad ────────────────────────────────────────────────────

class _TrackTab extends StatelessWidget {
  final String tierLabel;
  final Color tierColor;

  const _TrackTab({
    required this.tierLabel,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
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
              _preferenceRow(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Auto-Pause',
                value: 'Enabled (< 0.8 m/s)',
                valueColor: AppColors.primary,
              ),
              const Divider(color: AppColors.surfaceBorder, height: AppSpacing.lg),
              _preferenceRow(
                icon: Icons.shield_rounded,
                title: 'Live Beacon Safety',
                value: 'Ready for Sprint 2',
                valueColor: AppColors.textSecondary,
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

class _ClubsTab extends StatelessWidget {
  const _ClubsTab();

  @override
  Widget build(BuildContext context) {
    final clubs = [
      (
        name: 'BGC Run Club',
        neighborhood: 'Bonifacio High Street',
        members: 620,
        schedule: 'Tue & Thu · 6:30 PM',
        icon: '🏃‍♂️',
      ),
      (
        name: 'High Street Striders',
        neighborhood: '9th Avenue Amphitheater',
        members: 340,
        schedule: 'Sat · 6:00 AM Sunrise Run',
        icon: '🌅',
      ),
      (
        name: 'Ayala Tri & Marathoners',
        neighborhood: 'Greenway Park Loop',
        members: 195,
        schedule: 'Sun · 5:30 AM Long Run',
        icon: '⚡',
      ),
    ];

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
              border: Border.all(color: AppColors.surfaceBorder),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Joined ${club.name}! 🐝'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(72, 32),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        ),
                        onPressed: () {
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

        const SizedBox(height: AppSpacing.xl),

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
