import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClubEntity {
  final String id;
  final String name;
  final String neighborhood;
  final int members;
  final String schedule;
  final String icon;
  final bool isJoined;
  final String description;

  const ClubEntity({
    required this.id,
    required this.name,
    required this.neighborhood,
    required this.members,
    required this.schedule,
    required this.icon,
    required this.isJoined,
    required this.description,
  });

  ClubEntity copyWith({
    bool? isJoined,
    int? members,
  }) {
    return ClubEntity(
      id: id,
      name: name,
      neighborhood: neighborhood,
      members: members ?? this.members,
      schedule: schedule,
      icon: icon,
      isJoined: isJoined ?? this.isJoined,
      description: description,
    );
  }
}

class ClubsNotifier extends Notifier<List<ClubEntity>> {
  @override
  List<ClubEntity> build() {
    return const [
      ClubEntity(
        id: 'bgc_run_club',
        name: 'BGC Run Club',
        neighborhood: 'Bonifacio High Street',
        members: 620,
        schedule: 'Tue & Thu · 6:30 PM',
        icon: '🏃‍♂️',
        isJoined: false,
        description:
            'The flagship community running collective of Bonifacio Global City. Welcoming all paces from beginner to marathoners.',
      ),
      ClubEntity(
        id: 'high_street_striders',
        name: 'High Street Striders',
        neighborhood: '9th Avenue Amphitheater',
        members: 340,
        schedule: 'Sat · 6:00 AM Sunrise Run',
        icon: '🌅',
        isJoined: false,
        description:
            'Dedicated sunrise runners chasing progressive negative splits and morning endorphins across Taguig.',
      ),
      ClubEntity(
        id: 'ayala_tri',
        name: 'Ayala Tri & Marathoners',
        neighborhood: 'Greenway Park Loop',
        members: 195,
        schedule: 'Sun · 5:30 AM Long Run',
        icon: '⚡',
        isJoined: false,
        description:
            'Long run endurance specialists building aerobic base mileage through the Greenway Park and Lawton corridors.',
      ),
    ];
  }

  void toggleJoin(String clubId) {
    state = [
      for (final club in state)
        if (club.id == clubId)
          club.copyWith(
            isJoined: !club.isJoined,
            members: club.isJoined ? club.members - 1 : club.members + 1,
          )
        else
          club,
    ];
  }
}

final clubsProvider = NotifierProvider<ClubsNotifier, List<ClubEntity>>(
  ClubsNotifier.new,
);
