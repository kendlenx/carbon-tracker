import 'package:flutter/material.dart';
import 'dart:math' as math;

class LiquidPullRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration animationDuration;

  const LiquidPullRefresh({
    Key? key,
    required this.child,
    required this.onRefresh,
    this.color = Colors.blue,
    this.backgroundColor = Colors.white,
    this.height = 80.0,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<LiquidPullRefresh> createState() => _LiquidPullRefreshState();
}

class _LiquidPullRefreshState extends State<LiquidPullRefresh>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _dropController;
  late Animation<double> _waveAnimation;
  late Animation<double> _dropAnimation;
  
  bool _isRefreshing = false;
  double _dragOffset = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _dropController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));
    
    _dropAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dropController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _waveController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _dropController.forward();
    _waveController.repeat();
    
    try {
      await widget.onRefresh();
    } finally {
      _waveController.stop();
      await _dropController.reverse();
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _dragOffset = 0.0;
        });
      }
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isRefreshing) return;
    
    setState(() {
      _dragOffset = math.max(0, _dragOffset + details.delta.dy);
      if (_dragOffset > widget.height) {
        _dragOffset = widget.height;
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isRefreshing) return;
    
    if (_dragOffset >= widget.height * 0.8) {
      _handleRefresh();
    } else {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Liquid background
        Positioned(
          top: -widget.height + _dragOffset,
          left: 0,
          right: 0,
          height: widget.height,
          child: AnimatedBuilder(
            animation: Listenable.merge([_waveAnimation, _dropAnimation]),
            builder: (context, child) {
              return CustomPaint(
                painter: LiquidPainter(
                  color: widget.color,
                  backgroundColor: widget.backgroundColor,
                  wavePhase: _waveAnimation.value,
                  dragOffset: _dragOffset,
                  maxHeight: widget.height,
                  dropScale: _dropAnimation.value,
                  isRefreshing: _isRefreshing,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        
        // Child content
        GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Transform.translate(
            offset: Offset(0, _dragOffset * 0.5), // Parallax effect
            child: widget.child,
          ),
        ),
        
        // Refresh indicator
        if (_isRefreshing || _dragOffset > 20)
          Positioned(
            top: _dragOffset * 0.3,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _dropAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isRefreshing ? _dropAnimation.value : _dragOffset / widget.height,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _isRefreshing
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              color: widget.color,
                              size: 24,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class LiquidPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;
  final double wavePhase;
  final double dragOffset;
  final double maxHeight;
  final double dropScale;
  final bool isRefreshing;

  LiquidPainter({
    required this.color,
    required this.backgroundColor,
    required this.wavePhase,
    required this.dragOffset,
    required this.maxHeight,
    required this.dropScale,
    required this.isRefreshing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, maxHeight),
      backgroundPaint,
    );

    if (dragOffset <= 0 && !isRefreshing) return;

    final progress = dragOffset / maxHeight;
    final waveHeight = maxHeight * progress;

    // Create wave path
    final path = Path();
    path.moveTo(0, maxHeight);

    final waveAmplitude = 20 * progress * (isRefreshing ? dropScale : 1.0);
    final waveFrequency = 2.0;

    // Draw wavy top edge
    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      final y = maxHeight - waveHeight + 
          waveAmplitude * math.sin(waveFrequency * 2 * math.pi * normalizedX + wavePhase);
      
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Close the path
    path.lineTo(size.width, maxHeight);
    path.lineTo(0, maxHeight);
    path.close();

    // Add gradient effect
    if (isRefreshing) {
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.4),
        ],
      );
      
      paint.shader = gradient.createShader(
        Rect.fromLTWH(0, maxHeight - waveHeight, size.width, waveHeight),
      );
    }

    canvas.drawPath(path, paint);

    // Draw droplets effect
    if (isRefreshing && dropScale > 0.5) {
      final dropletPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 5; i++) {
        final x = (size.width / 6) * (i + 1);
        final dropletSize = (3 + i % 3) * dropScale;
        final y = maxHeight - waveHeight - (10 + i * 5) * dropScale;
        
        canvas.drawCircle(
          Offset(x, y),
          dropletSize,
          dropletPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LiquidPainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
           oldDelegate.dragOffset != dragOffset ||
           oldDelegate.dropScale != dropScale ||
           oldDelegate.isRefreshing != isRefreshing;
  }
}

// Extension for easier usage
extension LiquidRefreshExtension on Widget {
  Widget withLiquidRefresh({
    required Future<void> Function() onRefresh,
    Color color = Colors.blue,
    Color backgroundColor = Colors.white,
  }) {
    return LiquidPullRefresh(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: backgroundColor,
      child: this,
    );
  }
}