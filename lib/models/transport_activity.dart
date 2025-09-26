enum TransportType {
  car,
  bus,
  train,
  metro,
  bicycle,
  walking,
  plane,
  boat,
  motorbike,
  scooter,
  rideshare,
  taxi,
  other,
}

class TransportActivity {
  final String id;
  final TransportType type;
  final double distanceKm;
  final int durationMinutes;
  final double co2EmissionKg;
  final DateTime timestamp;
  final String? fromLocation;
  final String? toLocation;
  final String? notes;
  final Map<String, dynamic>? metadata;

  const TransportActivity({
    required this.id,
    required this.type,
    required this.distanceKm,
    required this.durationMinutes,
    required this.co2EmissionKg,
    required this.timestamp,
    this.fromLocation,
    this.toLocation,
    this.notes,
    this.metadata,
  });

  // Copy constructor
  TransportActivity copyWith({
    String? id,
    TransportType? type,
    double? distanceKm,
    int? durationMinutes,
    double? co2EmissionKg,
    DateTime? timestamp,
    String? fromLocation,
    String? toLocation,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return TransportActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      co2EmissionKg: co2EmissionKg ?? this.co2EmissionKg,
      timestamp: timestamp ?? this.timestamp,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'co2EmissionKg': co2EmissionKg,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'notes': notes,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  // Create from Map (database)
  factory TransportActivity.fromMap(Map<String, dynamic> map) {
    return TransportActivity(
      id: map['id'] as String,
      type: TransportType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransportType.other,
      ),
      distanceKm: (map['distanceKm'] as num).toDouble(),
      durationMinutes: map['durationMinutes'] as int,
      co2EmissionKg: (map['co2EmissionKg'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      fromLocation: map['fromLocation'] as String?,
      toLocation: map['toLocation'] as String?,
      notes: map['notes'] as String?,
      metadata: map['metadata'] != null 
          ? _decodeMetadata(map['metadata'] as String) 
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'co2EmissionKg': co2EmissionKg,
      'timestamp': timestamp.toIso8601String(),
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'notes': notes,
      'metadata': metadata,
    };
  }

  // Create from JSON
  factory TransportActivity.fromJson(Map<String, dynamic> json) {
    return TransportActivity(
      id: json['id'] as String,
      type: TransportType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TransportType.other,
      ),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMinutes: json['durationMinutes'] as int,
      co2EmissionKg: (json['co2EmissionKg'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      fromLocation: json['fromLocation'] as String?,
      toLocation: json['toLocation'] as String?,
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // Helper methods for metadata encoding/decoding
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON-like encoding for database storage
    return metadata.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
  }

  static Map<String, dynamic> _decodeMetadata(String encodedMetadata) {
    final map = <String, dynamic>{};
    for (final pair in encodedMetadata.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  // Utility methods
  String get typeDisplayName {
    switch (type) {
      case TransportType.car:
        return 'Car';
      case TransportType.bus:
        return 'Bus';
      case TransportType.train:
        return 'Train';
      case TransportType.metro:
        return 'Metro';
      case TransportType.bicycle:
        return 'Bicycle';
      case TransportType.walking:
        return 'Walking';
      case TransportType.plane:
        return 'Plane';
      case TransportType.boat:
        return 'Boat';
      case TransportType.motorbike:
        return 'Motorbike';
      case TransportType.scooter:
        return 'Scooter';
      case TransportType.rideshare:
        return 'Rideshare';
      case TransportType.taxi:
        return 'Taxi';
      case TransportType.other:
        return 'Other';
    }
  }

  double get averageSpeedKmh {
    if (durationMinutes == 0) return 0.0;
    return (distanceKm / durationMinutes) * 60;
  }

  double get co2PerKm {
    if (distanceKm == 0) return 0.0;
    return co2EmissionKg / distanceKm;
  }

  // Static factory method for creating activities with automatic CO2 calculation
  static TransportActivity create({
    required TransportType type,
    required double distanceKm,
    required int durationMinutes,
    String? fromLocation,
    String? toLocation,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    final co2EmissionKg = _calculateCO2Emission(type, distanceKm);
    return TransportActivity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      co2EmissionKg: co2EmissionKg,
      timestamp: DateTime.now(),
      fromLocation: fromLocation,
      toLocation: toLocation,
      notes: notes,
      metadata: metadata,
    );
  }

  // CO2 emission calculation based on Turkish transport data
  static double _calculateCO2Emission(TransportType type, double distanceKm) {
    // CO2 factors in kg CO₂ per km for Turkish transport system
    const co2Factors = {
      TransportType.car: 0.21, // Average gasoline car
      TransportType.bus: 0.08, // City bus per person
      TransportType.train: 0.06, // TCDD, YHT per person
      TransportType.metro: 0.04, // Istanbul Metro, Ankara Metro per person
      TransportType.bicycle: 0.0, // Zero emissions
      TransportType.walking: 0.0, // Zero emissions
      TransportType.plane: 0.25, // Domestic flights per person
      TransportType.boat: 0.15, // Ferry per person
      TransportType.motorbike: 0.13, // Motorcycle
      TransportType.scooter: 0.05, // Electric scooter (estimated)
      TransportType.rideshare: 0.18, // Shared ride
      TransportType.taxi: 0.21, // Similar to car
      TransportType.other: 0.15, // Default estimate
    };
    
    return (co2Factors[type] ?? 0.15) * distanceKm;
  }

  // Get display name for transport type
  static String getTransportTypeDisplayName(TransportType type, {bool isEnglish = true}) {
    if (isEnglish) {
      switch (type) {
        case TransportType.car:
          return 'Car';
        case TransportType.bus:
          return 'Bus';
        case TransportType.train:
          return 'Train';
        case TransportType.metro:
          return 'Metro/Tram';
        case TransportType.bicycle:
          return 'Bicycle';
        case TransportType.walking:
          return 'Walking';
        case TransportType.plane:
          return 'Plane';
        case TransportType.boat:
          return 'Boat/Ferry';
        case TransportType.motorbike:
          return 'Motorbike';
        case TransportType.scooter:
          return 'Scooter';
        case TransportType.rideshare:
          return 'Rideshare';
        case TransportType.taxi:
          return 'Taxi';
        case TransportType.other:
          return 'Other';
      }
    } else {
      switch (type) {
        case TransportType.car:
          return 'Araba';
        case TransportType.bus:
          return 'Otobüs';
        case TransportType.train:
          return 'Tren';
        case TransportType.metro:
          return 'Metro/Tramvay';
        case TransportType.bicycle:
          return 'Bisiklet';
        case TransportType.walking:
          return 'Yürüyüş';
        case TransportType.plane:
          return 'Uçak';
        case TransportType.boat:
          return 'Vapur/Feribot';
        case TransportType.motorbike:
          return 'Motorsiklet';
        case TransportType.scooter:
          return 'Scooter';
        case TransportType.rideshare:
          return 'Paylaşılan Yolculuk';
        case TransportType.taxi:
          return 'Taksi';
        case TransportType.other:
          return 'Diğer';
      }
    }
  }

  // Get icon for transport type
  static String getTransportTypeIcon(TransportType type) {
    switch (type) {
      case TransportType.car:
        return '🚗';
      case TransportType.bus:
        return '🚌';
      case TransportType.train:
        return '🚄';
      case TransportType.metro:
        return '🚇';
      case TransportType.bicycle:
        return '🚴';
      case TransportType.walking:
        return '🚶';
      case TransportType.plane:
        return '✈️';
      case TransportType.boat:
        return '⛴️';
      case TransportType.motorbike:
        return '🏍️';
      case TransportType.scooter:
        return '🛴';
      case TransportType.rideshare:
        return '🚗';
      case TransportType.taxi:
        return '🚕';
      case TransportType.other:
        return '🚀';
    }
  }

  // Get CO2 factor for transport type (kg CO₂ per km)
  static double getCO2Factor(TransportType type) {
    return _calculateCO2Emission(type, 1.0);
  }

  bool get isEcoFriendly {
    return type == TransportType.walking || 
           type == TransportType.bicycle ||
           co2EmissionKg < 0.1; // Less than 0.1 kg CO2
  }

  @override
  String toString() {
    return 'TransportActivity(id: $id, type: $type, distance: ${distanceKm}km, '
           'duration: ${durationMinutes}min, co2: ${co2EmissionKg}kg)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransportActivity &&
        other.id == id &&
        other.type == type &&
        other.distanceKm == distanceKm &&
        other.durationMinutes == durationMinutes &&
        other.co2EmissionKg == co2EmissionKg &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        type.hashCode ^
        distanceKm.hashCode ^
        durationMinutes.hashCode ^
        co2EmissionKg.hashCode ^
        timestamp.hashCode;
  }
}

// Extension for easier database operations
extension TransportActivityList on List<TransportActivity> {
  double get totalCO2 => fold(0.0, (sum, activity) => sum + activity.co2EmissionKg);
  double get totalDistance => fold(0.0, (sum, activity) => sum + activity.distanceKm);
  int get totalDuration => fold(0, (sum, activity) => sum + activity.durationMinutes);
  
  List<TransportActivity> get ecoFriendlyActivities => where((a) => a.isEcoFriendly).toList();
  List<TransportActivity> get highEmissionActivities => where((a) => !a.isEcoFriendly).toList();
  
  Map<TransportType, List<TransportActivity>> get groupedByType {
    final map = <TransportType, List<TransportActivity>>{};
    for (final activity in this) {
      map[activity.type] ??= [];
      map[activity.type]!.add(activity);
    }
    return map;
  }
  
  List<TransportActivity> sortedByDate([bool descending = true]) {
    final sorted = List<TransportActivity>.from(this);
    sorted.sort((a, b) => descending 
        ? b.timestamp.compareTo(a.timestamp)
        : a.timestamp.compareTo(b.timestamp));
    return sorted;
  }
}