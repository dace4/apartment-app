/// A fictional entry in the offline renovation directory.
class Contractor {
  const Contractor({
    required this.id,
    required this.name,
    required this.city,
    required this.trade,
    required this.description,
    required this.email,
  });

  final String id;
  final String name;
  final String city;
  final String trade;
  final String description;
  final String email;

  factory Contractor.fromMap(String id, Map<String, dynamic> map) => Contractor(
    id: id,
    name: map['name'] as String,
    city: map['city'] as String,
    trade: map['trade'] as String,
    description: map['description'] as String,
    email: map['email'] as String,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'city': city,
    'trade': trade,
    'description': description,
    'email': email,
  };
}
