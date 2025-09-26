import 'package:flutter/material.dart';
import '../services/language_service.dart';
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
  final LanguageService _languageService = LanguageService.instance;
  
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
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadGoals();
    _loadProgress();
    _setupAchievements();
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
    _achievements.addAll([
      Achievement(
        id: 'daily_green',
        title: _languageService.isEnglish ? 'Daily Green Champion' : 'Günlük Yeşil Şampiyon',
        description: _languageService.isEnglish ? 'Stay under daily goal for 7 days' : '7 gün boyunca günlük hedefin altında kal',
        icon: '🌱',
        color: Colors.green,
        type: AchievementType.daily,
        targetValue: 7,
        unit: 'gün',
        points: 50,
      ),
      Achievement(
        id: 'weekly_warrior',
        title: _languageService.isEnglish ? 'Weekly Warrior' : 'Haftalık Savaşçı',
        description: _languageService.isEnglish ? 'Achieve weekly goal 4 times' : '4 kez haftalık hedefe ulaş',
        icon: '🏆',
        color: Colors.blue,
        type: AchievementType.weekly,
        targetValue: 4,
        unit: 'hafta',
        points: 75,
      ),
      Achievement(
        id: 'monthly_master',
        title: _languageService.isEnglish ? 'Monthly Master' : 'Aylık Usta',
        description: _languageService.isEnglish ? 'Beat monthly goal' : 'Aylık hedefi geç',
        icon: '⭐',
        color: Colors.amber,
        type: AchievementType.monthly,
        targetValue: 1,
        unit: 'hedef',
        points: 100,
      ),
      Achievement(
        id: 'carbon_crusher',
        title: _languageService.isEnglish ? 'Carbon Crusher' : 'Karbon Ezici',
        description: _languageService.isEnglish ? 'Reduce emissions by 50%' : 'Emisyonları %50 azalt',
        icon: '📉',
        color: Colors.red,
        type: AchievementType.milestone,
        targetValue: 50,
        unit: '%',
        points: 200,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_languageService.isEnglish ? 'Carbon Goals' : 'Karbon Hedefleri'),
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        foregroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editGoals,
          ),
        ],
      ),
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
          _languageService.isEnglish ? 'Edit Goals' : 'Hedefleri Düzenle',
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
              _languageService.isEnglish ? 'Today\'s Goal Progress' : 'Bugünkü Hedef İlerlemesi',
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
                          '${_currentDaily.toStringAsFixed(1)}',
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
                  ? (_languageService.isEnglish ? 'On track' : 'Hedefteyiz')
                  : (_languageService.isEnglish ? 'Over goal' : 'Hedef aşıldı'),
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
          _languageService.isEnglish ? 'Goal Progress' : 'Hedef İlerlemesi',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildProgressCard(
          title: _languageService.isEnglish ? 'Weekly' : 'Haftalık',
          current: _currentWeekly,
          target: _weeklyGoal,
          icon: Icons.calendar_view_week,
          color: Colors.blue,
        ),
        
        const SizedBox(height: 12),
        
        _buildProgressCard(
          title: _languageService.isEnglish ? 'Monthly' : 'Aylık',
          current: _currentMonthly,
          target: _monthlyGoal,
          icon: Icons.calendar_month,
          color: Colors.orange,
        ),
        
        const SizedBox(height: 12),
        
        _buildProgressCard(
          title: _languageService.isEnglish ? 'Yearly' : 'Yıllık',
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
                    '${(progress * 100).toStringAsFixed(1)}% ${_languageService.isEnglish ? 'complete' : 'tamamlandı'}',
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
              _languageService.isEnglish ? 'Weekly Progress Trend' : 'Haftalık İlerleme Trendi',
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
                      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      final dayNamesTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                      
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
                            _languageService.isEnglish ? dayNames[index] : dayNamesTr[index],
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
                  _languageService.isEnglish ? 'Goal: ${_dailyGoal.toStringAsFixed(0)} kg/day' : 'Hedef: ${_dailyGoal.toStringAsFixed(0)} kg/gün',
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
                        _languageService.isEnglish ? 'On track' : 'Hedefteyiz',
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
                  _languageService.isEnglish ? 'Goal Achievements' : 'Hedef Başarıları',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_languageService.isEnglish 
                          ? 'More achievements coming soon!'
                          : 'Daha fazla başarı yakında!'),
                      ),
                    );
                  },
                  child: Text(_languageService.isEnglish ? 'View All' : 'Tümünü Gör'),
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
    final tips = _languageService.isEnglish ? [
      '🚶‍♂️ Walk or bike instead of driving short distances',
      '💡 Switch to LED bulbs to save energy',
      '🌱 Eat more plant-based meals',
      '♻️ Reduce, reuse, and recycle whenever possible',
      '🚗 Use public transport or carpool',
      '🏠 Improve home insulation',
    ] : [
      '🚶‍♂️ Kısa mesafelerde araba yerine yürü veya bisiklet kullan',
      '💡 Enerji tasarrufu için LED ampuller kullan',
      '🌱 Daha fazla bitki bazlı yemek ye',
      '♻️ Mümkün olduğunca azalt, yeniden kullan ve geri dönüştür',
      '🚗 Toplu taşıma kullan veya araç paylaş',
      '🏠 Ev yalıtımını iyileştir',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _languageService.isEnglish ? 'Tips to Reduce Carbon' : 'Karbonu Azaltma İpuçları',
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
          // Save to preferences in real app
          _progressAnimationController.reset();
          _chartAnimationController.reset();
          _progressAnimationController.forward();
          _chartAnimationController.forward();
        },
        languageService: _languageService,
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
            child: Text(_languageService.isEnglish ? 'Close' : 'Kapat'),
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
  final LanguageService languageService;

  const _GoalEditDialog({
    required this.currentDaily,
    required this.currentWeekly,
    required this.currentMonthly,
    required this.currentYearly,
    required this.onSave,
    required this.languageService,
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
      title: Text(widget.languageService.isEnglish ? 'Edit Goals' : 'Hedefleri Düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSlider(
              label: widget.languageService.isEnglish ? 'Daily Goal' : 'Günlük Hedef',
              value: _daily,
              min: 1.0,
              max: 50.0,
              onChanged: (value) => setState(() => _daily = value),
              unit: 'kg/day',
            ),
            _buildSlider(
              label: widget.languageService.isEnglish ? 'Weekly Goal' : 'Haftalık Hedef',
              value: _weekly,
              min: 10.0,
              max: 350.0,
              onChanged: (value) => setState(() => _weekly = value),
              unit: 'kg/week',
            ),
            _buildSlider(
              label: widget.languageService.isEnglish ? 'Monthly Goal' : 'Aylık Hedef',
              value: _monthly,
              min: 50.0,
              max: 1500.0,
              onChanged: (value) => setState(() => _monthly = value),
              unit: 'kg/month',
            ),
            _buildSlider(
              label: widget.languageService.isEnglish ? 'Yearly Goal' : 'Yıllık Hedef',
              value: _yearly,
              min: 500.0,
              max: 18000.0,
              onChanged: (value) => setState(() => _yearly = value),
              unit: 'kg/year',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.languageService.isEnglish ? 'Cancel' : 'İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_daily, _weekly, _monthly, _yearly);
            Navigator.of(context).pop();
          },
          child: Text(widget.languageService.isEnglish ? 'Save' : 'Kaydet'),
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

