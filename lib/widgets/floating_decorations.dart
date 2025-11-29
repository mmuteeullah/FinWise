import 'package:flutter/material.dart';

class FloatingDecorations extends StatefulWidget {
  final double scrollOffset;

  const FloatingDecorations({
    Key? key,
    required this.scrollOffset,
  }) : super(key: key);

  @override
  State<FloatingDecorations> createState() => _FloatingDecorationsState();
}

class _FloatingDecorationsState extends State<FloatingDecorations>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      5,
      (index) => AnimationController(
        duration: Duration(seconds: 3 + index),
        vsync: this,
      )..repeat(reverse: true),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: -20, end: 20).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Large circle top right
        Positioned(
          top: 50 - (widget.scrollOffset * 0.3),
          right: -50,
          child: AnimatedBuilder(
            animation: _animations[0],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animations[0].value),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Medium circle left
        Positioned(
          top: 150 - (widget.scrollOffset * 0.5),
          left: -30,
          child: AnimatedBuilder(
            animation: _animations[1],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animations[1].value, 0),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Small circle top center
        Positioned(
          top: 80 - (widget.scrollOffset * 0.2),
          left: size.width * 0.4,
          child: AnimatedBuilder(
            animation: _animations[2],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animations[2].value, _animations[2].value),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Tiny circle right
        Positioned(
          top: 200 - (widget.scrollOffset * 0.4),
          right: 40,
          child: AnimatedBuilder(
            animation: _animations[3],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animations[3].value),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Medium circle bottom left
        Positioned(
          top: 300 - (widget.scrollOffset * 0.6),
          left: 20,
          child: AnimatedBuilder(
            animation: _animations[4],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_animations[4].value * 0.5, _animations[4].value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
