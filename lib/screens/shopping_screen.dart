import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  List<Map<String, dynamic>> shoppingActivities = [];
  bool isLoading = true;
  double totalCarbonToday = 0.0;
  double totalCarbonWeek = 0.0;
  double totalCarbonMonth = 0.0;

  final LanguageService _languageService = LanguageService.instance;

  // Shopping categories with carbon factors (kg CO₂)
  final List<ShoppingCategory> shoppingCategories = [
    ShoppingCategory(
      id: 'clothing',
      nameEn: 'Clothing & Fashion',
      nameTr: 'Giyim ve Moda',
      icon: Icons.shopping_bag,
      color: Colors.purple,
      carbonPerItem: 15.0, // kg CO₂ per clothing item average
    ),
    ShoppingCategory(
      id: 'electronics',
      nameEn: 'Electronics',
      nameTr: 'Elektronik',
      icon: Icons.devices,
      color: Colors.blue,
      carbonPerItem: 200.0, // kg CO₂ per electronic device average
    ),
    ShoppingCategory(
      id: 'books',
      nameEn: 'Books & Media',
      nameTr: 'Kitap ve Medya',
      icon: Icons.book,
      color: Colors.green,
      carbonPerItem: 2.5, // kg CO₂ per book
    ),
    ShoppingCategory(
      id: 'cosmetics',
      nameEn: 'Beauty & Personal Care',
      nameTr: 'Kozmetik ve Bakım',
      icon: Icons.face,
      color: Colors.pink,
      carbonPerItem: 5.0, // kg CO₂ per cosmetic product
    ),
    ShoppingCategory(
      id: 'home',
      nameEn: 'Home & Garden',
      nameTr: 'Ev ve Bahçe',
      icon: Icons.home,
      color: Colors.orange,
      carbonPerItem: 25.0, // kg CO₂ per home item average
    ),
    ShoppingCategory(
      id: 'sports',
      nameEn: 'Sports & Outdoor',
      nameTr: 'Spor ve Outdoor',
      icon: Icons.sports,
      color: Colors.teal,
      carbonPerItem: 12.0, // kg CO₂ per sports item
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadShoppingData();
  }

  Future<void> _loadShoppingData() async {
    setState(() => isLoading = true);
    
    try {
      // Load shopping activities from database
      final activities = await DatabaseService.instance.getActivitiesByCategory('shopping');
      
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
          shoppingActivities = activities;
          totalCarbonToday = todayCarbon;
          totalCarbonWeek = weekCarbon;
          totalCarbonMonth = monthCarbon;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shopping data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addShoppingItem(ShoppingCategory category, int quantity) async {
    try {
      final carbonAmount = category.carbonPerItem * quantity;
      
      await DatabaseService.instance.insertActivity({
        'category': 'shopping',
        'subcategory': category.id,
        'description': '${category.getName(_languageService.isEnglish)} x$quantity',
        'co2_amount': carbonAmount,
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'quantity': quantity,
          'carbon_per_item': category.carbonPerItem,
        }
      });

      await _loadShoppingData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _languageService.isEnglish 
              ? 'Added $quantity ${category.nameEn} (+${carbonAmount.toStringAsFixed(1)} kg CO₂)'
              : '$quantity ${category.nameTr} eklendi (+${carbonAmount.toStringAsFixed(1)} kg CO₂)',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_languageService.isEnglish ? 'Error adding item' : 'Öğe eklenirken hata oluştu'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Shopping Carbon' : 'Alışveriş Karbonu'),
        backgroundColor: Colors.purple.withValues(alpha: 0.1),
        foregroundColor: Colors.purple,
      ),
      body: LiquidPullRefresh(
        onRefresh: _loadShoppingData,
        color: Colors.purple,
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

                    // Categories Grid
                    Text(
                      _languageService.isEnglish ? 'Shopping Categories' : 'Alışveriş Kategorileri',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoriesGrid(),
                    const SizedBox(height: 24),

                    // Recent Activities
                    if (shoppingActivities.isNotEmpty) ...[
                      Text(
                        _languageService.isEnglish ? 'Recent Activities' : 'Son Aktiviteler',
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

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _languageService.isEnglish ? 'Today' : 'Bugün',
            totalCarbonToday,
            Colors.purple,
            Icons.today,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            _languageService.isEnglish ? 'This Week' : 'Bu Hafta',
            totalCarbonWeek,
            Colors.deepPurple,
            Icons.calendar_view_week,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            _languageService.isEnglish ? 'This Month' : 'Bu Ay',
            totalCarbonMonth,
            Colors.indigo,
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
      itemCount: shoppingCategories.length,
      itemBuilder: (context, index) {
        final category = shoppingCategories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(ShoppingCategory category) {
    return MicroCard(
      onTap: () => _showQuantityDialog(category),
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
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '${category.carbonPerItem} kg CO₂',
              style: TextStyle(
                color: category.color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(ShoppingCategory category) {
    int quantity = 1;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category.getName(_languageService.isEnglish)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _languageService.isEnglish ? 'How many items?' : 'Kaç adet?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setDialogState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text(
                    quantity.toString(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    onPressed: quantity < 99
                        ? () => setDialogState(() => quantity++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${_languageService.isEnglish ? 'Total CO₂:' : 'Toplam CO₂:'} ${(category.carbonPerItem * quantity).toStringAsFixed(1)} kg',
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
                _addShoppingItem(category, quantity);
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
      itemCount: shoppingActivities.take(10).length,
      itemBuilder: (context, index) {
        final activity = shoppingActivities[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withValues(alpha: 0.1),
              child: const Icon(Icons.shopping_bag, color: Colors.purple),
            ),
            title: Text(activity['description'] ?? 'Shopping Item'),
            subtitle: Text(
              DateTime.parse(activity['created_at']).toString().split(' ')[0],
            ),
            trailing: Text(
              '${activity['co2_amount']?.toStringAsFixed(1) ?? '0.0'} kg CO₂',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ShoppingCategory {
  final String id;
  final String nameEn;
  final String nameTr;
  final IconData icon;
  final Color color;
  final double carbonPerItem;

  ShoppingCategory({
    required this.id,
    required this.nameEn,
    required this.nameTr,
    required this.icon,
    required this.color,
    required this.carbonPerItem,
  });

  String getName(bool isEnglish) => isEnglish ? nameEn : nameTr;
}