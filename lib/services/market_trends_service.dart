import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_price.dart';

/// Reads illustrative monthly prices from Firebase; no bundled fallback.
class MarketTrendsService {
  MarketTrendsService({this.firestore});
  final FirebaseFirestore? firestore;

  Future<List<MarketPrice>> getPrices() async {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('marketTrends')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map((doc) => MarketPrice.fromMap(doc.data())).toList();
  }
}
