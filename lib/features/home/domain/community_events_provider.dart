import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityEvent {
  final String id;
  final String title;
  final String dateSchedule;
  final String location;
  final String distance;
  final String routeDescription;
  final List<String> paceGroups;
  final int attendeesCount;
  final bool isRsvp;
  final String organizer;

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.dateSchedule,
    required this.location,
    required this.distance,
    required this.routeDescription,
    required this.paceGroups,
    required this.attendeesCount,
    required this.isRsvp,
    required this.organizer,
  });

  CommunityEvent copyWith({
    bool? isRsvp,
    int? attendeesCount,
  }) {
    return CommunityEvent(
      id: id,
      title: title,
      dateSchedule: dateSchedule,
      location: location,
      distance: distance,
      routeDescription: routeDescription,
      paceGroups: paceGroups,
      attendeesCount: attendeesCount ?? this.attendeesCount,
      isRsvp: isRsvp ?? this.isRsvp,
      organizer: organizer,
    );
  }
}

class CommunityEventsNotifier extends Notifier<List<CommunityEvent>> {
  @override
  List<CommunityEvent> build() {
    return const [
      CommunityEvent(
        id: 'bgc_sunrise_run',
        title: 'BGC Saturday Sunrise Run',
        dateSchedule: 'Saturday, 6:00 AM',
        location: 'Bonifacio High Street Amphitheater',
        distance: '5.0 KM',
        routeDescription:
            'Sunrise loop around Bonifacio High Street, Terra 28th Park, and Bonifacio Greenway loop.',
        paceGroups: ['Pacer (6:30/km)', 'Strider (5:30/km)', 'Elite (4:30/km)'],
        attendeesCount: 42,
        isRsvp: false,
        organizer: 'BGC Run Club',
      ),
      CommunityEvent(
        id: 'high_street_tempo',
        title: 'High Street Tuesday Tempo',
        dateSchedule: 'Tuesday, 6:30 PM',
        location: '9th Avenue Amphitheater',
        distance: '7.5 KM',
        routeDescription:
            'Progressive tempo laps around the 9th Avenue & 7th Avenue circuit.',
        paceGroups: ['Strider (5:15/km)', 'Elite (4:15/km)'],
        attendeesCount: 28,
        isRsvp: false,
        organizer: 'High Street Striders',
      ),
    ];
  }

  void toggleRsvp(String eventId) {
    state = [
      for (final event in state)
        if (event.id == eventId)
          event.copyWith(
            isRsvp: !event.isRsvp,
            attendeesCount:
                event.isRsvp ? event.attendeesCount - 1 : event.attendeesCount + 1,
          )
        else
          event,
    ];
  }
}

final communityEventsProvider =
    NotifierProvider<CommunityEventsNotifier, List<CommunityEvent>>(
  CommunityEventsNotifier.new,
);
