import 'package:cloud_firestore/cloud_firestore.dart';

/// An app maintenance window scheduled by an admin. During it, only admins
/// can use the app.
class AppMaintenance {
  const AppMaintenance({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool isActive(DateTime now) => !now.isBefore(start) && now.isBefore(end);
  bool isUpcoming(DateTime now) => now.isBefore(start);

  factory AppMaintenance.fromMap(Map<String, dynamic> map) {
    return AppMaintenance(
      start: (map['start'] as Timestamp).toDate(),
      end: (map['end'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'start': Timestamp.fromDate(start), 'end': Timestamp.fromDate(end)};
  }
}
