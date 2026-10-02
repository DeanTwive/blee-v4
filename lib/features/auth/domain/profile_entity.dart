import 'package:flutter/foundation.dart';

/// Represents the runner's persisted profile in Supabase `profiles` table.
@immutable
class ProfileEntity {
  final String id; // matches Firebase Auth UID
  final String displayName;
  final String username;
  final String? email;
  final String tier; // 'pacer' | 'strider' | 'elite'
  final String? identityGoal; // motivation anchor from onboarding
  final String? avatarUrl;
  final String city;
  final int rhythmWeeks;
  final int weeklyRhythmTarget; // 2 | 3 | 4
  final bool onboardingComplete;
  final DateTime createdAt;

  const ProfileEntity({
    required this.id,
    required this.displayName,
    required this.username,
    this.email,
    this.tier = 'pacer',
    this.identityGoal,
    this.avatarUrl,
    this.city = 'Taguig (BGC)',
    this.rhythmWeeks = 0,
    this.weeklyRhythmTarget = 3,
    this.onboardingComplete = false,
    required this.createdAt,
  });

  ProfileEntity copyWith({
    String? displayName,
    String? username,
    String? email,
    String? tier,
    String? identityGoal,
    String? avatarUrl,
    String? city,
    int? rhythmWeeks,
    int? weeklyRhythmTarget,
    bool? onboardingComplete,
  }) {
    return ProfileEntity(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email ?? this.email,
      tier: tier ?? this.tier,
      identityGoal: identityGoal ?? this.identityGoal,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      city: city ?? this.city,
      rhythmWeeks: rhythmWeeks ?? this.rhythmWeeks,
      weeklyRhythmTarget: weeklyRhythmTarget ?? this.weeklyRhythmTarget,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
    );
  }

  factory ProfileEntity.fromMap(Map<String, dynamic> map) {
    return ProfileEntity(
      id: map['id'] as String,
      displayName: map['display_name'] as String? ?? 'Runner',
      username: map['username'] as String? ?? '',
      email: map['email'] as String?,
      tier: map['tier'] as String? ?? 'pacer',
      identityGoal: map['identity_goal'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      city: map['city'] as String? ?? 'Taguig (BGC)',
      rhythmWeeks: map['rhythm_weeks'] as int? ?? 0,
      weeklyRhythmTarget: map['weekly_rhythm_target'] as int? ?? 3,
      onboardingComplete: map['onboarding_complete'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'username': username,
      if (email != null) 'email': email,
      'tier': tier,
      if (identityGoal != null) 'identity_goal': identityGoal,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'city': city,
      'rhythm_weeks': rhythmWeeks,
      'weekly_rhythm_target': weeklyRhythmTarget,
      'onboarding_complete': onboardingComplete,
    };
  }

  /// Tier display label.
  String get tierLabel => switch (tier) {
        'strider' => 'STRIDER',
        'elite' => 'ELITE',
        _ => 'PACER',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          username == other.username &&
          tier == other.tier &&
          onboardingComplete == other.onboardingComplete;

  @override
  int get hashCode =>
      id.hashCode ^ displayName.hashCode ^ username.hashCode ^ tier.hashCode;
}
