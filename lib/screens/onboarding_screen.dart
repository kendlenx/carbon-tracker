import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/language_service.dart';
import '../widgets/micro_interactions.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final LanguageService _languageService = LanguageService.instance;
  
  int _currentPage = 0;
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  Locale? _lastLocale;
  bool _pagesInitialized = false;

  final List<OnboardingPage> _pages = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Defer pages until localizations are available
    _fadeAnimationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (!_pagesInitialized || _lastLocale != currentLocale) {
      _setupPages();
      _lastLocale = currentLocale;
      _pagesInitialized = true;
      setState(() {});
    }
  }

  void _setupAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOutCubic));
  }

  void _setupPages() {
    final t = AppLocalizations.of(context)!;
    _pages.clear();
    _pages.addAll([
      OnboardingPage(
        title: t.translate('onboarding.p1.title'),
        subtitle: t.translate('onboarding.p1.subtitle'),
        icon: Icons.eco,
        color: Colors.green,
        animation: _buildWelcomeAnimation(),
      ),
      OnboardingPage(
        title: t.translate('onboarding.p2.title'),
        subtitle: t.translate('onboarding.p2.subtitle'),
        icon: Icons.track_changes,
        color: Colors.blue,
        animation: _buildTrackingAnimation(),
      ),
      OnboardingPage(
        title: t.translate('onboarding.p3.title'),
        subtitle: t.translate('onboarding.p3.subtitle'),
        icon: Icons.flag,
        color: Colors.orange,
        animation: _buildGoalsAnimation(),
      ),
      OnboardingPage(
        title: t.translate('onboarding.p4.title'),
        subtitle: t.translate('onboarding.p4.subtitle'),
        icon: Icons.mic,
        color: Colors.purple,
        animation: _buildSmartFeaturesAnimation(),
      ),
      OnboardingPage(
        title: t.translate('onboarding.p5.title'),
        subtitle: t.translate('onboarding.p5.subtitle'),
        icon: Icons.insights,
        color: Colors.indigo,
        animation: _buildInsightsAnimation(),
      ),
      OnboardingPage(
        title: t.translate('onboarding.p6.title'),
        subtitle: t.translate('onboarding.p6.subtitle'),
        icon: Icons.rocket_launch,
        color: Colors.teal,
        animation: _buildStartAnimation(),
      ),
    ]);
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Language picker
                  InkWell(
                    onTap: _showLanguagePicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_languageService.currentLanguageFlag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            _languageService.currentLanguageDisplayName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  
                  // Skip button
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      AppLocalizations.of(context)!.commonSkip,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _slideAnimationController.reset();
                  _slideAnimationController.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildPage(_pages[index]),
                    ),
                  );
                },
              ),
            ),

            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation/Icon area
          SizedBox(
            height: 280,
            child: page.animation ?? Container(
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                page.icon,
                size: 120,
                color: page.color,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: _currentPage == index ? 24.0 : 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: _currentPage == index 
                    ? _pages[_currentPage].color 
                    : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Action buttons
          Row(
            children: [
              // Back button
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousPage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: _pages[_currentPage].color),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.commonPrevious,
                      style: TextStyle(
                        color: _pages[_currentPage].color,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              if (_currentPage > 0) const SizedBox(width: 16),

              // Next/Get Started button
              Expanded(
                flex: _currentPage == 0 ? 1 : 1,
                child: ElevatedButton(
                  onPressed: _currentPage == _pages.length - 1 
                    ? _completeOnboarding 
                    : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: _pages[_currentPage].color.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1
                          ? AppLocalizations.of(context)!.commonDone
                          : AppLocalizations.of(context)!.commonNext,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentPage == _pages.length - 1
                          ? Icons.rocket_launch
                          : Icons.arrow_forward,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Custom animations for each page
  Widget _buildWelcomeAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 2000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ripple
            Container(
              width: 200 * value,
              height: 200 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3 * (1 - value)),
                  width: 2,
                ),
              ),
            ),
            // Inner ripple
            Container(
              width: 150 * value,
              height: 150 * value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.5 * (1 - value)),
                  width: 2,
                ),
              ),
            ),
            // Center icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco,
                size: 60,
                color: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackingAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Category icons animating in
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnimatedCategoryIcon(Icons.directions_car, Colors.blue, value * 1.0),
                _buildAnimatedCategoryIcon(Icons.flash_on, Colors.orange, value * 0.8),
                _buildAnimatedCategoryIcon(Icons.restaurant, Colors.green, value * 0.6),
                _buildAnimatedCategoryIcon(Icons.shopping_bag, Colors.purple, value * 0.4),
              ],
            ),
            const SizedBox(height: 40),
            // Central tracking icon
            Transform.scale(
              scale: value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.track_changes,
                  size: 40,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedCategoryIcon(IconData icon, Color color, double progress) {
    return Transform.scale(
      scale: progress.clamp(0.0, 1.0),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 24,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGoalsAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress bars
            ...List.generate(3, (index) {
              final delay = index * 0.3;
              final progress = (value - delay).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 200,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress * [0.7, 0.5, 0.9][index],
                  child: Container(
                    decoration: BoxDecoration(
                      color: [Colors.green, Colors.orange, Colors.blue][index],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 40),
            // Flag icon
            Transform.rotate(
              angle: value * 0.1,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag,
                  size: 40,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmartFeaturesAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 2200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Voice animation (sound waves)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final waveHeight = [15.0, 25.0, 35.0, 25.0, 15.0][index];
                final delay = index * 0.1;
                final progress = ((value - delay) * 2).clamp(0.0, 1.0);
                final animatedHeight = waveHeight * (0.3 + 0.7 * (1 - ((progress * 2 - 1).abs())));
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 4,
                  height: animatedHeight,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),
            
            // Smart features icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSmartFeatureIcon(Icons.mic, Colors.purple, value, 0.0),
                _buildSmartFeatureIcon(Icons.car_rental, Colors.blue, value, 0.3),
                _buildSmartFeatureIcon(Icons.shortcut, Colors.orange, value, 0.6),
              ],
            ),
            const SizedBox(height: 20),
            
            // Connection lines
            CustomPaint(
              size: const Size(200, 40),
              painter: ConnectionLinesPainter(value),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmartFeatureIcon(IconData icon, Color color, double globalProgress, double delay) {
    final progress = (globalProgress - delay).clamp(0.0, 1.0);
    return Transform.scale(
      scale: progress,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 24,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInsightsAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 2000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated chart bars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final barHeight = [20.0, 35.0, 15.0, 45.0, 25.0, 40.0, 30.0][index];
                final delay = index * 0.1;
                final progress = (value - delay).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 12,
                  height: barHeight * progress,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            // Insights icon
            Transform.scale(
              scale: value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights,
                  size: 40,
                  color: Colors.purple,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStartAnimation() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 2500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Rocket trail
            ...List.generate(5, (index) {
              final delay = index * 0.1;
              final progress = (value - delay).clamp(0.0, 1.0);
              return Positioned(
                bottom: 50 + (index * 20.0),
                child: Opacity(
                  opacity: progress * 0.6,
                  child: Container(
                    width: 4 - (index * 0.5),
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
            // Rocket
            Transform.translate(
              offset: Offset(0, -100 * value),
              child: Transform.rotate(
                angle: value * 0.2,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rocket_launch,
                    size: 40,
                    color: Colors.teal,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticHelper.trigger(HapticType.light);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      HapticHelper.trigger(HapticType.light);
    }
  }

  void _skipOnboarding() async {
    await HapticHelper.trigger(HapticType.warning);
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await HapticHelper.trigger(HapticType.success);
    
    // Mark onboarding as completed (use service key)
    await OnboardingService.instance.completeOnboarding();
    
    // Navigate to main app
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const CarbonTrackerHome(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  void _showLanguagePicker() {
    final codes = ['en','tr','es','de','fr','it','pt','ru'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _languageService.isTurkish ? 'Dil' : 'Language',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...codes.map((code) {
                    final isSelected = _languageService.currentLanguageCode == code;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Text(_languageService.getLanguageFlag(code), style: const TextStyle(fontSize: 22)),
                        title: Text(_languageService.getLanguageDisplayName(code)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined, color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        onTap: () async {
                          if (!isSelected) {
                            await _languageService.setLanguage(code);
                            _setupPages();
                            if (mounted) setState(() {});
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool> shouldShowOnboarding() async {
    return !(await OnboardingService.instance.isOnboardingComplete());
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? animation;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.animation,
  });
}

class ConnectionLinesPainter extends CustomPainter {
  final double progress;

  ConnectionLinesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final dashedPaint = Paint()
      ..color = Colors.purple.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw connecting lines
    final lineLength = size.width * progress;
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    
    for (double i = 0; i < lineLength; i += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(i, size.height / 2),
        Offset((i + dashWidth).clamp(0, lineLength), size.height / 2),
        dashedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
