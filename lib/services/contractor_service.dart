import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contractor.dart';

/// Reads the Firebase directory. The app never seeds or writes catalogue data.
class ContractorService {
  ContractorService({this.firestore});
  final FirebaseFirestore? firestore;

  Future<List<Contractor>> getContractors() async {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('contractors')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => Contractor.fromMap(doc.id, doc.data()))
        .toList();
  }
}
