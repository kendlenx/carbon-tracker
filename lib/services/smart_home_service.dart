import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'database_service.dart';
import 'goal_service.dart';
import 'notification_service.dart';

enum SmartDeviceType {
  thermostat,
  smartMeter,
  lightBulb,
  smartPlug,
  solarPanel,
  electricVehicle,
  smartWaterHeater,
  hvacSystem,
}

enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
}

class SmartDevice {
  final String id;
  final String name;
  final String manufacturer;
  final SmartDeviceType type;
  final String roomLocation;
  final ConnectionStatus status;
  final DateTime lastUpdate;
  final Map<String, dynamic> data;
  final bool isActive;
  final double powerConsumption; // Watts
  final double carbonFactor; // kg CO₂ per kWh

  SmartDevice({
    required this.id,
    required this.name,
    required this.manufacturer,
    required this.type,
    required this.roomLocation,
    required this.status,
    required this.lastUpdate,
    required this.data,
    this.isActive = true,
    this.powerConsumption = 0.0,
    this.carbonFactor = 0.5, // Default grid carbon factor
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'manufacturer': manufacturer,
      'type': type.name,
      'roomLocation': roomLocation,
      'status': status.name,
      'lastUpdate': lastUpdate.toIso8601String(),
      'data': data,
      'isActive': isActive,
      'powerConsumption': powerConsumption,
      'carbonFactor': carbonFactor,
    };
  }

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    return SmartDevice(
      id: json['id'],
      name: json['name'],
      manufacturer: json['manufacturer'],
      type: SmartDeviceType.values.firstWhere((e) => e.name == json['type']),
      roomLocation: json['roomLocation'],
      status: ConnectionStatus.values.firstWhere((e) => e.name == json['status']),
      lastUpdate: DateTime.parse(json['lastUpdate']),
      data: json['data'],
      isActive: json['isActive'] ?? true,
      powerConsumption: json['powerConsumption']?.toDouble() ?? 0.0,
      carbonFactor: json['carbonFactor']?.toDouble() ?? 0.5,
    );
  }

  SmartDevice copyWith({
    String? id,
    String? name,
    String? manufacturer,
    SmartDeviceType? type,
    String? roomLocation,
    ConnectionStatus? status,
    DateTime? lastUpdate,
    Map<String, dynamic>? data,
    bool? isActive,
    double? powerConsumption,
    double? carbonFactor,
  }) {
    return SmartDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      type: type ?? this.type,
      roomLocation: roomLocation ?? this.roomLocation,
      status: status ?? this.status,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      data: data ?? this.data,
      isActive: isActive ?? this.isActive,
      powerConsumption: powerConsumption ?? this.powerConsumption,
      carbonFactor: carbonFactor ?? this.carbonFactor,
    );
  }

  double get dailyCarbonEmission {
    // Calculate daily carbon emission based on power consumption
    final dailyKwh = (powerConsumption * 24) / 1000; // Convert W to kWh
    return dailyKwh * carbonFactor;
  }
}

class SmartHomeAutomation {
  final String id;
  final String name;
  final String description;
  final String trigger; // Time, sensor, manual
  final List<String> deviceIds;
  final Map<String, dynamic> actions;
  final bool isEnabled;
  final double estimatedSavings; // kg CO₂ per activation

  SmartHomeAutomation({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    required this.deviceIds,
    required this.actions,
    this.isEnabled = true,
    this.estimatedSavings = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trigger': trigger,
      'deviceIds': deviceIds,
      'actions': actions,
      'isEnabled': isEnabled,
      'estimatedSavings': estimatedSavings,
    };
  }

  factory SmartHomeAutomation.fromJson(Map<String, dynamic> json) {
    return SmartHomeAutomation(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      trigger: json['trigger'],
      deviceIds: List<String>.from(json['deviceIds']),
      actions: json['actions'],
      isEnabled: json['isEnabled'] ?? true,
      estimatedSavings: json['estimatedSavings']?.toDouble() ?? 0.0,
    );
  }
}

class SmartHomeService extends ChangeNotifier {
  static SmartHomeService? _instance;
  static SmartHomeService get instance => _instance ??= SmartHomeService._();
  
  SmartHomeService._();

  // Services
  final DatabaseService _databaseService = DatabaseService.instance;
  final GoalService _goalService = GoalService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  // Device data
  List<SmartDevice> _devices = [];
  List<SmartHomeAutomation> _automations = [];
  bool _isInitialized = false;
  
  // Connection settings
  bool _homeKitEnabled = false;
  bool _googleHomeEnabled = false;
  bool _autoDataCollection = true;
  int _dataCollectionIntervalMinutes = 15;
  
  // Statistics
  double _dailyEnergyConsumption = 0.0;
  double _dailyCarbonFromDevices = 0.0;
  double _totalSavingsFromAutomation = 0.0;

  // Getters
  List<SmartDevice> get devices => _devices;
  List<SmartDevice> get connectedDevices => _devices.where((d) => d.status == ConnectionStatus.connected).toList();
  List<SmartHomeAutomation> get automations => _automations;
  List<SmartHomeAutomation> get enabledAutomations => _automations.where((a) => a.isEnabled).toList();
  bool get isInitialized => _isInitialized;
  bool get homeKitEnabled => _homeKitEnabled;
  bool get googleHomeEnabled => _googleHomeEnabled;
  bool get autoDataCollection => _autoDataCollection;
  double get dailyEnergyConsumption => _dailyEnergyConsumption;
  double get dailyCarbonFromDevices => _dailyCarbonFromDevices;
  double get totalSavingsFromAutomation => _totalSavingsFromAutomation;

  /// Initialize smart home service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadSettings();
    await _loadDevices();
    await _loadAutomations();
    await _setupDefaultDevices();
    await _setupDefaultAutomations();
    await _startDataCollection();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Setup default smart devices (simulated)
  Future<void> _setupDefaultDevices() async {
    if (_devices.isNotEmpty) return;

    final defaultDevices = [
      SmartDevice(
        id: 'thermostat_1',
        name: 'Akıllı Termostat',
        manufacturer: 'Nest',
        type: SmartDeviceType.thermostat,
        roomLocation: 'Oturma Odası',
        status: ConnectionStatus.connected,
        lastUpdate: DateTime.now(),
        data: {
          'temperature': 22.5,
          'targetTemp': 23.0,
          'humidity': 45,
          'mode': 'heat',
        },
        powerConsumption: 150.0,
        carbonFactor: 0.4,
      ),
      SmartDevice(
        id: 'smart_meter_1',
        name: 'Akıllı Sayaç',
        manufacturer: 'Schneider Electric',
        type: SmartDeviceType.smartMeter,
        roomLocation: 'Elektrik Panosu',
        status: ConnectionStatus.connected,
        lastUpdate: DateTime.now(),
        data: {
          'currentPower': 2500.0,
          'dailyConsumption': 15.2,
          'voltage': 230.0,
          'frequency': 50.0,
        },
        powerConsumption: 2500.0,
        carbonFactor: 0.5,
      ),
      SmartDevice(
        id: 'smart_bulb_1',
        name: 'Akıllı Ampul - Salon',
        manufacturer: 'Philips Hue',
        type: SmartDeviceType.lightBulb,
        roomLocation: 'Salon',
        status: ConnectionStatus.connected,
        lastUpdate: DateTime.now(),
        data: {
          'brightness': 80,
          'color': '#ffffff',
          'isOn': true,
        },
        powerConsumption: 9.0,
        carbonFactor: 0.5,
      ),
      SmartDevice(
        id: 'smart_plug_1',
        name: 'Akıllı Priz - TV Ünitesi',
        manufacturer: 'TP-Link Kasa',
        type: SmartDeviceType.smartPlug,
        roomLocation: 'Salon',
        status: ConnectionStatus.connected,
        lastUpdate: DateTime.now(),
        data: {
          'isOn': true,
          'powerUsage': 120.0,
          'schedule': {'enabled': true, 'onTime': '07:00', 'offTime': '23:00'},
        },
        powerConsumption: 120.0,
        carbonFactor: 0.5,
      ),
    ];

    _devices.addAll(defaultDevices);
    await _saveDevices();
  }

  /// Setup default automations
  Future<void> _setupDefaultAutomations() async {
    if (_automations.isNotEmpty) return;

    final defaultAutomations = [
      SmartHomeAutomation(
        id: 'energy_saver_night',
        name: 'Gece Enerji Tasarrufu',
        description: 'Gece saatlerinde gereksiz cihazları kapatır',
        trigger: '23:00',
        deviceIds: ['smart_plug_1', 'smart_bulb_1'],
        actions: {
          'smart_plug_1': {'action': 'turnOff'},
          'smart_bulb_1': {'action': 'setBrightness', 'value': 20},
        },
        estimatedSavings: 1.2,
      ),
      SmartHomeAutomation(
        id: 'temperature_optimization',
        name: 'Sıcaklık Optimizasyonu',
        description: 'Kimse yokken termostatı düşürür',
        trigger: 'location_away',
        deviceIds: ['thermostat_1'],
        actions: {
          'thermostat_1': {'action': 'setTemperature', 'value': 18.0},
        },
        estimatedSavings: 2.5,
      ),
      SmartHomeAutomation(
        id: 'morning_routine',
        name: 'Sabah Rutini',
        description: 'Sabah saatlerinde verimli enerji kullanımı',
        trigger: '07:00',
        deviceIds: ['thermostat_1', 'smart_bulb_1'],
        actions: {
          'thermostat_1': {'action': 'setTemperature', 'value': 22.0},
          'smart_bulb_1': {'action': 'turnOn', 'brightness': 100},
        },
        estimatedSavings: 0.8,
      ),
    ];

    _automations.addAll(defaultAutomations);
    await _saveAutomations();
  }

  /// Start automatic data collection from devices
  Future<void> _startDataCollection() async {
    if (!_autoDataCollection) return;

    // Simulate periodic data collection
    Timer.periodic(Duration(minutes: _dataCollectionIntervalMinutes), (timer) async {
      if (!_autoDataCollection) {
        timer.cancel();
        return;
      }
      
      await _collectDeviceData();
      await _updateCarbonCalculations();
      notifyListeners();
    });
  }

  /// Collect data from connected devices
  Future<void> _collectDeviceData() async {
    for (int i = 0; i < _devices.length; i++) {
      if (_devices[i].status != ConnectionStatus.connected) continue;

      // Simulate data updates
      Map<String, dynamic> newData = Map.from(_devices[i].data);
      
      switch (_devices[i].type) {
        case SmartDeviceType.thermostat:
          newData['temperature'] = 20.0 + Random().nextDouble() * 8.0;
          newData['humidity'] = 30 + Random().nextInt(40);
          break;
        case SmartDeviceType.smartMeter:
          newData['currentPower'] = 1500.0 + Random().nextDouble() * 2000.0;
          newData['dailyConsumption'] = 10.0 + Random().nextDouble() * 20.0;
          break;
        case SmartDeviceType.lightBulb:
          newData['brightness'] = Random().nextInt(101);
          break;
        case SmartDeviceType.smartPlug:
          newData['powerUsage'] = 50.0 + Random().nextDouble() * 150.0;
          break;
        default:
          break;
      }

      _devices[i] = _devices[i].copyWith(
        data: newData,
        lastUpdate: DateTime.now(),
      );
    }
    
    await _saveDevices();
  }

  /// Update carbon calculations based on device data
  Future<void> _updateCarbonCalculations() async {
    _dailyEnergyConsumption = 0.0;
    _dailyCarbonFromDevices = 0.0;

    for (final device in connectedDevices) {
      if (device.type == SmartDeviceType.smartMeter) {
        _dailyEnergyConsumption = device.data['dailyConsumption']?.toDouble() ?? 0.0;
      }
      
      _dailyCarbonFromDevices += device.dailyCarbonEmission;
    }

    // Update goals with smart home carbon data
    if (_dailyCarbonFromDevices > 0) {
      await _goalService.updateAllGoalsProgress(_dailyCarbonFromDevices, GoalCategory.energy);
    }

    // Check for optimization opportunities
    await _checkOptimizationOpportunities();
  }

  /// Check for energy optimization opportunities
  Future<void> _checkOptimizationOpportunities() async {
    // High energy consumption alert
    if (_dailyEnergyConsumption > 20.0) {
      await _notificationService.showSmartSuggestion(
        'Günlük enerji tüketiminiz yüksek! Termostat sıcaklığını 1°C düşürmeyi deneyin.',
      );
    }

    // Device efficiency suggestions
    final inefficientDevices = _devices.where((d) => 
      d.status == ConnectionStatus.connected && d.dailyCarbonEmission > 2.0
    ).toList();

    if (inefficientDevices.isNotEmpty) {
      await _notificationService.showSmartSuggestion(
        'Bazı cihazlarınız çok enerji tüketiyor. Akıllı otomasyonları etkinleştirin.',
      );
    }
  }

  /// Add a new smart device
  Future<void> addDevice(SmartDevice device) async {
    _devices.add(device);
    await _saveDevices();
    notifyListeners();
  }

  /// Remove a smart device
  Future<void> removeDevice(String deviceId) async {
    _devices.removeWhere((d) => d.id == deviceId);
    for (var automation in _automations) {
      automation.deviceIds.removeWhere((id) => id == deviceId);
    }
    
    await _saveDevices();
    await _saveAutomations();
    notifyListeners();
  }

  /// Update device status
  Future<void> updateDeviceStatus(String deviceId, ConnectionStatus status) async {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      _devices[index] = _devices[index].copyWith(
        status: status,
        lastUpdate: DateTime.now(),
      );
      await _saveDevices();
      notifyListeners();
    }
  }

  /// Control smart device
  Future<void> controlDevice(String deviceId, Map<String, dynamic> commands) async {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index == -1) return;

    final device = _devices[index];
    Map<String, dynamic> newData = Map.from(device.data);

    // Process commands based on device type
    switch (device.type) {
      case SmartDeviceType.thermostat:
        if (commands.containsKey('setTemperature')) {
          newData['targetTemp'] = commands['setTemperature'];
        }
        if (commands.containsKey('setMode')) {
          newData['mode'] = commands['setMode'];
        }
        break;
      case SmartDeviceType.lightBulb:
        if (commands.containsKey('turnOn')) {
          newData['isOn'] = commands['turnOn'];
        }
        if (commands.containsKey('setBrightness')) {
          newData['brightness'] = commands['setBrightness'];
        }
        if (commands.containsKey('setColor')) {
          newData['color'] = commands['setColor'];
        }
        break;
      case SmartDeviceType.smartPlug:
        if (commands.containsKey('turnOn')) {
          newData['isOn'] = commands['turnOn'];
        }
        if (commands.containsKey('turnOff')) {
          newData['isOn'] = false;
        }
        break;
      default:
        break;
    }

    _devices[index] = device.copyWith(
      data: newData,
      lastUpdate: DateTime.now(),
    );

    await _saveDevices();
    notifyListeners();
  }

  /// Execute automation
  Future<void> executeAutomation(String automationId) async {
    final automation = _automations.firstWhere(
      (a) => a.id == automationId,
      orElse: () => throw Exception('Automation not found'),
    );

    if (!automation.isEnabled) return;

    for (final deviceId in automation.deviceIds) {
      if (automation.actions.containsKey(deviceId)) {
        await controlDevice(deviceId, automation.actions[deviceId]);
      }
    }

    // Track carbon savings
    _totalSavingsFromAutomation += automation.estimatedSavings;
    
    await _notificationService.showSmartSuggestion(
      'Otomasyon "${automation.name}" çalıştırıldı. ${automation.estimatedSavings.toStringAsFixed(1)} kg CO₂ tasarruf edildi!',
    );
  }

  /// Get device statistics
  Map<String, dynamic> getDeviceStatistics() {
    final connectedCount = connectedDevices.length;
    final totalDevices = _devices.length;
    final averagePower = connectedDevices.isEmpty ? 0.0 :
        connectedDevices.map((d) => d.powerConsumption).reduce((a, b) => a + b) / connectedCount;

    return {
      'totalDevices': totalDevices,
      'connectedDevices': connectedCount,
      'disconnectedDevices': totalDevices - connectedCount,
      'averagePowerConsumption': averagePower,
      'dailyEnergyConsumption': _dailyEnergyConsumption,
      'dailyCarbonEmission': _dailyCarbonFromDevices,
      'totalAutomationSavings': _totalSavingsFromAutomation,
      'activeAutomations': enabledAutomations.length,
    };
  }

  /// Get optimization suggestions
  List<Map<String, dynamic>> getOptimizationSuggestions() {
    final suggestions = <Map<String, dynamic>>[];

    // Temperature optimization
    final thermostats = connectedDevices.where((d) => d.type == SmartDeviceType.thermostat).toList();
    for (final thermostat in thermostats) {
      final currentTemp = thermostat.data['targetTemp']?.toDouble() ?? 22.0;
      if (currentTemp > 22.0) {
        suggestions.add({
          'type': 'temperature',
          'device': thermostat.name,
          'suggestion': 'Termostat sıcaklığını ${(currentTemp - 1).toStringAsFixed(0)}°C\'ye düşürün',
          'savings': '~${(0.07 * (currentTemp - 21)).toStringAsFixed(1)} kg CO₂/gün',
          'icon': Icons.thermostat,
          'priority': 'high',
        });
      }
    }

    // Smart plug scheduling
    final smartPlugs = connectedDevices.where((d) => d.type == SmartDeviceType.smartPlug).toList();
    for (final plug in smartPlugs) {
      if (!plug.data.containsKey('schedule') || !plug.data['schedule']['enabled']) {
        suggestions.add({
          'type': 'scheduling',
          'device': plug.name,
          'suggestion': 'Zamanlayıcı ayarlayarak gece otomatik kapanmasını sağlayın',
          'savings': '~0.5 kg CO₂/gün',
          'icon': Icons.schedule,
          'priority': 'medium',
        });
      }
    }

    // Lighting optimization
    final lightBulbs = connectedDevices.where((d) => d.type == SmartDeviceType.lightBulb).toList();
    for (final bulb in lightBulbs) {
      final brightness = bulb.data['brightness']?.toInt() ?? 100;
      if (brightness > 80) {
        suggestions.add({
          'type': 'lighting',
          'device': bulb.name,
          'suggestion': 'Parlaklığı %70\'e düşürün, %10 enerji tasarrufu sağlar',
          'savings': '~0.1 kg CO₂/gün',
          'icon': Icons.lightbulb,
          'priority': 'low',
        });
      }
    }

    return suggestions;
  }

  /// Update settings
  Future<void> updateSettings({
    bool? homeKitEnabled,
    bool? googleHomeEnabled,
    bool? autoDataCollection,
    int? dataCollectionIntervalMinutes,
  }) async {
    if (homeKitEnabled != null) {
      _homeKitEnabled = homeKitEnabled;
    }
    if (googleHomeEnabled != null) {
      _googleHomeEnabled = googleHomeEnabled;
    }
    if (autoDataCollection != null) {
      _autoDataCollection = autoDataCollection;
      if (_autoDataCollection) {
        await _startDataCollection();
      }
    }
    if (dataCollectionIntervalMinutes != null) {
      _dataCollectionIntervalMinutes = dataCollectionIntervalMinutes;
    }
    
    await _saveSettings();
    notifyListeners();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _homeKitEnabled = prefs.getBool('homekit_enabled') ?? false;
      _googleHomeEnabled = prefs.getBool('google_home_enabled') ?? false;
      _autoDataCollection = prefs.getBool('auto_data_collection') ?? true;
      _dataCollectionIntervalMinutes = prefs.getInt('data_collection_interval') ?? 15;
    } catch (e) {
      debugPrint('Error loading smart home settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('homekit_enabled', _homeKitEnabled);
      await prefs.setBool('google_home_enabled', _googleHomeEnabled);
      await prefs.setBool('auto_data_collection', _autoDataCollection);
      await prefs.setInt('data_collection_interval', _dataCollectionIntervalMinutes);
    } catch (e) {
      debugPrint('Error saving smart home settings: $e');
    }
  }

  /// Load devices from SharedPreferences
  Future<void> _loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = prefs.getString('smart_devices');
      
      if (devicesJson != null) {
        final devicesList = jsonDecode(devicesJson) as List;
        _devices = devicesList.map((json) => SmartDevice.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading smart devices: $e');
    }
  }

  /// Save devices to SharedPreferences
  Future<void> _saveDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = jsonEncode(_devices.map((d) => d.toJson()).toList());
      await prefs.setString('smart_devices', devicesJson);
    } catch (e) {
      debugPrint('Error saving smart devices: $e');
    }
  }

  /// Load automations from SharedPreferences
  Future<void> _loadAutomations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final automationsJson = prefs.getString('smart_automations');
      
      if (automationsJson != null) {
        final automationsList = jsonDecode(automationsJson) as List;
        _automations = automationsList.map((json) => SmartHomeAutomation.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading smart automations: $e');
    }
  }

  /// Save automations to SharedPreferences
  Future<void> _saveAutomations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final automationsJson = jsonEncode(_automations.map((a) => a.toJson()).toList());
      await prefs.setString('smart_automations', automationsJson);
    } catch (e) {
      debugPrint('Error saving smart automations: $e');
    }
  }
}