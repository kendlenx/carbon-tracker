import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'language_service.dart';

/// Comprehensive reporting and analytics service
class AdvancedReportingService extends ChangeNotifier {
  static AdvancedReportingService? _instance;
  static AdvancedReportingService get instance => _instance ??= AdvancedReportingService._();
  
  AdvancedReportingService._();

  final DatabaseService _databaseService = DatabaseService.instance;
  final LanguageService _languageService = LanguageService.instance;

  /// Report data cache
  Map<String, dynamic> _reportCache = {};
  DateTime? _lastCacheUpdate;
  
  /// Cache validity duration
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  /// Initialize the service
  Future<void> initialize() async {
    await _refreshCache();
  }

  /// Refresh the report cache
  Future<void> _refreshCache() async {
    _reportCache.clear();
    _lastCacheUpdate = DateTime.now();
    notifyListeners();
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidityDuration;
  }

  /// Get comprehensive dashboard report
  Future<DashboardReport> getDashboardReport() async {
    final cacheKey = 'dashboard_report';
    
    if (_isCacheValid() && _reportCache.containsKey(cacheKey)) {
      return _reportCache[cacheKey] as DashboardReport;
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get various time period data with error handling
      final todayData = await _getPeriodDataSafe(today, today.add(const Duration(days: 1)));
      final weekData = await _getPeriodDataSafe(today.subtract(const Duration(days: 7)), today);
      final monthData = await _getPeriodDataSafe(today.subtract(const Duration(days: 30)), today);
      final yearData = await _getPeriodDataSafe(today.subtract(const Duration(days: 365)), today);
      
      // Calculate trends with error handling
      final weekTrend = await _calculateTrendSafe(PeriodType.week);
      final monthTrend = await _calculateTrendSafe(PeriodType.month);
      
      // Get category breakdown with error handling
      final categoryBreakdown = await _getCategoryBreakdownSafe(today.subtract(const Duration(days: 30)), today);
      
      // Generate insights with error handling
      final insights = await _generateInsightsSafe(weekData, monthData, categoryBreakdown);
      
      // Get predictions with error handling
      final predictions = await _generatePredictionsSafe();
      
      final report = DashboardReport(
        today: todayData,
        week: weekData,
        month: monthData,
        year: yearData,
        weekTrend: weekTrend,
        monthTrend: monthTrend,
        categoryBreakdown: categoryBreakdown,
        insights: insights,
        predictions: predictions,
        generatedAt: now,
      );

      _reportCache[cacheKey] = report;
      return report;
    } catch (e) {
      // Return empty report on error
      return _createEmptyReport();
    }
  }

  /// Get period-specific data
  Future<PeriodData> _getPeriodData(DateTime start, DateTime end) async {
    final activities = await _databaseService.getTransportActivitiesInDateRange(start, end);
    
    double totalCO2 = 0.0;
    int totalActivities = activities.length;
    Map<String, double> dailyData = {};
    Map<String, double> categoryData = {};
    
    for (final activity in activities) {
      totalCO2 += activity.co2EmissionKg;
      
      // Daily breakdown
      final dayKey = DateFormat('yyyy-MM-dd').format(activity.timestamp);
      dailyData[dayKey] = (dailyData[dayKey] ?? 0.0) + activity.co2EmissionKg;
      
      // Category breakdown
      final categoryKey = activity.type.name;
      categoryData[categoryKey] = (categoryData[categoryKey] ?? 0.0) + activity.co2EmissionKg;
    }
    
    final days = end.difference(start).inDays;
    final averageDaily = days > 0 ? totalCO2 / days : 0.0;
    
    return PeriodData(
      totalCO2: totalCO2,
      averageDaily: averageDaily,
      totalActivities: totalActivities,
      dailyBreakdown: dailyData,
      categoryBreakdown: categoryData,
      startDate: start,
      endDate: end,
    );
  }

  /// Safe version of _getPeriodData with error handling
  Future<PeriodData> _getPeriodDataSafe(DateTime start, DateTime end) async {
    try {
      return await _getPeriodData(start, end);
    } catch (e) {
      return PeriodData(
        totalCO2: 0.0,
        averageDaily: 0.0,
        totalActivities: 0,
        dailyBreakdown: {},
        categoryBreakdown: {},
        startDate: start,
        endDate: end,
      );
    }
  }

  /// Calculate trend analysis
  Future<TrendAnalysis> _calculateTrend(PeriodType periodType) async {
    final now = DateTime.now();
    late DateTime currentStart, currentEnd, previousStart, previousEnd;
    
    switch (periodType) {
      case PeriodType.week:
        currentEnd = now;
        currentStart = now.subtract(const Duration(days: 7));
        previousEnd = currentStart;
        previousStart = currentStart.subtract(const Duration(days: 7));
        break;
      case PeriodType.month:
        currentEnd = now;
        currentStart = now.subtract(const Duration(days: 30));
        previousEnd = currentStart;
        previousStart = currentStart.subtract(const Duration(days: 30));
        break;
      case PeriodType.year:
        currentEnd = now;
        currentStart = now.subtract(const Duration(days: 365));
        previousEnd = currentStart;
        previousStart = currentStart.subtract(const Duration(days: 365));
        break;
    }

    final currentData = await _getPeriodData(currentStart, currentEnd);
    final previousData = await _getPeriodData(previousStart, previousEnd);
    
    final change = currentData.totalCO2 - previousData.totalCO2;
    final percentageChange = previousData.totalCO2 > 0 
        ? (change / previousData.totalCO2) * 100 
        : 0.0;
    
    TrendDirection direction;
    if (change > 0.1) {
      direction = TrendDirection.increasing;
    } else if (change < -0.1) {
      direction = TrendDirection.decreasing;
    } else {
      direction = TrendDirection.stable;
    }
    
    return TrendAnalysis(
      periodType: periodType,
      currentValue: currentData.totalCO2,
      previousValue: previousData.totalCO2,
      change: change,
      percentageChange: percentageChange,
      direction: direction,
      currentData: currentData,
      previousData: previousData,
    );
  }

  /// Get detailed category breakdown
  Future<List<CategoryBreakdown>> _getCategoryBreakdown(DateTime start, DateTime end) async {
    final categoryData = await _databaseService.getCO2ByTransportType(
      startDate: start,
      endDate: end,
    );
    
    final total = categoryData.values.fold<double>(0.0, (sum, value) => sum + value);
    
    final breakdowns = <CategoryBreakdown>[];
    for (final entry in categoryData.entries) {
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
      breakdowns.add(CategoryBreakdown(
        name: entry.key,
        value: entry.value,
        percentage: percentage,
        color: _getCategoryColor(entry.key),
      ));
    }
    
    // Sort by value descending
    breakdowns.sort((a, b) => b.value.compareTo(a.value));
    
    return breakdowns;
  }

  /// Generate AI-powered insights
  Future<List<CarbonInsight>> _generateInsights(
    PeriodData weekData, 
    PeriodData monthData, 
    List<CategoryBreakdown> categoryBreakdown
  ) async {
    final insights = <CarbonInsight>[];
    
    // High usage day insight
    if (weekData.dailyBreakdown.isNotEmpty) {
      final maxEntry = weekData.dailyBreakdown.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      final maxDate = DateTime.parse(maxEntry.key);
      final dayName = DateFormat('EEEE', _languageService.currentLocale.languageCode).format(maxDate);
      
      insights.add(CarbonInsight(
        type: InsightType.highUsageDay,
        title: _languageService.isEnglish 
            ? 'Highest Emission Day' 
            : 'En Yüksek Emisyon Günü',
        description: _languageService.isEnglish
            ? '$dayName was your highest emission day with ${maxEntry.value.toStringAsFixed(1)}kg CO₂'
            : '$dayName ${maxEntry.value.toStringAsFixed(1)}kg CO₂ ile en yüksek emisyon gününüz',
        impact: maxEntry.value > weekData.averageDaily * 1.5 ? InsightImpact.high : InsightImpact.medium,
        actionable: true,
        recommendations: [
          _languageService.isEnglish
              ? 'Consider using public transport on similar days'
              : 'Benzer günlerde toplu taşıma kullanmayı düşünün',
          _languageService.isEnglish
              ? 'Plan activities to reduce unnecessary trips'
              : 'Gereksiz seyahatleri azaltmak için aktiviteleri planlayın'
        ],
      ));
    }
    
    // Category dominance insight
    if (categoryBreakdown.isNotEmpty) {
      final topCategory = categoryBreakdown.first;
      if (topCategory.percentage > 60) {
        insights.add(CarbonInsight(
          type: InsightType.categoryDominance,
          title: _languageService.isEnglish 
              ? 'Category Focus Area' 
              : 'Kategori Odak Alanı',
          description: _languageService.isEnglish
              ? '${topCategory.name} accounts for ${topCategory.percentage.toStringAsFixed(0)}% of your emissions'
              : '${topCategory.name} emisyonlarınızın %${topCategory.percentage.toStringAsFixed(0)}\'ını oluşturuyor',
          impact: InsightImpact.high,
          actionable: true,
          recommendations: _getCategoryRecommendations(topCategory.name),
        ));
      }
    }
    
    // Weekly performance insight
    final currentWeekAvg = weekData.averageDaily;
    final previousWeekData = await _getPeriodData(
      weekData.startDate.subtract(const Duration(days: 7)),
      weekData.startDate,
    );
    
    if (previousWeekData.averageDaily > 0) {
      final improvement = ((previousWeekData.averageDaily - currentWeekAvg) / previousWeekData.averageDaily) * 100;
      if (improvement > 10) {
        insights.add(CarbonInsight(
          type: InsightType.improvement,
          title: _languageService.isEnglish ? 'Great Progress!' : 'Harika İlerleme!',
          description: _languageService.isEnglish
              ? 'You reduced your daily average by ${improvement.toStringAsFixed(0)}% this week'
              : 'Bu hafta günlük ortalamanızı %${improvement.toStringAsFixed(0)} azalttınız',
          impact: InsightImpact.positive,
          actionable: false,
          recommendations: [
            _languageService.isEnglish
                ? 'Keep up the great work!'
                : 'Harika işe devam edin!',
            _languageService.isEnglish
                ? 'Try to maintain this trend'
                : 'Bu trendi korumaya çalışın'
          ],
        ));
      } else if (improvement < -10) {
        insights.add(CarbonInsight(
          type: InsightType.warning,
          title: _languageService.isEnglish ? 'Increasing Trend' : 'Artan Trend',
          description: _languageService.isEnglish
              ? 'Your emissions increased by ${(-improvement).toStringAsFixed(0)}% this week'
              : 'Bu hafta emisyonlarınız %${(-improvement).toStringAsFixed(0)} arttı',
          impact: InsightImpact.medium,
          actionable: true,
          recommendations: [
            _languageService.isEnglish
                ? 'Review your recent activities'
                : 'Son aktivitelerinizi gözden geçirin',
            _languageService.isEnglish
                ? 'Consider setting a weekly goal'
                : 'Haftalık hedef belirlemeyi düşünün'
          ],
        ));
      }
    }
    
    return insights;
  }

  /// Generate predictive analytics
  Future<PredictionData> _generatePredictions() async {
    final now = DateTime.now();
    final historicalData = await _getPeriodData(
      now.subtract(const Duration(days: 90)), // Last 3 months
      now,
    );
    
    // Simple linear regression for trend prediction
    final dailyEmissions = <double>[];
    final dailyBreakdown = historicalData.dailyBreakdown;
    
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: 29 - i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      dailyEmissions.add(dailyBreakdown[dateKey] ?? 0.0);
    }
    
    // Calculate trend
    final trend = _calculateLinearTrend(dailyEmissions);
    
    // Predict next 7 days
    final predictions = <double>[];
    for (int i = 1; i <= 7; i++) {
      final predictedValue = math.max(0.0, trend.intercept + (trend.slope * (30 + i)));
      predictions.add(predictedValue);
    }
    
    // Monthly prediction
    final monthlyPrediction = predictions.reduce((a, b) => a + b) * 4.3; // Approximate weeks in month
    
    return PredictionData(
      dailyPredictions: predictions,
      weeklyPrediction: predictions.reduce((a, b) => a + b),
      monthlyPrediction: monthlyPrediction,
      confidence: math.max(0.3, math.min(0.9, 1 - trend.error)), // Confidence based on error
      trendDirection: trend.slope > 0.1 ? TrendDirection.increasing : 
                     trend.slope < -0.1 ? TrendDirection.decreasing : TrendDirection.stable,
      basedOnDays: 30,
    );
  }

  /// Calculate linear trend from data points
  LinearTrend _calculateLinearTrend(List<double> data) {
    if (data.length < 2) {
      return LinearTrend(slope: 0, intercept: data.isNotEmpty ? data.first : 0, error: 1.0);
    }
    
    final n = data.length;
    final x = List.generate(n, (i) => i.toDouble());
    final y = data;
    
    final sumX = x.reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumX2 = x.map((e) => e * e).reduce((a, b) => a + b);
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    
    // Calculate error (R-squared approximation)
    final yMean = sumY / n;
    final ssRes = List.generate(n, (i) => math.pow(y[i] - (intercept + slope * x[i]), 2)).reduce((a, b) => a + b);
    final ssTot = y.map((e) => math.pow(e - yMean, 2)).reduce((a, b) => a + b);
    final error = ssTot > 0 ? 1 - (ssRes / ssTot) : 1.0;
    
    return LinearTrend(slope: slope, intercept: intercept, error: error.abs());
  }

  /// Get category-specific color
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'car':
      case 'araba':
        return Colors.blue;
      case 'bus':
      case 'otobüs':
        return Colors.orange;
      case 'train':
      case 'tren':
        return Colors.green;
      case 'plane':
      case 'uçak':
        return Colors.red;
      case 'bike':
      case 'bisiklet':
        return Colors.lightGreen;
      case 'walking':
      case 'yürüme':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// Get category-specific recommendations
  List<String> _getCategoryRecommendations(String category) {
    final isEnglish = _languageService.isEnglish;
    
    switch (category.toLowerCase()) {
      case 'car':
      case 'araba':
        return isEnglish ? [
          'Consider carpooling or ride-sharing',
          'Use public transport when possible',
          'Plan routes to combine errands',
          'Walk or cycle for short distances'
        ] : [
          'Araç paylaşımını düşünün',
          'Mümkün olduğunda toplu taşıma kullanın',
          'İşleri birleştirmek için rota planlayın',
          'Kısa mesafeler için yürüyün veya bisiklet kullanın'
        ];
      case 'plane':
      case 'uçak':
        return isEnglish ? [
          'Consider video calls instead of business trips',
          'Choose direct flights when flying',
          'Offset carbon emissions when possible',
          'Explore local destinations for leisure'
        ] : [
          'İş seyahatleri yerine video görüşmeleri düşünün',
          'Uçarken direkt uçuşları tercih edin',
          'Mümkün olduğunda karbon emisyonunu telafi edin',
          'Eğlence için yerel destinasyonları keşfedin'
        ];
      default:
        return isEnglish ? [
          'Look for more efficient alternatives',
          'Plan activities to reduce usage',
          'Consider environmentally friendly options'
        ] : [
          'Daha verimli alternatifleri arayın',
          'Kullanımı azaltmak için aktiviteleri planlayın',
          'Çevre dostu seçenekleri düşünün'
        ];
    }
  }

  /// Clear cache and refresh data
  Future<void> refreshReports() async {
    await _refreshCache();
  }

  /// Safe version of _calculateTrend with error handling
  Future<TrendAnalysis> _calculateTrendSafe(PeriodType periodType) async {
    try {
      return await _calculateTrend(periodType);
    } catch (e) {
      final now = DateTime.now();
      final emptyData = PeriodData(
        totalCO2: 0.0,
        averageDaily: 0.0,
        totalActivities: 0,
        dailyBreakdown: {},
        categoryBreakdown: {},
        startDate: now,
        endDate: now,
      );
      return TrendAnalysis(
        periodType: periodType,
        currentValue: 0.0,
        previousValue: 0.0,
        change: 0.0,
        percentageChange: 0.0,
        direction: TrendDirection.stable,
        currentData: emptyData,
        previousData: emptyData,
      );
    }
  }

  /// Safe version of _getCategoryBreakdown with error handling
  Future<List<CategoryBreakdown>> _getCategoryBreakdownSafe(DateTime start, DateTime end) async {
    try {
      return await _getCategoryBreakdown(start, end);
    } catch (e) {
      return <CategoryBreakdown>[];
    }
  }

  /// Safe version of _generateInsights with error handling
  Future<List<CarbonInsight>> _generateInsightsSafe(PeriodData weekData, PeriodData monthData, List<CategoryBreakdown> categoryBreakdown) async {
    try {
      return await _generateInsights(weekData, monthData, categoryBreakdown);
    } catch (e) {
      return <CarbonInsight>[];
    }
  }

  /// Safe version of _generatePredictions with error handling
  Future<PredictionData> _generatePredictionsSafe() async {
    try {
      return await _generatePredictions();
    } catch (e) {
      return PredictionData(
        dailyPredictions: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        weeklyPrediction: 0.0,
        monthlyPrediction: 0.0,
        confidence: 0.0,
        trendDirection: TrendDirection.stable,
        basedOnDays: 0,
      );
    }
  }

  /// Create an empty report when data loading fails
  DashboardReport _createEmptyReport() {
    final now = DateTime.now();
    final emptyData = PeriodData(
      totalCO2: 0.0,
      averageDaily: 0.0,
      totalActivities: 0,
      dailyBreakdown: {},
      categoryBreakdown: {},
      startDate: now,
      endDate: now,
    );
    final emptyTrend = TrendAnalysis(
      periodType: PeriodType.week,
      currentValue: 0.0,
      previousValue: 0.0,
      change: 0.0,
      percentageChange: 0.0,
      direction: TrendDirection.stable,
      currentData: emptyData,
      previousData: emptyData,
    );
    final emptyPredictions = PredictionData(
      dailyPredictions: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      weeklyPrediction: 0.0,
      monthlyPrediction: 0.0,
      confidence: 0.0,
      trendDirection: TrendDirection.stable,
      basedOnDays: 0,
    );

    return DashboardReport(
      today: emptyData,
      week: emptyData,
      month: emptyData,
      year: emptyData,
      weekTrend: emptyTrend,
      monthTrend: emptyTrend,
      categoryBreakdown: <CategoryBreakdown>[],
      insights: <CarbonInsight>[],
      predictions: emptyPredictions,
      generatedAt: now,
    );
  }

  /// Generate comparison report between two periods
  Future<ComparisonReport> getComparisonReport(
    DateTime period1Start,
    DateTime period1End,
    DateTime period2Start, 
    DateTime period2End,
  ) async {
    final period1Data = await _getPeriodData(period1Start, period1End);
    final period2Data = await _getPeriodData(period2Start, period2End);
    
    final totalChange = period1Data.totalCO2 - period2Data.totalCO2;
    final percentageChange = period2Data.totalCO2 > 0 
        ? (totalChange / period2Data.totalCO2) * 100 
        : 0.0;
    
    return ComparisonReport(
      period1: period1Data,
      period2: period2Data,
      totalChange: totalChange,
      percentageChange: percentageChange,
      categoryChanges: _calculateCategoryChanges(period1Data, period2Data),
      insights: await _generateComparisonInsights(period1Data, period2Data),
    );
  }

  /// Calculate category-wise changes
  Map<String, double> _calculateCategoryChanges(PeriodData period1, PeriodData period2) {
    final changes = <String, double>{};
    
    final allCategories = {
      ...period1.categoryBreakdown.keys,
      ...period2.categoryBreakdown.keys,
    };
    
    for (final category in allCategories) {
      final value1 = period1.categoryBreakdown[category] ?? 0.0;
      final value2 = period2.categoryBreakdown[category] ?? 0.0;
      changes[category] = value1 - value2;
    }
    
    return changes;
  }

  /// Generate comparison-specific insights
  Future<List<CarbonInsight>> _generateComparisonInsights(
    PeriodData period1, 
    PeriodData period2
  ) async {
    final insights = <CarbonInsight>[];
    final isEnglish = _languageService.isEnglish;
    
    final totalChange = period1.totalCO2 - period2.totalCO2;
    final percentChange = period2.totalCO2 > 0 ? (totalChange / period2.totalCO2) * 100 : 0.0;
    
    if (totalChange < -1.0) { // Significant reduction
      insights.add(CarbonInsight(
        type: InsightType.improvement,
        title: isEnglish ? 'Significant Reduction' : 'Önemli Azalma',
        description: isEnglish
            ? 'You reduced emissions by ${(-totalChange).toStringAsFixed(1)}kg (${(-percentChange).toStringAsFixed(0)}%)'
            : 'Emisyonlarınızı ${(-totalChange).toStringAsFixed(1)}kg (%${(-percentChange).toStringAsFixed(0)}) azalttınız',
        impact: InsightImpact.positive,
        actionable: false,
        recommendations: [
          isEnglish ? 'Maintain these positive changes' : 'Bu olumlu değişiklikleri sürdürün',
        ],
      ));
    } else if (totalChange > 1.0) { // Significant increase
      insights.add(CarbonInsight(
        type: InsightType.warning,
        title: isEnglish ? 'Increased Emissions' : 'Artan Emisyonlar',
        description: isEnglish
            ? 'Emissions increased by ${totalChange.toStringAsFixed(1)}kg (${percentChange.toStringAsFixed(0)}%)'
            : 'Emisyonlar ${totalChange.toStringAsFixed(1)}kg (%${percentChange.toStringAsFixed(0)}) arttı',
        impact: InsightImpact.medium,
        actionable: true,
        recommendations: [
          isEnglish ? 'Review recent activity changes' : 'Son aktivite değişikliklerini gözden geçirin',
          isEnglish ? 'Set reduction targets' : 'Azaltma hedefleri belirleyin',
        ],
      ));
    }
    
    return insights;
  }
}

// Data Models

/// Comprehensive dashboard report
class DashboardReport {
  final PeriodData today;
  final PeriodData week;
  final PeriodData month;
  final PeriodData year;
  final TrendAnalysis weekTrend;
  final TrendAnalysis monthTrend;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<CarbonInsight> insights;
  final PredictionData predictions;
  final DateTime generatedAt;

  DashboardReport({
    required this.today,
    required this.week,
    required this.month,
    required this.year,
    required this.weekTrend,
    required this.monthTrend,
    required this.categoryBreakdown,
    required this.insights,
    required this.predictions,
    required this.generatedAt,
  });
}

/// Period-specific data
class PeriodData {
  final double totalCO2;
  final double averageDaily;
  final int totalActivities;
  final Map<String, double> dailyBreakdown;
  final Map<String, double> categoryBreakdown;
  final DateTime startDate;
  final DateTime endDate;

  PeriodData({
    required this.totalCO2,
    required this.averageDaily,
    required this.totalActivities,
    required this.dailyBreakdown,
    required this.categoryBreakdown,
    required this.startDate,
    required this.endDate,
  });
  
  String get formattedPeriod {
    final formatter = DateFormat('MMM dd');
    return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
  }
}

/// Trend analysis data
class TrendAnalysis {
  final PeriodType periodType;
  final double currentValue;
  final double previousValue;
  final double change;
  final double percentageChange;
  final TrendDirection direction;
  final PeriodData currentData;
  final PeriodData previousData;

  TrendAnalysis({
    required this.periodType,
    required this.currentValue,
    required this.previousValue,
    required this.change,
    required this.percentageChange,
    required this.direction,
    required this.currentData,
    required this.previousData,
  });
  
  String get formattedChange {
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}kg';
  }
  
  String get formattedPercentageChange {
    final sign = percentageChange >= 0 ? '+' : '';
    return '$sign${percentageChange.toStringAsFixed(0)}%';
  }
}

/// Category breakdown data
class CategoryBreakdown {
  final String name;
  final double value;
  final double percentage;
  final Color color;

  CategoryBreakdown({
    required this.name,
    required this.value,
    required this.percentage,
    required this.color,
  });
}

/// Carbon insights
class CarbonInsight {
  final InsightType type;
  final String title;
  final String description;
  final InsightImpact impact;
  final bool actionable;
  final List<String> recommendations;

  CarbonInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
    required this.actionable,
    required this.recommendations,
  });
}

/// Prediction data
class PredictionData {
  final List<double> dailyPredictions;
  final double weeklyPrediction;
  final double monthlyPrediction;
  final double confidence;
  final TrendDirection trendDirection;
  final int basedOnDays;

  PredictionData({
    required this.dailyPredictions,
    required this.weeklyPrediction,
    required this.monthlyPrediction,
    required this.confidence,
    required this.trendDirection,
    required this.basedOnDays,
  });
  
  String get confidenceText {
    if (confidence > 0.8) return 'High';
    if (confidence > 0.6) return 'Medium';
    return 'Low';
  }
}

/// Comparison report between two periods
class ComparisonReport {
  final PeriodData period1;
  final PeriodData period2;
  final double totalChange;
  final double percentageChange;
  final Map<String, double> categoryChanges;
  final List<CarbonInsight> insights;

  ComparisonReport({
    required this.period1,
    required this.period2,
    required this.totalChange,
    required this.percentageChange,
    required this.categoryChanges,
    required this.insights,
  });
}

/// Linear trend calculation result
class LinearTrend {
  final double slope;
  final double intercept;
  final double error;

  LinearTrend({
    required this.slope,
    required this.intercept,
    required this.error,
  });
}

// Enums

enum PeriodType { week, month, year }
enum TrendDirection { increasing, decreasing, stable }
enum InsightType { highUsageDay, categoryDominance, improvement, warning, prediction }
enum InsightImpact { high, medium, low, positive }