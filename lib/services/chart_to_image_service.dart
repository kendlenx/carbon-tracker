import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'language_service.dart';
import 'advanced_reporting_service.dart';

/// Service for converting FL Chart widgets to images
class ChartToImageService {
  static ChartToImageService? _instance;
  static ChartToImageService get instance => _instance ??= ChartToImageService._();
  
  ChartToImageService._();

  final LanguageService _languageService = LanguageService.instance;

  /// Capture any widget as image with proper sizing
  Future<Uint8List> captureWidgetAsImage({
    required Widget widget,
    Size size = const Size(400, 300),
    double pixelRatio = 3.0,
  }) async {
    try {
      // Create a RepaintBoundary
      final repaintBoundary = RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: size.width,
            height: size.height,
            color: Colors.white,
            child: widget,
          ),
        ),
      );

      // Create render objects
      final renderRepaintBoundary = RenderRepaintBoundary();
      final renderView = RenderView(
        view: WidgetsBinding.instance.platformDispatcher.views.first,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: renderRepaintBoundary,
        ),
        configuration: ViewConfiguration(
          logicalConstraints: BoxConstraints.tight(size),
          devicePixelRatio: pixelRatio,
        ),
      );

      // Build widget tree
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());
      
      final element = RenderObjectToWidgetAdapter<RenderBox>(
        container: renderView,
        child: repaintBoundary,
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(element);
      buildOwner.finalizeTree();

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      // Layout and paint
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      // Capture image
      final image = await renderRepaintBoundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to capture widget as image: $e');
    }
  }

  /// Convert pie chart to image
  Future<Uint8List> convertPieChartToImage({
    required List<CategoryBreakdown> categories,
    String title = '',
    Size size = const Size(400, 400),
  }) async {
    final chart = _buildPieChartWidget(categories, title);
    return await captureWidgetAsImage(
      widget: chart,
      size: size,
    );
  }

  /// Convert line chart to image
  Future<Uint8List> convertLineChartToImage({
    required Map<String, double> data,
    String title = '',
    String xAxisLabel = '',
    String yAxisLabel = '',
    Color lineColor = Colors.green,
    Size size = const Size(400, 300),
  }) async {
    final chart = _buildLineChartWidget(data, title, xAxisLabel, yAxisLabel, lineColor);
    return await captureWidgetAsImage(
      widget: chart,
      size: size,
    );
  }

  /// Convert bar chart to image
  Future<Uint8List> convertBarChartToImage({
    required Map<String, double> data,
    String title = '',
    String xAxisLabel = '',
    String yAxisLabel = '',
    Color barColor = Colors.blue,
    Size size = const Size(400, 300),
  }) async {
    final chart = _buildBarChartWidget(data, title, xAxisLabel, yAxisLabel, barColor);
    return await captureWidgetAsImage(
      widget: chart,
      size: size,
    );
  }

  /// Create dashboard analytics chart compilation
  Future<Uint8List> createAnalyticsCompilation({
    required DashboardReport report,
    Size size = const Size(800, 600),
  }) async {
    final isEnglish = _languageService.isEnglish;
    
    final compilation = _buildAnalyticsCompilationWidget(report, isEnglish);
    return await captureWidgetAsImage(
      widget: compilation,
      size: size,
    );
  }

  // Private widget builders

  Widget _buildPieChartWidget(List<CategoryBreakdown> categories, String title) {
    final isEnglish = _languageService.isEnglish;
    
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isEnglish ? 'No data available' : 'Veri bulunamadı',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: Row(
              children: [
                // Pie chart
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sections: categories.map((category) {
                        return PieChartSectionData(
                          value: category.value,
                          color: category.color,
                          title: '${category.percentage.toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: categories.take(5).map((category) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              color: category.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartWidget(
    Map<String, double> data,
    String title,
    String xAxisLabel,
    String yAxisLabel,
    Color lineColor,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          _languageService.isEnglish ? 'No data available' : 'Veri bulunamadı',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = sortedEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedEntries.length) {
                          final key = sortedEntries[index].key;
                          try {
                            final date = DateTime.parse(key);
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          } catch (e) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                key.length > 5 ? key.substring(0, 5) : key,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: null,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 42,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                minX: 0,
                maxX: (sortedEntries.length - 1).toDouble(),
                minY: 0,
                maxY: spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        lineColor.withValues(alpha: 0.8),
                        lineColor,
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: lineColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withValues(alpha: 0.1),
                          lineColor.withValues(alpha: 0.05),
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
    );
  }

  Widget _buildBarChartWidget(
    Map<String, double> data,
    String title,
    String xAxisLabel,
    String yAxisLabel,
    Color barColor,
  ) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          _languageService.isEnglish ? 'No data available' : 'Veri bulunamadı',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final barGroups = sortedEntries.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value,
            color: barColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedEntries.length) {
                          final key = sortedEntries[index].key;
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              key.length > 5 ? key.substring(0, 5) : key,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 38,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: null,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: null,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCompilationWidget(DashboardReport report, bool isEnglish) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Carbon Tracker',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      isEnglish ? 'Analytics Report' : 'Analitik Raporu',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Summary stats
          Row(
            children: [
              _buildStatCard(
                isEnglish ? 'Today' : 'Bugün',
                '${report.today.totalCO2.toStringAsFixed(1)} kg CO₂',
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                isEnglish ? 'This Week' : 'Bu Hafta',
                '${report.week.totalCO2.toStringAsFixed(1)} kg CO₂',
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                isEnglish ? 'This Month' : 'Bu Ay',
                '${report.month.totalCO2.toStringAsFixed(1)} kg CO₂',
                Colors.orange,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Charts section
          Expanded(
            child: Row(
              children: [
                // Category breakdown pie chart
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? 'Category Breakdown' : 'Kategori Dağılımı',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildPieChartWidget(report.categoryBreakdown, ''),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // Weekly trend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? 'Weekly Trend' : 'Haftalık Trend',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _buildLineChartWidget(
                          report.week.dailyBreakdown,
                          '',
                          isEnglish ? 'Days' : 'Günler',
                          'CO₂ (kg)',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                isEnglish ? 'Generated by Carbon Tracker' : 'Carbon Tracker Tarafından Oluşturuldu',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Utility methods for converting existing charts from Dashboard

  Future<List<Uint8List>> convertDashboardChartsToImages(DashboardReport report) async {
    final images = <Uint8List>[];
    final isEnglish = _languageService.isEnglish;

    try {
      // 1. Summary overview
      final summaryImage = await createAnalyticsCompilation(report: report);
      images.add(summaryImage);

      // 2. Category breakdown pie chart
      if (report.categoryBreakdown.isNotEmpty) {
        final pieChartImage = await convertPieChartToImage(
          categories: report.categoryBreakdown,
          title: isEnglish ? 'Emissions by Category' : 'Kategoriye Göre Emisyonlar',
        );
        images.add(pieChartImage);
      }

      // 3. Weekly trend line chart
      if (report.week.dailyBreakdown.isNotEmpty) {
        final lineChartImage = await convertLineChartToImage(
          data: report.week.dailyBreakdown,
          title: isEnglish ? 'Weekly CO₂ Trend' : 'Haftalık CO₂ Trendi',
          xAxisLabel: isEnglish ? 'Days' : 'Günler',
          yAxisLabel: 'CO₂ (kg)',
          lineColor: Colors.green,
        );
        images.add(lineChartImage);
      }

      // 4. Monthly comparison bar chart
      final monthlyData = <String, double>{
        isEnglish ? 'This Month' : 'Bu Ay': report.month.totalCO2,
        isEnglish ? 'Previous Month' : 'Geçen Ay': report.monthTrend.previousValue,
      };

      final barChartImage = await convertBarChartToImage(
        data: monthlyData,
        title: isEnglish ? 'Monthly Comparison' : 'Aylık Karşılaştırma',
        yAxisLabel: 'CO₂ (kg)',
        barColor: Colors.blue,
      );
      images.add(barChartImage);

      return images;
    } catch (e) {
      throw Exception('Failed to convert dashboard charts to images: $e');
    }
  }
}