import 'package:flutter/material.dart';
import 'screens/transport_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/energy_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/food_screen.dart';
import 'screens/shopping_screen.dart';
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
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'widgets/achievement_widgets.dart';
import 'widgets/voice_command_widget.dart';
import 'widgets/liquid_pull_refresh.dart';
import 'widgets/hero_dashboard.dart';
import 'widgets/page_transitions.dart';
import 'widgets/micro_interactions.dart';
import 'widgets/carbon_tracker_logo.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CarbonTrackerApp());
}

class CarbonTrackerApp extends StatelessWidget {
  const CarbonTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.instance,
        LanguageService.instance,
      ]),
      builder: (context, child) {
        return MaterialApp(
          title: 'Carbon Tracker',
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
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
      child: const SplashScreen(), // Pre-build child for performance
    );
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
    final isEnglish = _languageService.isEnglish;
    return [
      CategoryData(
        category: CarbonCategory.transport,
        title: isEnglish ? 'Transport' : 'Ulaşım',
        subtitle: isEnglish ? 'Car, metro, walking' : 'Araç, metro, yürüme',
        icon: Icons.directions_car,
        color: Colors.blue,
        todayValue: 8.2,
      ),
      CategoryData(
        category: CarbonCategory.energy,
        title: isEnglish ? 'Energy' : 'Enerji',
        subtitle: isEnglish ? 'Electricity, natural gas' : 'Elektrik, doğal gaz',
        icon: Icons.flash_on,
        color: Colors.orange,
        todayValue: 2.8,
      ),
      CategoryData(
        category: CarbonCategory.food,
        title: isEnglish ? 'Food' : 'Yemek',
        subtitle: isEnglish ? 'Nutrition habits' : 'Beslenme alışkanlıkları',
        icon: Icons.restaurant,
        color: Colors.green,
        todayValue: 1.2,
      ),
      CategoryData(
        category: CarbonCategory.shopping,
        title: isEnglish ? 'Shopping' : 'Alışveriş',
        subtitle: isEnglish ? 'Consumer goods' : 'Tüketim malları',
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
      
      // Check level achievements
      final levelAchievements = await achievementService.checkLevelAchievements();
      
      // Show unlock dialogs for new achievements
      final allNewAchievements = <Achievement>[...dailyAchievements, ...levelAchievements];
      if (allNewAchievements.isNotEmpty) {
        // Send notifications for achievements
        for (final achievement in allNewAchievements) {
          await NotificationService.instance.showAchievementNotification(
            achievement.title,
            achievement.description,
            achievement.points,
          );
        }
        _showAchievementUnlockDialog(allNewAchievements);
      }
    } catch (e) {
      print('Error checking achievements: $e');
    }
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
                  _languageService.isEnglish ? 'Categories' : 'Kategoriler',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.green.shade800.withOpacity(0.3)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _languageService.isEnglish ? 'Track Activities' : 'Aktiviteleri İzle',
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
                childAspectRatio: 1.1,
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
        if (result == true) {
          _loadDashboardData();
          await HapticHelper.trigger(HapticType.success);
        }
        break;
      case CarbonCategory.food:
        final result = await context.pushWithTransition<bool>(
          const FoodScreen(),
          transition: TransitionType.slideUp,
        );
        if (result == true) {
          _loadDashboardData();
          await HapticHelper.trigger(HapticType.success);
        }
        break;
      case CarbonCategory.shopping:
        final result = await context.pushWithTransition<bool>(
          const ShoppingScreen(),
          transition: TransitionType.fadeScale,
        );
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
                  const Text(
                    'Carbon Tracker',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _languageService,
                    builder: (context, child) => Text(
                      _languageService.isEnglish ? '🌍 Track your carbon footprint' : '🌍 Karbon ayak izini takip et',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // More options menu with all controls
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
                  // Ensure reporting service is initialized before opening
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
                    Text(_languageService.isEnglish ? 'Achievements' : 'Başarılar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Statistics' : 'İstatistikler'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'advanced_analytics',
                child: Row(
                  children: [
                    const Icon(Icons.auto_graph, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Advanced Analytics' : 'Gelişmiş Analitik'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'permissions',
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Permissions' : 'İzinler'),
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
          // Home (Dashboard)
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildHomeBody(),
          // Activities Hub
          const ActivitiesHubScreen(),
          // Achievements
          const AchievementsScreen(),
          // Goals
          const GoalsScreen(),
          // Settings
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
            label: _languageService.isEnglish ? 'Home' : 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline),
            activeIcon: const Icon(Icons.add_circle),
            label: _languageService.isEnglish ? 'Activities' : 'Aktiviteler',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.emoji_events_outlined),
            activeIcon: const Icon(Icons.emoji_events),
            label: _languageService.isEnglish ? 'Achievements' : 'Başarılar',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.flag_outlined),
            activeIcon: const Icon(Icons.flag),
            label: _languageService.isEnglish ? 'Goals' : 'Hedefler',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: _languageService.isEnglish ? 'Settings' : 'Ayarlar',
          ),
        ],
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
                color: category.color.withOpacity(0.1),
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
    final tips = CarbonCalculatorService.generateTips(weeklyAverage);
    
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
                  'Performans: ${comparison.performanceText}',
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
                _buildComparisonItem('Siz', '${weeklyAverage.toStringAsFixed(1)} kg'),
                _buildComparisonItem('TR Ort.', '${comparison.turkeyAverage.toStringAsFixed(1)} kg'),
                _buildComparisonItem('Paris Hedef', '${comparison.parisTarget.toStringAsFixed(1)} kg'),
              ],
            ),
            
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '💡 Öneriler',
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
                  Colors.purple.shade800.withOpacity(0.2),
                  Colors.blue.shade900.withOpacity(0.1),
                ]
              : [
                  Colors.purple.withOpacity(0.05),
                  Colors.blue.withOpacity(0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
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
                      color: Colors.amber.withOpacity(0.1),
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
                        _languageService.isEnglish ? 'Achievements' : 'Başarılar',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        Text(
                          _languageService.isEnglish ? 'Your recent milestones' : 'Son kazandığınız rozetler',
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
                  _languageService.isEnglish ? 'All' : 'Tümü',
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
                          color: achievement['color'].withOpacity(0.3),
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
                                    color: achievement['color'].withOpacity(0.2),
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
                    Colors.blue.shade800.withOpacity(0.2),
                    Colors.green.shade800.withOpacity(0.2),
                  ]
                : [
                    Colors.blue.withOpacity(0.1),
                    Colors.green.withOpacity(0.1),
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
                      color: tip['color'].withOpacity(0.2),
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
                          _languageService.isEnglish ? 'Eco Tip' : 'Eko İpucu',
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
                    color: Colors.green.withOpacity(0.1),
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
    final allAchievements = [
      {
        'title': _languageService.isEnglish ? 'First Steps' : 'İlk Adımlar',
        'icon': Icons.eco,
        'color': Colors.green,
        'isNew': true,
      },
      {
        'title': _languageService.isEnglish ? 'Week Warrior' : 'Hafta Savaşçısı',
        'icon': Icons.calendar_view_week,
        'color': Colors.blue,
        'isNew': false,
      },
      {
        'title': _languageService.isEnglish ? 'Green Commuter' : 'Yeşil Yolcu',
        'icon': Icons.directions_bike,
        'color': Colors.teal,
        'isNew': true,
      },
      {
        'title': _languageService.isEnglish ? 'Energy Saver' : 'Enerji Tasarrufçusu',
        'icon': Icons.flash_off,
        'color': Colors.orange,
        'isNew': false,
      },
      {
        'title': _languageService.isEnglish ? 'Food Hero' : 'Yemek Kahramanı',
        'icon': Icons.restaurant,
        'color': Colors.red,
        'isNew': false,
      },
      {
        'title': _languageService.isEnglish ? 'Mindful Shopper' : 'Bilinçli Alışverişçi',
        'icon': Icons.shopping_basket,
        'color': Colors.purple,
        'isNew': true,
      },
      {
        'title': _languageService.isEnglish ? 'Carbon Crusher' : 'Karbon Ezici',
        'icon': Icons.trending_down,
        'color': Colors.indigo,
        'isNew': false,
      },
      {
        'title': _languageService.isEnglish ? 'Planet Protector' : 'Gezegen Koruyucusu',
        'icon': Icons.public,
        'color': Colors.cyan,
        'isNew': true,
      },
    ];
    
    allAchievements.shuffle();
    return allAchievements.take(4).toList();
  }

  Map<String, dynamic> _getRandomTip() {
    final allTips = [
      {
        'text': _languageService.isEnglish ? 'Walk or cycle for trips under 5km. It\'s healthier and reduces emissions by up to 2.6 kg CO₂ per day.' : '5 km altındaki yolculuklarda yürüyün veya bisiklet kullanın. Daha sağlıklı ve günde 2.6 kg CO₂ tasarrufu sağlar.',
        'category': _languageService.isEnglish ? 'Transport' : 'Ulaşım',
        'icon': Icons.directions_bike,
        'color': Colors.green,
        'impact': _languageService.isEnglish ? 'Save up to 2.6 kg CO₂/day' : 'Günde 2.6 kg CO₂ tasarrufu',
      },
      {
        'text': _languageService.isEnglish ? 'Switch to LED bulbs throughout your home. They use 75% less energy and last 25 times longer.' : 'Evinizdeki tüm ampulleri LED ile değiştirin. %75 daha az enerji kullanır ve 25 kat daha uzun sürer.',
        'category': _languageService.isEnglish ? 'Energy' : 'Enerji',
        'icon': Icons.lightbulb,
        'color': Colors.orange,
        'impact': _languageService.isEnglish ? 'Save 75% energy' : '%75 enerji tasarrufu',
      },
      {
        'text': _languageService.isEnglish ? 'Try "Meatless Monday" - reducing meat consumption by one day saves 3.3 kg CO₂ weekly.' : '"Etsiz Pazartesi" deneyin - haftada bir gün et tüketimini azaltmak 3.3 kg CO₂ tasarrufu sağlar.',
        'category': _languageService.isEnglish ? 'Food' : 'Beslenme',
        'icon': Icons.restaurant,
        'color': Colors.red,
        'impact': _languageService.isEnglish ? 'Save 3.3 kg CO₂/week' : 'Haftada 3.3 kg CO₂ tasarrufu',
      },
      {
        'text': _languageService.isEnglish ? 'Buy local produce when possible. Food transport accounts for 11% of food-related emissions.' : 'Mümkün olduğunca yerel ürünler alın. Gıda taşımacılığı, gıdayla ilgili emisyonların %11\'ini oluşturur.',
        'category': _languageService.isEnglish ? 'Shopping' : 'Alışveriş',
        'icon': Icons.local_grocery_store,
        'color': Colors.green,
        'impact': _languageService.isEnglish ? 'Reduce transport emissions' : 'Taşıma emisyonlarını azaltır',
      },
      {
        'text': _languageService.isEnglish ? 'Unplug electronics when not in use. "Vampire" power consumption can add 10% to your electricity bill.' : 'Kullanmadığınızda elektronik cihazları prizden çekin. "Vampir" güç tüketimi elektrik faturanıza %10 ekleyebilir.',
        'category': _languageService.isEnglish ? 'Energy' : 'Enerji',
        'icon': Icons.power_off,
        'color': Colors.blue,
        'impact': _languageService.isEnglish ? 'Save 10% on electricity' : 'Elektrikte %10 tasarruf',
      },
      {
        'text': _languageService.isEnglish ? 'Use public transport or carpool. A full bus can take 40 cars off the road, saving 80 kg CO₂ per trip.' : 'Toplu taşıma kullanın veya araç paylaşın. Dolu bir otobüs yoldan 40 arabayı çıkarır, yolculuk başına 80 kg CO₂ tasarrufu.',
        'category': _languageService.isEnglish ? 'Transport' : 'Ulaşım',
        'icon': Icons.bus_alert,
        'color': Colors.teal,
        'impact': _languageService.isEnglish ? 'Save 80 kg CO₂/trip' : 'Yolculuk başına 80 kg CO₂ tasarrufu',
      },
      {
        'text': _languageService.isEnglish ? 'Fix leaky faucets promptly. A single drip per second wastes over 3,000 gallons per year.' : 'Sızıntılı muslukları hemen tamir edin. Saniyede bir damla, yılda 11.000 litreden fazla su israfi yapar.',
        'category': _languageService.isEnglish ? 'Home' : 'Ev',
        'icon': Icons.water_drop,
        'color': Colors.lightBlue,
        'impact': _languageService.isEnglish ? 'Save thousands of gallons' : 'Binlerce litre tasarruf',
      },
      {
        'text': _languageService.isEnglish ? 'Start composting kitchen scraps. It reduces methane emissions and creates nutrient-rich soil.' : 'Mutfak artıklarını kompostlamaya başlayın. Metan emisyonlarını azaltır ve besin açısından zengin toprak oluşturur.',
        'category': _languageService.isEnglish ? 'Waste' : 'Atık',
        'icon': Icons.compost,
        'color': Colors.brown,
        'impact': _languageService.isEnglish ? 'Reduce methane emissions' : 'Metan emisyonlarını azaltır',
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
          _languageService.isEnglish 
            ? 'Congratulations on earning this achievement! Keep up the great work in reducing your carbon footprint.'
            : 'Bu başarıyı kazandığınız için tebrikler! Karbon ayak izinizi azaltmada harika işler çıkarmaya devam edin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_languageService.isEnglish ? 'Close' : 'Kapat'),
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
                  Colors.green.shade800.withOpacity(0.2),
                  Colors.blue.shade900.withOpacity(0.1),
                ]
              : [
                  Colors.green.withOpacity(0.05),
                  Colors.blue.withOpacity(0.03),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
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
                      color: Colors.lightBlue.withOpacity(0.1),
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
                        _languageService.isEnglish ? 'Smart Tips' : 'Akıllı Öneriler',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _languageService.isEnglish ? 'AI-powered suggestions' : 'Yapay zeka destekli öneriler',
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
                      color: recommendation.color.withOpacity(0.05),
                      border: Border.all(
                        color: recommendation.color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: recommendation.color.withOpacity(0.1),
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
                                recommendation.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                recommendation.description,
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
                                color: Colors.green.withOpacity(0.1),
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
                recommendation.title,
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
            Text(recommendation.description),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
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
                    _languageService.isEnglish 
                        ? 'Potential saving: ${recommendation.potentialSaving.toStringAsFixed(1)} kg CO₂'
                        : 'Potansiyel tasarruf: ${recommendation.potentialSaving.toStringAsFixed(1)} kg CO₂',
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
            child: Text(_languageService.isEnglish ? 'Got it!' : 'Anladım!'),
          ),
        ],
      ),
    );
  }
}
