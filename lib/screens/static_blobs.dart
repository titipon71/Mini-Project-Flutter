import 'package:flutter/material.dart';
import 'dart:math';

class StaticBlobs extends StatelessWidget {
  const StaticBlobs({
    super.key,
    this.count = 24,
    this.areaWidth,
    this.areaHeight = 1000,
    this.minSize = 30,
    this.maxSize = 110,
    required this.colors,
  });

  final int count;
  final double? areaWidth;
  final double areaHeight;
  final double minSize;
  final double maxSize;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = areaWidth ?? constraints.maxWidth;
        final rnd = Random(42); // seed for deterministic layout
        final blobs = List.generate(count, (i) {
          final size = rnd.nextDouble() * (maxSize - minSize) + minSize;
          final left = rnd.nextDouble() * (w - size);
          final top = rnd.nextDouble() * (areaHeight - size);
          final color = colors[rnd.nextInt(colors.length)];
          return Positioned(
            top: top,
            left: left,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(.85), color],
                  center: Alignment.topLeft,
                  radius: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(.25),
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          );
        });
        return Stack(clipBehavior: Clip.none, children: blobs);
      },
    );
  }
}