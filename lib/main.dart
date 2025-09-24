import 'package:flutter/material.dart';
import 'screens/transport_screen.dart';
import 'services/database_service.dart';

void main() {
  runApp(const CarbonTrackerApp());
}

class CarbonTrackerApp extends StatelessWidget {
  const CarbonTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carbon Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const CarbonTrackerHome(),
      debugShowCheckedModeBanner: false,
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                    Text(
                      'Bugünkü Karbon Ayak İzi',
                      style: Theme.of(context).textTheme.titleLarge,
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
                        _buildStatItem('Aylık Hedef', '${monthlyGoal.toStringAsFixed(0)} kg'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
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
        onPressed: () {
          // Yeni aktivite ekleme
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yeni aktivite ekleme özelliği yakında!')),
          );
        },
        child: const Icon(Icons.add),
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
}
