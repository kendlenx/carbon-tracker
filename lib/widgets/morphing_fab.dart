import 'package:flutter/material.dart';
import 'dart:math' as math;

enum FABState {
  add,
  close,
  play,
  pause,
  save,
  edit,
  search,
  favorite,
  share,
  delete,
  refresh,
}

class FABAction {
  final FABState state;
  final IconData icon;
  final String tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback onPressed;
  final bool isExtended;
  final String? label;

  const FABAction({
    required this.state,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.isExtended = false,
    this.label,
  });
}

class MorphingFAB extends StatefulWidget {
  final FABAction currentAction;
  final Duration animationDuration;
  final Curve animationCurve;
  final double size;
  final bool showRotationAnimation;

  const MorphingFAB({
    Key? key,
    required this.currentAction,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
    this.size = 56.0,
    this.showRotationAnimation = true,
  }) : super(key: key);

  @override
  State<MorphingFAB> createState() => _MorphingFABState();
}

class _MorphingFABState extends State<MorphingFAB>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  FABAction? _previousAction;

  @override
  void initState() {
    super.initState();
    
    _morphController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: widget.animationCurve,
    ));
    
    _morphController.forward();
  }

  @override
  void dispose() {
    _morphController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MorphingFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.currentAction.state != widget.currentAction.state) {
      _previousAction = oldWidget.currentAction;
      _animateToNewState();
    }
  }

  void _animateToNewState() {
    _morphController.reset();
    
    if (widget.showRotationAnimation) {
      _rotationController.forward().then((_) {
        _rotationController.reset();
      });
    }
    
    _morphController.forward();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    
    widget.currentAction.onPressed();
  }

  Color _getBackgroundColor(BuildContext context) {
    return widget.currentAction.backgroundColor ?? 
           Theme.of(context).floatingActionButtonTheme.backgroundColor ??
           Theme.of(context).colorScheme.primary;
  }

  Color _getForegroundColor(BuildContext context) {
    return widget.currentAction.foregroundColor ?? 
           Theme.of(context).floatingActionButtonTheme.foregroundColor ??
           Theme.of(context).colorScheme.onPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _rotationAnimation, _morphController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * math.pi,
            child: widget.currentAction.isExtended
                ? _buildExtendedFAB(context)
                : _buildRegularFAB(context),
          ),
        );
      },
    );
  }

  Widget _buildRegularFAB(BuildContext context) {
    return AnimatedContainer(
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getBackgroundColor(context).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.size / 2),
          onTap: _handleTap,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _getBackgroundColor(context).withOpacity(0.8),
                  _getBackgroundColor(context),
                ],
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: widget.animationDuration.inMilliseconds ~/ 2),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  widget.currentAction.icon,
                  key: ValueKey(widget.currentAction.state),
                  color: _getForegroundColor(context),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtendedFAB(BuildContext context) {
    return AnimatedContainer(
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      height: widget.size,
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(widget.size / 2),
        boxShadow: [
          BoxShadow(
            color: _getBackgroundColor(context).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.size / 2),
          onTap: _handleTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size / 2),
              gradient: LinearGradient(
                colors: [
                  _getBackgroundColor(context).withOpacity(0.8),
                  _getBackgroundColor(context),
                ],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: Duration(milliseconds: widget.animationDuration.inMilliseconds ~/ 2),
                  child: Icon(
                    widget.currentAction.icon,
                    key: ValueKey('${widget.currentAction.state}_icon'),
                    color: _getForegroundColor(context),
                    size: 24,
                  ),
                ),
                if (widget.currentAction.label != null) ...[
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: widget.animationDuration.inMilliseconds ~/ 2),
                    child: Text(
                      widget.currentAction.label!,
                      key: ValueKey('${widget.currentAction.state}_label'),
                      style: TextStyle(
                        color: _getForegroundColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Multi-state FAB that can switch between different actions
class MultiStateFAB extends StatefulWidget {
  final List<FABAction> actions;
  final FABState currentState;
  final Duration animationDuration;
  final bool showStateIndicator;

  const MultiStateFAB({
    Key? key,
    required this.actions,
    required this.currentState,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showStateIndicator = true,
  }) : super(key: key);

  @override
  State<MultiStateFAB> createState() => _MultiStateFABState();
}

class _MultiStateFABState extends State<MultiStateFAB> {
  FABAction get currentAction {
    return widget.actions.firstWhere(
      (action) => action.state == widget.currentState,
      orElse: () => widget.actions.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MorphingFAB(
          currentAction: currentAction,
          animationDuration: widget.animationDuration,
        ),
        
        // State indicator dots
        if (widget.showStateIndicator && widget.actions.length > 1)
          Positioned(
            bottom: -4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.actions.asMap().entries.map((entry) {
                final isActive = entry.value.state == widget.currentState;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: isActive ? 8 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// Speed dial FAB with multiple quick actions
class SpeedDialFAB extends StatefulWidget {
  final Widget mainFAB;
  final List<SpeedDialAction> actions;
  final Duration animationDuration;
  final double spacing;

  const SpeedDialFAB({
    Key? key,
    required this.mainFAB,
    required this.actions,
    this.animationDuration = const Duration(milliseconds: 300),
    this.spacing = 70.0,
  }) : super(key: key);

  @override
  State<SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<SpeedDialFAB>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Overlay to close when tapped outside
        if (_isOpen)
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
        
        // Speed dial actions
        ...widget.actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          
          return AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              final offset = (index + 1) * widget.spacing * _scaleAnimation.value;
              
              return Transform.translate(
                offset: Offset(0, -offset),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _scaleAnimation.value,
                    child: FloatingActionButton.small(
                      heroTag: 'speed_dial_$index',
                      onPressed: () {
                        action.onPressed();
                        _toggle();
                      },
                      backgroundColor: action.backgroundColor,
                      child: Icon(action.icon),
                      tooltip: action.label,
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
        
        // Main FAB
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2 * math.pi,
              child: GestureDetector(
                onTap: _toggle,
                child: widget.mainFAB,
              ),
            );
          },
        ),
      ],
    );
  }
}

class SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
  });
}