import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import '../services/language_service.dart';
import '../widgets/page_transitions.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;
  List<OnboardingStep> _steps = [];

  final LanguageService _languageService = LanguageService.instance;
  final OnboardingService _onboardingService = OnboardingService.instance;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _steps = _onboardingService.getOnboardingSteps(_languageService.isEnglish);
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    await _onboardingService.completeOnboarding();
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  void _skipOnboarding() async {
    await _onboardingService.completeOnboarding();
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnglish = _languageService.isEnglish;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.05),
                    theme.colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
              ),
            ),
            
            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  isEnglish ? 'Skip' : 'Atla',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            // Main content
            Column(
              children: [
                // Page indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: index == _currentPage
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.2),
                        ),
                      ),
                    ),
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
                      _animationController.reset();
                      _animationController.forward();
                    },
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Image/Icon
                                Container(
                                  width: 120,
                                  height: 120,
                                  margin: const EdgeInsets.only(bottom: 32),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      step.image,
                                      style: const TextStyle(fontSize: 48),
                                    ),
                                  ),
                                ),
                                
                                // Title
                                Text(
                                  step.title,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Description
                                Text(
                                  step.description,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      // Previous button
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: Text(
                              isEnglish ? 'Previous' : 'Önceki',
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox()),
                      
                      const SizedBox(width: 16),
                      
                      // Next/Complete button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPage == _steps.length - 1
                                ? (isEnglish ? 'Get Started' : 'Başla')
                                : (isEnglish ? 'Continue' : 'Devam Et'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}