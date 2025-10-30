import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'services/error_handler_service.dart';
import 'screens/transport_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/energy_screen.dart';
import 'screens/food_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'services/security_service.dart';
import 'services/firebase_service.dart';
import 'screens/settings_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/activities_hub_screen.dart';
import 'screens/analytics_dashboard_screen.dart';
import 'services/database_service.dart';
import 'services/carbon_calculator_service.dart';
import 'services/theme_service.dart';
import 'services/achievement_service.dart' show AchievementService, Achievement;
import 'services/smart_features_service.dart';
import 'services/notification_service.dart';
import 'services/language_service.dart';
import 'services/permission_service.dart';
import 'services/advanced_reporting_service.dart';
import 'services/widget_data_provider.dart';
import 'services/admob_service.dart';
import 'services/performance_service.dart';
import 'services/background_init_service.dart';
import 'services/gamification_service.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'widgets/achievement_widgets.dart';
import 'widgets/liquid_pull_refresh.dart';
import 'widgets/hero_dashboard.dart';
import 'widgets/page_transitions.dart';
import 'widgets/micro_interactions.dart';
import 'widgets/carbon_tracker_logo.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/export_share_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Performance optimizations for release builds
  if (!kDebugMode) {
    // Disable debug logs in release
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  
  // Initialize global error handler (Crashlytics/Analytics)
  await ErrorHandlerService().initialize();
  
  // Forward Flutter framework errors to the handler (non-fatal)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorHandlerService().recordError(
      details.exception,
      details.stack,
      fatal: false,
      context: {
        'library': details.library ?? '',
        'context': details.context?.toDescription() ?? '',
      },
    );
  };
  
  // Also catch uncaught async errors
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    ErrorHandlerService().recordError(error, stack, fatal: true);
    return true;
  };
  
  // Create service instances without awaiting heavy initialization here
  final securityService = SecurityService();
  final firebaseService = FirebaseService();

  runApp(CarbonTrackerApp(
    securityService: securityService,
    firebaseService: firebaseService,
  ));
}

class CarbonTrackerApp extends StatefulWidget {
  final SecurityService securityService;
  final FirebaseService firebaseService;
  
  const CarbonTrackerApp({
    super.key, 
    required this.securityService,
    required this.firebaseService,
  });

  @override
  State<CarbonTrackerApp> createState() => _CarbonTrackerAppState();
}

class _CarbonTrackerAppState extends State<CarbonTrackerApp> {
  bool _isAuthenticated = false;
  bool _needsAuthentication = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    // Start heavy initializations in background without blocking UI
    BackgroundInitService.start(
      securityService: widget.securityService,
      firebaseService: widget.firebaseService,
    );
  }

  Future<void> _checkAuthentication() async {
    final needsAuth = await widget.securityService.isAppLockEnabled();
    setState(() {
      _needsAuthentication = needsAuth;
      _isAuthenticated = !needsAuth;
    });
  }

  Future<void> _showBiometricLock() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => const BiometricLockScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.instance,
        LanguageService.instance,
      ]),
      builder: (context, child) {
        return MaterialApp(
          title: 'Carbon Step',
          theme: ThemeService.instance.lightTheme,
          darkTheme: ThemeService.instance.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          locale: LanguageService.instance.currentLocale,
          supportedLocales: LanguageService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _buildHomeScreen(),
          debugShowCheckedModeBanner: false,
          // Performance optimizations
          checkerboardRasterCacheImages: kDebugMode,
          checkerboardOffscreenLayers: kDebugMode,
          showPerformanceOverlay: false,
          builder: (context, child) {
            final l10n = AppLocalizations.of(context)!;
            NotificationService.instance.setTranslator((key) => l10n.translate(key));
            return child!;
          },
        );
      },
    );
  }

  Widget _buildHomeScreen() {
    if (_needsAuthentication && !_isAuthenticated) {
      // Show biometric lock if authentication is needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showBiometricLock();
        }
      });
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }
    return const SplashScreen();
  }
}

// Carbon footprint categories
enum CarbonCategory {
  transport,
  energy,
  food,
  shopping,
}

class CategoryData {
  final CarbonCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double todayValue;

  CategoryData({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.todayValue,
  });
}

class CarbonTrackerHome extends StatefulWidget {
  const CarbonTrackerHome({super.key});

  @override
  State<CarbonTrackerHome> createState() => _CarbonTrackerHomeState();
}

class _CarbonTrackerHomeState extends State<CarbonTrackerHome> {
  double totalCarbonToday = 0.0; // kg CO₂
  double weeklyAverage = 0.0; // kg CO₂
  double monthlyGoal = 400.0; // kg CO₂
  bool isLoading = true;
  int _currentIndex = 0;
  final LanguageService _languageService = LanguageService.instance;
  final PermissionService _permissionService = PermissionService.instance;

  List<CategoryData> get categories {
    final l10n = AppLocalizations.of(context)!;
    return [
      CategoryData(
        category: CarbonCategory.transport,
        title: l10n.navTransport,
        subtitle: l10n.transportSubtitle,
        icon: Icons.directions_car,
        color: Colors.blue,
        todayValue: 8.2,
      ),
      CategoryData(
        category: CarbonCategory.energy,
        title: l10n.energyTitle,
        subtitle: l10n.energySubtitle,
        icon: Icons.flash_on,
        color: Colors.orange,
        todayValue: 2.8,
      ),
      CategoryData(
        category: CarbonCategory.food,
        title: l10n.translate('navigation.food'),
        subtitle: l10n.translate('food.subtitle'),
        icon: Icons.restaurant,
        color: Colors.green,
        todayValue: 1.2,
      ),
      CategoryData(
        category: CarbonCategory.shopping,
        title: l10n.translate('navigation.shopping'),
        subtitle: l10n.translate('shopping.subtitle'),
        icon: Icons.shopping_bag,
        color: Colors.purple,
        todayValue: 0.3,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadDashboardData();
    
    // Initialize widget data provider
    await WidgetDataProvider.instance.initialize();
    WidgetDataProvider.instance.schedulePeriodicUpdates();
    
    // Check permissions on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_permissionService.isFirstTimeSetup()) {
        await _permissionService.showFirstTimePermissionSetup(context);
      }
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      final stats = await DatabaseService.instance.getDashboardStats();
      if (mounted) {
        setState(() {
          totalCarbonToday = stats['todayTotal'];
          weeklyAverage = stats['weeklyAverage'];
          isLoading = false;
        });
        
        // Check for new achievements
        _checkAchievements();
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  // Achievement checking method
  Future<void> _checkAchievements() async {
    try {
      final achievementService = AchievementService.instance;
      
      // Check daily achievements
      final dailyAchievements = await achievementService.checkDailyAchievements(totalCarbonToday);
      
      // Check weekly achievements (streak + transport diversity)
      final streak = GamificationService.instance.streak;
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: DateTime.now().weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      final weekActivities = await DatabaseService.instance.getTransportActivities(
        startDate: weekStart,
        endDate: weekEnd,
      );
      final differentTransportTypes = weekActivities.map((a) => a.type.name).toSet().length;
      final weeklyAchievements = await achievementService.checkWeeklyAchievements(
        consecutiveDays: streak,
        differentTransportTypes: differentTransportTypes,
      );
      
      // Check level achievements
      final levelAchievements = await achievementService.checkLevelAchievements();
      
      // Show unlock dialogs for new achievements
      final allNewAchievements = <Achievement>[...dailyAchievements, ...weeklyAchievements, ...levelAchievements];
      if (allNewAchievements.isNotEmpty) {
        // Send notifications for achievements
        final l = AppLocalizations.of(context)!;
        for (final achievement in allNewAchievements) {
          final title = l.translate('ach.${achievement.id}.title');
          final desc = l.translate('ach.${achievement.id}.desc');
          await NotificationService.instance.showAchievementNotification(
            title,
            desc,
            achievement.points,
          );
        }
        _showAchievementUnlockDialog(allNewAchievements);
      }
    } catch (e) {
      print('Error checking achievements: $e');
    }
  }
  
  Widget _buildStreakBar() {
    return AnimatedBuilder(
      animation: GamificationService.instance,
      builder: (context, _) {
        final streak = GamificationService.instance.streak;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('ui.tabs.streak'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (streak % 7) / 7.0,
                        minHeight: 6,
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        color: Colors.green,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${streak}${AppLocalizations.of(context)!.translate('ui.daysShort')} ${AppLocalizations.of(context)!.translate('ui.tabs.streak').toLowerCase()} • ${(7 - (streak % 7))} ${AppLocalizations.of(context)!.translate('ui.toNextReward')}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FutureBuilder<WeeklyChallenge>(
                  future: GamificationService.instance.getWeeklyChallenge(),
                  builder: (context, snapshot) {
                    final completed = (snapshot.data?.completion ?? 0) >= 1.0;
                    if (!completed) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            AppLocalizations.of(context)!.translate('ui.weeklyReward'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _showAchievementUnlockDialog(List<Achievement> achievements) {
    if (achievements.isEmpty || !mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AchievementUnlockDialog(
        newAchievements: achievements,
      ),
    );
  }
  
  Widget _buildHomeBody() {
    return LiquidPullRefresh(
      onRefresh: _loadDashboardData,
      color: Theme.of(context).primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Dashboard
            HeroDashboard(
              totalCarbonToday: totalCarbonToday,
              weeklyAverage: weeklyAverage,
              monthlyGoal: monthlyGoal,
              isLoading: false,
            ),
            const SizedBox(height: 12),
            _buildStreakBar(),
            const SizedBox(height: 24),
            // Performance comparison
            if (weeklyAverage > 0) ...[
              _buildPerformanceCard(),
              const SizedBox(height: 24),
            ],
            // Tips section
            _buildTipsSection(),
            const SizedBox(height: 24),
            // Smart Recommendations section
            _buildSmartRecommendationsSection(),
            const SizedBox(height: 24),
            // Achievements section
            _buildAchievementsSection(),
            const SizedBox(height: 24),
            // Categories header
            Row(
              children: [
                Icon(
                  Icons.grid_view,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.dashboardCategories,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.green.shade800.withValues(alpha: 0.3)
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.translate('navigation.activities'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.shade300
                          : Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Category cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.95,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                double todayValue = 0.0;
                if (category.category == CarbonCategory.transport) {
                  todayValue = totalCarbonToday;
                }
                return _buildCategoryCard(category, todayValue);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _navigateToCategory(CategoryData category) async {
    // Haptic feedback for navigation
    await HapticHelper.trigger(HapticType.selection);
    
    switch (category.category) {
      case CarbonCategory.transport:
        final result = await context.pushWithTransition<bool>(
          const TransportScreen(),
          transition: TransitionType.slideLeft,
        );
        if (!mounted) return;
        // Eğer aktivite kaydedildiyse (result == true), verileri yenile
        if (result == true) {
          _loadDashboardData();
          await HapticHelper.trigger(HapticType.success);
        }
        break;
      case CarbonCategory.energy:
        final result = await context.pushWithTransition<bool>(
          const EnergyScreen(),
          transition: TransitionType.ripple,
        );
        if (!mounted) return;
        if (result == true) {
          _loadDashboardData();
          await HapticHelper.trigger(HapticType.success);
        }
        break;
      case CarbonCategory.food:
        final result = await context.pushWithTransition<bool>(
          FoodScreen(),
          transition: TransitionType.slideUp,
        );
        if (!mounted) return;
        if (result == true) {
          _loadDashboardData();
          await HapticHelper.trigger(HapticType.success);
        }
        break;
      case CarbonCategory.shopping:
        final result = await context.pushWithTransition<bool>(
          ShoppingScreen(),
          transition: TransitionType.fadeScale,
        );
        if (!mounted) return;
        if (result == true) {
          _loadDashboardData();
          await HapticHelper.trigger(HapticType.success);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            CarbonTrackerIcon(size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _languageService,
                    builder: (context, child) => Text(
                      '🌍 ${AppLocalizations.of(context)!.appSubtitle}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'achievements':
                  context.pushWithTransition(
                    const AchievementsScreen(),
                    transition: TransitionType.fadeScale,
                  );
                  break;
                case 'statistics':
                  context.pushWithTransition(
                    const StatisticsScreen(),
                    transition: TransitionType.slideUp,
                  );
                  break;
                case 'advanced_analytics':
                  await AdvancedReportingService.instance.initialize();
                  context.pushWithTransition(
                    const AnalyticsDashboardScreen(),
                    transition: TransitionType.slideLeft,
                  );
                  break;
                case 'permissions':
                  context.pushWithTransition(
                    const PermissionsScreen(),
                    transition: TransitionType.slideUp,
                  );
                  break;
                case 'settings':
                  context.pushWithTransition(
                    const SettingsScreen(),
                    transition: TransitionType.slideLeft,
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'achievements',
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.achievementsTitle),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.statisticsTitle),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'advanced_analytics',
                child: Row(
                  children: [
                    const Icon(Icons.auto_graph, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.translate('ui.advancedAnalytics')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'permissions',
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.permissionsTitle),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          isLoading ? const Center(child: CircularProgressIndicator()) : _buildHomeBody(),
          const ActivitiesHubScreen(),
          const AchievementsScreen(),
          const GoalsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdWidget(),
            BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 10,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: AppLocalizations.of(context)!.navHome,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.add_circle_outline),
                  activeIcon: const Icon(Icons.add_circle),
                  label: AppLocalizations.of(context)!.translate('navigation.activities'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.emoji_events_outlined),
                  activeIcon: const Icon(Icons.emoji_events),
                  label: AppLocalizations.of(context)!.navAchievements,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.flag_outlined),
                  activeIcon: const Icon(Icons.flag),
                  label: AppLocalizations.of(context)!.goalsTitle,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.navSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCategoryCard(CategoryData category, double todayValue) {
    return MicroCard(
      onTap: () => _navigateToCategory(category),
      hapticType: HapticType.light,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.icon,
              size: 40,
              color: category.color,
            ).withMicroTooltip(category.subtitle),
            const SizedBox(height: 12),
            Text(
              category.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              category.subtitle,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                '${todayValue.toStringAsFixed(1)} kg CO₂',
                style: TextStyle(
                  color: category.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final comparison = CarbonCalculatorService.compareWithAverage(weeklyAverage);
    final tips = CarbonCalculatorService.generateTips(
      weeklyAverage,
      (key) => AppLocalizations.of(context)!.translate(key),
    );
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPerformanceIcon(comparison.performanceLevel),
                  color: comparison.performanceColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${AppLocalizations.of(context)!.dashboardPerformance}: ${_perfLabel(AppLocalizations.of(context)!, comparison.performanceLevel)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Karşılaştırma verileri
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildComparisonItem(AppLocalizations.of(context)!.statisticsYourAverage, '${weeklyAverage.toStringAsFixed(1)} kg'),
                _buildComparisonItem(AppLocalizations.of(context)!.statisticsTurkeyAverage, '${comparison.turkeyAverage.toStringAsFixed(1)} kg'),
                _buildComparisonItem(AppLocalizations.of(context)!.statisticsParisTarget, '${comparison.parisTarget.toStringAsFixed(1)} kg'),
              ],
            ),
            
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '💡 ${AppLocalizations.of(context)!.translate('ui.ecoTip')}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...tips.take(2).map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: tip.difficultyColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip.tip,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade400
                : Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _translateRecommendationTitle(String title) {
    final l = AppLocalizations.of(context)!;
    switch (title) {
      case 'LED Dönüşümü':
        return l.translate('smartTips.ledConversion.title');
      case 'Yürüyüş Hedefi':
        return l.translate('smartTips.walkGoal.title');
      case 'Toplu Taşıma Avantajı':
        return l.translate('smartTips.publicTransport.title');
      case 'Akıllı Termostat':
        return l.translate('smartTips.smartThermostat.title');
      case 'Elektronik Cihaz Yönetimi':
        return l.translate('smartTips.electronicsManagement.title');
      case 'Bisiklet Kullanımı':
        return l.translate('smartTips.cycling.title');
      default:
        return title;
    }
  }

  String _translateRecommendationDesc(String desc) {
    final l = AppLocalizations.of(context)!;
    if (desc.contains('LED')) return l.translate('smartTips.ledConversion.desc');
    if (desc.contains('1 km') || desc.contains('yürüyerek')) return l.translate('smartTips.walkGoal.desc');
    if (desc.contains('toplu taşıma')) return l.translate('smartTips.publicTransport.desc');
    if (desc.contains('Termostat')) return l.translate('smartTips.smartThermostat.desc');
    if (desc.contains('cihazları')) return l.translate('smartTips.electronicsManagement.desc');
    if (desc.contains('bisiklet')) return l.translate('smartTips.cycling.desc');
    return desc;
  }

  String _perfLabel(AppLocalizations l, PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.excellent:
        return l.translate('ui.performance.excellent');
      case PerformanceLevel.good:
        return l.translate('ui.performance.good');
      case PerformanceLevel.average:
        return l.translate('ui.performance.average');
      case PerformanceLevel.poor:
        return l.translate('ui.performance.poor');
      case PerformanceLevel.critical:
        return l.translate('ui.performance.critical');
    }
  }

  IconData _getPerformanceIcon(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.excellent:
        return Icons.eco;
      case PerformanceLevel.good:
        return Icons.thumb_up;
      case PerformanceLevel.average:
        return Icons.remove;
      case PerformanceLevel.poor:
        return Icons.thumb_down;
      case PerformanceLevel.critical:
        return Icons.trending_up;
    }
  }

  Widget _buildAchievementsSection() {
    final achievements = _getRandomAchievements();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  Colors.purple.shade800.withValues(alpha: 0.2),
                  Colors.blue.shade900.withValues(alpha: 0.1),
                ]
              : [
                  Colors.purple.withValues(alpha: 0.05),
                  Colors.blue.withValues(alpha: 0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.achievementsTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        Text(
                          AppLocalizations.of(context)!.translate('ui.recentMilestones'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  context.pushWithTransition(
                    const AchievementsScreen(),
                    transition: TransitionType.fadeScale,
                  );
                },
                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                label: Text(
                  AppLocalizations.of(context)!.translate('common.all'),
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  child: MicroCard(
                    onTap: () => _showAchievementDetail(achievement),
                    hapticType: HapticType.light,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: achievement['color'].withOpacity(0.1),
                        border: Border.all(
                        color: achievement['color'].withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: achievement['color'].withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    achievement['icon'],
                                    color: achievement['color'],
                                    size: 16,
                                  ),
                                ),
                                if (achievement['isNew'] == true)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              achievement['title'],
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    final tip = _getRandomTip();
    
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    Colors.blue.shade800.withValues(alpha: 0.2),
                    Colors.green.shade800.withValues(alpha: 0.2),
                  ]
                : [
                    Colors.blue.withValues(alpha: 0.1),
                    Colors.green.withValues(alpha: 0.1),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tip['color'].withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tip['icon'],
                      color: tip['color'],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.translate('ui.ecoTip'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip['category'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      setState(() {}); // This will refresh and get a new tip
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tip['text'],
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (tip['impact'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tip['impact'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRandomAchievements() {
    final l = AppLocalizations.of(context)!;
    final allAchievements = [
      {
        'title': l.translate('homeAch.firstSteps'),
        'icon': Icons.eco,
        'color': Colors.green,
        'isNew': true,
      },
      {
        'title': l.translate('homeAch.weekWarrior'),
        'icon': Icons.calendar_view_week,
        'color': Colors.blue,
        'isNew': false,
      },
      {
        'title': l.translate('homeAch.greenCommuter'),
        'icon': Icons.directions_bike,
        'color': Colors.teal,
        'isNew': true,
      },
      {
        'title': l.translate('homeAch.energySaver'),
        'icon': Icons.flash_off,
        'color': Colors.orange,
        'isNew': false,
      },
      {
        'title': l.translate('homeAch.foodHero'),
        'icon': Icons.restaurant,
        'color': Colors.red,
        'isNew': false,
      },
      {
        'title': l.translate('homeAch.mindfulShopper'),
        'icon': Icons.shopping_basket,
        'color': Colors.purple,
        'isNew': true,
      },
      {
        'title': l.translate('homeAch.carbonCrusher'),
        'icon': Icons.trending_down,
        'color': Colors.indigo,
        'isNew': false,
      },
      {
        'title': l.translate('homeAch.planetProtector'),
        'icon': Icons.public,
        'color': Colors.cyan,
        'isNew': true,
      },
    ];
    
    allAchievements.shuffle();
    return allAchievements.take(4).toList();
  }

  Map<String, dynamic> _getRandomTip() {
    final l10n = AppLocalizations.of(context)!;
    final allTips = [
      {
        'text': l10n.translate('tips.walkMore'),
        'category': l10n.navTransport,
        'icon': Icons.directions_bike,
        'color': Colors.green,
        'impact': null,
      },
      {
        'text': l10n.translate('tips.usePublicTransport'),
        'category': l10n.navTransport,
        'icon': Icons.bus_alert,
        'color': Colors.teal,
        'impact': null,
      },
      {
        'text': l10n.translate('tips.energyEfficient'),
        'category': l10n.energyTitle,
        'icon': Icons.lightbulb,
        'color': Colors.orange,
        'impact': null,
      },
      {
        'text': l10n.translate('tips.localProducts'),
        'category': l10n.translate('navigation.shopping'),
        'icon': Icons.local_grocery_store,
        'color': Colors.green,
        'impact': null,
      },
      {
        'text': l10n.translate('tips.reduceWaste'),
        'category': l10n.translate('navigation.shopping'),
        'icon': Icons.delete_sweep,
        'color': Colors.brown,
        'impact': null,
      },
      {
        'text': l10n.translate('tips.smartThermostat'),
        'category': l10n.energyTitle,
        'icon': Icons.thermostat,
        'color': Colors.blue,
        'impact': null,
      },
    ];
    
    allTips.shuffle();
    return allTips.first;
  }

  void _showAchievementDetail(Map<String, dynamic> achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(achievement['icon'], color: achievement['color']),
            const SizedBox(width: 8),
            Expanded(child: Text(achievement['title'])),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.translate('achievements.detailMessage'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.close')),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSmartRecommendationsSection() {
    final smartService = SmartFeaturesService.instance;
    final recommendations = smartService.unreadRecommendations.take(3).toList();
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  Colors.green.shade800.withValues(alpha: 0.2),
                  Colors.blue.shade900.withValues(alpha: 0.1),
                ]
              : [
                  Colors.green.withValues(alpha: 0.05),
                  Colors.blue.withValues(alpha: 0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb,
                      color: Colors.lightBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('ui.smartTips'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.translate('ui.aiPoweredSuggestions'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: recommendations.map((recommendation) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: MicroCard(
                  onTap: () => _showRecommendationDetail(recommendation),
                  hapticType: HapticType.light,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: recommendation.color.withValues(alpha: 0.05),
                      border: Border.all(
                        color: recommendation.color.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: recommendation.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            recommendation.icon,
                            color: recommendation.color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _translateRecommendationTitle(recommendation.title),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _translateRecommendationDesc(recommendation.description),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '-${recommendation.potentialSaving.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  void _showRecommendationDetail(SmartRecommendation recommendation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              recommendation.icon,
              color: recommendation.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _translateRecommendationTitle(recommendation.title),
                style: TextStyle(
                  color: recommendation.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_translateRecommendationDesc(recommendation.description)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.eco,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${AppLocalizations.of(context)!.translate('ui.potentialSaving')}: ${recommendation.potentialSaving.toStringAsFixed(1)} kg CO₂',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Mark as read
              SmartFeaturesService.instance.markRecommendationAsRead(recommendation.id);
            },
            child: Text(AppLocalizations.of(context)!.translate('ui.gotIt')),
          ),
        ],
      ),
    );
  }
}
