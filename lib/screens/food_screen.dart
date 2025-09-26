import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import '../widgets/liquid_pull_refresh.dart';
import '../widgets/micro_interactions.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  List<Map<String, dynamic>> foodActivities = [];
  bool isLoading = true;
  double totalCarbonToday = 0.0;
  double totalCarbonWeek = 0.0;
  double totalCarbonMonth = 0.0;

  final LanguageService _languageService = LanguageService.instance;

  // Food categories with carbon factors (kg CO₂ per serving/kg)
  final List<FoodCategory> foodCategories = [
    FoodCategory(
      id: 'beef',
      nameEn: 'Beef & Red Meat',
      nameTr: 'Et ve Kırmızı Et',
      icon: Icons.lunch_dining,
      color: Colors.red,
      carbonPerServing: 27.0, // kg CO₂ per kg of beef
      unit: '100g',
    ),
    FoodCategory(
      id: 'chicken',
      nameEn: 'Chicken & Poultry',
      nameTr: 'Tavuk ve Kanatlı',
      icon: Icons.egg,
      color: Colors.orange,
      carbonPerServing: 6.9, // kg CO₂ per kg
      unit: '100g',
    ),
    FoodCategory(
      id: 'fish',
      nameEn: 'Fish & Seafood',
      nameTr: 'Balık ve Deniz Ürünleri',
      icon: Icons.set_meal,
      color: Colors.blue,
      carbonPerServing: 13.6, // kg CO₂ per kg
      unit: '100g',
    ),
    FoodCategory(
      id: 'dairy',
      nameEn: 'Dairy Products',
      nameTr: 'Süt Ürünleri',
      icon: Icons.local_drink,
      color: Colors.cyan,
      carbonPerServing: 9.8, // kg CO₂ per kg (cheese average)
      unit: 'portion',
    ),
    FoodCategory(
      id: 'vegetables',
      nameEn: 'Vegetables',
      nameTr: 'Sebzeler',
      icon: Icons.eco,
      color: Colors.green,
      carbonPerServing: 2.0, // kg CO₂ per kg
      unit: 'portion',
    ),
    FoodCategory(
      id: 'fruits',
      nameEn: 'Fruits',
      nameTr: 'Meyveler',
      icon: Icons.apple,
      color: Colors.lightGreen,
      carbonPerServing: 1.1, // kg CO₂ per kg
      unit: 'portion',
    ),
    FoodCategory(
      id: 'grains',
      nameEn: 'Grains & Cereals',
      nameTr: 'Tahıl ve Hububat',
      icon: Icons.grass,
      color: Colors.brown,
      carbonPerServing: 2.5, // kg CO₂ per kg
      unit: 'portion',
    ),
    FoodCategory(
      id: 'processed',
      nameEn: 'Processed Foods',
      nameTr: 'İşlenmiş Gıdalar',
      icon: Icons.fastfood,
      color: Colors.deepOrange,
      carbonPerServing: 5.5, // kg CO₂ per kg average
      unit: 'item',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFoodData();
  }

  Future<void> _loadFoodData() async {
    setState(() => isLoading = true);
    
    try {
      // Load food activities from database
      final activities = await DatabaseService.instance.getActivitiesByCategory('food');
      
      // Calculate totals
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));
      final monthAgo = DateTime(today.year, today.month - 1, today.day);

      double todayCarbon = 0.0;
      double weekCarbon = 0.0;
      double monthCarbon = 0.0;

      for (final activity in activities) {
        final activityDate = DateTime.parse(activity['created_at']);
        final carbon = activity['co2_amount'] ?? 0.0;

        if (activityDate.day == today.day && 
            activityDate.month == today.month && 
            activityDate.year == today.year) {
          todayCarbon += carbon;
        }

        if (activityDate.isAfter(weekAgo)) {
          weekCarbon += carbon;
        }

        if (activityDate.isAfter(monthAgo)) {
          monthCarbon += carbon;
        }
      }

      if (mounted) {
        setState(() {
          foodActivities = activities;
          totalCarbonToday = todayCarbon;
          totalCarbonWeek = weekCarbon;
          totalCarbonMonth = monthCarbon;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading food data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addFoodItem(FoodCategory category, int servings) async {
    try {
      final carbonAmount = category.carbonPerServing * servings * 0.1; // Convert to realistic serving size
      
      await DatabaseService.instance.insertActivity({
        'category': 'food',
        'subcategory': category.id,
        'description': '${category.getName(_languageService.isEnglish)} x$servings ${category.unit}',
        'co2_amount': carbonAmount,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'servings': servings,
          'carbon_per_serving': category.carbonPerServing,
          'unit': category.unit,
        }
      });

      await _loadFoodData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService.isEnglish 
              ? 'Added $servings ${category.unit} ${category.nameEn} (+${carbonAmount.toStringAsFixed(1)} kg CO₂)'
              : '$servings ${category.unit} ${category.nameTr} eklendi (+${carbonAmount.toStringAsFixed(1)} kg CO₂)',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.isEnglish ? 'Error adding food item' : 'Yiyecek eklenirken hata oluştu'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Food Carbon' : 'Yemek Karbonu'),
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        foregroundColor: Colors.green,
      ),
      body: LiquidPullRefresh(
        onRefresh: _loadFoodData,
        color: Colors.green,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Cards
                    _buildStatsCards(),
                    const SizedBox(height: 24),

                    // Environmental Impact Info
                    _buildInfoCard(),
                    const SizedBox(height: 24),

                    // Categories Grid
                    Text(
                      _languageService.isEnglish ? 'Food Categories' : 'Yemek Kategorileri',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoriesGrid(),
                    const SizedBox(height: 24),

                    // Recent Activities
                    if (foodActivities.isNotEmpty) ...[
                      Text(
                        _languageService.isEnglish ? 'Recent Meals' : 'Son Yemekler',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRecentActivities(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: Colors.green, size: 32),
            const SizedBox(height: 8),
            Text(
              _languageService.isEnglish ? 'Food Impact Facts' : 'Yemek Etki Bilgileri',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _languageService.isEnglish 
                ? '• Food production accounts for ~26% of global greenhouse gas emissions\n'
                  '• Livestock farming produces ~14.5% of global emissions\n'
                  '• Plant-based foods generally have lower carbon footprints\n'
                  '• Local, seasonal foods reduce transportation emissions'
                : '• Gıda üretimi küresel sera gazı emisyonlarının ~%26\'sını oluşturur\n'
                  '• Hayvancılık küresel emisyonların ~%14.5\'ini üretir\n'
                  '• Bitki bazlı gıdalar genelde daha düşük karbon ayak izine sahiptir\n'
                  '• Yerel, mevsimlik gıdalar ulaştırma emisyonlarını azaltır',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _languageService.isEnglish ? 'Today' : 'Bugün',
            totalCarbonToday,
            Colors.green,
            Icons.today,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            _languageService.isEnglish ? 'This Week' : 'Bu Hafta',
            totalCarbonWeek,
            Colors.teal,
            Icons.calendar_view_week,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            _languageService.isEnglish ? 'This Month' : 'Bu Ay',
            totalCarbonMonth,
            Colors.lightGreen,
            Icons.calendar_month,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, double value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(1)} kg',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              'CO₂',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: foodCategories.length,
      itemBuilder: (context, index) {
        final category = foodCategories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(FoodCategory category) {
    return MicroCard(
      onTap: () => _showServingsDialog(category),
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
            ),
            const SizedBox(height: 12),
            Text(
              category.getName(_languageService.isEnglish),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '${(category.carbonPerServing * 0.1).toStringAsFixed(1)} kg CO₂',
              style: TextStyle(
                color: category.color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            Text(
              'per ${category.unit}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServingsDialog(FoodCategory category) {
    int servings = 1;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category.getName(_languageService.isEnglish)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _languageService.isEnglish 
                  ? 'How many ${category.unit}s?' 
                  : 'Kaç ${category.unit}?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: servings > 1
                        ? () => setDialogState(() => servings--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    servings.toString(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    onPressed: servings < 20
                        ? () => setDialogState(() => servings++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_languageService.isEnglish ? 'Total CO₂:' : 'Toplam CO₂:'} ${(category.carbonPerServing * servings * 0.1).toStringAsFixed(1)} kg',
                style: TextStyle(
                  color: category.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_languageService.isEnglish ? 'Cancel' : 'İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addFoodItem(category, servings);
              },
              child: Text(_languageService.isEnglish ? 'Add' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: foodActivities.take(10).length,
      itemBuilder: (context, index) {
        final activity = foodActivities[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.restaurant, color: Colors.green),
            ),
            title: Text(activity['description'] ?? 'Food Item'),
            subtitle: Text(
              DateTime.parse(activity['created_at']).toString().split(' ')[0],
            ),
            trailing: Text(
              '${activity['co2_amount']?.toStringAsFixed(1) ?? '0.0'} kg CO₂',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }
}

class FoodCategory {
  final String id;
  final String nameEn;
  final String nameTr;
  final IconData icon;
  final Color color;
  final double carbonPerServing;
  final String unit;

  FoodCategory({
    required this.id,
    required this.nameEn,
    required this.nameTr,
    required this.icon,
    required this.color,
    required this.carbonPerServing,
    required this.unit,
  });

  String getName(bool isEnglish) => isEnglish ? nameEn : nameTr;
}