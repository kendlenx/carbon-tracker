import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/carbon_tracker_logo.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../services/permission_service.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textFade;
  late Animation<double> _backgroundOpacity;
  late Animation<Color?> _backgroundGradientStart;
  late Animation<Color?> _backgroundGradientEnd;

  String _statusText = 'Carbon Tracker\'ı başlatıyoruz...';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Background animation controller
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Logo animations
    _logoScale = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _logoRotation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack),
    ));

    // Text animation
    _textFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeIn),
    ));

    // Background animations
    _backgroundOpacity = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _backgroundGradientStart = ColorTween(
      begin: const Color(0xFF1B5E20),
      end: const Color(0xFF2E7D32),
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _backgroundGradientEnd = ColorTween(
      begin: const Color(0xFF0D1B0F),
      end: const Color(0xFF1B1B1B),
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _startSplashSequence() async {
    // Start background animation
    _backgroundController.forward();
    
    // Wait a bit, then start logo animation
    await Future.delayed(const Duration(milliseconds: 500));
    _logoController.forward();
    
    // Start text animation shortly after logo
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();
    
    // Initialize services in parallel with animations
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Simulate service initialization with status updates
      setState(() {
        _statusText = 'Servisleri yüklüyoruz...';
      });
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() {
        _statusText = 'Dil ayarlarını kontrol ediyoruz...';
      });
      await LanguageService.instance.initialize();
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        _statusText = 'Tema ayarlarını yüklüyoruz...';
      });
      await ThemeService.instance.loadThemePreference();
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        _statusText = 'İzinleri kontrol ediyoruz...';
      });
      await PermissionService.instance.initialize();
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        _statusText = 'Hazırlanıyoruz...';
      });
      await Future.delayed(const Duration(milliseconds: 800));

      _isInitialized = true;
      
      // Navigate to main screen with a smooth transition
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToMain();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Hata oluştu: $e';
      });
      // Still navigate after a delay even if there's an error
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        _navigateToMain();
      }
    }
  }

  void _navigateToMain() async {
    // Check if onboarding should be shown
    final prefs = await SharedPreferences.getInstance();
    final showOnboarding = !(prefs.getBool('onboarding_completed') ?? false);
    final targetScreen = showOnboarding ? const OnboardingScreen() : const CarbonTrackerHome();
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoController,
          _textController,
          _backgroundController,
        ]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _backgroundGradientStart.value ?? const Color(0xFF1B5E20),
                  _backgroundGradientEnd.value ?? const Color(0xFF0D1B0F),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated background elements
                _buildBackgroundElements(),
                
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated logo
                      Transform.scale(
                        scale: _logoScale.value,
                        child: Transform.rotate(
                          angle: _logoRotation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const CarbonTrackerLogo(
                              size: 120,
                              isDark: true,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // App name
                      FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            Text(
                              'Carbon Tracker',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.95),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '🌍 Karbon ayak izini takip et',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                      
                      // Loading indicator and status
                      FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _statusText,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Branding at bottom
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      '🌱 Çevre dostu bir gelecek için',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundElements() {
    return Positioned.fill(
      child: Opacity(
        opacity: _backgroundOpacity.value,
        child: Stack(
          children: [
            // Floating eco elements
            ...List.generate(6, (index) {
              return Positioned(
                top: 50.0 + (index * 120),
                left: (index % 2 == 0) ? -20.0 : null,
                right: (index % 2 == 1) ? -20.0 : null,
                child: Transform.rotate(
                  angle: _logoController.value * 0.5,
                  child: Opacity(
                    opacity: 0.1,
                    child: Icon(
                      index % 3 == 0
                          ? Icons.eco
                          : index % 3 == 1
                              ? Icons.nature
                              : Icons.energy_savings_leaf,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

