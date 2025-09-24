class TransportType {
  final String id;
  final String name;
  final String description;
  final double co2FactorPerKm; // kg CO₂ per km
  final String icon;

  TransportType({
    required this.id,
    required this.name,
    required this.description,
    required this.co2FactorPerKm,
    required this.icon,
  });
}

class TransportActivity {
  final String id;
  final TransportType transportType;
  final double distanceKm;
  final double co2Emission;
  final DateTime createdAt;
  final String? notes;

  TransportActivity({
    required this.id,
    required this.transportType,
    required this.distanceKm,
    required this.co2Emission,
    required this.createdAt,
    this.notes,
  });

  factory TransportActivity.create({
    required TransportType transportType,
    required double distanceKm,
    String? notes,
  }) {
    return TransportActivity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transportType: transportType,
      distanceKm: distanceKm,
      co2Emission: transportType.co2FactorPerKm * distanceKm,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }
}

// Türkiye için ulaşım türleri ve CO₂ emisyon faktörleri
class TransportData {
  static final List<TransportType> transportTypes = [
    TransportType(
      id: 'car_gasoline',
      name: 'Benzinli Araba',
      description: 'Orta boy benzinli araç',
      co2FactorPerKm: 0.21, // kg CO₂/km
      icon: '🚗',
    ),
    TransportType(
      id: 'car_diesel',
      name: 'Dizel Araba',
      description: 'Orta boy dizel araç',
      co2FactorPerKm: 0.18, // kg CO₂/km
      icon: '🚙',
    ),
    TransportType(
      id: 'motorcycle',
      name: 'Motorsiklet',
      description: 'Orta boy motorsiklet',
      co2FactorPerKm: 0.13, // kg CO₂/km
      icon: '🏍️',
    ),
    TransportType(
      id: 'bus_city',
      name: 'Şehir Otobüsü',
      description: 'İETT, dolmuş',
      co2FactorPerKm: 0.08, // kg CO₂/km per person
      icon: '🚌',
    ),
    TransportType(
      id: 'metro',
      name: 'Metro/Tramvay',
      description: 'İstanbul Metro, Ankara Metro',
      co2FactorPerKm: 0.04, // kg CO₂/km per person
      icon: '🚇',
    ),
    TransportType(
      id: 'train',
      name: 'Tren',
      description: 'TCDD, YHT',
      co2FactorPerKm: 0.06, // kg CO₂/km per person
      icon: '🚄',
    ),
    TransportType(
      id: 'plane_domestic',
      name: 'İç Hat Uçak',
      description: 'Türkiye içi uçuşlar',
      co2FactorPerKm: 0.25, // kg CO₂/km per person
      icon: '✈️',
    ),
    TransportType(
      id: 'bicycle',
      name: 'Bisiklet',
      description: 'Pedal gücü',
      co2FactorPerKm: 0.0, // kg CO₂/km
      icon: '🚴',
    ),
    TransportType(
      id: 'walking',
      name: 'Yürüyüş',
      description: 'Yaya olarak',
      co2FactorPerKm: 0.0, // kg CO₂/km
      icon: '🚶',
    ),
  ];

  static TransportType? getTransportTypeById(String id) {
    try {
      return transportTypes.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }
}