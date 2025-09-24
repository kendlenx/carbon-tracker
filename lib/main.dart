import 'package:flutter/material.dart';
import 'screens/transport_screen.dart';
import 'screens/add_activity_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/energy_screen.dart';
import 'screens/achievements_screen.dart';
import 'services/database_service.dart';
import 'services/carbon_calculator_service.dart';
import 'services/theme_service.dart';
import 'services/achievement_service.dart';
import 'widgets/achievement_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.instance.loadThemePreference();
  await AchievementService.instance.initialize();
  runApp(const CarbonTrackerApp());
}

class CarbonTrackerApp extends StatelessWidget {
  const CarbonTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Carbon Tracker',
          theme: ThemeService.instance.lightTheme,
          darkTheme: ThemeService.instance.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          home: const CarbonTrackerHome(),
          debugShowCheckedModeBanner: false,
        );
      },
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
  final AchievementService _achievementService = AchievementService.instance;

  final List<CategoryData> categories = [
    CategoryData(
      category: CarbonCategory.transport,
      title: 'Ulaşım',
      subtitle: 'Araç, metro, yürüme',
      icon: Icons.directions_car,
      color: Colors.blue,
      todayValue: 8.2,
    ),
    CategoryData(
      category: CarbonCategory.energy,
      title: 'Enerji',
      subtitle: 'Elektrik, doğal gaz',
      icon: Icons.flash_on,
      color: Colors.orange,
      todayValue: 2.8,
    ),
    CategoryData(
      category: CarbonCategory.food,
      title: 'Yemek',
      subtitle: 'Beslenme alışkanlıkları',
      icon: Icons.restaurant,
      color: Colors.green,
      todayValue: 1.2,
    ),
    CategoryData(
      category: CarbonCategory.shopping,
      title: 'Alışveriş',
      subtitle: 'Tüketim malları',
      icon: Icons.shopping_bag,
      color: Colors.purple,
      todayValue: 0.3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
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
  
  Future<void> _checkAchievements() async {
    final newAchievements = <Achievement>[];
    
    // Check daily achievements
    final dailyAchievements = await _achievementService.checkDailyAchievements(totalCarbonToday);
    newAchievements.addAll(dailyAchievements);
    
    // Check milestone achievements (this would need real data)
    // For demo purposes, using dummy values
    final milestoneAchievements = await _achievementService.checkMilestoneAchievements(
      totalCO2Saved: weeklyAverage * 7, // dummy calculation
      totalActivities: 10, // would be from database
    );
    newAchievements.addAll(milestoneAchievements);
    
    // Show achievement unlock dialog if any new achievements
    if (newAchievements.isNotEmpty && mounted) {
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for better UX
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AchievementUnlockDialog(
          newAchievements: newAchievements,
          onDismiss: () {
            // Refresh the UI to show updated achievements
            setState(() {});
          },
        ),
      );
    }
  }

  void _navigateToCategory(CategoryData category) async {
    switch (category.category) {
      case CarbonCategory.transport:
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const TransportScreen(),
          ),
        );
        // Eğer aktivite kaydedildiyse (result == true), verileri yenile
        if (result == true) {
          _loadDashboardData();
        }
        break;
      case CarbonCategory.energy:
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const EnergyScreen(),
          ),
        );
        if (result == true) {
          _loadDashboardData();
        }
        break;
      case CarbonCategory.food:
      case CarbonCategory.shopping:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${category.title} detayları yakında!')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🌱 Carbon Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: Icon(ThemeService.instance.themeIcon),
            tooltip: 'Tema: ${ThemeService.instance.themeName}',
            onPressed: () async {
              await ThemeService.instance.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Başarılar',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AchievementsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'İstatistikler',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StatisticsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Günlük özet kartı
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Bugünkü Karbon Ayak İzi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        // Recent achievements mini display
                        AnimatedBuilder(
                          animation: _achievementService,
                          builder: (context, child) {
                            final recentAchievements = _achievementService.getRecentAchievements();
                            if (recentAchievements.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AchievementsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20.0),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🏆', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '${recentAchievements.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${totalCarbonToday.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'kg CO₂',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Haftalık Ort.', '${weeklyAverage.toStringAsFixed(1)} kg'),
                        AnimatedBuilder(
                          animation: _achievementService,
                          builder: (context, child) {
                            return _buildStatItem(
                              'Seviye',
                              'Lv. ${_achievementService.userLevel} (${_achievementService.totalPoints} XP)',
                            );
                          },
                        ),
                        _buildStatItem('Aylık Hedef', '${monthlyGoal.toStringAsFixed(0)} kg'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Performans karşılaştırması
            if (weeklyAverage > 0) ...[
              _buildPerformanceCard(),
              const SizedBox(height: 24),
            ],
            
            // Kategoriler başlığı
            Text(
              'Kategoriler',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const AddActivityScreen(),
            ),
          );
          // Eğer aktivite eklendiyse verileri yenile
          if (result == true) {
            _loadDashboardData();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Yeni Aktivite Ekle',
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryData category, double todayValue) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          _navigateToCategory(category);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.icon,
                size: 40,
                color: category.color,
              ),
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
              Text(
                '${todayValue.toStringAsFixed(1)} kg CO₂',
                style: TextStyle(
                  color: category.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
