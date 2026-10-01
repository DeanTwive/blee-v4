import 'package:flutter/foundation.dart';

@immutable
class UserEntity {
  final String id;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          isAnonymous == other.isAnonymous;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      isAnonymous.hashCode;
}
