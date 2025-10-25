import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/device_integration_framework.dart';

/// Tesla API integration for automatic vehicle tracking
class TeslaIntegration extends DeviceIntegration {
  static const String _baseUrl = 'https://owner-api.teslamotors.com';
  static const String _userAgent = 'Carbon Tracker/1.0';
  
  String? _accessToken;
  String? _vehicleId;
  Timer? _pollingTimer;
  Map<String, dynamic>? _lastVehicleData;
  
  TeslaIntegration({
    required super.deviceId,
    required super.deviceName,
  }) : super(
          deviceType: DeviceType.smartVehicle,
          manufacturerName: 'Tesla',
        );

  @override
  Future<bool> initialize(Map<String, dynamic> config) async {
    try {
      updateConfig(config);
      
      // Extract credentials from config
      final email = config['email'] as String?;
      final password = config['password'] as String?;
      
      if (email == null || password == null) {
        throw Exception('Tesla credentials not provided');
      }

      // Authenticate with Tesla
      final authenticated = await _authenticate(email, password);
      if (!authenticated) {
        throw Exception('Tesla authentication failed');
      }

      // Get vehicle list and select the first one
      final vehicles = await _getVehicles();
      if (vehicles.isEmpty) {
        throw Exception('No Tesla vehicles found');
      }

      _vehicleId = vehicles.first['id_s'].toString();
      
      return true;
    } catch (e) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }
  }

  @override
  Future<bool> connect() async {
    if (_accessToken == null || _vehicleId == null) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.connecting);
      
      // Test connection by getting vehicle state
      final vehicleData = await _getVehicleData();
      if (vehicleData != null) {
        _lastVehicleData = vehicleData;
        setConnectionStatus(DeviceConnectionStatus.connected);
        _startPolling();
        return true;
      }
      
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    } catch (e) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    setConnectionStatus(DeviceConnectionStatus.disconnected);
  }

  @override
  Future<List<DeviceDataPoint>> syncData({DateTime? since}) async {
    if (connectionStatus != DeviceConnectionStatus.connected) {
      throw Exception('Tesla not connected');
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.syncing);
      
      final dataPoints = <DeviceDataPoint>[];
      final now = DateTime.now();
      final sinceTime = since ?? now.subtract(const Duration(days: 1));
      
      // Get current vehicle data
      final vehicleData = await _getVehicleData();
      if (vehicleData == null) {
        throw Exception('Failed to get vehicle data');
      }

      _lastVehicleData = vehicleData;
      
      // Extract trip data if vehicle has been driven
      final driveState = vehicleData['drive_state'] as Map<String, dynamic>?;
      final chargeState = vehicleData['charge_state'] as Map<String, dynamic>?;
      
      if (driveState != null && chargeState != null) {
        // Create data points for mileage
        final odometer = (driveState['odometer'] as num?)?.toDouble() ?? 0.0;
        if (odometer > 0) {
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.smartVehicle,
            deviceId: deviceId,
            dataType: DeviceDataType.mileage,
            value: odometer,
            unit: 'miles',
            timestamp: now,
            metadata: {
              'vehicle_name': deviceName,
              'location': {
                'latitude': driveState['latitude'],
                'longitude': driveState['longitude'],
              },
              'shift_state': driveState['shift_state'],
            },
            estimatedCO2: _calculateCO2FromMileage(odometer),
          ));
        }

        // Create data points for energy consumption
        final batteryLevel = (chargeState['battery_level'] as num?)?.toDouble() ?? 0.0;
        final usableBatteryLevel = (chargeState['usable_battery_level'] as num?)?.toDouble() ?? 0.0;
        final chargeEnergyAdded = (chargeState['charge_energy_added'] as num?)?.toDouble() ?? 0.0;
        
        if (chargeEnergyAdded > 0) {
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.smartVehicle,
            deviceId: deviceId,
            dataType: DeviceDataType.energyConsumption,
            value: chargeEnergyAdded,
            unit: 'kWh',
            timestamp: now,
            metadata: {
              'battery_level': batteryLevel,
              'usable_battery_level': usableBatteryLevel,
              'charging_state': chargeState['charging_state'],
              'charger_power': chargeState['charger_power'],
            },
            estimatedCO2: _calculateCO2FromEnergy(chargeEnergyAdded),
          ));
        }

        // Get trip data for recent drives
        final recentTrips = await _getRecentTrips(sinceTime);
        for (final trip in recentTrips) {
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.smartVehicle,
            deviceId: deviceId,
            dataType: DeviceDataType.tripData,
            value: trip['distance'],
            unit: 'miles',
            timestamp: DateTime.parse(trip['start_time']),
            metadata: {
              'trip_id': trip['id'],
              'duration': trip['duration'],
              'start_address': trip['start_address'],
              'end_address': trip['end_address'],
              'energy_used': trip['energy_used'],
              'avg_speed': trip['avg_speed'],
            },
            estimatedCO2: _calculateCO2FromTrip(trip),
          ));
        }
      }

      setLastSyncTime(now);
      setConnectionStatus(DeviceConnectionStatus.connected);
      return dataPoints;
    } catch (e) {
      setConnectionStatus(DeviceConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (_accessToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/1/vehicles'),
        headers: _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<DeviceHealthInfo> getHealthInfo() async {
    try {
      if (_lastVehicleData == null) {
        await _getVehicleData();
      }

      final vehicleData = _lastVehicleData;
      if (vehicleData == null) {
        return DeviceHealthInfo(
          isHealthy: false,
          lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
          errors: ['Unable to retrieve vehicle data'],
        );
      }

      final chargeState = vehicleData['charge_state'] as Map<String, dynamic>?;
      final vehicleState = vehicleData['vehicle_state'] as Map<String, dynamic>?;
      
      final batteryLevel = (chargeState?['battery_level'] as num?)?.toDouble() ?? 0.0;
      final isHealthy = batteryLevel > 10.0; // Consider healthy if battery > 10%
      
      final warnings = <String>[];
      final errors = <String>[];
      
      // Check battery level
      if (batteryLevel < 20.0) {
        warnings.add('Low battery: ${batteryLevel.toStringAsFixed(0)}%');
      }
      
      // Check if vehicle is locked
      final isLocked = vehicleState?['locked'] as bool? ?? true;
      if (!isLocked) {
        warnings.add('Vehicle is unlocked');
      }
      
      // Check software update status
      final softwareUpdate = vehicleState?['software_update'] as Map<String, dynamic>?;
      if (softwareUpdate?['status'] == 'available') {
        warnings.add('Software update available');
      }

      return DeviceHealthInfo(
        isHealthy: isHealthy && errors.isEmpty,
        batteryLevel: batteryLevel / 100.0, // Convert to 0-1 range
        lastActivity: DateTime.now(),
        warnings: warnings,
        errors: errors,
        diagnostics: {
          'battery_level': batteryLevel,
          'charging_state': chargeState?['charging_state'],
          'locked': isLocked,
          'odometer': vehicleData['drive_state']?['odometer'],
          'software_version': vehicleState?['car_version'],
        },
      );
    } catch (e) {
      return DeviceHealthInfo(
        isHealthy: false,
        lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
        errors: ['Health check failed: $e'],
      );
    }
  }

  @override
  Future<void> updateConfiguration(Map<String, dynamic> newConfig) async {
    updateConfig(newConfig);
    
    // If credentials changed, re-authenticate
    if (newConfig.containsKey('email') || newConfig.containsKey('password')) {
      await initialize(newConfig);
    }
  }

  @override
  List<DeviceDataType> getSupportedDataTypes() {
    return [
      DeviceDataType.mileage,
      DeviceDataType.energyConsumption,
      DeviceDataType.tripData,
    ];
  }

  // Private methods

  Future<bool> _authenticate(String email, String password) async {
    try {
      // Tesla OAuth flow
      final response = await http.post(
        Uri.parse('$_baseUrl/oauth/token'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent,
        },
        body: jsonEncode({
          'grant_type': 'password',
          'client_id': '81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384',
          'client_secret': 'c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3',
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _getVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/1/vehicles'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['response'] ?? []);
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getVehicleData() async {
    if (_vehicleId == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/1/vehicles/$_vehicleId/vehicle_data'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as Map<String, dynamic>?;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentTrips(DateTime since) async {
    // Note: Tesla doesn't provide a direct trips API
    // This would need to be implemented by tracking odometer changes
    // and location data over time. For now, return empty list.
    
    // In a real implementation, you might:
    // 1. Store odometer readings over time
    // 2. Detect significant changes that indicate trips
    // 3. Use location data to determine start/end points
    // 4. Calculate distance and energy consumption per trip
    
    return [];
  }

  Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Bearer $_accessToken',
      'User-Agent': _userAgent,
      'Content-Type': 'application/json',
    };
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(minutes: 5), // Poll every 5 minutes
      (_) => _pollVehicleData(),
    );
  }

  Future<void> _pollVehicleData() async {
    try {
      await syncData();
    } catch (e) {
      // Polling error - continue trying
      debugPrint('Tesla polling error: $e');
    }
  }

  double _calculateCO2FromMileage(double miles) {
    // Tesla Model S/3/X/Y are electric, so direct CO2 is 0
    // But we can estimate grid CO2 based on energy consumption
    // Average efficiency: ~0.28 kWh/mile
    // Average US grid CO2: ~0.4 kg CO2/kWh
    final estimatedKWh = miles * 0.28;
    return estimatedKWh * 0.4;
  }

  double _calculateCO2FromEnergy(double kWh) {
    // Grid CO2 varies by location and time
    // Using US average of ~0.4 kg CO2/kWh
    return kWh * 0.4;
  }

  double _calculateCO2FromTrip(Map<String, dynamic> trip) {
    final distance = (trip['distance'] as num?)?.toDouble() ?? 0.0;
    final energyUsed = (trip['energy_used'] as num?)?.toDouble() ?? 0.0;
    
    if (energyUsed > 0) {
      return _calculateCO2FromEnergy(energyUsed);
    } else {
      return _calculateCO2FromMileage(distance);
    }
  }
}

/// Factory function for creating Tesla integrations
DeviceIntegration createTeslaIntegration(Map<String, dynamic> config) {
  return TeslaIntegration(
    deviceId: config['deviceId'] ?? 'tesla_${DateTime.now().millisecondsSinceEpoch}',
    deviceName: config['deviceName'] ?? 'Tesla Vehicle',
  );
}

/// Register Tesla integration with the framework
void registerTeslaIntegration() {
  DeviceIntegrationRegistry.registerIntegration(
    DeviceType.smartVehicle,
    createTeslaIntegration,
  );
}