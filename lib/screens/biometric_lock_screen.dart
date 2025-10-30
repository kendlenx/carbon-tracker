import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/security_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with TickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  final LanguageService _languageService = LanguageService.instance;

  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  bool _isAuthenticating = false;
  bool _showRetry = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initBiometrics();
    _startAuthentication();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initBiometrics() async {
    final biometrics = await _securityService.getAvailableBiometrics();
    if (mounted) {
      setState(() {
        _availableBiometrics = biometrics;
      });
    }
  }

  Future<void> _startAuthentication() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _showRetry = false;
    });

    try {
      final bool success = await _securityService.authenticateWithBiometrics();
      
      if (success && mounted) {
        _scaleController.forward().then((_) {
          Navigator.of(context).pop(true);
        });
      } else if (mounted) {
        setState(() {
          _showRetry = true;
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showRetry = true;
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return Icons.visibility;
    }
    return Icons.security;
  }

  String _getBiometricTitle() {
    final l = AppLocalizations.of(context)!;
    if (_availableBiometrics.contains(BiometricType.face)) {
      return l.translate('biometric.faceIdTitle');
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return l.translate('biometric.fingerprintTitle');
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return l.translate('biometric.irisTitle');
    }
    return l.translate('biometric.genericTitle');
  }

  String _getInstructionText() {
    final l = AppLocalizations.of(context)!;
    if (_availableBiometrics.contains(BiometricType.face)) {
      return l.translate('biometric.faceInstruction');
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return l.translate('biometric.fingerprintInstruction');
    }
    return l.translate('biometric.genericInstruction');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.withValues(alpha: 0.1),
              Colors.black,
              Colors.green.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carbon Tracker',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.translate('biometric.secureAccess'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.green.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Biometric Icon and Animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value * _scaleAnimation.value,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.green.withValues(alpha: 0.3),
                                Colors.green.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _getBiometricIcon(),
                            size: 80,
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 32),

              // Title and Instructions
              Text(
                _getBiometricTitle(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Text(
                  _getInstructionText(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Loading or Retry Button
              if (_isAuthenticating)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.translate('biometric.authenticating'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                )
              else if (_showRetry)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _startAuthentication,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getBiometricIcon(),
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.translate('biometric.tryAgain'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        AppLocalizations.of(context)!.translate('common.cancel'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),

              const Spacer(flex: 2),

              // Security Footer
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.security,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.translate('biometric.footerNote'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}