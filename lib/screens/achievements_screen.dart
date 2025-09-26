import 'package:flutter/material.dart';
import 'package:carbon_tracker/services/achievement_service.dart';
import 'package:carbon_tracker/widgets/achievement_widgets.dart';
import 'package:carbon_tracker/widgets/animated_widgets.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AchievementService _achievementService = AchievementService.instance;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Başarılar'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tümü'),
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Seri'),
            Tab(text: 'Kilometre Taşları'),
            Tab(text: 'Özel'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _achievementService,
        builder: (context, child) {
          return Column(
            children: [
              // Level Progress Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FadeInWidget(
                  child: LevelProgressWidget(
                    level: _achievementService.userLevel,
                    progress: _achievementService.levelProgress,
                    totalPoints: _achievementService.totalPoints,
                    pointsForNextLevel: _achievementService.pointsForNextLevel,
                  ),
                ),
              ),
              
              // Statistics Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Kazanılan',
                        '${_achievementService.unlockedCount}',
                        '${_achievementService.totalAchievements}',
                        Colors.green,
                        Icons.emoji_events,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: _buildStatCard(
                        'Toplam XP',
                        '${_achievementService.totalPoints}',
                        'puan',
                        Colors.purple,
                        Icons.stars,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: _buildStatCard(
                        'Seviye',
                        '${_achievementService.userLevel}',
                        'level',
                        Colors.orange,
                        Icons.trending_up,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Achievement Lists
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllAchievements(),
                    _buildAchievementsByType(AchievementType.daily),
                    _buildAchievementsByType(AchievementType.weekly),
                    _buildAchievementsByType(AchievementType.streak),
                    _buildAchievementsByType(AchievementType.milestone),
                    _buildAchievementsByType(AchievementType.special),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return SlideInWidget(
      direction: SlideDirection.left,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 18.0,
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.0,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllAchievements() {
    final achievements = _achievementService.achievements;
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).toList();
    final lockedAchievements = achievements.where((a) => !a.isUnlocked).toList();
    
    // Sort unlocked by unlock date (newest first)
    unlockedAchievements.sort((a, b) => 
        (b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    
    // Sort locked by progress percentage (highest first)
    lockedAchievements.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    
    final sortedAchievements = [...unlockedAchievements, ...lockedAchievements];
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedAchievements.length,
      itemBuilder: (context, index) {
        final achievement = sortedAchievements[index];
        return SlideInWidget(
          delay: Duration(milliseconds: index * 100),
          direction: SlideDirection.right,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AchievementCard(
              achievement: achievement,
              onTap: () => _showAchievementDetails(achievement),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementsByType(AchievementType type) {
    final achievements = _achievementService.getAchievementsByType(type);
    
    if (achievements.isEmpty) {
      return const Center(
        child: Text('Bu kategoride henüz başarı yok.'),
      );
    }
    
    // Sort by unlock status and progress
    achievements.sort((a, b) {
      if (a.isUnlocked && !b.isUnlocked) return -1;
      if (!a.isUnlocked && b.isUnlocked) return 1;
      if (a.isUnlocked && b.isUnlocked) {
        return (b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      }
      return b.progressPercentage.compareTo(a.progressPercentage);
    });
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return SlideInWidget(
          delay: Duration(milliseconds: index * 100),
          direction: SlideDirection.left,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: AchievementCard(
              achievement: achievement,
              onTap: () => _showAchievementDetails(achievement),
            ),
          ),
        );
      },
    );
  }

  void _showAchievementDetails(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeWidget(
              achievement: achievement,
              size: 80.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              achievement.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              achievement.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: achievement.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hedef:',
                        style: TextStyle(
                          color: achievement.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${achievement.targetValue.toStringAsFixed(1)} ${achievement.unit}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'XP Değeri:',
                        style: TextStyle(
                          color: achievement.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${achievement.points} XP',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (!achievement.isUnlocked) ...[
                    const SizedBox(height: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'İlerleme:',
                          style: TextStyle(
                            color: achievement.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(achievement.progressPercentage * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    LinearProgressIndicator(
                      value: achievement.progressPercentage,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(achievement.color),
                    ),
                  ],
                  if (achievement.isUnlocked && achievement.unlockedAt != null) ...[
                    const SizedBox(height: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kazanıldı:',
                          style: TextStyle(
                            color: achievement.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${achievement.unlockedAt!.day}/${achievement.unlockedAt!.month}/${achievement.unlockedAt!.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}