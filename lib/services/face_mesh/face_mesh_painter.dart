import 'dart:ui';

import 'package:flutter/material.dart';

class FaceMeshPainter extends CustomPainter {
  final List<Offset> points;
  final double ratio;

  FaceMeshPainter({
    required this.points,
    required this.ratio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint1 = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2;

    canvas.drawPoints(PointMode.points,
        points.map((point) => point * ratio).toList(), paint1);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}