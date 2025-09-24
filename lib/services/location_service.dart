import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notification_service.dart';
import 'goal_service.dart';

enum TransportMode {
  walking,
  cycling,
  car,
  bus,
  train,
  stillOrUnknown,
}

enum LocationSuggestionType {
  nearbyBikePaths,
  publicTransport,
  walkingRoute,
  ecoFriendlyPlaces,
  chargingStations,
}

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final TransportMode detectedMode;
  final double? speed; // m/s
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.detectedMode = TransportMode.stillOrUnknown,
    this.speed,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'detectedMode': detectedMode.name,
      'speed': speed,
      'address': address,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      timestamp: DateTime.parse(json['timestamp']),
      detectedMode: TransportMode.values.firstWhere(
        (e) => e.name == json['detectedMode'],
        orElse: () => TransportMode.stillOrUnknown,
      ),
      speed: json['speed']?.toDouble(),
      address: json['address'],
    );
  }
}

class LocationSuggestion {
  final String id;
  final String title;
  final String description;
  final LocationSuggestionType type;
  final double latitude;
  final double longitude;
  final String address;
  final double distance; // meters
  final double carbonSaving; // estimated kg CO2 saved
  final IconData icon;
  final Color color;
  final DateTime createdAt;

  LocationSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distance,
    required this.carbonSaving,
    required this.icon,
    required this.color,
    required this.createdAt,
  });
}

class TripSegment {
  final LocationData startLocation;
  final LocationData endLocation;
  final TransportMode mode;
  final double distance; // meters
  final Duration duration;
  final double carbonEmission; // kg CO2
  final DateTime startTime;
  final DateTime endTime;

  TripSegment({
    required this.startLocation,
    required this.endLocation,
    required this.mode,
    required this.distance,
    required this.duration,
    required this.carbonEmission,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'startLocation': startLocation.toJson(),
      'endLocation': endLocation.toJson(),
      'mode': mode.name,
      'distance': distance,
      'duration': duration.inSeconds,
      'carbonEmission': carbonEmission,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory TripSegment.fromJson(Map<String, dynamic> json) {
    return TripSegment(
      startLocation: LocationData.fromJson(json['startLocation']),
      endLocation: LocationData.fromJson(json['endLocation']),
      mode: TransportMode.values.firstWhere((e) => e.name == json['mode']),
      distance: json['distance'],
      duration: Duration(seconds: json['duration']),
      carbonEmission: json['carbonEmission'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
    );
  }
}

class LocationService extends ChangeNotifier {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  
  LocationService._();

  // Services
  final NotificationService _notificationService = NotificationService.instance;
  final GoalService _goalService = GoalService.instance;
  
  // Location tracking
  StreamSubscription<Position>? _positionStream;
  LocationData? _currentLocation;
  List<LocationData> _locationHistory = [];
  List<TripSegment> _trips = [];
  List<LocationSuggestion> _suggestions = [];
  
  // Settings
  bool _locationTrackingEnabled = false;
  bool _autoDetectionEnabled = true;
  bool _suggestionsEnabled = true;
  int _trackingInterval = 30; // seconds
  
  // State
  bool _isTracking = false;
  TransportMode _currentTransportMode = TransportMode.stillOrUnknown;
  LocationData? _tripStartLocation;
  DateTime? _tripStartTime;
  
  // Getters
  bool get locationTrackingEnabled => _locationTrackingEnabled;
  bool get autoDetectionEnabled => _autoDetectionEnabled;
  bool get suggestionsEnabled => _suggestionsEnabled;
  bool get isTracking => _isTracking;
  LocationData? get currentLocation => _currentLocation;
  List<LocationSuggestion> get suggestions => _suggestions;
  List<TripSegment> get trips => _trips;
  TransportMode get currentTransportMode => _currentTransportMode;

  /// Initialize location service
  Future<void> initialize() async {
    await _loadSettings();
    await _loadLocationHistory();
    await _loadTrips();
    
    if (_locationTrackingEnabled) {
      await startTracking();
    }
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Start location tracking
  Future<void> startTracking() async {
    if (_isTracking) return;
    
    final hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      await _notificationService.showSmartSuggestion(
        'Konum izni gerekli! Ayarlardan konum erişimine izin verin.',
      );
      return;
    }

    _isTracking = true;
    
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // minimum 10 meter movement
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: (error) {
        print('Location tracking error: $error');
        _isTracking = false;
        notifyListeners();
      },
    );

    notifyListeners();
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    
    // Finalize current trip if any
    if (_tripStartLocation != null && _tripStartTime != null) {
      await _finalizeTripSegment();
    }
    
    notifyListeners();
  }

  /// Handle location updates
  void _onLocationUpdate(Position position) async {
    LocationData locationData = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
      speed: position.speed,
    );

    // Get address if possible
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: DateTime.now(),
          speed: position.speed,
          address: '${placemark.street}, ${placemark.locality}',
        );
      }
    } catch (e) {
      // Address lookup failed, continue without address
    }

    _currentLocation = locationData;
    _locationHistory.add(locationData);

    // Auto-detect transport mode
    if (_autoDetectionEnabled) {
      await _detectTransportMode(locationData);
    }

    // Generate location-based suggestions
    if (_suggestionsEnabled) {
      await _generateLocationSuggestions(locationData);
    }

    // Save location history periodically
    if (_locationHistory.length % 10 == 0) {
      await _saveLocationHistory();
    }

    notifyListeners();
  }

  /// Detect transport mode based on speed and movement patterns
  Future<void> _detectTransportMode(LocationData location) async {
    if (_locationHistory.length < 2) return;

    final previousLocation = _locationHistory[_locationHistory.length - 2];
    final speed = location.speed ?? 0; // m/s
    final speedKmh = speed * 3.6; // km/h

    TransportMode detectedMode = TransportMode.stillOrUnknown;

    // Simple speed-based detection
    if (speedKmh < 1) {
      detectedMode = TransportMode.stillOrUnknown;
    } else if (speedKmh <= 6) {
      detectedMode = TransportMode.walking;
    } else if (speedKmh <= 25) {
      detectedMode = TransportMode.cycling;
    } else if (speedKmh <= 60) {
      detectedMode = TransportMode.bus; // Could be car too
    } else {
      detectedMode = TransportMode.car;
    }

    // More sophisticated detection could use:
    // - Accelerometer data
    // - GPS track patterns
    // - WiFi/Bluetooth beacons
    // - Time of day patterns

    if (detectedMode != _currentTransportMode) {
      // Transport mode changed
      if (_tripStartLocation != null && _tripStartTime != null) {
        await _finalizeTripSegment();
      }
      
      _currentTransportMode = detectedMode;
      _tripStartLocation = location;
      _tripStartTime = location.timestamp;

      // Notify about mode change
      if (detectedMode != TransportMode.stillOrUnknown) {
        String modeText = _getTransportModeText(detectedMode);
        await _notificationService.showSmartSuggestion(
          '$modeText kullanımı tespit edildi! 🚶‍♂️🚲🚗',
        );
      }
    }
  }

  /// Finalize trip segment when transport mode changes
  Future<void> _finalizeTripSegment() async {
    if (_tripStartLocation == null || _tripStartTime == null || _currentLocation == null) {
      return;
    }

    final distance = Geolocator.distanceBetween(
      _tripStartLocation!.latitude,
      _tripStartLocation!.longitude,
      _currentLocation!.latitude,
      _currentLocation!.longitude,
    );

    final duration = _currentLocation!.timestamp.difference(_tripStartTime!);
    
    // Skip very short trips
    if (distance < 50 || duration.inMinutes < 1) {
      _tripStartLocation = null;
      _tripStartTime = null;
      return;
    }

    // Calculate carbon emission
    final carbonEmission = _calculateCarbonEmission(_currentTransportMode, distance);

    final trip = TripSegment(
      startLocation: _tripStartLocation!,
      endLocation: _currentLocation!,
      mode: _currentTransportMode,
      distance: distance,
      duration: duration,
      carbonEmission: carbonEmission,
      startTime: _tripStartTime!,
      endTime: _currentLocation!.timestamp,
    );

    _trips.add(trip);
    await _saveTrips();

    // Update goals
    GoalCategory category = GoalCategory.transport;
    switch (_currentTransportMode) {
      case TransportMode.car:
      case TransportMode.bus:
      case TransportMode.train:
        category = GoalCategory.transport;
        break;
      default:
        category = GoalCategory.total;
    }
    
    await _goalService.updateAllGoalsProgress(carbonEmission, category);

    // Reset trip tracking
    _tripStartLocation = null;
    _tripStartTime = null;

    notifyListeners();
  }

  /// Calculate carbon emission for transport mode and distance
  double _calculateCarbonEmission(TransportMode mode, double distanceMeters) {
    final distanceKm = distanceMeters / 1000;
    
    // Emission factors (kg CO2 per km)
    double emissionFactor = 0.0;
    switch (mode) {
      case TransportMode.walking:
      case TransportMode.cycling:
        emissionFactor = 0.0; // Zero emissions
        break;
      case TransportMode.car:
        emissionFactor = 0.2; // Average car
        break;
      case TransportMode.bus:
        emissionFactor = 0.08; // Public bus per person
        break;
      case TransportMode.train:
        emissionFactor = 0.04; // Train per person
        break;
      default:
        emissionFactor = 0.0;
    }
    
    return distanceKm * emissionFactor;
  }

  /// Generate location-based suggestions
  Future<void> _generateLocationSuggestions(LocationData location) async {
    _suggestions.clear();

    // Simulate nearby suggestions (in real app, use actual APIs)
    final suggestions = <LocationSuggestion>[];

    // Nearby bike paths
    suggestions.add(LocationSuggestion(
      id: 'bike_path_1',
      title: 'Yakındaki Bisiklet Yolu',
      description: '500m mesafede, 2.3kg CO₂ tasarruf',
      type: LocationSuggestionType.nearbyBikePaths,
      latitude: location.latitude + 0.005,
      longitude: location.longitude + 0.005,
      address: 'Sahil Bisiklet Yolu',
      distance: 500,
      carbonSaving: 2.3,
      icon: Icons.pedal_bike,
      color: Colors.green,
      createdAt: DateTime.now(),
    ));

    // Public transport
    suggestions.add(LocationSuggestion(
      id: 'bus_stop_1',
      title: 'Otobüs Durağı',
      description: '200m mesafede, toplu taşıma kullanın',
      type: LocationSuggestionType.publicTransport,
      latitude: location.latitude - 0.002,
      longitude: location.longitude + 0.003,
      address: 'Merkez Otobüs Durağı',
      distance: 200,
      carbonSaving: 1.8,
      icon: Icons.directions_bus,
      color: Colors.blue,
      createdAt: DateTime.now(),
    ));

    // Walking route
    suggestions.add(LocationSuggestion(
      id: 'walking_path_1',
      title: 'Yürüyüş Rotası',
      description: 'Güvenli yürüyüş parkuru, 1.2kg CO₂ tasarruf',
      type: LocationSuggestionType.walkingRoute,
      latitude: location.latitude + 0.003,
      longitude: location.longitude - 0.004,
      address: 'Park İçi Yürüyüş Yolu',
      distance: 300,
      carbonSaving: 1.2,
      icon: Icons.directions_walk,
      color: Colors.orange,
      createdAt: DateTime.now(),
    ));

    // Electric charging station
    if (_currentTransportMode == TransportMode.car) {
      suggestions.add(LocationSuggestion(
        id: 'charging_station_1',
        title: 'Elektrikli Araç Şarj İstasyonu',
        description: '1.2km mesafede, elektrikli araca geçin',
        type: LocationSuggestionType.chargingStations,
        latitude: location.latitude + 0.01,
        longitude: location.longitude - 0.008,
        address: 'Şarj Noktası - AVM',
        distance: 1200,
        carbonSaving: 4.5,
        icon: Icons.electrical_services,
        color: Colors.purple,
        createdAt: DateTime.now(),
      ));
    }

    _suggestions = suggestions;
    
    // Send notification for the best suggestion
    if (suggestions.isNotEmpty) {
      final bestSuggestion = suggestions.reduce(
        (a, b) => a.carbonSaving > b.carbonSaving ? a : b,
      );
      
      await _notificationService.showSmartSuggestion(
        '${bestSuggestion.title}: ${bestSuggestion.description}',
      );
    }
  }

  /// Update settings
  Future<void> updateSettings({
    bool? locationTrackingEnabled,
    bool? autoDetectionEnabled,
    bool? suggestionsEnabled,
    int? trackingInterval,
  }) async {
    if (locationTrackingEnabled != null) {
      _locationTrackingEnabled = locationTrackingEnabled;
      if (_locationTrackingEnabled && !_isTracking) {
        await startTracking();
      } else if (!_locationTrackingEnabled && _isTracking) {
        await stopTracking();
      }
    }
    
    if (autoDetectionEnabled != null) {
      _autoDetectionEnabled = autoDetectionEnabled;
    }
    
    if (suggestionsEnabled != null) {
      _suggestionsEnabled = suggestionsEnabled;
    }
    
    if (trackingInterval != null) {
      _trackingInterval = trackingInterval;
    }
    
    await _saveSettings();
    notifyListeners();
  }

  /// Get transport mode text in Turkish
  String _getTransportModeText(TransportMode mode) {
    switch (mode) {
      case TransportMode.walking:
        return 'Yürüyüş';
      case TransportMode.cycling:
        return 'Bisiklet';
      case TransportMode.car:
        return 'Araç';
      case TransportMode.bus:
        return 'Otobüs';
      case TransportMode.train:
        return 'Tren';
      default:
        return 'Bilinmiyor';
    }
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locationTrackingEnabled = prefs.getBool('location_tracking_enabled') ?? false;
      _autoDetectionEnabled = prefs.getBool('auto_detection_enabled') ?? true;
      _suggestionsEnabled = prefs.getBool('suggestions_enabled') ?? true;
      _trackingInterval = prefs.getInt('tracking_interval') ?? 30;
    } catch (e) {
      print('Error loading location settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_tracking_enabled', _locationTrackingEnabled);
      await prefs.setBool('auto_detection_enabled', _autoDetectionEnabled);
      await prefs.setBool('suggestions_enabled', _suggestionsEnabled);
      await prefs.setInt('tracking_interval', _trackingInterval);
    } catch (e) {
      print('Error saving location settings: $e');
    }
  }

  /// Load location history from SharedPreferences
  Future<void> _loadLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('location_history');
      
      if (historyJson != null) {
        final historyList = jsonDecode(historyJson) as List;
        _locationHistory = historyList
            .map((json) => LocationData.fromJson(json))
            .toList();
        
        // Keep only last 1000 locations to save storage
        if (_locationHistory.length > 1000) {
          _locationHistory = _locationHistory.sublist(_locationHistory.length - 1000);
        }
      }
    } catch (e) {
      print('Error loading location history: $e');
    }
  }

  /// Save location history to SharedPreferences
  Future<void> _saveLocationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(
        _locationHistory.map((location) => location.toJson()).toList(),
      );
      await prefs.setString('location_history', historyJson);
    } catch (e) {
      print('Error saving location history: $e');
    }
  }

  /// Load trips from SharedPreferences
  Future<void> _loadTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsJson = prefs.getString('trips');
      
      if (tripsJson != null) {
        final tripsList = jsonDecode(tripsJson) as List;
        _trips = tripsList.map((json) => TripSegment.fromJson(json)).toList();
        
        // Keep only last 100 trips
        if (_trips.length > 100) {
          _trips = _trips.sublist(_trips.length - 100);
        }
      }
    } catch (e) {
      print('Error loading trips: $e');
    }
  }

  /// Save trips to SharedPreferences
  Future<void> _saveTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripsJson = jsonEncode(
        _trips.map((trip) => trip.toJson()).toList(),
      );
      await prefs.setString('trips', tripsJson);
    } catch (e) {
      print('Error saving trips: $e');
    }
  }

  /// Get daily trip statistics
  Map<String, dynamic> getDailyTripStats() {
    final today = DateTime.now();
    final todayTrips = _trips.where((trip) {
      return trip.startTime.year == today.year &&
             trip.startTime.month == today.month &&
             trip.startTime.day == today.day;
    }).toList();

    double totalDistance = 0;
    double totalCarbon = 0;
    Duration totalDuration = Duration.zero;
    Map<TransportMode, int> modeCount = {};

    for (final trip in todayTrips) {
      totalDistance += trip.distance;
      totalCarbon += trip.carbonEmission;
      totalDuration += trip.duration;
      modeCount[trip.mode] = (modeCount[trip.mode] ?? 0) + 1;
    }

    return {
      'totalTrips': todayTrips.length,
      'totalDistance': totalDistance / 1000, // km
      'totalCarbon': totalCarbon,
      'totalDuration': totalDuration,
      'modeBreakdown': modeCount,
    };
  }

  /// Clear location data
  Future<void> clearLocationData() async {
    _locationHistory.clear();
    _trips.clear();
    _suggestions.clear();
    _currentLocation = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('location_history');
    await prefs.remove('trips');
    
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}