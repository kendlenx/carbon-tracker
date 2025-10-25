import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'language_service.dart';
import 'database_service.dart';
import '../models/transport_activity.dart';

/// CarPlay integration service for Carbon Tracker
class CarPlayService {
  static CarPlayService? _instance;
  static CarPlayService get instance => _instance ??= CarPlayService._();
  
  CarPlayService._();

  static const MethodChannel _channel = MethodChannel('carbon_tracker/carplay');
  static const EventChannel _eventChannel = EventChannel('carbon_tracker/carplay_events');
  
  final LanguageService _languageService = LanguageService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;
  
  // Trip tracking state
  bool _isCarPlayConnected = false;
  bool _isTripActive = false;
  DateTime? _tripStartTime;
  Position? _tripStartLocation;
  double _tripDistance = 0.0;
  List<Position> _tripPositions = [];
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  
  // Current trip data
  final Map<String, dynamic> _currentTripData = {};
  Timer? _carPlayUpdateTimer;

  /// Stream of CarPlay events
  Stream<Map<String, dynamic>>? _eventsStream;
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;

  /// Initialize CarPlay service
  Future<void> initialize() async {
    try {
      // Setup method call handler for native -> Flutter communication
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Setup event stream for CarPlay events
      _eventsStream = _eventChannel.receiveBroadcastStream()
          .map<Map<String, dynamic>>((dynamic event) => 
              Map<String, dynamic>.from(event));
      
      _eventsSubscription = _eventsStream?.listen(_handleCarPlayEvent);
      
      // Initialize CarPlay templates on native side
      await _setupCarPlayTemplates();
      
      debugPrint('CarPlay service initialized');
    } catch (e) {
      debugPrint('Failed to initialize CarPlay service: $e');
    }
  }

  /// Setup CarPlay templates on native side
  Future<void> _setupCarPlayTemplates() async {
    try {
      final isEnglish = _languageService.isEnglish;
      
      await _channel.invokeMethod('setupTemplates', {
        'rootTemplate': {
          'type': 'tabBar',
          'templates': [
            {
              'type': 'dashboard',
              'title': isEnglish ? 'Dashboard' : 'Kontrol Paneli',
              'systemIcon': 'gauge',
            },
            {
              'type': 'trip',
              'title': isEnglish ? 'Trip' : 'Seyahat',
              'systemIcon': 'car.fill',
            },
            {
              'type': 'stats',
              'title': isEnglish ? 'Stats' : 'İstatistikler',  
              'systemIcon': 'chart.bar.fill',
            }
          ]
        }
      });
    } catch (e) {
      debugPrint('Failed to setup CarPlay templates: $e');
    }
  }

  /// Handle method calls from native CarPlay
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'carPlayDidConnect':
        await _onCarPlayConnected();
        break;
      case 'carPlayDidDisconnect':
        await _onCarPlayDisconnected();
        break;
      case 'startTrip':
        await _startTrip();
        break;
      case 'endTrip':
        await _endTrip();
        break;
      case 'getDashboardData':
        return await _getDashboardData();
      case 'getTripData':
        return await _getTripData();
      case 'getStatsData':
        return await _getStatsData();
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  /// Handle CarPlay events from event stream
  void _handleCarPlayEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    
    switch (eventType) {
      case 'templateDidAppear':
        _onTemplateDidAppear(event['templateId'] as String?);
        break;
      case 'templateDidDisappear':
        _onTemplateDidDisappear(event['templateId'] as String?);
        break;
      case 'buttonPressed':
        _onButtonPressed(event['buttonId'] as String?);
        break;
      case 'listItemSelected':
        _onListItemSelected(event['itemId'] as String?);
        break;
    }
  }

  /// CarPlay connection established
  Future<void> _onCarPlayConnected() async {
    _isCarPlayConnected = true;
    debugPrint('CarPlay connected');
    
    // Start automatic location monitoring
    await _startLocationMonitoring();
    
    // Setup periodic updates for CarPlay UI
    _carPlayUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateCarPlayUI(),
    );
    
      // Update CarPlay with initial data
      await _updateCarPlayUI();
      
      // Notify listeners
      notifyListeners();
  }

  /// CarPlay disconnected
  Future<void> _onCarPlayDisconnected() async {
    _isCarPlayConnected = false;
    debugPrint('CarPlay disconnected');
    
    // End trip if active
    if (_isTripActive) {
      await _endTrip();
    }
    
    // Stop location monitoring
    await _stopLocationMonitoring();
    
      // Cancel update timer
      _carPlayUpdateTimer?.cancel();
      _carPlayUpdateTimer = null;
      
      // Notify listeners
      notifyListeners();
  }

  /// Start automatic trip tracking
  Future<void> _startTrip() async {
    if (_isTripActive) {
      debugPrint('Trip already active');
      return;
    }

    try {
      // Get current location
      // ignore: deprecated_member_use
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _isTripActive = true;
      _tripStartTime = DateTime.now();
      _tripStartLocation = position;
      _tripDistance = 0.0;
      _tripPositions = [position];
      
      debugPrint('Trip started at $_tripStartTime');
      
      // Start continuous location tracking
      await _startContinuousLocationTracking();
      
      // Update CarPlay UI
      await _updateCarPlayUI();
      
      // Notify listeners
      notifyListeners();
      
    } catch (e) {
      debugPrint('Failed to start trip: $e');
    }
  }

  /// Public method to start trip (for external calls)
  Future<void> startTrip() async {
    await _startTrip();
  }
  
  /// Public method to end trip (for external calls)
  Future<void> endTrip() async {
    await _endTrip();
  }
  
  /// End current trip and save to database
  Future<void> _endTrip() async {
    if (!_isTripActive) {
      debugPrint('No active trip to end');
      return;
    }

    try {
      final endTime = DateTime.now();
      // ignore: deprecated_member_use
      final endPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Calculate trip statistics
      final duration = endTime.difference(_tripStartTime!);
      final durationMinutes = duration.inMinutes;
      
      // Add final position
      _tripPositions.add(endPosition);
      
      // Calculate total distance if we have multiple positions
      if (_tripPositions.length > 1) {
        _tripDistance = 0.0;
        for (int i = 1; i < _tripPositions.length; i++) {
          _tripDistance += Geolocator.distanceBetween(
            _tripPositions[i-1].latitude,
            _tripPositions[i-1].longitude,
            _tripPositions[i].latitude,
            _tripPositions[i].longitude,
          );
        }
        _tripDistance /= 1000; // Convert to kilometers
      }
      
      // Create transport activity
      final activity = TransportActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: TransportType.car, // Default to car for CarPlay
        distanceKm: _tripDistance,
        durationMinutes: durationMinutes,
        co2EmissionKg: _calculateCO2Emission(_tripDistance),
        timestamp: _tripStartTime!,
        fromLocation: 'GPS: ${_tripStartLocation!.latitude.toStringAsFixed(4)}, ${_tripStartLocation!.longitude.toStringAsFixed(4)}',
        toLocation: 'GPS: ${endPosition.latitude.toStringAsFixed(4)}, ${endPosition.longitude.toStringAsFixed(4)}',
        notes: 'Automatic CarPlay trip',
      );

      // Save to database
      await _databaseService.addActivity(activity);
      
      debugPrint('Trip ended: ${_tripDistance.toStringAsFixed(2)} km, $durationMinutes minutes');
      
      // Reset trip state
      _isTripActive = false;
      _tripStartTime = null;
      _tripStartLocation = null;
      _tripDistance = 0.0;
      _tripPositions.clear();
      
      // Stop continuous location tracking
      await _stopContinuousLocationTracking();
      
      // Update CarPlay UI
      await _updateCarPlayUI();
      
      // Notify listeners
      notifyListeners();
      
    } catch (e) {
      debugPrint('Failed to end trip: $e');
    }
  }

  /// Start location monitoring for automatic trip detection
  Future<void> _startLocationMonitoring() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        debugPrint('Location permissions denied');
        return;
      }

      // Start monitoring significant location changes
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(_onLocationUpdate);
      
    } catch (e) {
      debugPrint('Failed to start location monitoring: $e');
    }
  }

  /// Stop location monitoring
  Future<void> _stopLocationMonitoring() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }

  /// Start continuous location tracking during trip
  Future<void> _startContinuousLocationTracking() async {
    if (_positionStream != null) {
      // Already tracking
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters during trip
      ),
    ).listen(_onTripLocationUpdate);
  }

  /// Stop continuous location tracking
  Future<void> _stopContinuousLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    
    // Restart basic location monitoring
    await _startLocationMonitoring();
  }

  /// Handle location updates for trip detection
  void _onLocationUpdate(Position position) {
    // Auto-start trip detection logic could go here
    // For now, we rely on manual start/end
  }

  /// Handle location updates during active trip
  void _onTripLocationUpdate(Position position) {
    if (!_isTripActive || _tripPositions.isEmpty) {
      return;
    }

    // Add position to trip
    final lastPosition = _tripPositions.last;
    final distance = Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      position.latitude,
      position.longitude,
    );

    // Only add if moved significantly (> 5 meters)
    if (distance > 5) {
      _tripPositions.add(position);
      
      // Update total distance
      _tripDistance += distance / 1000; // Convert to kilometers
    }
  }

  /// Calculate CO2 emission for distance
  double _calculateCO2Emission(double distanceKm) {
    // Average car emission: 0.2 kg CO2 per km
    return distanceKm * 0.2;
  }
  
  /// Get trip start time
  DateTime? get tripStartTime => _tripStartTime;
  
  // Simple listener system
  final List<VoidCallback> _listeners = [];
  
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }
  
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
  
  void notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in listener: $e');
      }
    }
  }
  
  /// Get connection status for testing
  Future<Map<String, dynamic>> getConnectionStatus() async {
    return {
      'connected': _isCarPlayConnected,
      'tripActive': _isTripActive,
      'distance': _tripDistance,
    };
  }

  /// Get dashboard data for CarPlay
  Future<Map<String, dynamic>> _getDashboardData() async {
    final isEnglish = _languageService.isEnglish;
    
    // Get today's activities
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final activities = await _databaseService.getActivitiesInDateRange(
      startOfDay, 
      today.add(const Duration(days: 1)),
    );

    final todayCO2 = activities.fold<double>(
      0.0, 
      (sum, activity) => sum + activity.co2EmissionKg,
    );

    return {
      'todayCO2': todayCO2.toStringAsFixed(1),
      'todayCO2Unit': 'kg CO₂',
      'tripStatus': _isTripActive 
          ? (isEnglish ? 'Trip Active' : 'Seyahat Aktif')
          : (isEnglish ? 'No Active Trip' : 'Aktif Seyahat Yok'),
      'isConnected': _isCarPlayConnected,
      'totalActivities': activities.length,
    };
  }

  /// Get current trip data for CarPlay
  Future<Map<String, dynamic>> _getTripData() async {
    final isEnglish = _languageService.isEnglish;
    
    if (!_isTripActive) {
      return {
        'isActive': false,
        'message': isEnglish ? 'No active trip' : 'Aktif seyahat yok',
      };
    }

    final now = DateTime.now();
    final duration = now.difference(_tripStartTime!);
    final estimatedCO2 = _calculateCO2Emission(_tripDistance);

    return {
      'isActive': true,
      'distance': _tripDistance.toStringAsFixed(1),
      'distanceUnit': 'km',
      'duration': duration.inMinutes,
      'durationUnit': isEnglish ? 'minutes' : 'dakika',
      'co2': estimatedCO2.toStringAsFixed(2),
      'co2Unit': 'kg CO₂',
      'startTime': _tripStartTime!.toIso8601String(),
    };
  }

  /// Get stats data for CarPlay
  Future<Map<String, dynamic>> _getStatsData() async {
    final isEnglish = _languageService.isEnglish;
    
    // Get this week's activities
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    final activities = await _databaseService.getActivitiesInDateRange(
      startOfWeekDay,
      now.add(const Duration(days: 1)),
    );

    final weekCO2 = activities.fold<double>(
      0.0,
      (sum, activity) => sum + activity.co2EmissionKg,
    );

    final totalDistance = activities.fold<double>(
      0.0,
      (sum, activity) => sum + activity.distanceKm,
    );

    return {
      'weekCO2': weekCO2.toStringAsFixed(1),
      'weekCO2Unit': 'kg CO₂',
      'totalDistance': totalDistance.toStringAsFixed(1),
      'totalDistanceUnit': 'km',
      'totalTrips': activities.length,
      'averageCO2': activities.isNotEmpty 
          ? (weekCO2 / activities.length).toStringAsFixed(2)
          : '0.0',
    };
  }

  /// Update CarPlay UI with current data
  Future<void> _updateCarPlayUI() async {
    if (!_isCarPlayConnected) return;

    try {
      final dashboardData = await _getDashboardData();
      final tripData = await _getTripData();
      final statsData = await _getStatsData();

      await _channel.invokeMethod('updateTemplates', {
        'dashboard': dashboardData,
        'trip': tripData,
        'stats': statsData,
      });
    } catch (e) {
      debugPrint('Failed to update CarPlay UI: $e');
    }
  }

  /// Handle template appearance
  void _onTemplateDidAppear(String? templateId) {
    debugPrint('Template appeared: $templateId');
    // Trigger data refresh for the active template
    _updateCarPlayUI();
  }

  /// Handle template disappearance
  void _onTemplateDidDisappear(String? templateId) {
    debugPrint('Template disappeared: $templateId');
  }

  /// Handle button presses
  void _onButtonPressed(String? buttonId) {
    debugPrint('Button pressed: $buttonId');
    
    switch (buttonId) {
      case 'startTrip':
        _startTrip();
        break;
      case 'endTrip':
        _endTrip();
        break;
      case 'refresh':
        _updateCarPlayUI();
        break;
    }
  }

  /// Handle list item selection
  void _onListItemSelected(String? itemId) {
    debugPrint('List item selected: $itemId');
  }

  /// Check if CarPlay is currently connected
  bool get isCarPlayConnected => _isCarPlayConnected;

  /// Check if trip is currently active
  bool get isTripActive => _isTripActive;

  /// Get current trip distance
  double get currentTripDistance => _tripDistance;

  /// Get current trip duration in minutes
  int get currentTripDuration {
    if (!_isTripActive || _tripStartTime == null) return 0;
    return DateTime.now().difference(_tripStartTime!).inMinutes;
  }

  /// Dispose resources
  void dispose() {
    _carPlayUpdateTimer?.cancel();
    _locationTimer?.cancel();
    _positionStream?.cancel();
    _eventsSubscription?.cancel();
  }
}