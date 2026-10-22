import 'package:cloud_firestore/cloud_firestore.dart';

/// US-20: the stored status of a visit. "Past" is not stored: a booked visit
/// is past once its time slot has ended (see [Visit.isUpcoming]).
enum VisitStatus {
  booked('Booked'),
  cancelled('Cancelled');

  const VisitStatus(this.label);
  final String label;

  static VisitStatus fromName(Object? name) => values.firstWhere(
    (status) => status.name == name,
    orElse: () => VisitStatus.booked,
  );
}

/// US-20: a visit of an apartment booked by a renter or buyer in one of the
/// apartment's time slots.
class Visit {
  const Visit({
    required this.id,
    required this.apartmentId,
    required this.apartmentTitle,
    required this.ownerId,
    required this.visitorId,
    required this.visitorEmail,
    required this.slotId,
    required this.slotStart,
    required this.status,
  });

  /// A visit lasts the whole slot: 09:00–11:00 or 14:00–16:00.
  static const slotLength = Duration(hours: 2);

  final String id;
  final String apartmentId;

  /// Stored with the visit so the list does not need to load every
  /// apartment.
  final String apartmentTitle;

  /// The apartment's owner, who is notified of the booking.
  final String ownerId;
  final String visitorId;

  /// Shown to the owner so they know who is coming.
  final String visitorEmail;

  /// ID of the `visitSlots` document that reserves the slot.
  final String slotId;
  final DateTime slotStart;
  final VisitStatus status;

  DateTime get slotEnd => slotStart.add(slotLength);

  bool get isCancelled => status == VisitStatus.cancelled;

  /// Booked and not over yet.
  bool isUpcoming(DateTime now) => !isCancelled && now.isBefore(slotEnd);

  /// It can be cancelled until the visit starts. The Firestore rules enforce
  /// the same limit on the server.
  bool canCancel(DateTime now) => !isCancelled && now.isBefore(slotStart);

  factory Visit.fromMap(String id, Map<String, dynamic> map) {
    return Visit(
      id: id,
      apartmentId: map['apartmentId'] as String,
      apartmentTitle: map['apartmentTitle'] as String,
      ownerId: map['ownerId'] as String,
      visitorId: map['visitorId'] as String,
      visitorEmail: map['visitorEmail'] as String? ?? '',
      slotId: map['slotId'] as String,
      slotStart: (map['slotStart'] as Timestamp).toDate(),
      status: VisitStatus.fromName(map['status']),
    );
  }
}
