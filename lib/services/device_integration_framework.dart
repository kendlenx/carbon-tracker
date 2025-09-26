import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_service.dart';

/// Device types supported by the integration framework
enum DeviceType {
  smartVehicle,
  fitnessTracker,
  smartThermostat,
  smartPlug,
  energyMonitor,
  publicTransport,
  ridesharing,
  navigationApp,
}

/// Device connection status
enum DeviceConnectionStatus {
  disconnected,
  connecting,
  connected,
  syncing,
  error,
  unauthorized,
}

/// Device data types that can be collected
enum DeviceDataType {
  fuelConsumption,
  mileage,
  electricityUsage,
  gasUsage,
  stepCount,
  cyclingDistance,
  tripData,
  locationData,
  energyConsumption,
}

/// Privacy levels for data collection
enum PrivacyLevel {
  minimal,     // Only basic required data
  balanced,    // Standard data collection
  comprehensive, // Full data collection for better insights
}

/// Base class for all device integrations
abstract class DeviceIntegration {
  final DeviceType deviceType;
  final String deviceId;
  final String deviceName;
  final String manufacturerName;
  
  DeviceConnectionStatus _connectionStatus = DeviceConnectionStatus.disconnected;
  Map<String, dynamic> _configuration = {};
  DateTime? _lastSyncTime;
  
  DeviceIntegration({
    required this.deviceType,
    required this.deviceId,
    required this.deviceName,
    required this.manufacturerName,
  });

  /// Current connection status
  DeviceConnectionStatus get connectionStatus => _connectionStatus;
  
  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;
  
  /// Device configuration
  Map<String, dynamic> get configuration => _configuration;

  /// Initialize and authenticate with the device/service
  Future<bool> initialize(Map<String, dynamic> config);
  
  /// Connect to the device/service
  Future<bool> connect();
  
  /// Disconnect from the device/service
  Future<void> disconnect();
  
  /// Sync data from the device
  Future<List<DeviceDataPoint>> syncData({DateTime? since});
  
  /// Check if device is available/reachable
  Future<bool> isAvailable();
  
  /// Get device health/status information
  Future<DeviceHealthInfo> getHealthInfo();
  
  /// Update device configuration
  Future<void> updateConfiguration(Map<String, dynamic> newConfig);
  
  /// Get supported data types for this device
  List<DeviceDataType> getSupportedDataTypes();
  
  /// Set connection status (protected method for subclasses)
  @protected
  void setConnectionStatus(DeviceConnectionStatus status) {
    _connectionStatus = status;
  }
  
  /// Set last sync time (protected method for subclasses)
  @protected
  void setLastSyncTime(DateTime time) {
    _lastSyncTime = time;
  }
  
  /// Update configuration (protected method for subclasses)
  @protected
  void updateConfig(Map<String, dynamic> config) {
    _configuration = config;
  }
}

/// Data point collected from a device
class DeviceDataPoint {
  final DeviceType sourceDevice;
  final String deviceId;
  final DeviceDataType dataType;
  final dynamic value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final double? estimatedCO2;

  DeviceDataPoint({
    required this.sourceDevice,
    required this.deviceId,
    required this.dataType,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata = const {},
    this.estimatedCO2,
  });

  Map<String, dynamic> toJson() {
    return {
      'sourceDevice': sourceDevice.toString(),
      'deviceId': deviceId,
      'dataType': dataType.toString(),
      'value': value,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'estimatedCO2': estimatedCO2,
    };
  }

  factory DeviceDataPoint.fromJson(Map<String, dynamic> json) {
    return DeviceDataPoint(
      sourceDevice: DeviceType.values.firstWhere(
        (e) => e.toString() == json['sourceDevice'],
      ),
      deviceId: json['deviceId'],
      dataType: DeviceDataType.values.firstWhere(
        (e) => e.toString() == json['dataType'],
      ),
      value: json['value'],
      unit: json['unit'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      estimatedCO2: json['estimatedCO2']?.toDouble(),
    );
  }
}

/// Device health and status information
class DeviceHealthInfo {
  final bool isHealthy;
  final double batteryLevel;
  final DateTime lastActivity;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, dynamic> diagnostics;

  DeviceHealthInfo({
    required this.isHealthy,
    this.batteryLevel = -1.0, // -1 means no battery info
    required this.lastActivity,
    this.warnings = const [],
    this.errors = const [],
    this.diagnostics = const {},
  });
}

/// Device integration registry and factory
class DeviceIntegrationRegistry {
  static final Map<DeviceType, Function> _integrationFactories = {};
  
  /// Register a device integration factory
  static void registerIntegration(
    DeviceType deviceType, 
    Function factory,
  ) {
    _integrationFactories[deviceType] = factory;
  }
  
  /// Create a device integration instance
  static DeviceIntegration? createIntegration(
    DeviceType deviceType,
    Map<String, dynamic> config,
  ) {
    final factory = _integrationFactories[deviceType];
    return factory?.call(config);
  }
  
  /// Get available device types
  static List<DeviceType> getAvailableDeviceTypes() {
    return _integrationFactories.keys.toList();
  }
}

/// Main device integration service
class DeviceIntegrationService {
  static DeviceIntegrationService? _instance;
  static DeviceIntegrationService get instance => 
      _instance ??= DeviceIntegrationService._();
  
  DeviceIntegrationService._();

  final Map<String, DeviceIntegration> _connectedDevices = {};
  final StreamController<DeviceEvent> _eventController = 
      StreamController<DeviceEvent>.broadcast();
  final LanguageService _languageService = LanguageService.instance;
  
  Timer? _syncTimer;
  PrivacyLevel _privacyLevel = PrivacyLevel.balanced;

  /// Stream of device events
  Stream<DeviceEvent> get events => _eventController.stream;
  
  /// Currently connected devices
  List<DeviceIntegration> get connectedDevices => 
      _connectedDevices.values.toList();
  
  /// Current privacy level
  PrivacyLevel get privacyLevel => _privacyLevel;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadDeviceConfigurations();
    await _loadPrivacySettings();
    _startPeriodicSync();
  }

  /// Set privacy level for data collection
  Future<void> setPrivacyLevel(PrivacyLevel level) async {
    _privacyLevel = level;
    await _savePrivacySettings();
    
    // Notify all devices about privacy level change
    for (final device in _connectedDevices.values) {
      await device.updateConfiguration({
        ...device.configuration,
        'privacyLevel': level.toString(),
      });
    }
    
    _eventController.add(DeviceEvent(
      type: DeviceEventType.privacySettingsChanged,
      deviceId: 'system',
      data: {'privacyLevel': level.toString()},
    ));
  }

  /// Add a new device integration
  Future<bool> addDevice(
    DeviceType deviceType,
    Map<String, dynamic> config,
  ) async {
    try {
      final integration = DeviceIntegrationRegistry.createIntegration(
        deviceType, 
        config,
      );
      
      if (integration == null) {
        throw Exception('Unknown device type: $deviceType');
      }

      // Initialize the device
      final initialized = await integration.initialize(config);
      if (!initialized) {
        throw Exception('Failed to initialize device');
      }

      // Attempt connection
      final connected = await integration.connect();
      if (!connected) {
        throw Exception('Failed to connect to device');
      }

      _connectedDevices[integration.deviceId] = integration;
      await _saveDeviceConfiguration(integration);

      _eventController.add(DeviceEvent(
        type: DeviceEventType.deviceConnected,
        deviceId: integration.deviceId,
        data: {
          'deviceType': deviceType.toString(),
          'deviceName': integration.deviceName,
        },
      ));

      return true;
    } catch (e) {
      _eventController.add(DeviceEvent(
        type: DeviceEventType.deviceError,
        deviceId: config['deviceId'] ?? 'unknown',
        data: {'error': e.toString()},
      ));
      return false;
    }
  }

  /// Remove a device integration
  Future<void> removeDevice(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device != null) {
      await device.disconnect();
      _connectedDevices.remove(deviceId);
      await _removeDeviceConfiguration(deviceId);

      _eventController.add(DeviceEvent(
        type: DeviceEventType.deviceDisconnected,
        deviceId: deviceId,
        data: {'deviceName': device.deviceName},
      ));
    }
  }

  /// Get device by ID
  DeviceIntegration? getDevice(String deviceId) {
    return _connectedDevices[deviceId];
  }

  /// Get devices by type
  List<DeviceIntegration> getDevicesByType(DeviceType deviceType) {
    return _connectedDevices.values
        .where((device) => device.deviceType == deviceType)
        .toList();
  }

  /// Sync data from all connected devices
  Future<List<DeviceDataPoint>> syncAllDevices({DateTime? since}) async {
    final allDataPoints = <DeviceDataPoint>[];
    
    for (final device in _connectedDevices.values) {
      try {
        _eventController.add(DeviceEvent(
          type: DeviceEventType.syncStarted,
          deviceId: device.deviceId,
          data: {'deviceName': device.deviceName},
        ));

        final dataPoints = await device.syncData(since: since);
        allDataPoints.addAll(dataPoints);
        
        _eventController.add(DeviceEvent(
          type: DeviceEventType.syncCompleted,
          deviceId: device.deviceId,
          data: {
            'deviceName': device.deviceName,
            'dataPointsCount': dataPoints.length,
          },
        ));
      } catch (e) {
        _eventController.add(DeviceEvent(
          type: DeviceEventType.syncError,
          deviceId: device.deviceId,
          data: {
            'deviceName': device.deviceName,
            'error': e.toString(),
          },
        ));
      }
    }
    
    return allDataPoints;
  }

  /// Sync data from specific device
  Future<List<DeviceDataPoint>> syncDevice(
    String deviceId, {
    DateTime? since,
  }) async {
    final device = _connectedDevices[deviceId];
    if (device == null) {
      throw Exception('Device not found: $deviceId');
    }

    _eventController.add(DeviceEvent(
      type: DeviceEventType.syncStarted,
      deviceId: deviceId,
      data: {'deviceName': device.deviceName},
    ));

    try {
      final dataPoints = await device.syncData(since: since);
      
      _eventController.add(DeviceEvent(
        type: DeviceEventType.syncCompleted,
        deviceId: deviceId,
        data: {
          'deviceName': device.deviceName,
          'dataPointsCount': dataPoints.length,
        },
      ));
      
      return dataPoints;
    } catch (e) {
      _eventController.add(DeviceEvent(
        type: DeviceEventType.syncError,
        deviceId: deviceId,
        data: {
          'deviceName': device.deviceName,
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  /// Check health of all devices
  Future<Map<String, DeviceHealthInfo>> checkAllDevicesHealth() async {
    final healthMap = <String, DeviceHealthInfo>{};
    
    for (final device in _connectedDevices.values) {
      try {
        healthMap[device.deviceId] = await device.getHealthInfo();
      } catch (e) {
        healthMap[device.deviceId] = DeviceHealthInfo(
          isHealthy: false,
          lastActivity: DateTime.now().subtract(const Duration(days: 1)),
          errors: [e.toString()],
        );
      }
    }
    
    return healthMap;
  }

  /// Get available device types for integration
  List<DeviceType> getAvailableDeviceTypes() {
    return DeviceIntegrationRegistry.getAvailableDeviceTypes();
  }

  /// Start periodic sync
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 30), // Sync every 30 minutes
      (_) => syncAllDevices(),
    );
  }

  /// Load device configurations from storage
  Future<void> _loadDeviceConfigurations() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('device_configurations');
    
    if (configJson != null) {
      final configs = Map<String, dynamic>.from(
        jsonDecode(configJson),
      );
      
      for (final entry in configs.entries) {
        final deviceConfig = Map<String, dynamic>.from(entry.value);
        final deviceTypeStr = deviceConfig['deviceType'];
        final deviceType = DeviceType.values.firstWhere(
          (e) => e.toString() == deviceTypeStr,
          orElse: () => DeviceType.smartVehicle,
        );
        
        try {
          await addDevice(deviceType, deviceConfig);
        } catch (e) {
          debugPrint('Failed to restore device ${entry.key}: $e');
        }
      }
    }
  }

  /// Save device configuration to storage
  Future<void> _saveDeviceConfiguration(DeviceIntegration device) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('device_configurations') ?? '{}';
    final configs = Map<String, dynamic>.from(jsonDecode(configJson));
    
    configs[device.deviceId] = {
      'deviceType': device.deviceType.toString(),
      'deviceId': device.deviceId,
      'deviceName': device.deviceName,
      'manufacturerName': device.manufacturerName,
      ...device.configuration,
    };
    
    await prefs.setString('device_configurations', jsonEncode(configs));
  }

  /// Remove device configuration from storage
  Future<void> _removeDeviceConfiguration(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('device_configurations') ?? '{}';
    final configs = Map<String, dynamic>.from(jsonDecode(configJson));
    
    configs.remove(deviceId);
    await prefs.setString('device_configurations', jsonEncode(configs));
  }

  /// Load privacy settings
  Future<void> _loadPrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final privacyLevelStr = prefs.getString('device_privacy_level') ??
        PrivacyLevel.balanced.toString();
    
    _privacyLevel = PrivacyLevel.values.firstWhere(
      (e) => e.toString() == privacyLevelStr,
      orElse: () => PrivacyLevel.balanced,
    );
  }

  /// Save privacy settings
  Future<void> _savePrivacySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'device_privacy_level', 
      _privacyLevel.toString(),
    );
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _eventController.close();
  }
}

/// Device event types
enum DeviceEventType {
  deviceConnected,
  deviceDisconnected,
  deviceError,
  syncStarted,
  syncCompleted,
  syncError,
  privacySettingsChanged,
  dataReceived,
}

/// Device event
class DeviceEvent {
  final DeviceEventType type;
  final String deviceId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  DeviceEvent({
    required this.type,
    required this.deviceId,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}