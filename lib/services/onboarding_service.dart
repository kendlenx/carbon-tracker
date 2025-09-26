import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _firstLaunchKey = 'first_launch';
  static const String _tutorialStepKey = 'tutorial_step';
  static const String _featureDiscoveryKey = 'feature_discovery';

  static OnboardingService? _instance;
  static OnboardingService get instance {
    _instance ??= OnboardingService._();
    return _instance!;
  }

  OnboardingService._();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Check if this is the first launch
  Future<bool> isFirstLaunch() async {
    await _initPrefs();
    return !(_prefs!.getBool(_firstLaunchKey) ?? false);
  }

  /// Mark first launch as completed
  Future<void> markFirstLaunchComplete() async {
    await _initPrefs();
    await _prefs!.setBool(_firstLaunchKey, true);
  }

  /// Check if onboarding is completed
  Future<bool> isOnboardingComplete() async {
    await _initPrefs();
    return _prefs!.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    await _initPrefs();
    await _prefs!.setBool(_onboardingCompleteKey, true);
  }

  /// Get current tutorial step
  Future<int> getCurrentTutorialStep() async {
    await _initPrefs();
    return _prefs!.getInt(_tutorialStepKey) ?? 0;
  }

  /// Set current tutorial step
  Future<void> setTutorialStep(int step) async {
    await _initPrefs();
    await _prefs!.setInt(_tutorialStepKey, step);
  }

  /// Check if a specific feature discovery was shown
  Future<bool> wasFeatureDiscoveryShown(String featureKey) async {
    await _initPrefs();
    final shownFeatures = _prefs!.getStringList(_featureDiscoveryKey) ?? [];
    return shownFeatures.contains(featureKey);
  }

  /// Mark a feature discovery as shown
  Future<void> markFeatureDiscoveryShown(String featureKey) async {
    await _initPrefs();
    final shownFeatures = _prefs!.getStringList(_featureDiscoveryKey) ?? [];
    if (!shownFeatures.contains(featureKey)) {
      shownFeatures.add(featureKey);
      await _prefs!.setStringList(_featureDiscoveryKey, shownFeatures);
    }
  }

  /// Reset all onboarding data (for testing)
  Future<void> resetOnboarding() async {
    await _initPrefs();
    await _prefs!.remove(_onboardingCompleteKey);
    await _prefs!.remove(_firstLaunchKey);
    await _prefs!.remove(_tutorialStepKey);
    await _prefs!.remove(_featureDiscoveryKey);
  }

  /// Get onboarding steps data
  List<OnboardingStep> getOnboardingSteps(bool isEnglish) {
    if (isEnglish) {
      return [
        OnboardingStep(
          title: '🌍 Welcome to Carbon Tracker',
          description: 'Track your carbon footprint and make a positive impact on the environment',
          image: '🌱',
          actionText: 'Get Started',
        ),
        OnboardingStep(
          title: '🚗 Track Your Transportation',
          description: 'Log your daily transportation activities to see your CO₂ emissions',
          image: '🚕',
          actionText: 'Continue',
        ),
        OnboardingStep(
          title: '⚡ Monitor Energy Usage',
          description: 'Keep track of your electricity and natural gas consumption',
          image: '💡',
          actionText: 'Continue',
        ),
        OnboardingStep(
          title: '🏆 Earn Achievements',
          description: 'Unlock badges and level up as you reduce your carbon footprint',
          image: '🎯',
          actionText: 'Continue',
        ),
        OnboardingStep(
          title: '📊 View Your Progress',
          description: 'Analyze your data with beautiful charts and statistics',
          image: '📈',
          actionText: 'Start Tracking',
        ),
      ];
    } else {
      return [
        OnboardingStep(
          title: '🌍 Carbon Tracker\'a Hoş Geldiniz',
          description: 'Karbon ayak izinizi takip edin ve çevreye pozitif katkıda bulunun',
          image: '🌱',
          actionText: 'Başla',
        ),
        OnboardingStep(
          title: '🚗 Ulaşımınızı Takip Edin',
          description: 'Günlük ulaşım aktivitelerinizi kaydedin ve CO₂ emisyonlarınızı görün',
          image: '🚕',
          actionText: 'Devam Et',
        ),
        OnboardingStep(
          title: '⚡ Enerji Kullanımını İzleyin',
          description: 'Elektrik ve doğal gaz tüketiminizi takip edin',
          image: '💡',
          actionText: 'Devam Et',
        ),
        OnboardingStep(
          title: '🏆 Başarılar Kazanın',
          description: 'Karbon ayak izinizi azalttıkça rozet ve seviye kazanın',
          image: '🎯',
          actionText: 'Devam Et',
        ),
        OnboardingStep(
          title: '📊 İlerlemenizi Görün',
          description: 'Güzel grafikler ve istatistiklerle verilerinizi analiz edin',
          image: '📈',
          actionText: 'Takibe Başla',
        ),
      ];
    }
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final String image;
  final String actionText;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.image,
    required this.actionText,
  });
}