import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../services/language_service.dart';
import 'micro_interactions.dart';
import 'dart:math' as math;

class VoiceCommandWidget extends StatefulWidget {
  final VoidCallback? onCommandExecuted;
  
  const VoiceCommandWidget({
    Key? key,
    this.onCommandExecuted,
  }) : super(key: key);

  @override
  State<VoiceCommandWidget> createState() => _VoiceCommandWidgetState();
}

class _VoiceCommandWidgetState extends State<VoiceCommandWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  final VoiceService _voiceService = VoiceService.instance;
  final LanguageService _languageService = LanguageService.instance;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _voiceService.addListener(_onVoiceServiceUpdate);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _voiceService.removeListener(_onVoiceServiceUpdate);
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_waveController);
  }

  void _onVoiceServiceUpdate() {
    if (_voiceService.isListening) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } else {
      _pulseController.stop();
      _waveController.stop();
      _pulseController.reset();
      _waveController.reset();
    }
    setState(() {});
  }

  Future<void> _toggleListening() async {
    await HapticHelper.trigger(HapticType.light);
    
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
    } else {
      if (!_voiceService.speechEnabled) {
        _showEnableVoiceDialog();
        return;
      }
      await _voiceService.startListening();
    }
  }

  void _showEnableVoiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_languageService.isEnglish 
          ? 'Enable Voice Commands' 
          : 'Sesli Komutları Etkinleştir'),
        content: Text(_languageService.isEnglish
          ? 'Voice commands require microphone permission. Please enable it in settings.'
          : 'Sesli komutlar mikrofon izni gerektirir. Lütfen ayarlarda etkinleştirin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _voiceService.initialize();
            },
            child: Text(_languageService.isEnglish ? 'Enable' : 'Etkinleştir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _voiceService,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Voice button with animations
              _buildVoiceButton(),
              const SizedBox(height: 16),
              
              // Status text
              _buildStatusText(),
              
              // Recognized words display
              if (_voiceService.currentWords.isNotEmpty)
                _buildRecognizedWords(),
                
              // Quick command suggestions
              if (!_voiceService.isListening)
                _buildQuickCommands(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _voiceService.isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _voiceService.isListening
                    ? RadialGradient(
                        colors: [
                          Colors.red.withOpacity(0.8),
                          Colors.red.withOpacity(0.4),
                          Colors.red.withOpacity(0.1),
                        ],
                      )
                    : RadialGradient(
                        colors: [
                          Colors.blue.withOpacity(0.8),
                          Colors.blue.withOpacity(0.4),
                          Colors.blue.withOpacity(0.1),
                        ],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (_voiceService.isListening ? Colors.red : Colors.blue)
                        .withOpacity(0.3),
                    blurRadius: _voiceService.isListening ? 20 : 10,
                    spreadRadius: _voiceService.isListening ? 5 : 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated waves
                  if (_voiceService.isListening)
                    AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(120, 120),
                          painter: WavePainter(_waveAnimation.value),
                        );
                      },
                    ),
                  
                  // Microphone icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _voiceService.isListening 
                          ? Colors.red 
                          : Colors.blue,
                    ),
                    child: Icon(
                      _voiceService.isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusText() {
    String statusText;
    Color statusColor;

    if (!_voiceService.speechEnabled) {
      statusText = _languageService.isEnglish 
          ? 'Voice commands disabled' 
          : 'Sesli komutlar devre dışı';
      statusColor = Colors.grey;
    } else if (_voiceService.isListening) {
      statusText = _languageService.isEnglish 
          ? 'Listening...' 
          : 'Dinleniyor...';
      statusColor = Colors.red;
    } else {
      statusText = _languageService.isEnglish 
          ? 'Tap to speak' 
          : 'Konuşmak için dokunun';
      statusColor = Colors.blue;
    }

    return Text(
      statusText,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: statusColor,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRecognizedWords() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            _languageService.isEnglish ? 'Recognized:' : 'Tanınan:',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _voiceService.currentWords,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (_voiceService.confidence > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: _voiceService.confidence,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _voiceService.confidence > 0.8 
                      ? Colors.green 
                      : _voiceService.confidence > 0.5 
                          ? Colors.orange 
                          : Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickCommands() {
    final commands = [
      {
        'text': _languageService.isEnglish ? '"Add 5km car trip"' : '"5km araba yolculuğu ekle"',
        'icon': Icons.directions_car,
        'color': Colors.blue,
      },
      {
        'text': _languageService.isEnglish ? '"Show my statistics"' : '"İstatistiklerimi göster"',
        'icon': Icons.bar_chart,
        'color': Colors.green,
      },
      {
        'text': _languageService.isEnglish ? '"Set daily goal to 8kg"' : '"Günlük hedefi 8kg yap"',
        'icon': Icons.flag,
        'color': Colors.orange,
      },
    ];

    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            _languageService.isEnglish ? 'Try saying:' : 'Şunları deneyin:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          ...commands.map((command) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: MicroCard(
              onTap: () => _simulateVoiceCommand(command['text'] as String),
              hapticType: HapticType.light,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      command['icon'] as IconData,
                      color: command['color'] as Color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        command['text'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _simulateVoiceCommand(String command) async {
    // Remove quotes from the command text
    String cleanCommand = command.replaceAll('"', '');
    
    // Show processing feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _languageService.isEnglish 
              ? 'Processing: $cleanCommand'
              : 'İşleniyor: $cleanCommand',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Process the voice command using VoiceService
    try {
      await _voiceService.processTextCommand(cleanCommand);
      
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService.isEnglish 
                ? 'Command executed successfully!'
                : 'Komut başarıyla çalıştırıldı!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.onCommandExecuted?.call();
    } catch (e) {
      // Show error feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService.isEnglish 
                ? 'Error processing command: $e'
                : 'Komut işlenirken hata: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw multiple expanding circles
    for (int i = 0; i < 3; i++) {
      final waveRadius = (radius * (animationValue + i * 0.3)) % radius;
      final opacity = 1.0 - (waveRadius / radius);
      
      paint.color = Colors.white.withOpacity(opacity * 0.5);
      canvas.drawCircle(center, waveRadius, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class VoiceCommandDialog extends StatefulWidget {
  const VoiceCommandDialog({Key? key}) : super(key: key);

  @override
  State<VoiceCommandDialog> createState() => _VoiceCommandDialogState();
}

class _VoiceCommandDialogState extends State<VoiceCommandDialog> {
  final LanguageService _languageService = LanguageService.instance;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.purple.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color: Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _languageService.isEnglish 
                        ? 'Voice Commands' 
                        : 'Sesli Komutlar',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Voice command widget
            VoiceCommandWidget(
              onCommandExecuted: () {
                // Could close dialog after successful command
                // Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}