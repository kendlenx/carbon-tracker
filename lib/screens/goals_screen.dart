import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/database_service.dart';
import '../services/achievement_service.dart' show Achievement, AchievementType;
import '../widgets/liquid_pull_refresh.dart';
import 'dart:math' as math;

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with TickerProviderStateMixin {
  
  // Goals
  double _dailyGoal = 10.0;
  double _weeklyGoal = 70.0;
  double _monthlyGoal = 300.0;
  double _yearlyGoal = 3650.0;
  
  // Current Progress
  double _currentDaily = 0.0;
  double _currentWeekly = 0.0;
  double _currentMonthly = 0.0;
  double _currentYearly = 0.0;
  
  // Achievement thresholds
  final List<Achievement> _achievements = [];
  
  // Animation controllers
  late AnimationController _progressAnimationController;
  late AnimationController _chartAnimationController;
  bool _achievementsInitialized = false;
  Locale? _lastLocale;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadGoals();
    _loadProgress();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLocale = Localizations.localeOf(context);
    if (!_achievementsInitialized || _lastLocale != currentLocale) {
      setState(() {
        _setupAchievements();
        _achievementsInitialized = true;
        _lastLocale = currentLocale;
      });
    }
  }

  void _setupAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _chartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    // In a real app, load from SharedPreferences or database
    setState(() {
      _dailyGoal = 10.0;
      _weeklyGoal = 70.0;
      _monthlyGoal = 300.0;
      _yearlyGoal = 3650.0;
    });
  }

  Future<void> _loadProgress() async {
    try {
      final stats = await DatabaseService.instance.getDashboardStats();
      
      setState(() {
        _currentDaily = stats['todayTotal'] ?? 0.0;
        _currentWeekly = stats['weeklyAverage'] ?? 0.0;
        _currentMonthly = stats['monthlyTotal'] ?? 0.0;
        _currentYearly = stats['yearlyTotal'] ?? 0.0;
      });
      
      _progressAnimationController.forward();
      _chartAnimationController.forward();
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  void _setupAchievements() {
    try {
      _achievements.clear();
      final l = AppLocalizations.of(context);
      if (l == null) return;
      String t(String key, String fallback) => l.translate(key).isEmpty ? fallback : l.translate(key);
      _achievements.addAll([
        Achievement(
          id: 'daily_green',
          title: t('goals.ach.dailyGreenChampion.title', 'Daily Green Champion'),
          description: t('goals.ach.dailyGreenChampion.desc', 'Stay under your daily goal for 7 days'),
          icon: '🌱',
          color: Colors.green,
          type: AchievementType.daily,
          targetValue: 7,
          unit: t('goals.units.days', 'days'),
          points: 50,
        ),
        Achievement(
          id: 'weekly_warrior',
          title: t('goals.ach.weeklyWarrior.title', 'Weekly Warrior'),
          description: t('goals.ach.weeklyWarrior.desc', 'Reach your weekly goal 4 times'),
          icon: '🏆',
          color: Colors.blue,
          type: AchievementType.weekly,
          targetValue: 4,
          unit: t('goals.units.weeks', 'weeks'),
          points: 75,
        ),
        Achievement(
          id: 'monthly_master',
          title: t('goals.ach.monthlyMaster.title', 'Monthly Master'),
          description: t('goals.ach.monthlyMaster.desc', 'Exceed your monthly goal'),
          icon: '⭐',
          color: Colors.amber,
          type: AchievementType.monthly,
          targetValue: 1,
          unit: t('goals.units.goal', 'goal'),
          points: 100,
        ),
        Achievement(
          id: 'carbon_crusher',
          title: t('goals.ach.carbonCrusher.title', 'Carbon Crusher'),
          description: t('goals.ach.carbonCrusher.desc', 'Reduce emissions by 50%'),
          icon: '📉',
          color: Colors.red,
          type: AchievementType.milestone,
          targetValue: 50,
          unit: '%',
          points: 200,
        ),
      ]);
    } catch (e) {
      debugPrint('Error in _setupAchievements: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: LiquidPullRefresh(
        onRefresh: () async {
          await _loadProgress();
        },
        color: Colors.green,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview Card
              _buildOverviewCard(),
              const SizedBox(height: 24),

              // Goal Progress Cards
              _buildGoalProgressCards(),
              const SizedBox(height: 24),

              // Weekly Chart
              _buildWeeklyChart(),
              const SizedBox(height: 24),

              // Achievement Section
              _buildAchievementsSection(),
              const SizedBox(height: 24),

              // Tips & Motivations
              _buildTipsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editGoals,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: Text(
          AppLocalizations.of(context)!.translate('ui.editGoals'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final dailyProgress = _currentDaily / _dailyGoal;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              AppLocalizations.of(context)!.translate('ui.todaysGoalProgress'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Simplified Progress Ring
            AnimatedBuilder(
              animation: _progressAnimationController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: (dailyProgress * _progressAnimationController.value).clamp(0.0, 1.0),
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          dailyProgress <= 1.0 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentDaily.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'kg CO₂',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            // Simple progress text
            Text(
              '${_currentDaily.toStringAsFixed(1)} / ${_dailyGoal.toStringAsFixed(0)} kg CO₂',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: dailyProgress <= 1.0 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dailyProgress <= 1.0 
                  ? AppLocalizations.of(context)!.goalsOnTrack
                  : AppLocalizations.of(context)!.goalsExceeded,
                style: TextStyle(
                  color: dailyProgress <= 1.0 ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('ui.goalProgress'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildProgressCard(
          title: AppLocalizations.of(context)!.goalsWeekly,
          current: _currentWeekly,
          target: _weeklyGoal,
          icon: Icons.calendar_view_week,
          color: Colors.blue,
        ),
        
        const SizedBox(height: 12),
        
        _buildProgressCard(
          title: AppLocalizations.of(context)!.goalsMonthly,
          current: _currentMonthly,
          target: _monthlyGoal,
          icon: Icons.calendar_month,
          color: Colors.orange,
        ),
        
        const SizedBox(height: 12),
        
        _buildProgressCard(
          title: AppLocalizations.of(context)!.translate('ui.yearly'),
          current: _currentYearly,
          target: _yearlyGoal,
          icon: Icons.calendar_today,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildProgressCard({
    required String title,
    required double current,
    required double target,
    required IconData icon,
    required Color color,
  }) {
    final progress = current / target;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${current.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} kg',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _progressAnimationController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: math.min(progress * _progressAnimationController.value, 1.0),
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress <= 1.0 ? color : Colors.red,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
'${(progress * 100).toStringAsFixed(1)}% ${AppLocalizations.of(context)!.translate('ui.completeShort')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('ui.weeklyProgressTrend'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Simple bar chart representation
            AnimatedBuilder(
              animation: _chartAnimationController,
              builder: (context, child) {
                return SizedBox(
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      // Sample data for demonstration
                      final values = [8.2, 12.1, 9.8, 15.4, 7.3, 11.2, _currentDaily];
                      final firstDayOfWeek = DateTime.now().subtract(Duration(days: (DateTime.now().weekday + 6) % 7));
                      final dayNames = List.generate(7, (i) => DateFormat.E(Localizations.localeOf(context).toString())
                          .format(firstDayOfWeek.add(Duration(days: i))));
                      
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 20,
                            height: (values[index] / _dailyGoal * 80 * _chartAnimationController.value).clamp(4.0, 80.0),
                            decoration: BoxDecoration(
                              color: values[index] <= _dailyGoal ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayNames[index],
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.translate('goals.target')}: ${_dailyGoal.toStringAsFixed(0)} kg',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.translate('goals.onTrack'),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    // Show only first 3 achievements for simplicity
    final displayAchievements = _achievements.take(3).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.translate('ui.goalAchievements'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.translate('ui.moreAchievementsSoon')),
                      ),
                    );
                  },
                  child: Text(AppLocalizations.of(context)!.translate('common.viewAll')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Simple achievement list
            ...displayAchievements.map((achievement) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: achievement.isUnlocked 
                        ? achievement.color.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      achievement.icon,
                      style: TextStyle(
                        fontSize: 16,
                        color: achievement.isUnlocked 
                          ? achievement.color
                          : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      achievement.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: achievement.isUnlocked 
                          ? null
                          : Colors.grey,
                      ),
                    ),
                  ),
                  if (achievement.isUnlocked)
                    Icon(
                      Icons.check_circle,
                      color: achievement.color,
                      size: 16,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    final tips = [
      AppLocalizations.of(context)!.translate('tips.walkMore'),
      AppLocalizations.of(context)!.translate('tips.usePublicTransport'),
      AppLocalizations.of(context)!.translate('tips.energyEfficient'),
      AppLocalizations.of(context)!.translate('tips.reduceWaste'),
      AppLocalizations.of(context)!.translate('tips.localProducts'),
      AppLocalizations.of(context)!.translate('tips.smartThermostat'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.translate('ui.carbonReductionTips'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...tips.take(3).map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                tip,
                style: const TextStyle(fontSize: 14),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _editGoals() {
    showDialog(
      context: context,
      builder: (context) => _GoalEditDialog(
        currentDaily: _dailyGoal,
        currentWeekly: _weeklyGoal,
        currentMonthly: _monthlyGoal,
        currentYearly: _yearlyGoal,
        onSave: (daily, weekly, monthly, yearly) {
          setState(() {
            _dailyGoal = daily;
            _weeklyGoal = weekly;
            _monthlyGoal = monthly;
            _yearlyGoal = yearly;
          });
          _progressAnimationController.reset();
          _chartAnimationController.reset();
          _progressAnimationController.forward();
          _chartAnimationController.forward();
        },
      ),
    );
  }

  void _showAchievementDetails(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(achievement.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.icon,
              style: TextStyle(
                fontSize: 48,
                color: achievement.isUnlocked ? achievement.color : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(achievement.description),
            const SizedBox(height: 16),
            if (!achievement.isUnlocked)
              LinearProgressIndicator(
                value: 0.3, // Sample progress
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(achievement.color),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common.close')),
          ),
        ],
      ),
    );
  }
}

class _GoalEditDialog extends StatefulWidget {
  final double currentDaily;
  final double currentWeekly;
  final double currentMonthly;
  final double currentYearly;
  final Function(double, double, double, double) onSave;

  const _GoalEditDialog({
    required this.currentDaily,
    required this.currentWeekly,
    required this.currentMonthly,
    required this.currentYearly,
    required this.onSave,
  });

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
  late double _daily;
  late double _weekly;
  late double _monthly;
  late double _yearly;

  @override
  void initState() {
    super.initState();
    _daily = widget.currentDaily;
    _weekly = widget.currentWeekly;
    _monthly = widget.currentMonthly;
    _yearly = widget.currentYearly;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.translate('ui.editGoals')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSlider(
              label: AppLocalizations.of(context)!.translate('goals.daily'),
              value: _daily,
              min: 1.0,
              max: 50.0,
              onChanged: (value) => setState(() => _daily = value),
              unit: 'kg',
            ),
            _buildSlider(
              label: AppLocalizations.of(context)!.translate('goals.weekly'),
              value: _weekly,
              min: 10.0,
              max: 350.0,
              onChanged: (value) => setState(() => _weekly = value),
              unit: 'kg',
            ),
            _buildSlider(
              label: AppLocalizations.of(context)!.translate('goals.monthly'),
              value: _monthly,
              min: 50.0,
              max: 1500.0,
              onChanged: (value) => setState(() => _monthly = value),
              unit: 'kg',
            ),
            _buildSlider(
              label: AppLocalizations.of(context)!.translate('ui.yearly'),
              value: _yearly,
              min: 500.0,
              max: 18000.0,
              onChanged: (value) => setState(() => _yearly = value),
              unit: 'kg',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_daily, _weekly, _monthly, _yearly);
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.translate('common.save')),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${value.toStringAsFixed(0)} $unit', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 5).round(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

