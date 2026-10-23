import 'package:cloud_firestore/cloud_firestore.dart';

/// US-19: how the renter wants the agent to answer.
enum ContactMethod {
  email('Email'),
  phone('Phone');

  const ContactMethod(this.label);
  final String label;

  static ContactMethod fromName(Object? name) => values.firstWhere(
    (method) => method.name == name,
    orElse: () => ContactMethod.email,
  );
}

/// US-19: a renter's request to an insurance agent. Stored in
/// `insuranceRequests`; the agent reads it in the Firebase console.
class InsuranceRequest {
  const InsuranceRequest({
    required this.id,
    required this.coverageId,
    required this.coverageName,
    required this.agentName,
    required this.contactMethod,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String coverageId;

  /// Copied from the coverage so the request reads on its own.
  final String coverageName;
  final String agentName;
  final ContactMethod contactMethod;
  final String message;

  /// null for a moment after sending, until the server sets the time.
  final DateTime? createdAt;

  factory InsuranceRequest.fromMap(String id, Map<String, dynamic> map) {
    return InsuranceRequest(
      id: id,
      coverageId: map['coverageId'] as String,
      coverageName: map['coverageName'] as String,
      agentName: map['agentName'] as String? ?? '',
      contactMethod: ContactMethod.fromName(map['contactMethod']),
      message: map['message'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
