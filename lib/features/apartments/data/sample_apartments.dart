import '../models/apartment.dart';

/// Fake listings used until the app is connected to Firebase.
const sampleApartments = <Apartment>[
  Apartment(
    id: '1',
    availability: ApartmentAvailability.available,
    title: 'Bright apartment near the old town',
    address: 'Rue du Grand-Pont 12',
    city: '1950 Sion',
    listingType: ListingType.rent,
    price: 1850,
    rooms: 3.5,
    surface: 85,
    imageUrl: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=80',
    description:
        'Renovated apartment on the 3rd floor with a large balcony facing '
        'the castles. Close to shops, schools and the train station.',
  ),
  Apartment(
    id: '2',
    availability: ApartmentAvailability.reserved,
    title: 'Studio for students',
    address: 'Route du Rawyl 47',
    city: '1950 Sion',
    listingType: ListingType.rent,
    price: 950,
    rooms: 1.5,
    surface: 32,
    imageUrl: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800&q=80',
    description:
        'Furnished studio a few minutes from the HES-SO campus. '
        'Equipped kitchen, cellar and laundry room in the building.',
  ),
  Apartment(
    id: '3',
    availability: ApartmentAvailability.unavailable,
    title: 'Family apartment with garden',
    address: 'Avenue de la Gare 8',
    city: '3960 Sierre',
    listingType: ListingType.rent,
    price: 2350,
    rooms: 4.5,
    surface: 115,
    imageUrl:
        'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800&q=80',
    description:
        'Ground-floor apartment with a private garden, two bathrooms and '
        'an underground parking space. Quiet residential area.',
  ),
  Apartment(
    id: '4',
    availability: ApartmentAvailability.available,
    title: 'Modern loft in the city centre',
    address: 'Place Centrale 3',
    city: '1920 Martigny',
    listingType: ListingType.rent,
    price: 2100,
    rooms: 2.5,
    surface: 78,
    imageUrl: 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=800&q=80',
    description:
        'Open-plan loft with high ceilings and large windows. '
        'Shops, restaurants and public transport at the door.',
  ),
  Apartment(
    id: '5',
    availability: ApartmentAvailability.available,
    title: 'Cosy apartment with mountain view',
    address: 'Route du Simplon 22',
    city: '1870 Monthey',
    listingType: ListingType.rent,
    price: 1450,
    rooms: 2.5,
    surface: 60,
    imageUrl: 'https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800&q=80',
    description:
        'Bright apartment with a new kitchen and a view of the Dents du '
        'Midi. Elevator and bicycle storage in the building.',
  ),
  Apartment(
    id: '6',
    availability: ApartmentAvailability.available,
    title: 'Quiet apartment close to the station',
    address: 'Bahnhofstrasse 15',
    city: '3900 Brig',
    listingType: ListingType.rent,
    price: 1600,
    rooms: 3.5,
    surface: 82,
    imageUrl: 'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=800&q=80',
    description:
        'Well-kept apartment two minutes from the train station, ideal for '
        'commuters. Balcony, cellar and shared garden.',
  ),
  Apartment(
    id: '7',
    availability: ApartmentAvailability.available,
    title: 'Chalet-style flat for sale',
    address: 'Route de la Combaz 5',
    city: '3963 Crans-Montana',
    listingType: ListingType.sale,
    price: 890000,
    rooms: 3.5,
    surface: 95,
    imageUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800&q=80',
    description:
        'Charming flat with a fireplace and a south-facing terrace, '
        'close to the ski slopes and the golf course.',
  ),
  Apartment(
    id: '8',
    availability: ApartmentAvailability.available,
    title: 'New-build apartment for sale',
    address: 'Chemin des Vignes 9',
    city: '1964 Conthey',
    listingType: ListingType.sale,
    price: 745000,
    rooms: 4.5,
    surface: 120,
    imageUrl: 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=800&q=80',
    description:
        'Apartment in a new Minergie building surrounded by vineyards. '
        'Two parking spaces and a large covered terrace.',
  ),
];
