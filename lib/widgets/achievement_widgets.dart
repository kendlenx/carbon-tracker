import 'package:flutter/material.dart';
import 'package:carbon_tracker/services/achievement_service.dart';
import 'package:carbon_tracker/widgets/animated_widgets.dart';

class BadgeWidget extends StatefulWidget {
  final Achievement achievement;
  final bool showUnlockAnimation;
  final VoidCallback? onTap;
  final double size;

  const BadgeWidget({
    Key? key,
    required this.achievement,
    this.showUnlockAnimation = false,
    this.onTap,
    this.size = 60.0,
  }) : super(key: key);

  @override
  State<BadgeWidget> createState() => _BadgeWidgetState();
}

class _BadgeWidgetState extends State<BadgeWidget>
    with TickerProviderStateMixin {
  late AnimationController _unlockAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _unlockAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _unlockAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    if (widget.showUnlockAnimation) {
      _unlockAnimationController.forward().then((_) {
        if (mounted) {
          _pulseAnimationController.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _unlockAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = widget.achievement.isUnlocked;
    
    Widget badge = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUnlocked
            ? RadialGradient(
                colors: [
                  widget.achievement.color.withOpacity(0.8),
                  widget.achievement.color,
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade400,
                ],
              ),
        border: Border.all(
          color: isUnlocked ? Colors.white : Colors.grey.shade500,
          width: 2.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: widget.achievement.color.withOpacity(0.3),
                  blurRadius: 8.0,
                  spreadRadius: 2.0,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          widget.achievement.icon,
          style: TextStyle(
            fontSize: widget.size * 0.4,
            color: isUnlocked ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );

    if (!isUnlocked) {
      badge = Stack(
        alignment: Alignment.center,
        children: [
          badge,
          Icon(
            Icons.lock,
            color: Colors.grey.shade600,
            size: widget.size * 0.3,
          ),
        ],
      );
    }

    if (widget.showUnlockAnimation && isUnlocked) {
      badge = AnimatedBuilder(
        animation: _unlockAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: badge,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: TapScaleWidget(
        child: badge,
      ),
    );
  }
}

class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool showProgress;
  final VoidCallback? onTap;

  const AchievementCard({
    Key? key,
    required this.achievement,
    this.showProgress = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;
    
    return Card(
      elevation: isUnlocked ? 4.0 : 2.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              BadgeWidget(
                achievement: achievement,
                size: 50.0,
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isUnlocked 
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isUnlocked) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: achievement.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              '+${achievement.points} XP',
                              style: TextStyle(
                                color: achievement.color,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      achievement.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (showProgress && !isUnlocked) ...[
                      const SizedBox(height: 8.0),
                      _buildProgressBar(theme),
                    ],
                    if (isUnlocked && achievement.unlockedAt != null) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        _formatUnlockDate(achievement.unlockedAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: achievement.color,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    final progress = achievement.progressPercentage;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'İlerleme',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              '${achievement.currentProgress.toStringAsFixed(1)}/${achievement.targetValue.toStringAsFixed(1)} ${achievement.unit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(achievement.color),
        ),
      ],
    );
  }

  String _formatUnlockDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Bugün kazanıldı';
    } else if (difference.inDays == 1) {
      return 'Dün kazanıldı';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce kazanıldı';
    } else {
      return '${date.day}/${date.month}/${date.year} tarihinde kazanıldı';
    }
  }
}

class AchievementUnlockDialog extends StatefulWidget {
  final List<Achievement> newAchievements;
  final VoidCallback? onDismiss;

  const AchievementUnlockDialog({
    Key? key,
    required this.newAchievements,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<AchievementUnlockDialog> createState() => _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _sparkleController;
  late Animation<Offset> _slideAnimation;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _slideController.forward();
    _sparkleController.repeat();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievement = widget.newAchievements[_currentIndex];
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                achievement.color.withOpacity(0.1),
                Colors.white,
                achievement.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: achievement.color.withOpacity(0.3),
              width: 2.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: achievement.color,
                      size: 24.0,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'Başarı Kazanıldı!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: achievement.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onDismiss?.call();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
                
                // Achievement Badge with Sparkles
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sparkle effect
                    AnimatedBuilder(
                      animation: _sparkleController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _sparkleController.value * 2 * 3.14159,
                          child: Container(
                            width: 120.0,
                            height: 120.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  achievement.color.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Main badge
                    BadgeWidget(
                      achievement: achievement,
                      size: 80.0,
                      showUnlockAnimation: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
                
                // Achievement Info
                Text(
                  achievement.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                
                // Points earned
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: achievement.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Text(
                    '+${achievement.points} XP Kazandın!',
                    style: TextStyle(
                      color: achievement.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                
                // Navigation for multiple achievements
                if (widget.newAchievements.length > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.newAchievements.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentIndex
                              ? achievement.color
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],
                
                // Actions
                Row(
                  children: [
                    if (widget.newAchievements.length > 1 && _currentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _currentIndex--;
                            });
                          },
                          child: const Text('Önceki'),
                        ),
                      ),
                    if (widget.newAchievements.length > 1 && _currentIndex > 0)
                      const SizedBox(width: 8.0),
                    Expanded(
                      child: widget.newAchievements.length > 1 && _currentIndex < widget.newAchievements.length - 1
                          ? ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _currentIndex++;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: achievement.color,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Sonraki'),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onDismiss?.call();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: achievement.color,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Harika!'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LevelProgressWidget extends StatelessWidget {
  final int level;
  final double progress;
  final int totalPoints;
  final int pointsForNextLevel;

  const LevelProgressWidget({
    Key? key,
    required this.level,
    required this.progress,
    required this.totalPoints,
    required this.pointsForNextLevel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDark ? 0.1 : 0.9),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Level badge with glow effect
              Container(
                width: 50.0,
                height: 50.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber,
                      Colors.orange,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalPoints XP earned',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '$pointsForNextLevel XP to go',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // Progress bar with better styling
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to Level ${level + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      LinearGradient(
                        colors: [Colors.purple, Colors.blue],
                      ).colors[0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}