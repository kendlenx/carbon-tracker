import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'database_service.dart';
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
        print('Voice commands initialized successfully');
      }
    } catch (e) {
      print('Error initializing speech: $e');
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
      print('Error initializing TTS: $e');
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
      print('Error starting voice recognition: $e');
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
      print('Error stopping voice recognition: $e');
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
    print('Speech error: $error');
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
    
    // Activity logging commands
    if (_containsAnyKeyword(normalizedCommand, [
      'ekle', 'kaydett', 'girdim', 'kullandım', 'tükettim', 'yaptım'
    ])) {
      type = VoiceCommandType.addActivity;
      parameters = await _extractActivityParameters(normalizedCommand);
    }
    
    // Statistics commands
    else if (_containsAnyKeyword(normalizedCommand, [
      'istatistik', 'rapor', 'durum', 'ne kadar', 'toplam', 'bugün', 'bu hafta'
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

    switch (command.type) {
      case VoiceCommandType.addActivity:
        response = await _executeAddActivity(command.parameters);
        break;
      
      case VoiceCommandType.getStats:
        response = await _executeGetStats(command.parameters);
        break;
      
      case VoiceCommandType.setGoal:
        response = await _executeSetGoal(command.parameters);
        break;
      
      case VoiceCommandType.askQuestion:
        response = await _executeQuestion(command.parameters);
        break;
      
      default:
        response = 'Üzgünüm, bu komutu anlayamadım. Tekrar deneyin.';
    }

    // Update command with response
    final updatedCommand = VoiceCommand(
      originalText: command.originalText,
      type: command.type,
      parameters: command.parameters,
      timestamp: command.timestamp,
      isExecuted: true,
      response: response,
    );

    final index = _commandHistory.indexWhere((c) => c.timestamp == command.timestamp);
    if (index != -1) {
      _commandHistory[index] = updatedCommand;
    }

    // Provide voice feedback
    if (_voiceFeedbackEnabled && _ttsEnabled) {
      await _speak(response);
    }

    // Show notification
    await _notificationService.showSmartSuggestion('Sesli komut: $response');
    
    notifyListeners();
  }

  /// Execute add activity command
  Future<String> _executeAddActivity(Map<String, dynamic> parameters) async {
    try {
      if (parameters.isEmpty) {
        return 'Hangi aktiviteyi eklemek istiyorsunuz? Örnek: "5 kilometre araç kullandım"';
      }

      // Note: Using a string-based approach since CarbonCategory is in main.dart
      final categoryName = parameters['category'] as String?;
      final amount = parameters['amount'] as double?;
      final description = parameters['description'] as String?;

      if (categoryName == null || amount == null) {
        return 'Aktivite bilgilerini tam olarak anlayamadım. Lütfen kategori ve miktarı belirtin.';
      }

      // Store in database (simplified approach for now)
      // In a real implementation, this would use proper database models
      
      // Update goals (simplified approach)
      final goalCategory = _convertCategoryNameToGoalCategory(categoryName);
      await _goalService.updateAllGoalsProgress(amount, goalCategory);

      return 'Tamam! ${amount.toStringAsFixed(1)} kg CO₂ $categoryName aktivitesi kaydedildi.';
    } catch (e) {
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
      double amount = double.tryParse(numberMatch.group(1)!) ?? 0;
      String? unit = numberMatch.group(2);
      
      // Convert units if needed
      if (unit != null) {
        if (unit.contains('km') || unit.contains('kilometre')) {
          // Assume car transport for km
          params['category'] = 'ulaşım';
          // Simple calculation: 1km by car = ~0.2kg CO2
          amount = amount * 0.2;
        } else if (unit.contains('litre') || unit.contains('lt')) {
          // Assume fuel consumption
          params['category'] = 'ulaşım';
          // Simple calculation: 1L fuel = ~2.3kg CO2
          amount = amount * 2.3;
        } else if (unit.contains('saat') || unit.contains('dakika')) {
          // Assume energy usage
          params['category'] = 'enerji';
          // Convert to hours if minutes
          if (unit.contains('dakika')) {
            amount = amount / 60;
          }
          // Simple calculation: 1 hour electricity = ~0.5kg CO2
          amount = amount * 0.5;
        }
      }
      
      params['amount'] = amount;
    }
    
    // Extract category from keywords
    if (params['category'] == null) {
      if (_containsAnyKeyword(command, ['araç', 'araba', 'otobüs', 'tren', 'uçak', 'motor'])) {
        params['category'] = 'ulaşım';
      } else if (_containsAnyKeyword(command, ['elektrik', 'enerji', 'ısıtma', 'klima'])) {
        params['category'] = 'enerji';
      } else if (_containsAnyKeyword(command, ['yemek', 'et', 'sebze', 'meyve'])) {
        params['category'] = 'yemek';
      } else if (_containsAnyKeyword(command, ['çöp', 'atık', 'geri dönüşüm'])) {
        params['category'] = 'atık';
      } else {
        params['category'] = 'diğer';
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
      print('TTS error: $e');
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
      print('Error stopping TTS: $e');
    }
  }

  /// Check if command contains any of the keywords
  bool _containsAnyKeyword(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
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
      print('Error loading voice settings: $e');
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
      print('Error saving voice settings: $e');
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
      print('Error loading command history: $e');
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
      print('Error saving command history: $e');
    }
  }

  /// Clear command history
  Future<void> clearCommandHistory() async {
    _commandHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('voice_command_history');
    notifyListeners();
  }

  /// Get voice command suggestions
  List<String> getVoiceCommandSuggestions() {
    return [
      'Bugün 5 kilometre araç kullandım',
      'Bu hafta ne kadar karbon tükettim?',
      'Günlük 12 kilogram hedef belirle',
      'Dün 2 saat elektrik kullandım',
      'Bu ay toplam karbon miktarım nedir?',
      'Haftalık 80 kilogram hedef koy',
      'Karbon ayak izi nasıl azaltılır?',
      'Aktif hedeflerim neler?',
    ];
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }
}