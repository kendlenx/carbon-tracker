import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'database_service.dart';
import 'goal_service.dart';
import 'notification_service.dart';
import 'voice_service.dart';

enum DeviceType {
  appleWatch,
  wearOS,
  siriShortcuts,
  googleAssistant,
  carPlay,
  androidAuto,
  smartphone,
}

enum IntegrationStatus {
  connected,
  disconnected,
  pairing,
  syncing,
  error,
}

class DeviceIntegration {
  final String id;
  final String name;
  final DeviceType type;
  final IntegrationStatus status;
  final DateTime lastSync;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> settings;
  final bool isEnabled;

  DeviceIntegration({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.lastSync,
    required this.capabilities,
    required this.settings,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'status': status.name,
      'lastSync': lastSync.toIso8601String(),
      'capabilities': capabilities,
      'settings': settings,
      'isEnabled': isEnabled,
    };
  }

  factory DeviceIntegration.fromJson(Map<String, dynamic> json) {
    return DeviceIntegration(
      id: json['id'],
      name: json['name'],
      type: DeviceType.values.firstWhere((e) => e.name == json['type']),
      status: IntegrationStatus.values.firstWhere((e) => e.name == json['status']),
      lastSync: DateTime.parse(json['lastSync']),
      capabilities: json['capabilities'],
      settings: json['settings'],
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  DeviceIntegration copyWith({
    String? id,
    String? name,
    DeviceType? type,
    IntegrationStatus? status,
    DateTime? lastSync,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? settings,
    bool? isEnabled,
  }) {
    return DeviceIntegration(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      lastSync: lastSync ?? this.lastSync,
      capabilities: capabilities ?? this.capabilities,
      settings: settings ?? this.settings,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class ShortcutAction {
  final String id;
  final String name;
  final String phrase;
  final String actionType; // log_activity, get_stats, set_goal, etc.
  final Map<String, dynamic> parameters;
  final IconData icon;
  final bool isEnabled;

  ShortcutAction({
    required this.id,
    required this.name,
    required this.phrase,
    required this.actionType,
    required this.parameters,
    required this.icon,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phrase': phrase,
      'actionType': actionType,
      'parameters': parameters,
      'icon': icon.codePoint,
      'isEnabled': isEnabled,
    };
  }

  factory ShortcutAction.fromJson(Map<String, dynamic> json) {
    return ShortcutAction(
      id: json['id'],
      name: json['name'],
      phrase: json['phrase'],
      actionType: json['actionType'],
      parameters: json['parameters'],
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      isEnabled: json['isEnabled'] ?? true,
    );
  }
}

class DeviceIntegrationService extends ChangeNotifier {
  static DeviceIntegrationService? _instance;
  static DeviceIntegrationService get instance => _instance ??= DeviceIntegrationService._();
  
  DeviceIntegrationService._();

  // Services
  final DatabaseService _databaseService = DatabaseService.instance;
  final GoalService _goalService = GoalService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final VoiceService _voiceService = VoiceService.instance;

  // Platform channels
  static const MethodChannel _methodChannel = MethodChannel('carbon_tracker/device_integration');
  static const EventChannel _eventChannel = EventChannel('carbon_tracker/device_events');

  // Integration data
  List<DeviceIntegration> _integrations = [];
  List<ShortcutAction> _shortcuts = [];
  bool _isInitialized = false;
  StreamSubscription? _deviceEventSubscription;

  // Statistics
  int _totalSyncCount = 0;
  int _totalShortcutUsage = 0;
  DateTime? _lastWatchSync;
  DateTime? _lastCarPlaySync;

  // Getters
  List<DeviceIntegration> get integrations => _integrations;
  List<DeviceIntegration> get connectedDevices => _integrations.where((d) => d.status == IntegrationStatus.connected).toList();
  List<ShortcutAction> get shortcuts => _shortcuts;
  List<ShortcutAction> get enabledShortcuts => _shortcuts.where((s) => s.isEnabled).toList();
  bool get isInitialized => _isInitialized;
  int get totalSyncCount => _totalSyncCount;
  int get totalShortcutUsage => _totalShortcutUsage;
  DateTime? get lastWatchSync => _lastWatchSync;
  DateTime? get lastCarPlaySync => _lastCarPlaySync;

  /// Initialize device integration service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadIntegrations();
    await _loadShortcuts();
    await _loadStatistics();
    await _setupDefaultIntegrations();
    await _setupDefaultShortcuts();
    await _setupDeviceEventHandlers();
    await _registerShortcuts();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Setup default device integrations
  Future<void> _setupDefaultIntegrations() async {
    if (_integrations.isNotEmpty) return;

    final defaultIntegrations = [
      DeviceIntegration(
        id: 'apple_watch_1',
        name: 'Apple Watch',
        type: DeviceType.appleWatch,
        status: IntegrationStatus.disconnected,
        lastSync: DateTime.now().subtract(const Duration(hours: 1)),
        capabilities: {
          'health_data': true,
          'workout_tracking': true,
          'notifications': true,
          'complications': true,
          'haptic_feedback': true,
        },
        settings: {
          'sync_interval': 300, // 5 minutes
          'auto_track_workouts': true,
          'show_complications': true,
          'haptic_enabled': true,
        },
      ),
      DeviceIntegration(
        id: 'wear_os_1',
        name: 'Wear OS Watch',
        type: DeviceType.wearOS,
        status: IntegrationStatus.disconnected,
        lastSync: DateTime.now().subtract(const Duration(hours: 2)),
        capabilities: {
          'health_data': true,
          'fitness_tracking': true,
          'notifications': true,
          'tiles': true,
          'voice_actions': true,
        },
        settings: {
          'sync_interval': 300,
          'auto_track_fitness': true,
          'show_tiles': true,
          'voice_enabled': true,
        },
      ),
      DeviceIntegration(
        id: 'siri_shortcuts_1',
        name: 'Siri Shortcuts',
        type: DeviceType.siriShortcuts,
        status: IntegrationStatus.connected,
        lastSync: DateTime.now(),
        capabilities: {
          'voice_commands': true,
          'workflow_automation': true,
          'quick_actions': true,
          'background_sync': true,
        },
        settings: {
          'auto_register': true,
          'background_refresh': true,
          'confirmation_required': false,
        },
      ),
      DeviceIntegration(
        id: 'google_assistant_1',
        name: 'Google Assistant',
        type: DeviceType.googleAssistant,
        status: IntegrationStatus.connected,
        lastSync: DateTime.now(),
        capabilities: {
          'voice_commands': true,
          'smart_home_integration': true,
          'routine_actions': true,
          'conversational_actions': true,
        },
        settings: {
          'auto_register': true,
          'context_awareness': true,
          'conversation_memory': true,
        },
      ),
      DeviceIntegration(
        id: 'carplay_1',
        name: 'CarPlay',
        type: DeviceType.carPlay,
        status: IntegrationStatus.disconnected,
        lastSync: DateTime.now().subtract(const Duration(days: 1)),
        capabilities: {
          'transport_tracking': true,
          'voice_commands': true,
          'route_optimization': true,
          'fuel_efficiency': true,
        },
        settings: {
          'auto_track_trips': true,
          'voice_feedback': true,
          'route_suggestions': true,
          'eco_mode_alerts': true,
        },
      ),
    ];

    _integrations.addAll(defaultIntegrations);
    await _saveIntegrations();
  }

  /// Setup default shortcuts
  Future<void> _setupDefaultShortcuts() async {
    if (_shortcuts.isNotEmpty) return;

    final defaultShortcuts = [
      ShortcutAction(
        id: 'log_transport',
        name: 'Ulaşım Kaydı',
        phrase: 'Karbon kaydı ulaşım',
        actionType: 'log_transport',
        parameters: {'category': 'transport'},
        icon: Icons.directions_car,
      ),
      ShortcutAction(
        id: 'daily_stats',
        name: 'Günlük İstatistikler',
        phrase: 'Bugünkü karbon ayak izim',
        actionType: 'get_daily_stats',
        parameters: {},
        icon: Icons.bar_chart,
      ),
      ShortcutAction(
        id: 'set_goal',
        name: 'Hedef Belirleme',
        phrase: 'Karbon hedefi belirle',
        actionType: 'set_carbon_goal',
        parameters: {},
        icon: Icons.flag,
      ),
      ShortcutAction(
        id: 'eco_tips',
        name: 'Ekolojik İpuçları',
        phrase: 'Çevre dostu öneriler',
        actionType: 'get_eco_tips',
        parameters: {},
        icon: Icons.eco,
      ),
      ShortcutAction(
        id: 'weekly_report',
        name: 'Haftalık Rapor',
        phrase: 'Haftalık karbon raporu',
        actionType: 'get_weekly_report',
        parameters: {},
        icon: Icons.assessment,
      ),
      ShortcutAction(
        id: 'voice_log',
        name: 'Sesli Kayıt',
        phrase: 'Sesli karbon kaydı',
        actionType: 'voice_activity_log',
        parameters: {},
        icon: Icons.mic,
      ),
    ];

    _shortcuts.addAll(defaultShortcuts);
    await _saveShortcuts();
  }

  /// Setup device event handlers
  Future<void> _setupDeviceEventHandlers() async {
    try {
      _deviceEventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleDeviceEvent,
        onError: (error) {
          print('Device event stream error: $error');
        },
      );
    } catch (e) {
      print('Error setting up device event handlers: $e');
    }
  }

  /// Handle device events
  void _handleDeviceEvent(dynamic event) {
    try {
      final eventData = Map<String, dynamic>.from(event);
      final eventType = eventData['type'] as String;

      switch (eventType) {
        case 'watch_connection':
          _handleWatchConnection(eventData);
          break;
        case 'carplay_connection':
          _handleCarPlayConnection(eventData);
          break;
        case 'shortcut_invoked':
          _handleShortcutInvocation(eventData);
          break;
        case 'health_data_sync':
          _handleHealthDataSync(eventData);
          break;
        default:
          print('Unknown device event type: $eventType');
      }
    } catch (e) {
      print('Error handling device event: $e');
    }
  }

  /// Handle watch connection events
  void _handleWatchConnection(Map<String, dynamic> eventData) {
    final connected = eventData['connected'] as bool;
    final watchIntegration = _integrations.firstWhere(
      (i) => i.type == DeviceType.appleWatch || i.type == DeviceType.wearOS,
      orElse: () => throw Exception('Watch integration not found'),
    );

    final index = _integrations.indexOf(watchIntegration);
    if (index != -1) {
      _integrations[index] = watchIntegration.copyWith(
        status: connected ? IntegrationStatus.connected : IntegrationStatus.disconnected,
        lastSync: DateTime.now(),
      );

      if (connected) {
        _lastWatchSync = DateTime.now();
        _syncWithWatch();
      }

      notifyListeners();
    }
  }

  /// Handle CarPlay connection events
  void _handleCarPlayConnection(Map<String, dynamic> eventData) {
    final connected = eventData['connected'] as bool;
    final carPlayIntegration = _integrations.firstWhere(
      (i) => i.type == DeviceType.carPlay || i.type == DeviceType.androidAuto,
      orElse: () => throw Exception('CarPlay integration not found'),
    );

    final index = _integrations.indexOf(carPlayIntegration);
    if (index != -1) {
      _integrations[index] = carPlayIntegration.copyWith(
        status: connected ? IntegrationStatus.connected : IntegrationStatus.disconnected,
        lastSync: DateTime.now(),
      );

      if (connected) {
        _lastCarPlaySync = DateTime.now();
        _enableCarMode();
      } else {
        _disableCarMode();
      }

      notifyListeners();
    }
  }

  /// Handle shortcut invocations
  Future<void> _handleShortcutInvocation(Map<String, dynamic> eventData) async {
    final shortcutId = eventData['shortcut_id'] as String;
    final parameters = eventData['parameters'] as Map<String, dynamic>?;

    _totalShortcutUsage++;
    await _saveStatistics();

    final shortcut = _shortcuts.firstWhere(
      (s) => s.id == shortcutId,
      orElse: () => throw Exception('Shortcut not found'),
    );

    await _executeShortcutAction(shortcut, parameters ?? {});
  }

  /// Handle health data sync
  Future<void> _handleHealthDataSync(Map<String, dynamic> eventData) async {
    final healthData = eventData['health_data'] as Map<String, dynamic>;
    
    // Process health data for carbon footprint calculation
    if (healthData.containsKey('steps')) {
      final steps = healthData['steps'] as int;
      final walkingDistance = steps * 0.0008; // Approximate km per step
      final carbonSaved = walkingDistance * 0.12; // kg CO₂ saved vs car
      
      // Log walking activity
      await _databaseService.addActivity({
        'type': 'Yürüme',
        'distance': walkingDistance,
        'carbonFootprint': -carbonSaved, // Negative because it's saved
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'health_sync',
      });

      await _notificationService.showSmartSuggestion(
        'Harika! ${steps} adım atarak ${carbonSaved.toStringAsFixed(2)} kg CO₂ tasarruf ettiniz!',
      );
    }

    _totalSyncCount++;
    await _saveStatistics();
    notifyListeners();
  }

  /// Sync data with Apple Watch/Wear OS
  Future<void> _syncWithWatch() async {
    try {
      final todayStats = await _databaseService.getDashboardStats();
      final goals = _goalService.getAllGoals();

      await _methodChannel.invokeMethod('syncWatchData', {
        'todayCarbon': todayStats['todayTotal'],
        'weeklyAverage': todayStats['weeklyAverage'],
        'goals': goals.map((g) => g.toJson()).toList(),
      });

      _lastWatchSync = DateTime.now();
    } catch (e) {
      print('Error syncing with watch: $e');
    }
  }

  /// Enable car mode
  Future<void> _enableCarMode() async {
    try {
      await _methodChannel.invokeMethod('enableCarMode', {
        'ecoMode': true,
        'voiceCommands': true,
        'autoTracking': true,
      });

      await _notificationService.showSmartSuggestion(
        'Araç modu etkinleştirildi. Sürüş verileriniz otomatik olarak kaydedilecek.',
      );
    } catch (e) {
      print('Error enabling car mode: $e');
    }
  }

  /// Disable car mode
  Future<void> _disableCarMode() async {
    try {
      await _methodChannel.invokeMethod('disableCarMode');
    } catch (e) {
      print('Error disabling car mode: $e');
    }
  }

  /// Register shortcuts with system
  Future<void> _registerShortcuts() async {
    try {
      for (final shortcut in enabledShortcuts) {
        await _methodChannel.invokeMethod('registerShortcut', {
          'id': shortcut.id,
          'name': shortcut.name,
          'phrase': shortcut.phrase,
          'actionType': shortcut.actionType,
          'parameters': shortcut.parameters,
        });
      }
    } catch (e) {
      print('Error registering shortcuts: $e');
    }
  }

  /// Execute shortcut action
  Future<void> _executeShortcutAction(ShortcutAction shortcut, Map<String, dynamic> parameters) async {
    try {
      switch (shortcut.actionType) {
        case 'log_transport':
          await _handleLogTransportShortcut(parameters);
          break;
        case 'get_daily_stats':
          await _handleDailyStatsShortcut();
          break;
        case 'set_carbon_goal':
          await _handleSetGoalShortcut(parameters);
          break;
        case 'get_eco_tips':
          await _handleEcoTipsShortcut();
          break;
        case 'get_weekly_report':
          await _handleWeeklyReportShortcut();
          break;
        case 'voice_activity_log':
          await _handleVoiceLogShortcut();
          break;
        default:
          print('Unknown shortcut action: ${shortcut.actionType}');
      }
    } catch (e) {
      print('Error executing shortcut action: $e');
    }
  }

  /// Handle transport logging shortcut
  Future<void> _handleLogTransportShortcut(Map<String, dynamic> parameters) async {
    // For now, trigger voice logging
    await _voiceService.startListening();
  }

  /// Handle daily stats shortcut
  Future<void> _handleDailyStatsShortcut() async {
    final stats = await _databaseService.getDashboardStats();
    await _voiceService.speak(
      'Bugünkü karbon ayak iziniz ${stats['todayTotal'].toStringAsFixed(1)} kilogram CO2. '
      'Haftalık ortalamanız ${stats['weeklyAverage'].toStringAsFixed(1)} kilogram.',
    );
  }

  /// Handle set goal shortcut
  Future<void> _handleSetGoalShortcut(Map<String, dynamic> parameters) async {
    await _voiceService.speak('Hangi tür hedef belirlemek istiyorsunuz? Günlük, haftalık veya aylık?');
    await _voiceService.startListening();
  }

  /// Handle eco tips shortcut
  Future<void> _handleEcoTipsShortcut() async {
    final tips = [
      'Toplu taşıma kullanarak günde 2-3 kg CO2 tasarruf edebilirsiniz.',
      'Evinizdeki termostatı 1 derece düşürerek yıllık 200 kg CO2 tasarrufu yapabilirsiniz.',
      'Yerel ve mevsimlik ürünler tüketerek karbon ayak izinizi %20 azaltabilirsiniz.',
    ];
    
    final randomTip = tips[(DateTime.now().millisecondsSinceEpoch % tips.length)];
    await _voiceService.speak('İşte size bir çevre dostu öneri: $randomTip');
  }

  /// Handle weekly report shortcut
  Future<void> _handleWeeklyReportShortcut() async {
    final stats = await _databaseService.getDashboardStats();
    final weeklyTotal = stats['weeklyAverage'] * 7;
    
    await _voiceService.speak(
      'Bu hafta toplam ${weeklyTotal.toStringAsFixed(1)} kilogram CO2 ürettiniz. '
      'Geçen haftaya göre %5 azalma var. Harika ilerliyorsunuz!',
    );
  }

  /// Handle voice log shortcut
  Future<void> _handleVoiceLogShortcut() async {
    await _voiceService.speak('Hangi aktiviteyi kaydetmek istiyorsunuz?');
    await _voiceService.startListening();
  }

  /// Add new device integration
  Future<void> addIntegration(DeviceIntegration integration) async {
    _integrations.add(integration);
    await _saveIntegrations();
    notifyListeners();
  }

  /// Remove device integration
  Future<void> removeIntegration(String integrationId) async {
    _integrations.removeWhere((i) => i.id == integrationId);
    await _saveIntegrations();
    notifyListeners();
  }

  /// Update integration status
  Future<void> updateIntegrationStatus(String integrationId, IntegrationStatus status) async {
    final index = _integrations.indexWhere((i) => i.id == integrationId);
    if (index != -1) {
      _integrations[index] = _integrations[index].copyWith(
        status: status,
        lastSync: DateTime.now(),
      );
      await _saveIntegrations();
      notifyListeners();
    }
  }

  /// Get integration statistics
  Map<String, dynamic> getIntegrationStatistics() {
    final connectedCount = connectedDevices.length;
    final totalIntegrations = _integrations.length;
    final watchConnected = _integrations.any((i) => 
        (i.type == DeviceType.appleWatch || i.type == DeviceType.wearOS) && 
        i.status == IntegrationStatus.connected);
    final carModeActive = _integrations.any((i) => 
        (i.type == DeviceType.carPlay || i.type == DeviceType.androidAuto) && 
        i.status == IntegrationStatus.connected);

    return {
      'totalIntegrations': totalIntegrations,
      'connectedDevices': connectedCount,
      'watchConnected': watchConnected,
      'carModeActive': carModeActive,
      'totalSyncCount': _totalSyncCount,
      'totalShortcutUsage': _totalShortcutUsage,
      'lastWatchSync': _lastWatchSync?.toIso8601String(),
      'lastCarPlaySync': _lastCarPlaySync?.toIso8601String(),
    };
  }

  /// Load integrations from SharedPreferences
  Future<void> _loadIntegrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final integrationsJson = prefs.getString('device_integrations');
      
      if (integrationsJson != null) {
        final integrationsList = jsonDecode(integrationsJson) as List;
        _integrations = integrationsList.map((json) => DeviceIntegration.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading device integrations: $e');
    }
  }

  /// Save integrations to SharedPreferences
  Future<void> _saveIntegrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final integrationsJson = jsonEncode(_integrations.map((i) => i.toJson()).toList());
      await prefs.setString('device_integrations', integrationsJson);
    } catch (e) {
      print('Error saving device integrations: $e');
    }
  }

  /// Load shortcuts from SharedPreferences
  Future<void> _loadShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = prefs.getString('device_shortcuts');
      
      if (shortcutsJson != null) {
        final shortcutsList = jsonDecode(shortcutsJson) as List;
        _shortcuts = shortcutsList.map((json) => ShortcutAction.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading device shortcuts: $e');
    }
  }

  /// Save shortcuts to SharedPreferences
  Future<void> _saveShortcuts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shortcutsJson = jsonEncode(_shortcuts.map((s) => s.toJson()).toList());
      await prefs.setString('device_shortcuts', shortcutsJson);
    } catch (e) {
      print('Error saving device shortcuts: $e');
    }
  }

  /// Load statistics from SharedPreferences
  Future<void> _loadStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSyncCount = prefs.getInt('total_sync_count') ?? 0;
      _totalShortcutUsage = prefs.getInt('total_shortcut_usage') ?? 0;
      
      final lastWatchSyncString = prefs.getString('last_watch_sync');
      if (lastWatchSyncString != null) {
        _lastWatchSync = DateTime.parse(lastWatchSyncString);
      }
      
      final lastCarPlaySyncString = prefs.getString('last_carplay_sync');
      if (lastCarPlaySyncString != null) {
        _lastCarPlaySync = DateTime.parse(lastCarPlaySyncString);
      }
    } catch (e) {
      print('Error loading device integration statistics: $e');
    }
  }

  /// Save statistics to SharedPreferences
  Future<void> _saveStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_sync_count', _totalSyncCount);
      await prefs.setInt('total_shortcut_usage', _totalShortcutUsage);
      
      if (_lastWatchSync != null) {
        await prefs.setString('last_watch_sync', _lastWatchSync!.toIso8601String());
      }
      
      if (_lastCarPlaySync != null) {
        await prefs.setString('last_carplay_sync', _lastCarPlaySync!.toIso8601String());
      }
    } catch (e) {
      print('Error saving device integration statistics: $e');
    }
  }

  @override
  void dispose() {
    _deviceEventSubscription?.cancel();
    super.dispose();
  }
}