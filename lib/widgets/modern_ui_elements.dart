import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

// Glassmorphism effect widget
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? color;
  final double blur;
  final double opacity;
  final Border? border;
  final Gradient? gradient;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassContainer({
    Key? key,
    required this.child,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius,
    this.color,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.border,
    this.gradient,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: color?.withValues(alpha: opacity) ?? 
                     Colors.white.withValues(alpha: opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              border: border ?? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              gradient: gradient,
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

// Neumorphism style container
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final Color? color;
  final BorderRadius? borderRadius;
  final double depth;
  final bool isPressed;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const NeumorphicContainer({
    Key? key,
    required this.child,
    this.width = double.infinity,
    this.height = double.infinity,
    this.color,
    this.borderRadius,
    this.depth = 8.0,
    this.isPressed = false,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Theme.of(context).scaffoldBackgroundColor;
    
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.5),
                  offset: Offset(-depth / 2, -depth / 2),
                  blurRadius: depth,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: Offset(depth / 2, depth / 2),
                  blurRadius: depth,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.7),
                  offset: Offset(-depth, -depth),
                  blurRadius: depth * 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: Offset(depth, depth),
                  blurRadius: depth * 2,
                ),
              ],
      ),
      padding: padding,
      child: child,
    );
  }
}

// Gradient card with modern design
class ModernCard extends StatefulWidget {
  final Widget child;
  final Gradient? gradient;
  final List<Color>? colors;
  final double borderRadius;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool enableHover;
  final Duration animationDuration;

  const ModernCard({
    Key? key,
    required this.child,
    this.gradient,
    this.colors,
    this.borderRadius = 16.0,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onTap,
    this.enableHover = true,
    this.animationDuration = const Duration(milliseconds: 200),
  }) : super(key: key);

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    if (!widget.enableHover) return;
    
    setState(() {
      _isHovering = hovering;
    });
    
    if (hovering) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ??
        (widget.colors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.colors!,
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  Theme.of(context).primaryColor.withValues(alpha: 0.05),
                ],
              ));

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.width,
                height: widget.height,
                margin: widget.margin,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: _isHovering ? 20 : 10,
                      offset: Offset(0, _isHovering ? 10 : 5),
                    ),
                  ],
                ),
                padding: widget.padding,
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

// Modern bottom sheet with glassmorphism
class ModernBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final double? height;
  final bool isDismissible;
  final bool enableDrag;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const ModernBottomSheet({
    Key? key,
    required this.child,
    this.title,
    this.height,
    this.isDismissible = true,
    this.enableDrag = true,
    this.backgroundColor,
    this.borderRadius,
  }) : super(key: key);

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    double? height,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      builder: (context) => ModernBottomSheet(
        title: title,
        height: height,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: height ?? screenHeight * 0.9,
      margin: EdgeInsets.only(bottom: keyboardHeight),
      child: GlassContainer(
        color: backgroundColor ?? Colors.white,
        opacity: 0.95,
        blur: 20,
        borderRadius: borderRadius ?? 
                     const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            if (enableDrag)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            
            // Title
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isDismissible)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          shape: const CircleBorder(),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            
            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Floating action menu with modern design
class FloatingActionMenu extends StatefulWidget {
  final List<FloatingActionItem> items;
  final Widget mainButton;
  final Duration animationDuration;
  final double spacing;
  final Color? backgroundColor;

  const FloatingActionMenu({
    Key? key,
    required this.items,
    required this.mainButton,
    this.animationDuration = const Duration(milliseconds: 300),
    this.spacing = 70.0,
    this.backgroundColor,
  }) : super(key: key);

  @override
  State<FloatingActionMenu> createState() => _FloatingActionMenuState();
}

class _FloatingActionMenuState extends State<FloatingActionMenu>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _itemAnimations;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _itemAnimations = List.generate(
      widget.items.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.1,
          0.6 + index * 0.1,
          curve: Curves.elasticOut,
        ),
      )),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Background overlay
        if (_isOpen)
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        
        // Menu items
        ...widget.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          return AnimatedBuilder(
            animation: _itemAnimations[index],
            builder: (context, child) {
              final offset = (index + 1) * widget.spacing * _itemAnimations[index].value;
              
              return Transform.translate(
                offset: Offset(0, -offset),
                child: Transform.scale(
                  scale: _itemAnimations[index].value,
                  child: Opacity(
                    opacity: _itemAnimations[index].value,
                    child: GlassContainer(
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(28),
                      color: item.backgroundColor ?? Colors.white,
                      opacity: 0.9,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            item.onPressed();
                            _toggle();
                          },
                          child: Center(
                            child: Icon(
                              item.icon,
                              color: item.iconColor ?? Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
        
        // Main button
        GestureDetector(
          onTap: _toggle,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0.0,
            duration: widget.animationDuration,
            child: widget.mainButton,
          ),
        ),
      ],
    );
  }
}

class FloatingActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const FloatingActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });
}

// Animated progress ring
class ModernProgressRing extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? center;
  final Duration animationDuration;

  const ModernProgressRing({
    Key? key,
    required this.progress,
    this.size = 100.0,
    this.strokeWidth = 8.0,
    this.color,
    this.backgroundColor,
    this.center,
    this.animationDuration = const Duration(milliseconds: 1000),
  }) : super(key: key);

  @override
  State<ModernProgressRing> createState() => _ModernProgressRingState();
}

class _ModernProgressRingState extends State<ModernProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void didUpdateWidget(ModernProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.progress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ProgressRingPainter(
              progress: _progressAnimation,
              strokeWidth: widget.strokeWidth,
              color: widget.color ?? Theme.of(context).primaryColor,
              backgroundColor: widget.backgroundColor ?? Colors.grey.shade300,
            ),
          ),
          if (widget.center != null) widget.center!,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final Animation<double> progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.value;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Modern notification card
class NotificationCard extends StatefulWidget {
  final Widget content;
  final NotificationType type;
  final Duration? duration;
  final VoidCallback? onDismiss;
  final bool isDismissible;

  const NotificationCard({
    Key? key,
    required this.content,
    this.type = NotificationType.info,
    this.duration,
    this.onDismiss,
    this.isDismissible = true,
  }) : super(key: key);

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
    
    if (widget.duration != null) {
      Future.delayed(widget.duration!, _dismiss);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: GlassContainer(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        color: _getColorForType(widget.type),
        opacity: 0.9,
        child: Row(
          children: [
            Icon(
              _getIconForType(widget.type),
              color: _getColorForType(widget.type),
            ),
            const SizedBox(width: 12),
            Expanded(child: widget.content),
            if (widget.isDismissible)
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close),
                iconSize: 20,
              ),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.info:
      default:
        return Colors.blue;
    }
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.info:
      default:
        return Icons.info;
    }
  }
}

enum NotificationType { info, success, warning, error }