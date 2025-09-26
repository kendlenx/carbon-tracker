import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'carplay_service.dart';
import 'language_service.dart';
import 'database_service.dart';
import '../models/transport_activity.dart';

/// Siri Shortcuts integration for CarPlay
class CarPlaySiriService {
  static CarPlaySiriService? _instance;
  static CarPlaySiriService get instance => _instance ??= CarPlaySiriService._();
  
  CarPlaySiriService._();

  static const MethodChannel _channel = MethodChannel('carbon_tracker/siri_shortcuts');
  
  final CarPlayService _carPlayService = CarPlayService.instance;
  final LanguageService _languageService = LanguageService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;

  /// Initialize Siri Shortcuts
  Future<void> initialize() async {
    try {
      // Setup method call handler for Siri -> Flutter communication
      _channel.setMethodCallHandler(_handleSiriIntent);
      
      // Donate shortcuts to Siri
      await _donateShortcuts();
      
      debugPrint('CarPlay Siri service initialized');
    } catch (e) {
      debugPrint('Failed to initialize CarPlay Siri service: $e');
    }
  }

  /// Donate shortcuts to Siri for voice recognition
  Future<void> _donateShortcuts() async {
    try {
      final isEnglish = _languageService.isEnglish;
      
      final shortcuts = [
        // Start trip shortcut
        {
          'identifier': 'start_trip',
          'title': isEnglish ? 'Start Trip' : 'Seyahat Başlat',
          'subtitle': isEnglish ? 'Begin tracking your journey' : 'Yolculuğunuzu takip etmeye başlayın',
          'phrases': isEnglish 
              ? ['Start trip', 'Begin journey', 'Start tracking', 'Start driving']
              : ['Seyahat başlat', 'Yolculuk başlat', 'Takip başlat', 'Sürüş başlat'],
          'systemImageName': 'car.fill',
          'category': 'travel',
        },
        
        // End trip shortcut
        {
          'identifier': 'end_trip',
          'title': isEnglish ? 'End Trip' : 'Seyahat Bitir',
          'subtitle': isEnglish ? 'Finish and save your journey' : 'Yolculuğunuzu bitirin ve kaydedin',
          'phrases': isEnglish 
              ? ['End trip', 'Stop tracking', 'Finish journey', 'Stop driving']
              : ['Seyahat bitir', 'Takip durdur', 'Yolculuk bitir', 'Sürüş durdur'],
          'systemImageName': 'stop.circle.fill',
          'category': 'travel',
        },
        
        // Check CO2 shortcut
        {
          'identifier': 'check_co2',
          'title': isEnglish ? 'Check CO₂ Status' : 'CO₂ Durumu Kontrol Et',
          'subtitle': isEnglish ? 'View your carbon footprint' : 'Karbon ayak izinizi görüntüleyin',
          'phrases': isEnglish 
              ? ['Check CO2', 'Show emissions', 'Carbon footprint', 'Check pollution']
              : ['CO2 kontrol et', 'Emisyonları göster', 'Karbon ayak izi', 'Kirlilik kontrol'],
          'systemImageName': 'leaf.fill',
          'category': 'information',
        },
        
        // Get route suggestions shortcut
        {
          'identifier': 'eco_route',
          'title': isEnglish ? 'Get Eco Route' : 'Çevreci Rota Al',
          'subtitle': isEnglish ? 'Find the most eco-friendly route' : 'En çevre dostu rotayı bulun',
          'phrases': isEnglish 
              ? ['Eco route', 'Green route', 'Efficient route', 'Best route']
              : ['Çevreci rota', 'Yeşil rota', 'Verimli rota', 'En iyi rota'],
          'systemImageName': 'map.fill',
          'category': 'navigation',
        },
        
        // Quick status shortcut
        {
          'identifier': 'quick_status',
          'title': isEnglish ? 'Quick Status' : 'Hızlı Durum',
          'subtitle': isEnglish ? 'Get a summary of your day' : 'Gününüzün özetini alın',
          'phrases': isEnglish 
              ? ['Quick status', 'Daily summary', 'Today status', 'Show stats']
              : ['Hızlı durum', 'Günlük özet', 'Bugünkü durum', 'İstatistikleri göster'],
          'systemImageName': 'chart.bar.fill',
          'category': 'information',
        },
        
        // Add manual trip shortcut
        {
          'identifier': 'add_manual_trip',
          'title': isEnglish ? 'Add Manual Trip' : 'Manuel Seyahat Ekle',
          'subtitle': isEnglish ? 'Add a trip you forgot to track' : 'Takip etmeyi unuttuğunuz bir seyahat ekleyin',
          'phrases': isEnglish 
              ? ['Add trip', 'Log trip', 'Record journey', 'Add manual trip']
              : ['Seyahat ekle', 'Seyahat kaydet', 'Yolculuk kaydet', 'Manuel seyahat ekle'],
          'systemImageName': 'plus.circle.fill',
          'category': 'travel',
        },
      ];

      await _channel.invokeMethod('donateShortcuts', {
        'shortcuts': shortcuts,
        'language': isEnglish ? 'en' : 'tr',
      });
      
      debugPrint('Donated ${shortcuts.length} shortcuts to Siri');
    } catch (e) {
      debugPrint('Failed to donate shortcuts: $e');
    }
  }

  /// Handle Siri intent recognition
  Future<dynamic> _handleSiriIntent(MethodCall call) async {
    try {
      final intentType = call.arguments['intentType'] as String?;
      final parameters = call.arguments['parameters'] as Map<String, dynamic>? ?? {};
      
      debugPrint('Received Siri intent: $intentType with parameters: $parameters');
      
      switch (intentType) {
        case 'start_trip':
          return await _handleStartTripIntent(parameters);
        case 'end_trip':
          return await _handleEndTripIntent(parameters);
        case 'check_co2':
          return await _handleCheckCO2Intent(parameters);
        case 'eco_route':
          return await _handleEcoRouteIntent(parameters);
        case 'quick_status':
          return await _handleQuickStatusIntent(parameters);
        case 'add_manual_trip':
          return await _handleAddManualTripIntent(parameters);
        default:
          return _createErrorResponse('Unknown intent: $intentType');
      }
    } catch (e) {
      debugPrint('Error handling Siri intent: $e');
      return _createErrorResponse('Failed to process voice command: $e');
    }
  }

  /// Handle start trip intent
  Future<Map<String, dynamic>> _handleStartTripIntent(Map<String, dynamic> parameters) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
      if (_carPlayService.isTripActive) {
        return _createResponse(
          success: false,
          message: isEnglish ? 'Trip is already active' : 'Seyahat zaten aktif',
          speakableText: isEnglish ? 'You already have an active trip' : 'Zaten aktif bir seyahatiniz var',
        );
      }

      await _carPlayService.startTrip();
      
      return _createResponse(
        success: true,
        message: isEnglish ? 'Trip started successfully' : 'Seyahat başarıyla başlatıldı',
        speakableText: isEnglish ? 'Trip started. I\'ll track your journey.' : 'Seyahat başladı. Yolculuğunuzu takip edeceğim.',
        data: {
          'tripActive': true,
          'startTime': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      return _createErrorResponse(
        isEnglish ? 'Failed to start trip' : 'Seyahat başlatılamadı',
      );
    }
  }

  /// Handle end trip intent
  Future<Map<String, dynamic>> _handleEndTripIntent(Map<String, dynamic> parameters) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
      if (!_carPlayService.isTripActive) {
        return _createResponse(
          success: false,
          message: isEnglish ? 'No active trip to end' : 'Bitirilecek aktif seyahat yok',
          speakableText: isEnglish ? 'You don\'t have an active trip' : 'Aktif bir seyahatiniz bulunmuyor',
        );
      }

      final distance = _carPlayService.currentTripDistance;
      final duration = _carPlayService.currentTripDuration;
      
      await _carPlayService.endTrip();
      
      return _createResponse(
        success: true,
        message: isEnglish ? 'Trip ended successfully' : 'Seyahat başarıyla bitirildi',
        speakableText: isEnglish 
            ? 'Trip ended. You traveled ${distance.toStringAsFixed(1)} kilometers in $duration minutes.'
            : 'Seyahat bitti. $duration dakikada ${distance.toStringAsFixed(1)} kilometre yol aldınız.',
        data: {
          'distance': distance,
          'duration': duration,
          'co2': distance * 0.2, // Estimated CO2
        },
      );
    } catch (e) {
      return _createErrorResponse(
        isEnglish ? 'Failed to end trip' : 'Seyahat bitirilemedi',
      );
    }
  }

  /// Handle check CO2 intent
  Future<Map<String, dynamic>> _handleCheckCO2Intent(Map<String, dynamic> parameters) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
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

      final totalDistance = activities.fold<double>(
        0.0,
        (sum, activity) => sum + activity.distanceKm,
      );

      String statusMessage;
      String speakableText;

      if (todayCO2 < 5.0) {
        statusMessage = isEnglish ? 'Great job! Low emissions today.' : 'Harika! Bugün düşük emisyon.';
        speakableText = isEnglish 
            ? 'Great job! Your carbon emissions today are ${todayCO2.toStringAsFixed(1)} kilograms. Keep it up!'
            : 'Harika! Bugünkü karbon emisyonunuz ${todayCO2.toStringAsFixed(1)} kilogram. Böyle devam edin!';
      } else if (todayCO2 < 15.0) {
        statusMessage = isEnglish ? 'Moderate emissions today.' : 'Bugün orta seviye emisyon.';
        speakableText = isEnglish 
            ? 'Your carbon emissions today are ${todayCO2.toStringAsFixed(1)} kilograms. Consider using more eco-friendly transport.'
            : 'Bugünkü karbon emisyonunuz ${todayCO2.toStringAsFixed(1)} kilogram. Daha çevre dostu ulaşım kullanmayı düşünün.';
      } else {
        statusMessage = isEnglish ? 'High emissions today.' : 'Bugün yüksek emisyon.';
        speakableText = isEnglish 
            ? 'Your carbon emissions today are ${todayCO2.toStringAsFixed(1)} kilograms. Try to use public transport or walk more.'
            : 'Bugünkü karbon emisyonunuz ${todayCO2.toStringAsFixed(1)} kilogram. Toplu taşıma kullanmaya veya daha fazla yürümeye çalışın.';
      }

      return _createResponse(
        success: true,
        message: statusMessage,
        speakableText: speakableText,
        data: {
          'todayCO2': todayCO2,
          'totalDistance': totalDistance,
          'activitiesCount': activities.length,
          'status': todayCO2 < 5.0 ? 'good' : todayCO2 < 15.0 ? 'moderate' : 'high',
        },
      );
    } catch (e) {
      return _createErrorResponse(
        isEnglish ? 'Failed to get CO₂ status' : 'CO₂ durumu alınamadı',
      );
    }
  }

  /// Handle eco route intent
  Future<Map<String, dynamic>> _handleEcoRouteIntent(Map<String, dynamic> parameters) async {
    final isEnglish = _languageService.isEnglish;
    
    // Extract destination from parameters (if provided)
    final destination = parameters['destination'] as String?;
    
    try {
      // For now, provide general eco-friendly routing suggestions
      final suggestions = [
        isEnglish ? 'Choose routes with less traffic' : 'Daha az trafikli rotaları seçin',
        isEnglish ? 'Maintain steady speeds' : 'Sabit hızlarda sürün',
        isEnglish ? 'Avoid excessive acceleration' : 'Aşırı hızlanmaktan kaçının',
        isEnglish ? 'Use cruise control on highways' : 'Otoyollarda hız sabitleyici kullanın',
      ];
      
      final randomSuggestion = suggestions[DateTime.now().millisecond % suggestions.length];
      
      return _createResponse(
        success: true,
        message: isEnglish ? 'Eco-friendly routing tips' : 'Çevre dostu rota ipuçları',
        speakableText: isEnglish 
            ? 'For eco-friendly driving, $randomSuggestion. This can reduce your carbon footprint by up to 20%.'
            : 'Çevre dostu sürüş için, $randomSuggestion. Bu karbon ayak izinizi %20\'ye kadar azaltabilir.',
        data: {
          'suggestion': randomSuggestion,
          'destination': destination,
          'estimatedCO2Reduction': '15-20%',
        },
      );
    } catch (e) {
      return _createErrorResponse(
        isEnglish ? 'Failed to get route suggestions' : 'Rota önerileri alınamadı',
      );
    }
  }

  /// Handle quick status intent
  Future<Map<String, dynamic>> _handleQuickStatusIntent(Map<String, dynamic> parameters) async {
    final isEnglish = _languageService.isEnglish;
    
    try {
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

      final tripStatus = _carPlayService.isTripActive 
          ? (isEnglish ? 'Active trip in progress' : 'Aktif seyahat devam ediyor')
          : (isEnglish ? 'No active trip' : 'Aktif seyahat yok');

      return _createResponse(
        success: true,
        message: isEnglish ? 'Here\'s your quick status' : 'Hızlı durumunuz',
        speakableText: isEnglish 
            ? 'Today you\'ve generated ${todayCO2.toStringAsFixed(1)} kilograms of CO2 from ${activities.length} activities. $tripStatus.'
            : 'Bugün ${activities.length} aktiviteden ${todayCO2.toStringAsFixed(1)} kilogram CO2 ürettiniz. $tripStatus.',
        data: {
          'todayCO2': todayCO2,
          'activitiesCount': activities.length,
          'tripActive': _carPlayService.isTripActive,
          'carPlayConnected': _carPlayService.isCarPlayConnected,
        },
      );
    } catch (e) {
      return _createErrorResponse(
        isEnglish ? 'Failed to get status' : 'Durum alınamadı',
      );
    }
  }

  /// Handle add manual trip intent
  Future<Map<String, dynamic>> _handleAddManualTripIntent(Map<String, dynamic> parameters) async {
    final isEnglish = _languageService.isEnglish;
    
    // Extract parameters from voice input
    final distance = parameters['distance'] as double?;
    final duration = parameters['duration'] as int?;
    final transportType = parameters['transportType'] as String?;
    
    try {
      if (distance == null || distance <= 0) {
        return _createResponse(
          success: false,
          message: isEnglish ? 'Please specify the distance' : 'Lütfen mesafeyi belirtin',
          speakableText: isEnglish 
              ? 'I need to know the distance of your trip. Please say something like "Add a 10 kilometer trip"'
              : 'Seyahatinizin mesafesini bilmem gerekiyor. "10 kilometrelik bir seyahat ekle" gibi söyleyin',
        );
      }

      // Use default values if not specified
      final tripDuration = duration ?? (distance * 3).round(); // Estimate 3 minutes per km
      final co2Emission = distance * 0.2; // Standard car emission

      // Create activity
      final activity = TransportActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: TransportType.car, // Default for manual CarPlay entry
        distanceKm: distance,
        durationMinutes: tripDuration,
        co2EmissionKg: co2Emission,
        timestamp: DateTime.now(),
        fromLocation: isEnglish ? 'Voice added' : 'Sesle eklendi',
        toLocation: isEnglish ? 'Voice added' : 'Sesle eklendi',
        notes: isEnglish ? 'Added via CarPlay voice command' : 'CarPlay ses komutu ile eklendi',
      );

      await _databaseService.addActivity(activity);

      return _createResponse(
        success: true,
        message: isEnglish ? 'Trip added successfully' : 'Seyahat başarıyla eklendi',
        speakableText: isEnglish 
            ? 'I\'ve added a ${distance.toStringAsFixed(1)} kilometer trip with ${co2Emission.toStringAsFixed(1)} kilograms of CO2 emissions.'
            : '${distance.toStringAsFixed(1)} kilometrelik bir seyahat ekledim. ${co2Emission.toStringAsFixed(1)} kilogram CO2 emisyonu ile.',
        data: {
          'distance': distance,
          'duration': tripDuration,
          'co2': co2Emission,
          'activityId': activity.id,
        },
      );
    } catch (e) {
      return _createErrorResponse(
        isEnglish ? 'Failed to add trip' : 'Seyahat eklenemedi',
      );
    }
  }

  /// Create success/info response
  Map<String, dynamic> _createResponse({
    required bool success,
    required String message,
    required String speakableText,
    Map<String, dynamic>? data,
  }) {
    return {
      'success': success,
      'message': message,
      'speakableText': speakableText,
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Create error response
  Map<String, dynamic> _createErrorResponse(String message) {
    final isEnglish = _languageService.isEnglish;
    
    return {
      'success': false,
      'message': message,
      'speakableText': isEnglish 
          ? 'Sorry, I couldn\'t complete that request.'
          : 'Üzgünüm, bu isteği tamamlayamadım.',
      'error': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Update shortcuts based on current app state
  Future<void> updateShortcuts() async {
    try {
      await _donateShortcuts();
    } catch (e) {
      debugPrint('Failed to update shortcuts: $e');
    }
  }

  /// Set up shortcuts based on current context
  Future<void> setupContextualShortcuts() async {
    try {
      final isEnglish = _languageService.isEnglish;
      
      // Different shortcuts based on current state
      List<Map<String, dynamic>> contextualShortcuts = [];

      if (_carPlayService.isTripActive) {
        // Show trip-related shortcuts when trip is active
        contextualShortcuts.addAll([
          {
            'identifier': 'end_current_trip',
            'title': isEnglish ? 'End Current Trip' : 'Mevcut Seyahat Bitir',
            'subtitle': isEnglish ? 'End your active journey' : 'Aktif yolculuğunuzu bitirin',
            'phrases': isEnglish 
                ? ['End current trip', 'Stop current trip', 'Finish this journey']
                : ['Mevcut seyahat bitir', 'Bu seyahat durdur', 'Bu yolculuk bitir'],
            'systemImageName': 'stop.circle.fill',
            'category': 'travel',
            'priority': 'high',
          }
        ]);
      } else {
        // Show start trip shortcuts when no trip is active
        contextualShortcuts.addAll([
          {
            'identifier': 'start_new_trip',
            'title': isEnglish ? 'Start New Trip' : 'Yeni Seyahat Başlat',
            'subtitle': isEnglish ? 'Begin a new journey' : 'Yeni bir yolculuk başlatın',
            'phrases': isEnglish 
                ? ['Start new trip', 'Begin new journey', 'New trip']
                : ['Yeni seyahat başlat', 'Yeni yolculuk başlat', 'Yeni seyahat'],
            'systemImageName': 'car.fill',
            'category': 'travel',
            'priority': 'high',
          }
        ]);
      }

      await _channel.invokeMethod('updateContextualShortcuts', {
        'shortcuts': contextualShortcuts,
        'language': isEnglish ? 'en' : 'tr',
      });

    } catch (e) {
      debugPrint('Failed to setup contextual shortcuts: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    // Clean up any resources
  }
}