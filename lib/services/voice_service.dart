import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'database_service.dart';
import '../models/transport_activity.dart';
import 'notification_service.dart';
import 'goal_service.dart';

enum VoiceCommandType {
  addActivity,
  getStats,
  setGoal,
  askQuestion,
  unknown,
}

class VoiceCommand {
  final String originalText;
  final VoiceCommandType type;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;
  final bool isExecuted;
  final String? response;

  VoiceCommand({
    required this.originalText,
    required this.type,
    required this.parameters,
    required this.timestamp,
    this.isExecuted = false,
    this.response,
  });

  Map<String, dynamic> toJson() {
    return {
      'originalText': originalText,
      'type': type.name,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
      'isExecuted': isExecuted,
      'response': response,
    };
  }

  factory VoiceCommand.fromJson(Map<String, dynamic> json) {
    return VoiceCommand(
      originalText: json['originalText'],
      type: VoiceCommandType.values.firstWhere((e) => e.name == json['type']),
      parameters: json['parameters'],
      timestamp: DateTime.parse(json['timestamp']),
      isExecuted: json['isExecuted'] ?? false,
      response: json['response'],
    );
  }
}

class VoiceService extends ChangeNotifier {
  static VoiceService? _instance;
  static VoiceService get instance => _instance ??= VoiceService._();
  
  VoiceService._();

  // Services
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final DatabaseService _databaseService = DatabaseService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final GoalService _goalService = GoalService.instance;

  // State
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _ttsEnabled = true;
  String _currentWords = '';
  double _confidence = 0.0;
  List<VoiceCommand> _commandHistory = [];
  
  // Settings
  bool _voiceCommandsEnabled = true;
  bool _voiceFeedbackEnabled = true;
  double _speechRate = 0.5;
  double _speechPitch = 1.0;
  String _speechLanguage = 'tr-TR';

  // Getters
  bool get isListening => _isListening;
  bool get speechEnabled => _speechEnabled;
  bool get ttsEnabled => _ttsEnabled;
  bool get voiceCommandsEnabled => _voiceCommandsEnabled;
  bool get voiceFeedbackEnabled => _voiceFeedbackEnabled;
  String get currentWords => _currentWords;
  double get confidence => _confidence;
  List<VoiceCommand> get commandHistory => _commandHistory;

  /// Initialize voice service
  Future<void> initialize() async {
    await _loadSettings();
    await _loadCommandHistory();
    await _initializeSpeech();
    await _initializeTTS();
  }

  /// Initialize speech recognition
  Future<void> _initializeSpeech() async {
    try {
      final hasPermission = await Permission.microphone.request();
      if (!hasPermission.isGranted) {
        _speechEnabled = false;
        return;
      }

      _speechEnabled = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
      
      if (_speechEnabled) {
        debugPrint('Voice commands initialized successfully');
      }
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      _speechEnabled = false;
    }
  }

  /// Initialize Text-to-Speech
  Future<void> _initializeTTS() async {
    try {
      await _tts.setLanguage(_speechLanguage);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_speechPitch);
      await _tts.setVolume(0.8);
      
      _ttsEnabled = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      _ttsEnabled = false;
    }
  }

  /// Start listening for voice commands
  Future<void> startListening() async {
    if (!_speechEnabled || _isListening) return;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: _speechLanguage,
        onSoundLevelChange: (level) => {
          // Could be used for visual feedback
        },
      );
      
      _isListening = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting voice recognition: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping voice recognition: $e');
    }
  }

  /// Handle speech recognition results
  void _onSpeechResult(result) {
    _currentWords = result.recognizedWords;
    _confidence = result.confidence;
    
    if (result.finalResult) {
      _processVoiceCommand(_currentWords);
    }
    
    notifyListeners();
  }

  /// Handle speech errors
  void _onSpeechError(error) {
    debugPrint('Speech error: $error');
    _isListening = false;
    notifyListeners();
  }

  /// Handle speech status changes
  void _onSpeechStatus(status) {
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      notifyListeners();
    }
  }

  /// Process voice command and extract intent
  Future<void> _processVoiceCommand(String command) async {
    final normalizedCommand = command.toLowerCase().trim();
    
    VoiceCommandType type = VoiceCommandType.unknown;
    Map<String, dynamic> parameters = {};
    
      // Activity logging commands (daha kapsamlı kelimeler)
    if (_containsAnyKeyword(normalizedCommand, [
      'ekle', 'kaydet', 'girdim', 'kullandım', 'tükettim', 'yaptım', 'gittim', 'aldım'
    ]) || normalizedCommand.contains('kilometre') || normalizedCommand.contains('km') || normalizedCommand.contains('saat') || normalizedCommand.contains('litre')) {
      type = VoiceCommandType.addActivity;
      parameters = await _extractActivityParameters(normalizedCommand);
    }
    
    // Statistics commands (daha kapsamlı)
    else if (_containsAnyKeyword(normalizedCommand, [
      'istatistik', 'rapor', 'durum', 'ne kadar', 'toplam', 'bugün', 'bu hafta', 'karbon', 'emisyon', 'ayak izi', 'göster', 'nedir'
    ])) {
      type = VoiceCommandType.getStats;
      parameters = await _extractStatsParameters(normalizedCommand);
    }
    
    // Goal setting commands
    else if (_containsAnyKeyword(normalizedCommand, [
      'hedef', 'amaç', 'belirle', 'koy', 'planla'
    ])) {
      type = VoiceCommandType.setGoal;
      parameters = await _extractGoalParameters(normalizedCommand);
    }
    
    // Question commands
    else if (_containsAnyKeyword(normalizedCommand, [
      'nasıl', 'neden', 'ne', 'kim', 'nerede', 'ne zaman', 'kaç'
    ])) {
      type = VoiceCommandType.askQuestion;
      parameters = {'question': normalizedCommand};
    }

    final voiceCommand = VoiceCommand(
      originalText: command,
      type: type,
      parameters: parameters,
      timestamp: DateTime.now(),
    );

    _commandHistory.insert(0, voiceCommand);
    await _saveCommandHistory();
    
    // Execute the command
    await _executeVoiceCommand(voiceCommand);
  }

  /// Execute voice command
  Future<void> _executeVoiceCommand(VoiceCommand command) async {
    String response = '';
    bool isSuccessful = false;

    try {
      switch (command.type) {
        case VoiceCommandType.addActivity:
          response = await _executeAddActivity(command.parameters);
          isSuccessful = !response.contains('hata') && !response.contains('sorun');
          break;
        
        case VoiceCommandType.getStats:
          response = await _executeGetStats(command.parameters);
          isSuccessful = !response.contains('hata');
          break;
        
        case VoiceCommandType.setGoal:
          response = await _executeSetGoal(command.parameters);
          isSuccessful = !response.contains('hata');
          break;
        
        case VoiceCommandType.askQuestion:
          response = await _executeQuestion(command.parameters);
          isSuccessful = true; // Questions always succeed
          break;
        
        default:
          response = 'Üzgünüm, bu komutu anlayamadım. Şunları deneyebilirsiniz: aktivite ekle, istatistik göster, hedef belirle.';
          isSuccessful = false;
      }
    } catch (e) {
      response = 'Komut işlenirken beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
      isSuccessful = false;
      debugPrint('Error executing voice command: $e');
    }

    // Update command with response
    final updatedCommand = VoiceCommand(
      originalText: command.originalText,
      type: command.type,
      parameters: command.parameters,
      timestamp: command.timestamp,
      isExecuted: isSuccessful,
      response: response,
    );

    final index = _commandHistory.indexWhere((c) => c.timestamp == command.timestamp);
    if (index != -1) {
      _commandHistory[index] = updatedCommand;
    }
    await _saveCommandHistory();

    // Provide voice feedback
    if (_voiceFeedbackEnabled && _ttsEnabled) {
      await _speak(response);
    }

    // Show notification with appropriate type
    if (isSuccessful) {
      await _notificationService.showSmartSuggestion('✅ $response');
    } else {
      await _notificationService.showSmartSuggestion('❌ $response');
    }
    
    notifyListeners();
  }

  /// Execute add activity command
  Future<String> _executeAddActivity(Map<String, dynamic> parameters) async {
    try {
      if (parameters.isEmpty) {
        return 'Hangi aktiviteyi eklemek istiyorsunuz? Örnek: "5 kilometre araç kullandım"';
      }

      final categoryName = parameters['category'] as String?;
      final amount = parameters['amount'] as double?;
      final description = parameters['description'] as String?;
      final originalAmount = parameters['originalAmount'] as double?;
      final unit = parameters['unit'] as String?;

      if (categoryName == null || amount == null) {
        return 'Aktivite bilgilerini tam olarak anlayamadım. Lütfen kategori ve miktarı belirtin.';
      }

      // Prepare activity data for database
      final activityData = {
        'type': _getCategoryTransportType(categoryName),
        'distance': originalAmount ?? 1.0, // Use original amount for distance
        'carbonFootprint': amount, // CO2 amount
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'voice_command',
      };

      // Save to database using DatabaseService
      // Create proper TransportActivity from voice data  
      final distanceValue = originalAmount ?? 1.0;
      final activity = TransportActivity.create(
        type: _parseTransportType(categoryName),
        distanceKm: distanceValue,
        durationMinutes: (distanceValue * 60 / 30).round(), // Estimate based on 30 km/h average
        notes: description ?? 'Added via voice command',
        metadata: {
          'source': 'voice_command',
          'category': categoryName,
          'unit': unit ?? 'km',
          'co2_calculated': amount,
        },
      );
      
      final activityId = await _databaseService.addActivity(activity);
      
      if (activityId.isEmpty) {
        return 'Aktivite kaydedilirken bir sorun oluştu.';
      }

      // Update goals
      final goalCategory = _convertCategoryNameToGoalCategory(categoryName);
      await _goalService.updateAllGoalsProgress(amount, goalCategory);

      // Format response with original amount and unit if available
      String responseAmount = amount.toStringAsFixed(1);
      String responseText = 'Tamam! ';
      
      if (originalAmount != null && unit != null) {
        responseText += '${originalAmount.toStringAsFixed(originalAmount == originalAmount.toInt() ? 0 : 1)} $unit ';
        responseText += '($responseAmount kg CO₂) ';
      } else {
        responseText += '$responseAmount kg CO₂ ';
      }
      
      responseText += '$categoryName aktivitesi başarıyla kaydedildi.';
      
      return responseText;
    } catch (e) {
      debugPrint('Error in _executeAddActivity: $e');
      return 'Aktivite eklenirken bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }

  /// Execute get statistics command
  Future<String> _executeGetStats(Map<String, dynamic> parameters) async {
    try {
      final period = parameters['period'] as String? ?? 'bugün';
      
      // Get daily stats (simplified approach)
      // In a real implementation, this would query the database properly
      double totalCarbon = 0.0;
      
      try {
        final stats = await _databaseService.getDashboardStats();
        totalCarbon = stats['todayTotal'] ?? 0.0;
      } catch (e) {
        // Fallback to 0 if database query fails
        totalCarbon = 0.0;
      }

      if (totalCarbon == 0) {
        return '$period hiç aktivite kaydedilmemiş.';
      }

      final goals = _goalService.activeGoals.where((goal) => 
        goal.type == GoalType.daily && goal.category == GoalCategory.total
      ).toList();

      String goalInfo = '';
      if (goals.isNotEmpty) {
        final goal = goals.first;
        final percentage = goal.progressPercentage;
        goalInfo = ' Günlük hedefinizin ${percentage.toInt()}%\'ini tamamladınız.';
      }

      return '$period toplam ${totalCarbon.toStringAsFixed(1)} kg CO₂ ayak izi.$goalInfo';
    } catch (e) {
      return 'İstatistik bilgileri alınırken bir hata oluştu.';
    }
  }

  /// Execute set goal command  
  Future<String> _executeSetGoal(Map<String, dynamic> parameters) async {
    try {
      final amount = parameters['amount'] as double?;
      final period = parameters['period'] as String? ?? 'günlük';
      
      if (amount == null) {
        return 'Hedef miktarını belirtmediniz. Örnek: "Günlük 10 kilogram hedef koy"';
      }

      GoalType goalType = GoalType.daily;
      Duration duration = const Duration(days: 1);

      if (period.contains('hafta')) {
        goalType = GoalType.weekly;
        duration = const Duration(days: 7);
      } else if (period.contains('ay')) {
        goalType = GoalType.monthly;
        duration = const Duration(days: 30);
      }

      await _goalService.createGoal(
        title: 'Sesli Komut Hedefi',
        description: 'Sesli komut ile oluşturulan $period hedef',
        type: goalType,
        category: GoalCategory.total,
        targetValue: amount,
        duration: duration,
      );

      return 'Tamam! $period maksimum ${amount.toStringAsFixed(1)} kg CO₂ hedefi oluşturuldu.';
    } catch (e) {
      return 'Hedef oluşturulurken bir hata oluştu.';
    }
  }

  /// Execute question command
  Future<String> _executeQuestion(Map<String, dynamic> parameters) async {
    final question = parameters['question'] as String? ?? '';
    
    // Simple knowledge base
    if (question.contains('karbon') && question.contains('nedir')) {
      return 'Karbon ayak izi, aktivitelerinizin atmosfere salınan CO₂ miktarıdır.';
    }
    if (question.contains('nasıl') && question.contains('azalt')) {
      return 'Karbon ayak izini azaltmak için toplu taşıma kullanın, enerji tasarrufu yapın ve geri dönüşüm yapın.';
    }
    if (question.contains('hedef') && question.contains('ne')) {
      final goals = _goalService.activeGoals;
      if (goals.isEmpty) {
        return 'Şu anda aktif hedefiniz bulunmuyor.';
      }
      final goal = goals.first;
      return 'Aktif hedefiniz: ${goal.title} - ${goal.progressText}';
    }
    
    return 'Bu konuda bilgi bulunmuyor. Daha spesifik bir soru sorabilirsiniz.';
  }

  /// Extract activity parameters from voice command
  Future<Map<String, dynamic>> _extractActivityParameters(String command) async {
    Map<String, dynamic> params = {};
    
    // Extract numbers (amount)
    final numberRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(kilometre|km|kilo|kg|litre|lt|saat|dakika)?');
    final numberMatch = numberRegex.firstMatch(command);
    
    if (numberMatch != null) {
      double originalAmount = double.tryParse(numberMatch.group(1)!) ?? 0;
      String? unit = numberMatch.group(2);
      double co2Amount = originalAmount; // Default to original amount
      
      // Store original amount and unit for response formatting
      params['originalAmount'] = originalAmount;
      params['unit'] = unit ?? '';
      
      // Convert units to CO2 if needed
      if (unit != null) {
        if (unit.contains('km') || unit.contains('kilometre')) {
          // Assume car transport for km
          params['category'] = 'ulaşım';
          // Simple calculation: 1km by car = ~0.2kg CO2
          co2Amount = originalAmount * 0.2;
        } else if (unit.contains('litre') || unit.contains('lt')) {
          // Assume fuel consumption
          params['category'] = 'ulaşım';
          // Simple calculation: 1L fuel = ~2.3kg CO2
          co2Amount = originalAmount * 2.3;
        } else if (unit.contains('saat') || unit.contains('dakika')) {
          // Assume energy usage
          params['category'] = 'enerji';
          // Convert to hours if minutes
          double hours = originalAmount;
          if (unit.contains('dakika')) {
            hours = originalAmount / 60;
          }
          // Simple calculation: 1 hour electricity = ~0.5kg CO2
          co2Amount = hours * 0.5;
        }
      }
      
      params['amount'] = co2Amount;
    }
    
      // Extract category from keywords (geliştirilmiş)
    if (params['category'] == null) {
      if (_containsAnyKeyword(command, ['araç', 'araba', 'otobüs', 'tren', 'uçak', 'motor', 'kullandım', 'gittim', 'ulaşım', 'metro', 'taksi', 'bisiklet', 'yürüdüm', 'koştum'])) {
        params['category'] = 'ulaşım';
      } else if (_containsAnyKeyword(command, ['elektrik', 'enerji', 'ısıtma', 'klima', 'ampul', 'cihaz', 'doğalgaz', 'kömür', 'petrol'])) {
        params['category'] = 'enerji';
      } else if (_containsAnyKeyword(command, ['yemek', 'et', 'sebze', 'meyve', 'yedim', 'içtim', 'beslenme', 'kahvaltı', 'öğle', 'akşam'])) {
        params['category'] = 'yemek';
      } else if (_containsAnyKeyword(command, ['çöp', 'atık', 'geri dönüşüm', 'attım', 'çöpe', 'plastik', 'kağıt'])) {
        params['category'] = 'atık';
      } else if (_containsAnyKeyword(command, ['kilometre', 'km', 'mesafe', 'yol'])) {
        params['category'] = 'ulaşım'; // Default for distance-based commands
      } else {
        params['category'] = 'ulaşım'; // Default to transport for better UX
      }
    }
    
    params['description'] = 'Sesli komut: $command';
    
    return params;
  }

  /// Extract stats parameters
  Future<Map<String, dynamic>> _extractStatsParameters(String command) async {
    Map<String, dynamic> params = {};
    
    if (command.contains('bugün')) {
      params['period'] = 'bugün';
    } else if (command.contains('dün')) {
      params['period'] = 'dün';
    } else if (command.contains('hafta')) {
      params['period'] = 'bu hafta';
    } else if (command.contains('ay')) {
      params['period'] = 'bu ay';
    } else {
      params['period'] = 'bugün';
    }
    
    return params;
  }

  /// Extract goal parameters
  Future<Map<String, dynamic>> _extractGoalParameters(String command) async {
    Map<String, dynamic> params = {};
    
    // Extract amount
    final numberRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kilo|kg)?');
    final numberMatch = numberRegex.firstMatch(command);
    
    if (numberMatch != null) {
      params['amount'] = double.tryParse(numberMatch.group(1)!) ?? 10.0;
    }
    
    // Extract period
    if (command.contains('günlük') || command.contains('gün')) {
      params['period'] = 'günlük';
    } else if (command.contains('haftalık') || command.contains('hafta')) {
      params['period'] = 'haftalık';
    } else if (command.contains('aylık') || command.contains('ay')) {
      params['period'] = 'aylık';
    } else {
      params['period'] = 'günlük';
    }
    
    return params;
  }

  /// Speak text using TTS
  Future<void> _speak(String text) async {
    if (!_ttsEnabled || !_voiceFeedbackEnabled) return;
    
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }
  
  /// Public method to speak text
  Future<void> speak(String text) async {
    await _speak(text);
  }

  /// Stop TTS
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  /// Check if command contains any of the keywords
  bool _containsAnyKeyword(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// Convert category name to transport type for database
  String _getCategoryTransportType(String categoryName) {
    switch (categoryName) {
      case 'ulaşım':
        return 'Araba'; // Default transport type
      case 'enerji':
        return 'Elektrik'; // For energy, we'll use a generic type
      case 'yemek':
        return 'Beslenme';
      case 'atık':
        return 'Atık';
      default:
        return 'Diğer';
    }
  }

  /// Convert category name to GoalCategory
  GoalCategory _convertCategoryNameToGoalCategory(String categoryName) {
    switch (categoryName) {
      case 'ulaşım':
        return GoalCategory.transport;
      case 'enerji':
        return GoalCategory.energy;
      case 'yemek':
        return GoalCategory.food;
      case 'atık':
        return GoalCategory.waste;
      default:
        return GoalCategory.total;
    }
  }

  /// Get category display name in Turkish
  String _getCategoryDisplayName(String categoryName) {
    switch (categoryName) {
      case 'ulaşım':
        return 'ulaşım';
      case 'enerji':
        return 'enerji';
      case 'yemek':
        return 'beslenme';
      case 'atık':
        return 'atık';
      default:
        return 'diğer';
    }
  }

  /// Update settings
  Future<void> updateSettings({
    bool? voiceCommandsEnabled,
    bool? voiceFeedbackEnabled,
    double? speechRate,
    double? speechPitch,
    String? speechLanguage,
  }) async {
    if (voiceCommandsEnabled != null) {
      _voiceCommandsEnabled = voiceCommandsEnabled;
    }
    if (voiceFeedbackEnabled != null) {
      _voiceFeedbackEnabled = voiceFeedbackEnabled;
    }
    if (speechRate != null) {
      _speechRate = speechRate;
      await _tts.setSpeechRate(speechRate);
    }
    if (speechPitch != null) {
      _speechPitch = speechPitch;
      await _tts.setPitch(speechPitch);
    }
    if (speechLanguage != null) {
      _speechLanguage = speechLanguage;
      await _tts.setLanguage(speechLanguage);
    }
    
    await _saveSettings();
    notifyListeners();
  }

  /// Load settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voiceCommandsEnabled = prefs.getBool('voice_commands_enabled') ?? true;
      _voiceFeedbackEnabled = prefs.getBool('voice_feedback_enabled') ?? true;
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _speechPitch = prefs.getDouble('speech_pitch') ?? 1.0;
      _speechLanguage = prefs.getString('speech_language') ?? 'tr-TR';
    } catch (e) {
      debugPrint('Error loading voice settings: $e');
    }
  }

  /// Save settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_commands_enabled', _voiceCommandsEnabled);
      await prefs.setBool('voice_feedback_enabled', _voiceFeedbackEnabled);
      await prefs.setDouble('speech_rate', _speechRate);
      await prefs.setDouble('speech_pitch', _speechPitch);
      await prefs.setString('speech_language', _speechLanguage);
    } catch (e) {
      debugPrint('Error saving voice settings: $e');
    }
  }

  /// Load command history
  Future<void> _loadCommandHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('voice_command_history');
      
      if (historyJson != null) {
        final historyList = jsonDecode(historyJson) as List;
        _commandHistory = historyList
            .map((json) => VoiceCommand.fromJson(json))
            .toList();
            
        // Keep only last 50 commands
        if (_commandHistory.length > 50) {
          _commandHistory = _commandHistory.sublist(0, 50);
        }
      }
    } catch (e) {
      debugPrint('Error loading command history: $e');
    }
  }

  /// Save command history
  Future<void> _saveCommandHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(
        _commandHistory.take(50).map((cmd) => cmd.toJson()).toList(),
      );
      await prefs.setString('voice_command_history', historyJson);
    } catch (e) {
      debugPrint('Error saving command history: $e');
    }
  }

  /// Clear command history
  Future<void> clearCommandHistory() async {
    _commandHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('voice_command_history');
    notifyListeners();
  }

  /// Process text command manually (for UI testing)
  Future<void> processTextCommand(String command) async {
    await _processVoiceCommand(command);
  }

  /// Get voice command suggestions
  List<String> getVoiceCommandSuggestions() {
    return [
      'Bugün 5 kilometre araç kullandım',
      'Bu hafta ne kadar karbon tükettim?',
      'Günlük 12 kilogram hedef belirle',
      '2 saat elektrik kullandım',
      'Bu ay toplam karbon miktarım nedir?',
      'Haftalık 80 kilogram hedef koy',
      'Karbon ayak izi nasıl azaltılır?',
      'Bugünkü istatistiklerimi göster',
      '10 kilometre bisiklet sürdüm',
      'Metro ile 5 kilometre gittim',
      'Günlük karbon durumum nedir?',
      'Bu hafta hedefime ne kadar yakınım?',
    ];
  }

  // Helper method to parse transport type from voice input
  TransportType _parseTransportType(String? transportType) {
    if (transportType == null) return TransportType.other;
    
    final lowerType = transportType.toLowerCase();
    
    if (lowerType.contains('car') || lowerType.contains('araba')) {
      return TransportType.car;
    } else if (lowerType.contains('bus') || lowerType.contains('otobüs')) {
      return TransportType.bus;
    } else if (lowerType.contains('train') || lowerType.contains('tren')) {
      return TransportType.train;
    } else if (lowerType.contains('metro') || lowerType.contains('tramvay')) {
      return TransportType.metro;
    } else if (lowerType.contains('bike') || lowerType.contains('bisiklet')) {
      return TransportType.bicycle;
    } else if (lowerType.contains('walk') || lowerType.contains('yürü')) {
      return TransportType.walking;
    } else if (lowerType.contains('plane') || lowerType.contains('uçak')) {
      return TransportType.plane;
    } else if (lowerType.contains('taxi') || lowerType.contains('taksi')) {
      return TransportType.taxi;
    } else {
      return TransportType.other;
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }
}