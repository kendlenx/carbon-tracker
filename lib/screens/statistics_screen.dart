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
    _animationController.forward();
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
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Statistics' : 'İstatistikler'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(),
                _buildMonthlyTab(),
                _buildCategoryTab(),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          indicatorWeight: 3,
          splashFactory: InkSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.green.withOpacity(0.1);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.green.withOpacity(0.05);
              }
              return null;
            },
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.calendar_view_week),
              text: _languageService.isEnglish ? 'Weekly' : 'Haftalık',
            ),
            Tab(
              icon: const Icon(Icons.calendar_month),
              text: _languageService.isEnglish ? 'Monthly' : 'Aylık',
            ),
            Tab(
              icon: const Icon(Icons.pie_chart),
              text: _languageService.isEnglish ? 'Categories' : 'Kategoriler',
            ),
          ],
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
          // Header with summary
          Text(
            _languageService.isEnglish ? 'Weekly Overview' : 'Haftalık Özet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Main stats grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard(
                title: _languageService.isEnglish ? 'Total CO₂' : 'Toplam CO₂',
                value: '${totalWeekCO2.toStringAsFixed(1)} kg',
                icon: Icons.eco,
                color: Colors.green,
              ),
              _buildStatCard(
                title: _languageService.isEnglish ? 'Daily Average' : 'Günlük Ort.',
                value: '${averageDaily.toStringAsFixed(1)} kg',
                icon: Icons.calendar_today,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: _languageService.isEnglish ? 'Best Day' : 'En İyi Gün',
                value: _getBestDay(),
                icon: Icons.trending_down,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: _languageService.isEnglish ? 'Progress' : 'İlerleme',
                value: _getProgress(),
                icon: Icons.show_chart,
                color: Colors.purple,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Performance indicator
          _buildPerformanceIndicator(),
          
          const SizedBox(height: 24),
          // Chart Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _languageService.isEnglish ? '7-Day Trend' : '7 Günlük Trend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey.shade700 
                              : Colors.grey.shade200,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey.shade400 
                                    : Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 25,
                            getTitlesWidget: (value, meta) {
                              final now = DateTime.now();
                              final date = now.subtract(Duration(days: (6 - value.toInt())));
                              return Text(
                                DateFormat('MM/dd').format(date),
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.grey.shade400 
                                    : Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: weeklyData,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: Colors.green.shade600,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.3),
                                Colors.green.withOpacity(0.1),
                                Colors.green.withOpacity(0.05),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
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
          // Header with proper theme support
          Text(
            _languageService.isEnglish ? 'Monthly Overview' : 'Aylık Özet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineSmall?.color,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Monthly summary card
          _buildStatCard(
            title: _languageService.isEnglish ? 'Monthly Total' : 'Aylık Toplam',
            value: '${totalMonthCO2.toStringAsFixed(1)} kg CO₂',
            icon: Icons.calendar_month,
            color: Colors.orange,
            isFullWidth: true,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            _languageService.isEnglish ? '30-Day CO₂ Trend' : 'Son 30 Gün CO₂ Trendi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
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
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.grey.shade400 
                                      : Colors.grey.shade600,
                                ),
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
            _languageService.isEnglish ? 'Transport Category Distribution (Last 7 Days)' : 'Ulaşım Türü Dağılımı (Son 7 Gün)',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (categoryData.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _languageService.isEnglish ? 'No data yet' : 'Henüz veri yok',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _languageService.isEnglish 
                            ? 'Add activities to view charts.'
                            : 'Aktivite ekleyerek grafiği görüntüleyebilirsiniz.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
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

  Widget _buildCleanStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ) : null,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 10, color: Colors.green.shade600),
                    const SizedBox(width: 2),
                    Text(
                      '7d',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Theme.of(context).textTheme.bodySmall?.color : Colors.grey.shade600,
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
              color: isDark ? Theme.of(context).textTheme.bodySmall?.color : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: isDark ? 8 : 2,
      color: isDark ? Theme.of(context).cardColor : null,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isDark ? Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ) : null,
        ),
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
                    color: isDark ? Theme.of(context).textTheme.bodySmall?.color : Colors.grey.shade600,
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

  String _getBestDay() {
    if (weeklyData.isEmpty) return '--';
    
    double minValue = weeklyData.first.y;
    int bestIndex = 0;
    
    for (int i = 0; i < weeklyData.length; i++) {
      if (weeklyData[i].y < minValue) {
        minValue = weeklyData[i].y;
        bestIndex = i;
      }
    }
    
    final date = DateTime.now().subtract(Duration(days: 6 - bestIndex));
    return DateFormat('EEE').format(date);
  }
  
  String _getProgress() {
    if (weeklyData.length < 2) return '+0%';
    
    final firstValue = weeklyData.first.y;
    final lastValue = weeklyData.last.y;
    
    if (firstValue == 0) return '+0%';
    
    final change = ((lastValue - firstValue) / firstValue * 100);
    return '${change > 0 ? '+' : ''}${change.toStringAsFixed(0)}%';
  }
  
  Widget _buildPerformanceIndicator() {
    final isGoodPerformance = averageDaily < 10.0; // Arbitrary threshold
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      color: isDark ? Theme.of(context).cardColor : null,
      elevation: isDark ? 8 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isDark ? Border.all(
            color: (isGoodPerformance ? Colors.green : Colors.orange).withOpacity(0.3),
            width: 1,
          ) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isGoodPerformance ? Icons.eco : Icons.warning,
                    color: isGoodPerformance ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _languageService.isEnglish ? 'Performance Status' : 'Performans Durumu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Theme.of(context).textTheme.titleLarge?.color : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isGoodPerformance
                    ? (_languageService.isEnglish
                        ? 'Great job! Your carbon footprint is below average.'
                        : 'Harika! Karbon ayak iziniz ortalamanın altında.')
                    : (_languageService.isEnglish
                        ? 'There\'s room for improvement in your carbon footprint.'
                        : 'Karbon ayak izinizde iyileştirme yapılabilir.'),
                style: TextStyle(
                  color: isDark ? Theme.of(context).textTheme.bodyMedium?.color : Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: isGoodPerformance ? 0.8 : 0.4,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  isGoodPerformance ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
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
