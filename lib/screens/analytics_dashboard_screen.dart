import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/advanced_reporting_service.dart';
import '../services/language_service.dart';
import '../widgets/micro_interactions.dart';
import '../widgets/liquid_pull_refresh.dart';
import '../widgets/export_share_widgets.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _chartAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late TabController _tabController;

  final AdvancedReportingService _reportingService = AdvancedReportingService.instance;
  final LanguageService _languageService = LanguageService.instance;

  DashboardReport? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chartAnimationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final report = await _reportingService.getDashboardReport();
      
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
        _animationController.forward();
        _chartAnimationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshAnalytics() async {
    await _reportingService.refreshReports();
    await _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Advanced Analytics' : 'Gelişmiş Analitik'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
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
        ),
        actions: [
          ExportShareWidgets.buildExportButton(context, showText: false),
          ExportShareWidgets.buildShareButton(context, showText: false),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAnalytics,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: ExportShareWidgets.buildShareFAB(
        context,
        heroTag: "analytics_share_fab",
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading advanced analytics...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text('Error loading analytics'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: Text(_languageService.isEnglish ? 'Retry' : 'Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return Center(
        child: Text(_languageService.isEnglish 
            ? 'No data available' 
            : 'Veri bulunamadı'),
      );
    }

    return LiquidPullRefresh(
      onRefresh: _refreshAnalytics,
      child: Column(
        children: [
          // Summary cards
          _buildSummaryCards(),
          
          // Tab navigation
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(
                  icon: const Icon(Icons.trending_up),
                  text: _languageService.isEnglish ? 'Trends' : 'Trendler',
                ),
                Tab(
                  icon: const Icon(Icons.pie_chart),
                  text: _languageService.isEnglish ? 'Breakdown' : 'Dağılım',
                ),
                Tab(
                  icon: const Icon(Icons.lightbulb_outline),
                  text: _languageService.isEnglish ? 'Insights' : 'Öngörüler',
                ),
                Tab(
                  icon: const Icon(Icons.auto_graph),
                  text: _languageService.isEnglish ? 'Predictions' : 'Tahminler',
                ),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTrendsTab(),
                _buildBreakdownTab(),
                _buildInsightsTab(),
                _buildPredictionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: _languageService.isEnglish ? 'Today' : 'Bugün',
                      value: '${_report!.today.totalCO2.toStringAsFixed(1)} kg',
                      icon: Icons.today,
                      color: Colors.blue,
                      trend: _getTrendIcon(_report!.today.totalCO2, _report!.week.averageDaily),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: _languageService.isEnglish ? 'This Week' : 'Bu Hafta',
                      value: '${_report!.week.totalCO2.toStringAsFixed(1)} kg',
                      icon: Icons.calendar_view_week,
                      color: Colors.green,
                      trend: _getTrendIcon(_report!.weekTrend.currentValue, _report!.weekTrend.previousValue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: _languageService.isEnglish ? 'This Month' : 'Bu Ay',
                      value: '${_report!.month.totalCO2.toStringAsFixed(1)} kg',
                      icon: Icons.calendar_month,
                      color: Colors.orange,
                      trend: _getTrendIcon(_report!.monthTrend.currentValue, _report!.monthTrend.previousValue),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Widget? trend,
  }) {
    return MicroCard(
      onTap: () => HapticHelper.trigger(HapticType.light),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                if (trend != null) trend,
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
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
      ),
    );
  }

  Widget? _getTrendIcon(double current, double previous) {
    if (previous == 0) return null;
    
    final change = current - previous;
    final changePercent = (change / previous) * 100;
    
    if (changePercent.abs() < 5) {
      return Icon(Icons.trending_flat, color: Colors.grey, size: 16);
    } else if (change > 0) {
      return Icon(Icons.trending_up, color: Colors.red, size: 16);
    } else {
      return Icon(Icons.trending_down, color: Colors.green, size: 16);
    }
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly trend
          _buildTrendCard(
            title: _languageService.isEnglish ? 'Weekly Trend' : 'Haftalık Trend',
            trend: _report!.weekTrend,
          ),
          const SizedBox(height: 16),
          
          // Monthly trend
          _buildTrendCard(
            title: _languageService.isEnglish ? 'Monthly Trend' : 'Aylık Trend',
            trend: _report!.monthTrend,
          ),
          const SizedBox(height: 16),
          
          // Daily emissions chart
          _buildDailyEmissionsChart(),
        ],
      ),
    );
  }

  Widget _buildTrendCard({
    required String title,
    required TrendAnalysis trend,
  }) {
    final isPositive = trend.direction == TrendDirection.decreasing;
    final color = isPositive ? Colors.green : 
                 trend.direction == TrendDirection.increasing ? Colors.red : Colors.grey;
    
    return MicroCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend.direction == TrendDirection.increasing ? Icons.trending_up :
                        trend.direction == TrendDirection.decreasing ? Icons.trending_down :
                        Icons.trending_flat,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend.formattedPercentageChange,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_languageService.isEnglish ? 'Current:' : 'Şu anki:'} ${trend.currentValue.toStringAsFixed(1)} kg',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  '${_languageService.isEnglish ? 'Previous:' : 'Önceki:'} ${trend.previousValue.toStringAsFixed(1)} kg',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_languageService.isEnglish ? 'Change:' : 'Değişim:'} ${trend.formattedChange}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyEmissionsChart() {
    final weekData = _report!.week.dailyBreakdown;
    if (weekData.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Text(_languageService.isEnglish 
              ? 'No data available' 
              : 'Veri bulunamadı'),
        ),
      );
    }

    final sortedEntries = weekData.entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));

    final spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    return MicroCard(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? 'Daily Emissions (Last 7 Days)' : 'Günlük Emisyonlar (Son 7 Gün)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: _chartAnimationController,
                builder: (context, child) {
                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toStringAsFixed(0)}kg',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
                                final date = DateTime.parse(sortedEntries[value.toInt()].key);
                                return Text(
                                  DateFormat('MMM dd').format(date),
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots.take((spots.length * _chartAnimationController.value).ceil()).toList(),
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.5),
                            ],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.3),
                                Theme.of(context).primaryColor.withOpacity(0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category pie chart
          _buildCategoryPieChart(),
          const SizedBox(height: 16),
          
          // Category details list
          _buildCategoryDetailsList(),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    final categoryData = _report!.categoryBreakdown;
    
    if (categoryData.isEmpty) {
      return Container(
        height: 200,
        child: Center(
          child: Text(_languageService.isEnglish 
              ? 'No category data available' 
              : 'Kategori verisi bulunamadı'),
        ),
      );
    }

    return MicroCard(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? 'Emissions by Category' : 'Kategorilere Göre Emisyonlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: _chartAnimationController,
                builder: (context, child) {
                  return PieChart(
                    PieChartData(
                      sections: categoryData.map((category) {
                        return PieChartSectionData(
                          value: category.value * _chartAnimationController.value,
                          color: category.color,
                          title: '${category.percentage.toStringAsFixed(0)}%',
                          radius: 80,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDetailsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _languageService.isEnglish ? 'Category Details' : 'Kategori Detayları',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...(_report!.categoryBreakdown.map((category) => 
          _buildCategoryListItem(category))),
      ],
    );
  }

  Widget _buildCategoryListItem(CategoryBreakdown category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MicroCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${category.value.toStringAsFixed(1)} kg CO₂',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${category.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: category.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    final insights = _report!.insights;
    
    if (insights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _languageService.isEnglish 
                  ? 'No insights available yet\nAdd more activities to get personalized insights'
                  : 'Henüz insight bulunmuyor\nKişiselleştirilmiş öngörüler için daha fazla aktivite ekleyin',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: insights.length,
      itemBuilder: (context, index) {
        final insight = insights[index];
        return AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value * (index + 1) * 0.1),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: _buildInsightCard(insight, index),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInsightCard(CarbonInsight insight, int index) {
    final impactColor = _getImpactColor(insight.impact);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MicroCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: impactColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getInsightIcon(insight.type),
                    color: impactColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (insight.impact == InsightImpact.positive)
                  const Icon(Icons.celebration, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              insight.description,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            if (insight.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _languageService.isEnglish ? 'Recommendations:' : 'Öneriler:',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ...insight.recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: impactColor)),
                    Expanded(
                      child: Text(
                        rec,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPredictionsTab() {
    final predictions = _report!.predictions;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence indicator
          _buildConfidenceIndicator(predictions),
          const SizedBox(height: 16),
          
          // Predictions summary
          _buildPredictionsSummary(predictions),
          const SizedBox(height: 16),
          
          // Prediction chart
          _buildPredictionsChart(predictions),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(PredictionData predictions) {
    final confidenceColor = predictions.confidence > 0.7 ? Colors.green :
                           predictions.confidence > 0.4 ? Colors.orange : Colors.red;
    
    return MicroCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? 'Prediction Confidence' : 'Tahmin Güvenilirliği',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: predictions.confidence,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(predictions.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: confidenceColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _languageService.isEnglish 
                  ? 'Based on ${predictions.basedOnDays} days of data'
                  : '${predictions.basedOnDays} günlük veriye dayalı',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsSummary(PredictionData predictions) {
    return Row(
      children: [
        Expanded(
          child: MicroCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_view_week,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${predictions.weeklyPrediction.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _languageService.isEnglish ? 'Next Week' : 'Gelecek Hafta',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MicroCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${predictions.monthlyPrediction.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _languageService.isEnglish ? 'Next Month' : 'Gelecek Ay',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionsChart(PredictionData predictions) {
    final spots = predictions.dailyPredictions.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return MicroCard(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? '7-Day Emission Forecast' : '7 Günlük Emisyon Tahmini',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}kg',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final day = (value.toInt() + 1);
                          return Text(
                            'Day $day',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.purple,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      dashArray: [5, 5], // Dashed line for predictions
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purple.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getImpactColor(InsightImpact impact) {
    switch (impact) {
      case InsightImpact.high:
        return Colors.red;
      case InsightImpact.medium:
        return Colors.orange;
      case InsightImpact.low:
        return Colors.blue;
      case InsightImpact.positive:
        return Colors.green;
    }
  }

  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.highUsageDay:
        return Icons.calendar_today;
      case InsightType.categoryDominance:
        return Icons.pie_chart;
      case InsightType.improvement:
        return Icons.trending_down;
      case InsightType.warning:
        return Icons.warning;
      case InsightType.prediction:
        return Icons.auto_graph;
    }
  }
}