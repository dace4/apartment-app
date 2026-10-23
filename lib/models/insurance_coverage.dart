/// US-19: an insurance coverage a renter can take out, and the agent to
/// contact about it. Stored in the Firestore collection `insuranceCoverages`,
/// which is only edited in the Firebase console.
class InsuranceCoverage {
  const InsuranceCoverage({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.covered,
    required this.priceFromChf,
    required this.provider,
    required this.order,
    required this.agentName,
    required this.agentEmail,
    required this.agentPhone,
  });

  final String id;
  final String name;

  /// One line shown in the catalogue.
  final String summary;
  final String description;

  /// What the coverage pays for, one item per line.
  final List<String> covered;

  /// Indicative monthly price in CHF; 0 when unknown.
  final int priceFromChf;
  final String provider;

  /// Position in the catalogue, smallest first.
  final int order;

  // The agent who answers the renter's requests.
  final String agentName;
  final String agentEmail;
  final String agentPhone;

  /// Missing optional fields become empty values, so one incomplete
  /// coverage does not break the whole catalogue.
  factory InsuranceCoverage.fromMap(String id, Map<String, dynamic> map) {
    return InsuranceCoverage(
      id: id,
      name: map['name'] as String,
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String? ?? '',
      covered: map['covered'] is List
          ? List.unmodifiable((map['covered'] as List).whereType<String>())
          : const [],
      priceFromChf: (map['priceFromChf'] as num?)?.toInt() ?? 0,
      provider: map['provider'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      agentName: map['agentName'] as String? ?? '',
      agentEmail: map['agentEmail'] as String? ?? '',
      agentPhone: map['agentPhone'] as String? ?? '',
    );
  }
}
