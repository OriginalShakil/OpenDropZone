import 'package:flutter/material.dart';

class PopoverClipper extends CustomClipper<Path> {
  final double arrowOffset;
  final double arrowWidth;
  final double arrowHeight;
  final double cornerRadius;

  PopoverClipper({
    required this.arrowOffset,
    this.arrowWidth = 20.0,
    this.arrowHeight = 10.0,
    this.cornerRadius = 16.0,
  });

  @override
  Path getClip(Size size) {
    return buildPopoverPath(
      size: size,
      arrowOffset: arrowOffset,
      arrowWidth: arrowWidth,
      arrowHeight: arrowHeight,
      cornerRadius: cornerRadius,
    );
  }

  @override
  bool shouldReclip(covariant PopoverClipper oldClipper) {
    return oldClipper.arrowOffset != arrowOffset ||
        oldClipper.arrowWidth != arrowWidth ||
        oldClipper.arrowHeight != arrowHeight ||
        oldClipper.cornerRadius != cornerRadius;
  }

  static Path buildPopoverPath({
    required Size size,
    required double arrowOffset,
    double arrowWidth = 20.0,
    double arrowHeight = 10.0,
    double cornerRadius = 16.0,
  }) {
    final path = Path();
    final top = arrowHeight;
    const left = 0.0;
    final right = size.width;
    final bottom = size.height;

    final clampedArrowX = arrowOffset.clamp(
      left + cornerRadius + 14.0,
      right - cornerRadius - 14.0,
    );
    final halfArrowW = arrowWidth / 2;

    // Start at top-left corner after radius
    path.moveTo(left, top + cornerRadius);

    // Top-left arc
    path.arcToPoint(
      Offset(left + cornerRadius, top),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Line to arrow left base
    path.lineTo(clampedArrowX - halfArrowW, top);

    // Left flare into arrow
    path.cubicTo(
      clampedArrowX - halfArrowW * 0.45,
      top,
      clampedArrowX - 2.8,
      1.5,
      clampedArrowX,
      0.5,
    );
    // Right flare down from arrow
    path.cubicTo(
      clampedArrowX + 2.8,
      1.5,
      clampedArrowX + halfArrowW * 0.45,
      top,
      clampedArrowX + halfArrowW,
      top,
    );

    // Line to top-right corner
    path.lineTo(right - cornerRadius, top);

    // Top-right arc
    path.arcToPoint(
      Offset(right, top + cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Right edge
    path.lineTo(right, bottom - cornerRadius);

    // Bottom-right arc
    path.arcToPoint(
      Offset(right - cornerRadius, bottom),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Bottom edge
    path.lineTo(left + cornerRadius, bottom);

    // Bottom-left arc
    path.arcToPoint(
      Offset(left, bottom - cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );

    // Close path on left edge
    path.close();
    return path;
  }
}

class PopoverBorderPainter extends CustomPainter {
  final double arrowOffset;
  final double arrowWidth;
  final double arrowHeight;
  final double cornerRadius;
  final Color borderColor;
  final double borderWidth;

  PopoverBorderPainter({
    required this.arrowOffset,
    this.arrowWidth = 20.0,
    this.arrowHeight = 10.0,
    this.cornerRadius = 16.0,
    required this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = PopoverClipper.buildPopoverPath(
      size: size,
      arrowOffset: arrowOffset,
      arrowWidth: arrowWidth,
      arrowHeight: arrowHeight,
      cornerRadius: cornerRadius,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant PopoverBorderPainter oldDelegate) {
    return oldDelegate.arrowOffset != arrowOffset ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
