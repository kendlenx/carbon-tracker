import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/carbon_calculator_service.dart';

class HeroDashboard extends StatefulWidget {
  final double totalCarbonToday;
  final double weeklyAverage;
  final double monthlyGoal;
  final bool isLoading;

  const HeroDashboard({
    super.key,
    required this.totalCarbonToday,
    required this.weeklyAverage,
    required this.monthlyGoal,
    this.isLoading = false,
  });

  @override
  State<HeroDashboard> createState() => _HeroDashboardState();
}

class _HeroDashboardState extends State<HeroDashboard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _countController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _countAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _countController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.elasticOut,
    ));

    _countAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _progressController.forward();
    _countController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comparison = CarbonCalculatorService.compareWithAverage(widget.weeklyAverage);
    final dailyGoal = 20.0; // kg CO₂ per day target
    final progressPercentage = widget.totalCarbonToday / dailyGoal;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Hero Progress Ring
          SizedBox(
            height: 200,
            width: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Ring
                CustomPaint(
                  size: const Size(200, 200),
                  painter: ProgressRingPainter(
                    progress: 1.0,
                    strokeWidth: 12,
                    color: Colors.grey.withOpacity(0.2),
                    isBackground: true,
                  ),
                ),
                // Progress Ring with Animation
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(200, 200),
                      painter: ProgressRingPainter(
                        progress: progressPercentage * _progressAnimation.value,
                        strokeWidth: 12,
                        color: _getProgressColor(progressPercentage),
                        isBackground: false,
                      ),
                    );
                  },
                ),
                // Center Content with Pulse
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseAnimation.value * 0.05),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated Counter
                          AnimatedBuilder(
                            animation: _countAnimation,
                            builder: (context, child) {
                              final displayValue = widget.totalCarbonToday * _countAnimation.value;
                              return Text(
                                displayValue.toStringAsFixed(1),
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getProgressColor(progressPercentage),
                                  fontSize: 36,
                                ),
                              );
                            },
                          ),
                          Text(
                            'kg CO₂',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bugün',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Performance Badge
                if (comparison.performanceLevel == PerformanceLevel.excellent)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '🌟',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Mini Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat(
                icon: Icons.trending_up,
                label: 'Haftalık',
                value: '${widget.weeklyAverage.toStringAsFixed(1)} kg',
                color: Colors.blue,
              ),
              _buildMiniStat(
                icon: Icons.flag,
                label: 'Hedef',
                value: '${dailyGoal.toStringAsFixed(0)} kg',
                color: Colors.orange,
              ),
              _buildMiniStat(
                icon: Icons.eco,
                label: 'Durum',
                value: comparison.performanceText.split(' ')[0],
                color: comparison.performanceColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress <= 0.5) {
      return Colors.green;
    } else if (progress <= 0.8) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final bool isBackground;

  ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    this.isBackground = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = isBackground ? StrokeCap.round : StrokeCap.round;

    if (isBackground) {
      canvas.drawCircle(center, radius, paint);
    } else {
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}