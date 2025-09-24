import 'package:flutter/material.dart';
import 'screens/transport_screen.dart';
import 'screens/add_activity_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/energy_screen.dart';
import 'screens/achievements_screen.dart';
import 'screens/food_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/permissions_screen.dart';
import 'services/database_service.dart';
import 'services/carbon_calculator_service.dart';
import 'services/theme_service.dart';
import 'services/achievement_service.dart';
import 'services/smart_features_service.dart';
import 'services/notification_service.dart';
import 'services/goal_service.dart';
import 'services/location_service.dart';
import 'services/voice_service.dart';
import 'services/smart_home_service.dart';
import 'services/device_integration_service.dart';
import 'services/language_service.dart';
import 'services/permission_service.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'widgets/achievement_widgets.dart';
import 'widgets/liquid_pull_refresh.dart';
import 'widgets/hero_dashboard.dart';
import 'widgets/morphing_fab.dart';
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
        
        // Achievement checking disabled for now
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
  
  // Achievement checking temporarily disabled

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
                case 'language':
                  await _languageService.toggleLanguage();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_languageService.isEnglish ? 'Language changed to' : 'Dil değiştirildi:'} ${_languageService.currentLanguageDisplayName}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                  break;
                case 'theme':
                  await ThemeService.instance.toggleTheme();
                  break;
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
                case 'goals':
                  context.pushWithTransition(
                    const GoalsScreen(),
                    transition: TransitionType.fadeScale,
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    Text(
                      _languageService.currentLanguageFlag,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Language' : 'Dil'),
                    const Spacer(),
                    Text(
                      _languageService.currentLanguageDisplayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(ThemeService.instance.themeIcon, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Theme' : 'Tema'),
                    const Spacer(),
                    Text(
                      _languageService.isEnglish ? ThemeService.instance.themeName : 
                        (ThemeService.instance.themeName == 'Light' ? 'Açık' : 
                         ThemeService.instance.themeName == 'Dark' ? 'Koyu' : 'Sistem'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
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
                value: 'permissions',
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Permissions' : 'İzinler'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'goals',
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Goals' : 'Hedefler'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(_languageService.isEnglish ? 'Settings' : 'Ayarlar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LiquidPullRefresh(
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
            
            // Performans karşılaştırması
            if (weeklyAverage > 0) ...[
              _buildPerformanceCard(),
              const SizedBox(height: 24),
            ],
            
            // Kategoriler başlığı
            Text(
              _languageService.isEnglish ? 'Categories' : 'Kategoriler',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Kategori kartları
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
                
                // Sadece ulaşım kategorisi için bugünkü değeri göster
                if (category.category == CarbonCategory.transport) {
                  todayValue = totalCarbonToday;
                }
                
                return _buildCategoryCard(category, todayValue);
              },
            ),
          ],
                ),
              ),
            ),
      floatingActionButton: SpeedDialFAB(
        mainFAB: MorphingFAB(
          currentAction: FABAction(
            state: FABState.add,
            icon: Icons.add,
            tooltip: _languageService.isEnglish ? 'Quick Actions' : 'Hızlı İşlemler',
            onPressed: () async {
              final result = await context.pushWithTransition<bool>(
                const AddActivityScreen(),
                transition: TransitionType.fadeScale,
                duration: const Duration(milliseconds: 350),
              );
              if (result == true) {
                _loadDashboardData();
              }
            },
          ),
        ),
        actions: [
          SpeedDialAction(
            icon: Icons.directions_car,
            label: _languageService.isEnglish ? 'Transport' : 'Ulaşım',
            backgroundColor: Colors.blue,
            onPressed: () async {
              final result = await context.pushWithTransition<bool>(
                const TransportScreen(),
                transition: TransitionType.slideLeft,
                duration: const Duration(milliseconds: 300),
              );
              if (result == true) {
                _loadDashboardData();
              }
            },
          ),
          SpeedDialAction(
            icon: Icons.flash_on,
            label: _languageService.isEnglish ? 'Energy' : 'Enerji',
            backgroundColor: Colors.orange,
            onPressed: () async {
              final result = await context.pushWithTransition<bool>(
                const EnergyScreen(),
                transition: TransitionType.ripple,
                duration: const Duration(milliseconds: 400),
              );
              if (result == true) {
                _loadDashboardData();
              }
            },
          ),
          SpeedDialAction(
            icon: Icons.add,
            label: _languageService.isEnglish ? 'Add General' : 'Genel Ekle',
            backgroundColor: Colors.green,
            onPressed: () async {
              final result = await context.pushWithTransition<bool>(
                const AddActivityScreen(),
                transition: TransitionType.morphing,
                duration: const Duration(milliseconds: 450),
              );
              if (result == true) {
                _loadDashboardData();
              }
            },
          ),
          SpeedDialAction(
            icon: Icons.mic_none,
            label: _languageService.isEnglish ? 'Voice Command' : 'Sesli Komut',
            backgroundColor: Colors.purple,
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_languageService.isEnglish ? 'Voice command feature coming soon!' : 'Sesli komut özelliği yakında!')),
              );
            },
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
                color: Colors.grey.shade600,
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
            color: Colors.grey.shade600,
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
        return Icons.warning;
    }
  }
}
