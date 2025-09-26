import 'package:flutter/material.dart';
import 'dart:math' as math;

enum TransitionType {
  slide,
  fade,
  scale,
  rotation,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  fadeScale,
  rotationScale,
  ripple,
  flip,
  bounceIn,
  morphing,
}

class PageTransitionBuilder {
  static PageRouteBuilder<T> build<T extends Object?>({
    required Widget page,
    required TransitionType type,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    Alignment alignment = Alignment.center,
    Offset? slideOffset,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildTransition(
          type: type,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
          curve: curve,
          alignment: alignment,
          slideOffset: slideOffset,
        );
      },
    );
  }

  static Widget _buildTransition({
    required TransitionType type,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    required Curve curve,
    required Alignment alignment,
    Offset? slideOffset,
  }) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

    switch (type) {
      case TransitionType.slide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset ?? const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.slideUp:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.slideDown:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.slideLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.slideRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );

      case TransitionType.scale:
        return ScaleTransition(
          alignment: alignment,
          scale: curvedAnimation,
          child: child,
        );

      case TransitionType.rotation:
        return RotationTransition(
          alignment: alignment,
          turns: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.fadeScale:
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            alignment: alignment,
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );

      case TransitionType.rotationScale:
        return ScaleTransition(
          alignment: alignment,
          scale: curvedAnimation,
          child: RotationTransition(
            alignment: alignment,
            turns: Tween<double>(begin: 0.0, end: 0.25).animate(curvedAnimation),
            child: child,
          ),
        );

      case TransitionType.ripple:
        return _RippleTransition(
          animation: curvedAnimation,
          child: child,
        );

      case TransitionType.flip:
        return _FlipTransition(
          animation: curvedAnimation,
          child: child,
        );

      case TransitionType.bounceIn:
        final bounceAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.bounceOut,
        );
        return ScaleTransition(
          alignment: alignment,
          scale: bounceAnimation,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );

      case TransitionType.morphing:
        return _MorphingTransition(
          animation: curvedAnimation,
          child: child,
        );
    }
  }
}

class _RippleTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _RippleTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(animation.value),
          child: ClipPath(
            clipper: _RippleClipper(animation.value),
            child: this.child,
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(math.pow(size.width, 2) + math.pow(size.height, 2));
    final radius = maxRadius * progress;

    if (progress > 0) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RippleClipper extends CustomClipper<Path> {
  final double progress;

  _RippleClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(math.pow(size.width, 2) + math.pow(size.height, 2));
    final radius = maxRadius * progress;

    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(covariant _RippleClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

class _FlipTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FlipTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final isShowingFrontSide = animation.value < 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(animation.value * math.pi),
          child: isShowingFrontSide
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.blue.withValues(alpha: 0.1),
                )
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: this.child,
                ),
        );
      },
    );
  }
}

class _MorphingTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _MorphingTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animation.value),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(0.3 * (1 - animation.value))
              ..rotateY(0.1 * (1 - animation.value)),
            child: Opacity(
              opacity: animation.value,
              child: this.child,
            ),
          ),
        );
      },
    );
  }
}

// Hero transition for seamless element animation
class HeroPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final String heroTag;
  final Duration duration;

  HeroPageRoute({
    required this.child,
    required this.heroTag,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

// Extensions for easy navigation with transitions
extension NavigatorExtensions on NavigatorState {
  Future<T?> pushWithTransition<T extends Object?>(
    Widget page, {
    TransitionType transition = TransitionType.slideRight,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return push<T>(
      PageTransitionBuilder.build<T>(
        page: page,
        type: transition,
        duration: duration,
        curve: curve,
      ),
    );
  }

  Future<T?> pushReplacementWithTransition<T extends Object?, TO extends Object?>(
    Widget page, {
    TransitionType transition = TransitionType.slideRight,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    TO? result,
  }) {
    return pushReplacement<T, TO>(
      PageTransitionBuilder.build<T>(
        page: page,
        type: transition,
        duration: duration,
        curve: curve,
      ),
      result: result,
    );
  }

  Future<T?> pushHero<T extends Object?>(
    Widget page, {
    required String heroTag,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return push<T>(
      HeroPageRoute<T>(
        child: page,
        heroTag: heroTag,
        duration: duration,
      ),
    );
  }
}

extension NavigatorContextExtensions on BuildContext {
  Future<T?> pushWithTransition<T extends Object?>(
    Widget page, {
    TransitionType transition = TransitionType.slideRight,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return Navigator.of(this).pushWithTransition<T>(
      page,
      transition: transition,
      duration: duration,
      curve: curve,
    );
  }

  Future<T?> pushReplacementWithTransition<T extends Object?, TO extends Object?>(
    Widget page, {
    TransitionType transition = TransitionType.slideRight,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    TO? result,
  }) {
    return Navigator.of(this).pushReplacementWithTransition<T, TO>(
      page,
      transition: transition,
      duration: duration,
      curve: curve,
      result: result,
    );
  }

  Future<T?> pushHero<T extends Object?>(
    Widget page, {
    required String heroTag,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return Navigator.of(this).pushHero<T>(
      page,
      heroTag: heroTag,
      duration: duration,
    );
  }
}

// Custom route animations for specific transitions
class CustomPageRoute<T> extends PageRoute<T> {
  final Widget child;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) transitionBuilder;

  CustomPageRoute({
    required this.child,
    required this.transitionBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Duration reverseTransitionDuration = const Duration(milliseconds: 300),
    RouteSettings? settings,
  }) : _transitionDuration = transitionDuration,
       _reverseTransitionDuration = reverseTransitionDuration,
       super(settings: settings);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return transitionBuilder(context, animation, secondaryAnimation, child);
  }
}