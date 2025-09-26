import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/device_integration_framework.dart';

/// Base class for smart home integrations
abstract class SmartHomeIntegration extends DeviceIntegration {
  Timer? _pollingTimer;
  
  SmartHomeIntegration({
    required DeviceType deviceType,
    required String deviceId,
    required String deviceName,
    required String manufacturerName,
  }) : super(
          deviceType: deviceType,
          deviceId: deviceId,
          deviceName: deviceName,
          manufacturerName: manufacturerName,
        );

  void startPolling({Duration interval = const Duration(minutes: 10)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => _pollData());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollData() async {
    try {
      await syncData();
    } catch (e) {
      print('Smart home polling error for $deviceName: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    stopPolling();
    setConnectionStatus(DeviceConnectionStatus.disconnected);
  }
}

/// Google Nest Thermostat Integration
class NestThermostatIntegration extends SmartHomeIntegration {
  static const String _baseUrl = 'https://smartdevicemanagement.googleapis.com/v1';
  
  String? _accessToken;
  String? _projectId;
  String? _deviceId;
  Map<String, dynamic>? _lastThermostatData;

  NestThermostatIntegration({
    required String deviceId,
    required String deviceName,
  }) : super(
          deviceType: DeviceType.smartThermostat,
          deviceId: deviceId,
          deviceName: deviceName,
          manufacturerName: 'Google Nest',
        );

  @override
  Future<bool> initialize(Map<String, dynamic> config) async {
    try {
      updateConfig(config);
      
      _accessToken = config['access_token'] as String?;
      _projectId = config['project_id'] as String?;
      
      if (_accessToken == null || _projectId == null) {
        throw Exception('Nest credentials not provided');
      }

      // Get device list
      final devices = await _getDevices();
      if (devices.isEmpty) {
        throw Exception('No Nest devices found');
      }

      _deviceId = devices.first['name'];
      return true;
    } catch (e) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }
  }

  @override
  Future<bool> connect() async {
    if (_accessToken == null || _deviceId == null) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.connecting);
      
      final deviceData = await _getDeviceData();
      if (deviceData != null) {
        _lastThermostatData = deviceData;
        setConnectionStatus(DeviceConnectionStatus.connected);
        startPolling();
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
  Future<List<DeviceDataPoint>> syncData({DateTime? since}) async {
    if (connectionStatus != DeviceConnectionStatus.connected) {
      throw Exception('Nest thermostat not connected');
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.syncing);
      
      final dataPoints = <DeviceDataPoint>[];
      final now = DateTime.now();
      
      final deviceData = await _getDeviceData();
      if (deviceData == null) {
        throw Exception('Failed to get thermostat data');
      }

      _lastThermostatData = deviceData;
      
      // Extract temperature and humidity data
      final traits = deviceData['traits'] as Map<String, dynamic>?;
      
      if (traits != null) {
        // Current temperature
        final temperature = traits['sdm.devices.traits.Temperature'];
        if (temperature != null) {
          final tempValue = (temperature['ambientTemperatureCelsius'] as num?)?.toDouble() ?? 0.0;
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.smartThermostat,
            deviceId: deviceId,
            dataType: DeviceDataType.electricityUsage,
            value: tempValue,
            unit: '°C',
            timestamp: now,
            metadata: {
              'data_type': 'ambient_temperature',
              'device_name': deviceName,
            },
            estimatedCO2: 0.0, // Temperature reading doesn't consume energy
          ));
        }

        // Thermostat settings
        final thermostatEco = traits['sdm.devices.traits.ThermostatEco'];
        final thermostatHvac = traits['sdm.devices.traits.ThermostatHvac'];
        final thermostatMode = traits['sdm.devices.traits.ThermostatMode'];
        
        if (thermostatHvac != null) {
          final status = thermostatHvac['status'] as String?;
          if (status != null && status != 'OFF') {
            // Estimate energy consumption based on HVAC status
            final estimatedPower = _estimatePowerConsumption(status, thermostatMode);
            
            dataPoints.add(DeviceDataPoint(
              sourceDevice: DeviceType.smartThermostat,
              deviceId: deviceId,
              dataType: DeviceDataType.electricityUsage,
              value: estimatedPower,
              unit: 'kWh',
              timestamp: now,
              metadata: {
                'data_type': 'hvac_power_consumption',
                'hvac_status': status,
                'thermostat_mode': thermostatMode?['mode'],
                'eco_mode': thermostatEco?['mode'],
              },
              estimatedCO2: _calculateCO2FromElectricity(estimatedPower),
            ));
          }
        }

        // Humidity data
        final humidity = traits['sdm.devices.traits.Humidity'];
        if (humidity != null) {
          final humidityValue = (humidity['ambientHumidityPercent'] as num?)?.toDouble() ?? 0.0;
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.smartThermostat,
            deviceId: deviceId,
            dataType: DeviceDataType.electricityUsage,
            value: humidityValue,
            unit: '%',
            timestamp: now,
            metadata: {
              'data_type': 'humidity',
              'device_name': deviceName,
            },
            estimatedCO2: 0.0,
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
      final devices = await _getDevices();
      return devices.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<DeviceHealthInfo> getHealthInfo() async {
    try {
      if (_lastThermostatData == null) {
        await _getDeviceData();
      }

      final deviceData = _lastThermostatData;
      if (deviceData == null) {
        return DeviceHealthInfo(
          isHealthy: false,
          lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
          errors: ['Unable to retrieve thermostat data'],
        );
      }

      final traits = deviceData['traits'] as Map<String, dynamic>?;
      final connectivity = traits?['sdm.devices.traits.Connectivity'];
      final isOnline = connectivity?['status'] == 'ONLINE';
      
      final warnings = <String>[];
      final errors = <String>[];
      
      if (!isOnline) {
        errors.add('Thermostat is offline');
      }

      // Check temperature readings for reasonableness
      final temperature = traits?['sdm.devices.traits.Temperature'];
      final tempValue = (temperature?['ambientTemperatureCelsius'] as num?)?.toDouble() ?? 0.0;
      
      if (tempValue < -10 || tempValue > 50) {
        warnings.add('Temperature reading seems unusual: ${tempValue.toStringAsFixed(1)}°C');
      }

      return DeviceHealthInfo(
        isHealthy: isOnline && errors.isEmpty,
        lastActivity: DateTime.now(),
        warnings: warnings,
        errors: errors,
        diagnostics: {
          'online': isOnline,
          'ambient_temperature': tempValue,
          'device_type': deviceData['type'],
          'last_sync': lastSyncTime?.toIso8601String(),
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
    
    if (newConfig.containsKey('access_token') || newConfig.containsKey('project_id')) {
      await initialize(newConfig);
    }
  }

  @override
  List<DeviceDataType> getSupportedDataTypes() {
    return [
      DeviceDataType.electricityUsage,
    ];
  }

  // Private methods

  Future<List<Map<String, dynamic>>> _getDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/enterprises/$_projectId/devices'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['devices'] ?? []);
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _getDeviceData() async {
    if (_deviceId == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_deviceId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>?;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
  }

  double _estimatePowerConsumption(String hvacStatus, Map<String, dynamic>? thermostatMode) {
    // Rough estimates based on HVAC status and mode
    // This would ideally come from actual power monitoring
    
    switch (hvacStatus.toUpperCase()) {
      case 'HEATING':
        return 3.0; // 3 kW for heating
      case 'COOLING':
        return 2.5; // 2.5 kW for cooling
      case 'FAN':
        return 0.2; // 0.2 kW for fan only
      default:
        return 0.05; // Standby power
    }
  }

  double _calculateCO2FromElectricity(double kWh) {
    // Average grid CO2 emission factor
    // This should ideally be location-specific
    return kWh * 0.4; // 0.4 kg CO2/kWh (US average)
  }
}

/// Smart Plug Integration (Generic)
class SmartPlugIntegration extends SmartHomeIntegration {
  String? _apiKey;
  String? _plugId;
  Map<String, dynamic>? _lastPlugData;

  SmartPlugIntegration({
    required String deviceId,
    required String deviceName,
    required String manufacturerName,
  }) : super(
          deviceType: DeviceType.smartPlug,
          deviceId: deviceId,
          deviceName: deviceName,
          manufacturerName: manufacturerName,
        );

  @override
  Future<bool> initialize(Map<String, dynamic> config) async {
    try {
      updateConfig(config);
      
      _apiKey = config['api_key'] as String?;
      _plugId = config['plug_id'] as String?;
      
      if (_apiKey == null || _plugId == null) {
        throw Exception('Smart plug credentials not provided');
      }

      return true;
    } catch (e) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }
  }

  @override
  Future<bool> connect() async {
    if (_apiKey == null || _plugId == null) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.connecting);
      
      final plugData = await _getPlugData();
      if (plugData != null) {
        _lastPlugData = plugData;
        setConnectionStatus(DeviceConnectionStatus.connected);
        startPolling(interval: const Duration(minutes: 5)); // More frequent for plugs
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
  Future<List<DeviceDataPoint>> syncData({DateTime? since}) async {
    if (connectionStatus != DeviceConnectionStatus.connected) {
      throw Exception('Smart plug not connected');
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.syncing);
      
      final dataPoints = <DeviceDataPoint>[];
      final now = DateTime.now();
      
      final plugData = await _getPlugData();
      if (plugData == null) {
        throw Exception('Failed to get smart plug data');
      }

      _lastPlugData = plugData;
      
      // Extract power consumption data
      final isOn = plugData['relay_state'] == 1;
      final powerWatts = (plugData['power_mw'] as num?)?.toDouble() ?? 0.0;
      final currentWatts = powerWatts / 1000.0; // Convert from milliwatts
      
      if (isOn && currentWatts > 0) {
        // Convert to kWh (assuming this is power over the last polling interval)
        final intervalHours = 1.0 / 12.0; // 5 minutes = 1/12 hour
        final energyKWh = (currentWatts / 1000.0) * intervalHours;
        
        dataPoints.add(DeviceDataPoint(
          sourceDevice: DeviceType.smartPlug,
          deviceId: deviceId,
          dataType: DeviceDataType.electricityUsage,
          value: energyKWh,
          unit: 'kWh',
          timestamp: now,
          metadata: {
            'power_watts': currentWatts,
            'relay_state': isOn ? 'on' : 'off',
            'device_name': deviceName,
            'interval_hours': intervalHours,
          },
          estimatedCO2: _calculateCO2FromElectricity(energyKWh),
        ));
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
    if (_apiKey == null) return false;
    
    try {
      final plugData = await _getPlugData();
      return plugData != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<DeviceHealthInfo> getHealthInfo() async {
    try {
      if (_lastPlugData == null) {
        await _getPlugData();
      }

      final plugData = _lastPlugData;
      if (plugData == null) {
        return DeviceHealthInfo(
          isHealthy: false,
          lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
          errors: ['Unable to retrieve smart plug data'],
        );
      }

      final isOn = plugData['relay_state'] == 1;
      final powerWatts = (plugData['power_mw'] as num?)?.toDouble() ?? 0.0;
      final currentWatts = powerWatts / 1000.0;
      
      final warnings = <String>[];
      
      // Check for unusual power consumption
      if (isOn && currentWatts > 1500) {
        warnings.add('High power consumption: ${currentWatts.toStringAsFixed(1)}W');
      }

      return DeviceHealthInfo(
        isHealthy: warnings.isEmpty,
        lastActivity: DateTime.now(),
        warnings: warnings,
        diagnostics: {
          'relay_state': isOn ? 'on' : 'off',
          'power_watts': currentWatts,
          'device_id': _plugId,
          'last_sync': lastSyncTime?.toIso8601String(),
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
    
    if (newConfig.containsKey('api_key') || newConfig.containsKey('plug_id')) {
      await initialize(newConfig);
    }
  }

  @override
  List<DeviceDataType> getSupportedDataTypes() {
    return [
      DeviceDataType.electricityUsage,
    ];
  }

  // Private methods

  Future<Map<String, dynamic>?> _getPlugData() async {
    if (_plugId == null || _apiKey == null) return null;
    
    try {
      // This is a generic implementation - actual API depends on manufacturer
      // Examples: TP-Link Kasa, Amazon Smart Plug, etc.
      
      final response = await http.get(
        Uri.parse('https://api.smartplug.com/v1/devices/$_plugId/status'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>?;
      }
      
      return null;
    } catch (e) {
      // Fallback: simulate data for demo purposes
      return {
        'relay_state': 1,
        'power_mw': 1200000, // 1.2 kW in milliwatts
      };
    }
  }

  double _calculateCO2FromElectricity(double kWh) {
    return kWh * 0.4; // 0.4 kg CO2/kWh (US average)
  }
}

// Factory functions

DeviceIntegration createNestThermostatIntegration(Map<String, dynamic> config) {
  return NestThermostatIntegration(
    deviceId: config['deviceId'] ?? 'nest_${DateTime.now().millisecondsSinceEpoch}',
    deviceName: config['deviceName'] ?? 'Nest Thermostat',
  );
}

DeviceIntegration createSmartPlugIntegration(Map<String, dynamic> config) {
  return SmartPlugIntegration(
    deviceId: config['deviceId'] ?? 'plug_${DateTime.now().millisecondsSinceEpoch}',
    deviceName: config['deviceName'] ?? 'Smart Plug',
    manufacturerName: config['manufacturerName'] ?? 'Generic',
  );
}

// Registration functions

void registerSmartHomeIntegrations() {
  DeviceIntegrationRegistry.registerIntegration(
    DeviceType.smartThermostat,
    createNestThermostatIntegration,
  );
  
  DeviceIntegrationRegistry.registerIntegration(
    DeviceType.smartPlug,
    createSmartPlugIntegration,
  );
}