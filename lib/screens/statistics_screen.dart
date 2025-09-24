import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/language_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final LanguageService _languageService = LanguageService.instance;
  bool isLoading = true;
  
  // Veri listeleri
  List<FlSpot> weeklyData = [];
  List<FlSpot> monthlyData = [];
  Map<String, double> categoryData = {};
  
  // İstatistikler
  double totalWeekCO2 = 0.0;
  double totalMonthCO2 = 0.0;
  double averageDaily = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      await _loadWeeklyData();
      await _loadMonthlyData();
      await _loadCategoryData();
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  Future<void> _loadWeeklyData() async {
    final now = DateTime.now();
    weeklyData.clear();
    totalWeekCO2 = 0.0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final co2 = await DatabaseService.instance.getTotalCO2ForDate(date);
      weeklyData.add(FlSpot(i.toDouble(), co2));
      totalWeekCO2 += co2;
    }
    
    averageDaily = totalWeekCO2 / 7;
  }

  Future<void> _loadMonthlyData() async {
    final now = DateTime.now();
    monthlyData.clear();
    totalMonthCO2 = 0.0;

    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final co2 = await DatabaseService.instance.getTotalCO2ForDate(date);
      monthlyData.add(FlSpot(i.toDouble(), co2));
      totalMonthCO2 += co2;
    }
  }

  Future<void> _loadCategoryData() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    categoryData = await DatabaseService.instance.getCO2ByTransportType(
      startDate: weekAgo,
      endDate: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.analytics,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _languageService.isEnglish ? 'Statistics' : 'İstatistikler',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _languageService.isEnglish ? 'Your carbon footprint insights' : 'Karbon ayak izi analiziniz',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
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
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Theme.of(context).primaryColor,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_view_week, size: 16),
                          const SizedBox(width: 4),
                          Text(_languageService.isEnglish ? 'Weekly' : 'Haftalık'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month, size: 16),
                          const SizedBox(width: 4),
                          Text(_languageService.isEnglish ? 'Monthly' : 'Aylık'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pie_chart, size: 16),
                          const SizedBox(width: 4),
                          Text(_languageService.isEnglish ? 'Categories' : 'Kategori'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _languageService.isEnglish ? 'Loading statistics...' : 'İstatistikler yükleniyor...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: LiquidPullRefresh(
                onRefresh: _loadStatistics,
                color: Theme.of(context).primaryColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWeeklyTab(),
                    _buildMonthlyTab(),
                    _buildCategoryTab(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildWeeklyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero stats section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.blue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.analytics, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _languageService.isEnglish ? 'Weekly Overview' : 'Haftalık Özet',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _languageService.isEnglish ? 'Last 7 days carbon analysis' : 'Son 7 günün karbon analizi',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernStatCard(
                        title: _languageService.isEnglish ? 'Total' : 'Toplam',
                        value: '${totalWeekCO2.toStringAsFixed(1)} kg',
                        subtitle: 'CO₂',
                        icon: Icons.eco,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModernStatCard(
                        title: _languageService.isEnglish ? 'Daily Avg' : 'Günlük Ort.',
                        value: '${averageDaily.toStringAsFixed(1)} kg',
                        subtitle: 'CO₂',
                        icon: Icons.today,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.show_chart,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _languageService.isEnglish ? 'Weekly Trend' : 'Haftalık Trend',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Haftalık grafik
          SizedBox(
            height: 300,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: const Text('kg CO₂'),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final now = DateTime.now();
                            final date = now.subtract(Duration(days: (6 - value.toInt())));
                            return Text(
                              DateFormat('MM/dd').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: weeklyData,
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Özet kartı
          _buildStatCard(
            title: 'Aylık Toplam',
            value: '${totalMonthCO2.toStringAsFixed(1)} kg CO₂',
            icon: Icons.calendar_month,
            color: Colors.orange,
            isFullWidth: true,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Son 30 Gün CO₂ Trendi',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Aylık grafik
          SizedBox(
            height: 300,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: const Text('kg CO₂'),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() % 5 == 0) {
                              final now = DateTime.now();
                              final date = now.subtract(Duration(days: (29 - value.toInt())));
                              return Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthlyData,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.orange.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab() {
    final totalCategoryCO2 = categoryData.values.fold(0.0, (a, b) => a + b);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ulaşım Türü Dağılımı (Son 7 Gün)',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (categoryData.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Henüz veri yok'),
                      Text('Aktivite ekleyerek grafiği görüntüleyebilirsiniz.'),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // Pasta grafik
            SizedBox(
              height: 250,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: PieChart(
                    PieChartData(
                      sections: _buildPieChartSections(),
                      centerSpaceRadius: 60,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Kategori listesi
            ...categoryData.entries.map((entry) {
              final percentage = totalCategoryCO2 > 0 
                  ? (entry.value / totalCategoryCO2 * 100)
                  : 0.0;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getCategoryColor(entry.key),
                    child: Text(
                      _getCategoryEmoji(entry.key),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  title: Text(entry.key),
                  subtitle: Text('${percentage.toStringAsFixed(1)}%'),
                  trailing: Text(
                    '${entry.value.toStringAsFixed(2)} kg CO₂',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.trending_up, color: color, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $subtitle',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final totalCO2 = categoryData.values.fold(0.0, (a, b) => a + b);
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple];
    
    return categoryData.entries.map((entry) {
      final index = categoryData.keys.toList().indexOf(entry.key);
      final percentage = totalCO2 > 0 ? (entry.value / totalCO2 * 100) : 0.0;
      
      return PieChartSectionData(
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'benzinli araba':
        return Colors.red;
      case 'dizel araba':
        return Colors.orange;
      case 'motorsiklet':
        return Colors.purple;
      case 'şehir otobüsü':
        return Colors.blue;
      case 'metro/tramvay':
        return Colors.green;
      case 'tren':
        return Colors.indigo;
      case 'iç hat uçak':
        return Colors.pink;
      case 'bisiklet':
        return Colors.lightGreen;
      case 'yürüyüş':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'benzinli araba':
        return '🚗';
      case 'dizel araba':
        return '🚙';
      case 'motorsiklet':
        return '🏍️';
      case 'şehir otobüsü':
        return '🚌';
      case 'metro/tramvay':
        return '🚇';
      case 'tren':
        return '🚄';
      case 'iç hat uçak':
        return '✈️';
      case 'bisiklet':
        return '🚴';
      case 'yürüyüş':
        return '🚶';
      default:
        return '🌱';
    }
  }
}
