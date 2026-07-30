import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Custom painted nav icons matching the app's icon style.
/// Each painter draws the inactive (outline) version.
/// Active state is handled by changing the color to [Color(0xff2B1564)].

// ─────────────────────────────────────────────
// 1. HOME / FEED  — compass diamond shape
// ─────────────────────────────────────────────
class HomeNavIcon extends StatelessWidget {
  final Color color;
  final double size;
  const HomeNavIcon({super.key, required this.color, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HomePainter(color: color),
    );
  }
}

class _HomePainter extends CustomPainter {
  final Color color;
  _HomePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    // Outer circle
    canvas.drawCircle(center, r, paint);

    // Inner diamond / compass shape
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final dr = size.width * 0.16;
    final path = Path()
      ..moveTo(center.dx, center.dy - dr * 1.5) // top
      ..lineTo(center.dx + dr, center.dy)         // right
      ..lineTo(center.dx, center.dy + dr * 1.5)  // bottom
      ..lineTo(center.dx - dr, center.dy)         // left
      ..close();
    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(_HomePainter old) => old.color != color;
}

// ─────────────────────────────────────────────
// 2. MAP — location pin with inner ring
// ─────────────────────────────────────────────
class MapNavIcon extends StatelessWidget {
  final Color color;
  final double size;
  const MapNavIcon({super.key, required this.color, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MapPainter(color: color),
    );
  }
}

class _MapPainter extends CustomPainter {
  final Color color;
  _MapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final headR = size.width * 0.28;
    final headCy = size.height * 0.35;

    // Outer teardrop pin shape
    final path = Path();
    // Top arc (circle head)
    path.addArc(
      Rect.fromCircle(center: Offset(cx, headCy), radius: headR),
      math.pi,      // start: left
      -math.pi,     // sweep: full circle going left (counter-clockwise top half)
    );
    // Actually draw full head circle then add tail
    final headPath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(cx, headCy), radius: headR),
        -math.pi * 0.72,
        math.pi * 1.44,
      )
      ..lineTo(cx, size.height * 0.88)
      ..close();
    canvas.drawPath(headPath, paint);

    // Inner dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, headCy), size.width * 0.09, dotPaint);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.color != color;
}

// ─────────────────────────────────────────────
// 3. EXPLORE — binoculars  (uses asset if available, falls back to painter)
// ─────────────────────────────────────────────
class ExploreNavIcon extends StatelessWidget {
  final Color color;
  final double size;
  const ExploreNavIcon({super.key, required this.color, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return ImageIcon(
      const AssetImage('assets/icons/nav_explore.png'),
      size: size,
      color: color,
    );
  }
}

// ─────────────────────────────────────────────
// 4. PROFILE — person silhouette in circle
// ─────────────────────────────────────────────
class ProfileNavIcon extends StatelessWidget {
  final Color color;
  final double size;
  const ProfileNavIcon({super.key, required this.color, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ProfilePainter(color: color),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  final Color color;
  _ProfilePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Head circle
    final headR = size.width * 0.13;
    final headCy = cy - size.height * 0.10;
    canvas.drawCircle(Offset(cx, headCy), headR, paint);

    // Shoulders arc
    final shoulderPaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final shoulderPath = Path()
      ..moveTo(cx - r * 0.62, cy + r * 0.55)
      ..quadraticBezierTo(
        cx - r * 0.55, cy + r * 0.10,
        cx, cy + r * 0.07,
      )
      ..quadraticBezierTo(
        cx + r * 0.55, cy + r * 0.10,
        cx + r * 0.62, cy + r * 0.55,
      );
    canvas.drawPath(shoulderPath, shoulderPaint);
  }

  @override
  bool shouldRepaint(_ProfilePainter old) => old.color != color;
}
