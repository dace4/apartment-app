/// An illustrative apartment sale price per square metre for one month.
class MarketPrice {
  const MarketPrice({
    required this.city,
    required this.month,
    required this.pricePerSquareMetre,
  });

  final String city;
  final DateTime month;
  final int pricePerSquareMetre;

  String get monthLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  factory MarketPrice.fromMap(Map<String, dynamic> map) => MarketPrice(
    city: map['city'] as String,
    month: DateTime.parse(map['month'] as String),
    pricePerSquareMetre: map['pricePerSquareMetre'] as int,
  );

  Map<String, dynamic> toMap() => {
    'city': city,
    'month': month.toIso8601String(),
    'pricePerSquareMetre': pricePerSquareMetre,
  };
}
