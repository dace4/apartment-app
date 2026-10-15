import 'package:cloud_firestore/cloud_firestore.dart';

/// US 16: where an application is in the process, with its user-facing label.
enum ApplicationStatus {
  submitted('Submitted'),
  underReview('Under review'),
  accepted('Accepted'),
  rejected('Rejected'),
  withdrawn('Withdrawn');

  const ApplicationStatus(this.label);
  final String label;

  /// Unknown values are shown as submitted instead of crashing the list.
  static ApplicationStatus fromName(Object? name) => values.firstWhere(
    (status) => status.name == name,
    orElse: () => ApplicationStatus.submitted,
  );

  /// Only applications still waiting for a decision can be edited or
  /// withdrawn.
  bool get isOpen =>
      this == ApplicationStatus.submitted ||
      this == ApplicationStatus.underReview;
}

/// The fields the applicant fills in, both when applying and when editing.
class ApplicationDetails {
  const ApplicationDetails({
    required this.fullName,
    required this.phone,
    required this.moveInDate,
    required this.occupants,
    this.message = '',
  });

  final String fullName;
  final String phone;

  /// Date only; the time of day is ignored.
  final DateTime moveInDate;
  final int occupants;
  final String message;

  factory ApplicationDetails.fromMap(Map<String, dynamic> map) {
    return ApplicationDetails(
      fullName: map['fullName'] as String,
      phone: map['phone'] as String,
      moveInDate: (map['moveInDate'] as Timestamp).toDate(),
      occupants: map['occupants'] as int,
      message: map['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      // Date only: the time of day is not stored.
      'moveInDate': Timestamp.fromDate(
        DateTime(moveInDate.year, moveInDate.month, moveInDate.day),
      ),
      'occupants': occupants,
      'message': message.trim(),
    };
  }
}

/// A submitted application for one apartment.
class RentalApplication {
  const RentalApplication({
    required this.id,
    required this.userId,
    required this.apartmentId,
    required this.apartmentTitle,
    required this.details,
    required this.status,
    required this.submittedAt,
    this.documentIds = const [],
  });

  /// US 16 acceptance criterion: edit or withdraw within 5 days.
  static const changeWindow = Duration(days: 5);

  final String id;
  final String userId;
  final String apartmentId;

  /// Stored with the application so the list does not need to load every
  /// apartment.
  final String apartmentTitle;
  final ApplicationDetails details;
  final ApplicationStatus status;
  final DateTime submittedAt;

  /// US-15: reusable file IDs selected at submission; empty for older records.
  final List<String> documentIds;

  DateTime get changeDeadline => submittedAt.add(changeWindow);

  /// Whether the applicant may still edit or withdraw it. The Firestore
  /// rules enforce the same limit on the server.
  bool canChange(DateTime now) => status.isOpen && now.isBefore(changeDeadline);

  factory RentalApplication.fromMap(String id, Map<String, dynamic> map) {
    return RentalApplication(
      id: id,
      userId: map['userId'] as String,
      apartmentId: map['apartmentId'] as String,
      apartmentTitle: map['apartmentTitle'] as String,
      details: ApplicationDetails.fromMap(map),
      status: ApplicationStatus.fromName(map['status']),
      documentIds: List<String>.unmodifiable(
        (map['documentIds'] as List? ?? []).cast<String>(),
      ),
      // null for a moment after submitting, until the server sets the time.
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
