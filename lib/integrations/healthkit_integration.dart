import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../services/device_integration_framework.dart';

/// Apple HealthKit integration for fitness and activity tracking
class HealthKitIntegration extends DeviceIntegration {
  static final Health _health = Health();
  Timer? _syncTimer;
  DateTime? _lastSyncDate;
  
  HealthKitIntegration({
    required super.deviceId,
    required super.deviceName,
  }) : super(
          deviceType: DeviceType.fitnessTracker,
          manufacturerName: 'Apple',
        );

  @override
  Future<bool> initialize(Map<String, dynamic> config) async {
    if (!Platform.isIOS) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }

    try {
      updateConfig(config);
      
      // Define the types to get permissions for
      final types = _getHealthDataTypes();
      
      // Request permissions
      bool requested = await _health.requestAuthorization(types, permissions: [
        HealthDataAccess.READ,
      ]);

      if (!requested) {
        throw Exception('HealthKit authorization denied');
      }

      return true;
    } catch (e) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }
  }

  @override
  Future<bool> connect() async {
    if (!Platform.isIOS) {
      setConnectionStatus(DeviceConnectionStatus.error);
      return false;
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.connecting);
      
      // Test connection by getting today's step count
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      
      if (steps != null) {
        setConnectionStatus(DeviceConnectionStatus.connected);
        _startPeriodicSync();
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
    _syncTimer?.cancel();
    _syncTimer = null;
    setConnectionStatus(DeviceConnectionStatus.disconnected);
  }

  @override
  Future<List<DeviceDataPoint>> syncData({DateTime? since}) async {
    if (connectionStatus != DeviceConnectionStatus.connected) {
      throw Exception('HealthKit not connected');
    }

    if (!Platform.isIOS) {
      throw Exception('HealthKit only available on iOS');
    }

    try {
      setConnectionStatus(DeviceConnectionStatus.syncing);
      
      final dataPoints = <DeviceDataPoint>[];
      final now = DateTime.now();
      final sinceTime = since ?? _lastSyncDate ?? now.subtract(const Duration(days: 7));
      
      // Get step count data
      await _syncStepsData(dataPoints, sinceTime, now);
      
      // Get cycling distance data
      await _syncCyclingData(dataPoints, sinceTime, now);
      
      // Get walking/running distance data
      await _syncWalkingRunningData(dataPoints, sinceTime, now);
      
      // Get workout data
      await _syncWorkoutData(dataPoints, sinceTime, now);
      
      // Get active energy burned
      await _syncActiveEnergyData(dataPoints, sinceTime, now);

      _lastSyncDate = now;
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
    if (!Platform.isIOS) return false;
    
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      return steps != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<DeviceHealthInfo> getHealthInfo() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      // Get today's activity data
      final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
      
      // Get distance and active energy from health data
      double distance = 0;
      double activeEnergy = 0;
      
      try {
        final distanceData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.DISTANCE_WALKING_RUNNING],
          startTime: startOfDay,
          endTime: now,
        );
        distance = distanceData.fold<double>(0, (sum, data) => sum + (data.value as num).toDouble());
      } catch (e) {
        // Handle distance data error
      }
      
      try {
        final energyData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: startOfDay,
          endTime: now,
        );
        activeEnergy = energyData.fold<double>(0, (sum, data) => sum + (data.value as num).toDouble());
      } catch (e) {
        // Handle energy data error
      }
      
      final warnings = <String>[];
      final diagnostics = <String, dynamic>{};
      
      // Check activity levels
      if (steps < 5000) {
        warnings.add('Low daily step count: ${steps.toInt()} steps');
      }
      
      diagnostics['daily_steps'] = steps.toInt();
      diagnostics['daily_distance_km'] = (distance / 1000).toStringAsFixed(2);
      diagnostics['active_energy_cal'] = activeEnergy.toInt();
      diagnostics['last_sync'] = _lastSyncDate?.toIso8601String();
      
      return DeviceHealthInfo(
        isHealthy: warnings.isEmpty,
        lastActivity: now,
        warnings: warnings,
        diagnostics: diagnostics,
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
    // HealthKit doesn't need re-authentication for config changes
  }

  @override
  List<DeviceDataType> getSupportedDataTypes() {
    return [
      DeviceDataType.stepCount,
      DeviceDataType.cyclingDistance,
    ];
  }

  // Private methods

  List<HealthDataType> _getHealthDataTypes() {
    return [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.DISTANCE_CYCLING,
      HealthDataType.WORKOUT,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.HEART_RATE,
    ];
  }

  Future<void> _syncStepsData(
    List<DeviceDataPoint> dataPoints, 
    DateTime from, 
    DateTime to
  ) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: from,
        endTime: to,
      );

      for (final data in healthData) {
        if (data.type == HealthDataType.STEPS) {
          final steps = (data.value as num).toDouble();
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.fitnessTracker,
            deviceId: deviceId,
            dataType: DeviceDataType.stepCount,
            value: steps,
            unit: 'steps',
            timestamp: data.dateTo,
            metadata: {
              'source': data.sourceId,
              'source_name': data.sourceName,
              'workout_type': 'walking',
            },
            estimatedCO2: _calculateCO2FromSteps(steps),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error syncing steps data: $e');
    }
  }

  Future<void> _syncCyclingData(
    List<DeviceDataPoint> dataPoints,
    DateTime from,
    DateTime to
  ) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_CYCLING],
        startTime: from,
        endTime: to,
      );

      for (final data in healthData) {
        if (data.type == HealthDataType.DISTANCE_CYCLING) {
          final distance = (data.value as num).toDouble(); // in meters
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.fitnessTracker,
            deviceId: deviceId,
            dataType: DeviceDataType.cyclingDistance,
            value: distance / 1000, // Convert to kilometers
            unit: 'km',
            timestamp: data.dateTo,
            metadata: {
              'source': data.sourceId,
              'source_name': data.sourceName,
              'workout_type': 'cycling',
              'distance_meters': distance,
            },
            estimatedCO2: _calculateCO2FromCycling(distance / 1000),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error syncing cycling data: $e');
    }
  }

  Future<void> _syncWalkingRunningData(
    List<DeviceDataPoint> dataPoints,
    DateTime from,
    DateTime to
  ) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: from,
        endTime: to,
      );

      for (final data in healthData) {
        if (data.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
          final distance = (data.value as num).toDouble(); // in meters
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.fitnessTracker,
            deviceId: deviceId,
            dataType: DeviceDataType.stepCount,
            value: distance / 1000, // Convert to kilometers
            unit: 'km',
            timestamp: data.dateTo,
            metadata: {
              'source': data.sourceId,
              'source_name': data.sourceName,
              'workout_type': 'walking_running',
              'distance_meters': distance,
            },
            estimatedCO2: _calculateCO2FromWalkingRunning(distance / 1000),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error syncing walking/running data: $e');
    }
  }

  Future<void> _syncWorkoutData(
    List<DeviceDataPoint> dataPoints,
    DateTime from,
    DateTime to
  ) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: from,
        endTime: to,
      );

      for (final data in healthData) {
        if (data.type == HealthDataType.WORKOUT) {
          final workoutData = data.value as WorkoutHealthValue;
          final duration = data.dateTo.difference(data.dateFrom).inMinutes.toDouble();
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.fitnessTracker,
            deviceId: deviceId,
            dataType: DeviceDataType.stepCount, // Generic activity type
            value: duration,
            unit: 'minutes',
            timestamp: data.dateTo,
            metadata: {
              'source': data.sourceId,
              'source_name': data.sourceName,
              'workout_type': workoutData.workoutActivityType.toString(),
              'total_energy_burned': workoutData.totalEnergyBurned,
              'total_distance': workoutData.totalDistance,
              'duration_minutes': duration,
            },
            estimatedCO2: _calculateCO2FromWorkout(workoutData, duration),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error syncing workout data: $e');
    }
  }

  Future<void> _syncActiveEnergyData(
    List<DeviceDataPoint> dataPoints,
    DateTime from,
    DateTime to
  ) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: from,
        endTime: to,
      );

      for (final data in healthData) {
        if (data.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          final energy = (data.value as num).toDouble(); // in calories
          
          dataPoints.add(DeviceDataPoint(
            sourceDevice: DeviceType.fitnessTracker,
            deviceId: deviceId,
            dataType: DeviceDataType.stepCount, // Generic activity type
            value: energy,
            unit: 'cal',
            timestamp: data.dateTo,
            metadata: {
              'source': data.sourceId,
              'source_name': data.sourceName,
              'energy_type': 'active',
            },
            estimatedCO2: _calculateCO2FromActiveEnergy(energy),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error syncing active energy data: $e');
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(hours: 2), // Sync every 2 hours
      (_) => _performPeriodicSync(),
    );
  }

  Future<void> _performPeriodicSync() async {
    try {
      await syncData();
    } catch (e) {
      debugPrint('HealthKit periodic sync error: $e');
    }
  }

  // CO2 calculation methods

  double _calculateCO2FromSteps(double steps) {
    // Walking/running replaces car usage
    // Assume each 1000 steps ~= 0.8 km walked
    // Assume each km walked replaces 1 km of car travel
    // Average car CO2: ~0.2 kg CO2/km
    final kmWalked = (steps / 1000) * 0.8;
    return -kmWalked * 0.2; // Negative because it saves CO2
  }

  double _calculateCO2FromCycling(double kmCycled) {
    // Cycling replaces car/public transport usage
    // Assume each km cycled replaces 1 km of car travel
    // Average car CO2: ~0.2 kg CO2/km
    return -kmCycled * 0.2; // Negative because it saves CO2
  }

  double _calculateCO2FromWalkingRunning(double kmWalkingRunning) {
    // Similar to steps, walking/running replaces car usage
    return -kmWalkingRunning * 0.2; // Negative because it saves CO2
  }

  double _calculateCO2FromWorkout(WorkoutHealthValue workout, double durationMinutes) {
    // Different workout types have different CO2 impact
    // Most workouts replace sedentary activities or car travel
    
    final workoutType = workout.workoutActivityType.toString();
    final distance = workout.totalDistance ?? 0;
    
    switch (workoutType.toLowerCase()) {
      case 'cycling':
        return _calculateCO2FromCycling(distance / 1000);
      case 'walking':
      case 'running':
        return _calculateCO2FromWalkingRunning(distance / 1000);
      case 'swimming':
        // Swimming doesn't directly replace transport, minimal impact
        return 0.0;
      default:
        // General workout, assume it replaces some car usage
        // Rough estimate: 30 min workout = 5 km car travel saved
        final equivalentKm = (durationMinutes / 30) * 5;
        return -equivalentKm * 0.2; // Negative because it saves CO2
    }
  }

  double _calculateCO2FromActiveEnergy(double calories) {
    // Active energy burned can indicate level of physical activity
    // High activity often correlates with less car usage
    // Very rough estimate: 100 calories burned = 1 km car travel saved
    final equivalentKm = calories / 100;
    return -equivalentKm * 0.2; // Negative because it saves CO2
  }
}

/// Factory function for creating HealthKit integrations
DeviceIntegration createHealthKitIntegration(Map<String, dynamic> config) {
  return HealthKitIntegration(
    deviceId: config['deviceId'] ?? 'healthkit_${DateTime.now().millisecondsSinceEpoch}',
    deviceName: config['deviceName'] ?? 'Apple HealthKit',
  );
}

/// Register HealthKit integration with the framework
void registerHealthKitIntegration() {
  DeviceIntegrationRegistry.registerIntegration(
    DeviceType.fitnessTracker,
    createHealthKitIntegration,
  );
}