import 'dart:math';

import 'package:flutter/material.dart';

/// Mood states for the animated character.
enum CharacterMood { angry, neutral, happy, confused, talking }

/// A minimalist animated character face widget that changes expression based on mood.
///
/// Uses [CustomPainter] for face drawing with smooth transitions between moods
/// and a subtle idle bounce animation.
class AnimatedCharacter extends StatefulWidget {
  final CharacterMood mood;
  final double size;

  const AnimatedCharacter({
    super.key,
    this.mood = CharacterMood.neutral,
    this.size = 120,
  });

  @override
  State<AnimatedCharacter> createState() => _AnimatedCharacterState();
}

class _AnimatedCharacterState extends State<AnimatedCharacter>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _moodTransitionController;
  late AnimationController _talkController;
  late Animation<double> _breathAnimation;
  late Animation<double> _moodAnimation;
  late Animation<double> _talkAnimation;

  CharacterMood _previousMood = CharacterMood.neutral;

  @override
  void initState() {
    super.initState();

    // Idle breathing/bounce animation
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Mood transition animation
    _moodTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _moodAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _moodTransitionController, curve: Curves.easeInOut),
    );
    _moodTransitionController.value = 1.0;

    // Talking mouth animation
    _talkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _talkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _talkController, curve: Curves.easeInOut),
    );

    if (widget.mood == CharacterMood.talking) {
      _talkController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _previousMood = oldWidget.mood;
      _moodTransitionController.forward(from: 0.0);

      if (widget.mood == CharacterMood.talking) {
        _talkController.repeat(reverse: true);
      } else {
        _talkController.stop();
        _talkController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _moodTransitionController.dispose();
    _talkController.dispose();
    super.dispose();
  }

  Color _getFaceTint(CharacterMood mood) {
    switch (mood) {
      case CharacterMood.angry:
        return const Color(0xFFFFF0F0);
      case CharacterMood.happy:
        return const Color(0xFFF0FFF4);
      case CharacterMood.confused:
        return const Color(0xFFFFFDE8);
      case CharacterMood.neutral:
      case CharacterMood.talking:
        return const Color(0xFFF7F3F2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_breathAnimation, _moodAnimation, _talkAnimation]),
      builder: (context, child) {
        final breathOffset = _breathAnimation.value * 3.0;
        final currentTint = ColorTween(
          begin: _getFaceTint(_previousMood),
          end: _getFaceTint(widget.mood),
        ).evaluate(_moodAnimation)!;

        return Transform.translate(
          offset: Offset(0, -breathOffset),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _CharacterFacePainter(
                mood: widget.mood,
                previousMood: _previousMood,
                moodProgress: _moodAnimation.value,
                talkProgress: _talkAnimation.value,
                faceTint: currentTint,
              ),
              size: Size(widget.size, widget.size),
            ),
          ),
        );
      },
    );
  }
}

class _CharacterFacePainter extends CustomPainter {
  final CharacterMood mood;
  final CharacterMood previousMood;
  final double moodProgress;
  final double talkProgress;
  final Color faceTint;

  _CharacterFacePainter({
    required this.mood,
    required this.previousMood,
    required this.moodProgress,
    required this.talkProgress,
    required this.faceTint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    _drawFace(canvas, center, radius);
    _drawEyes(canvas, center, radius);
    _drawEyebrows(canvas, center, radius);
    _drawMouth(canvas, center, radius);
  }

  void _drawFace(Canvas canvas, Offset center, double radius) {
    // Face fill
    final facePaint = Paint()
      ..color = faceTint
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, facePaint);

    // Face border
    final borderPaint = Paint()
      ..color = const Color(0xFFD4CFCD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawEyes(Canvas canvas, Offset center, double radius) {
    final eyePaint = Paint()
      ..color = const Color(0xFF1C1B1B)
      ..style = PaintingStyle.fill;

    final leftEyeCenter = Offset(center.dx - radius * 0.3, center.dy - radius * 0.15);
    final rightEyeCenter = Offset(center.dx + radius * 0.3, center.dy - radius * 0.15);

    final eyeWidth = radius * 0.12;
    final eyeHeight = radius * 0.12;

    switch (mood) {
      case CharacterMood.angry:
        // Half-closed eyes (narrow ellipses)
        final angryEyeHeight = eyeHeight * 0.5;
        canvas.drawOval(
          Rect.fromCenter(center: leftEyeCenter, width: eyeWidth * 2, height: angryEyeHeight * 2),
          eyePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: rightEyeCenter, width: eyeWidth * 2, height: angryEyeHeight * 2),
          eyePaint,
        );
        break;
      case CharacterMood.confused:
        // Wide eyes (larger circles)
        final confusedEyeSize = eyeWidth * 1.4;
        canvas.drawCircle(leftEyeCenter, confusedEyeSize, eyePaint);
        canvas.drawCircle(rightEyeCenter, confusedEyeSize, eyePaint);
        break;
      case CharacterMood.happy:
        // Happy squinted eyes (arcs)
        final happyEyePaint = Paint()
          ..color = const Color(0xFF1C1B1B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;
        final arcWidth = radius * 0.22;
        final arcHeight = radius * 0.1;
        canvas.drawArc(
          Rect.fromCenter(center: leftEyeCenter, width: arcWidth, height: arcHeight),
          pi, pi, false, happyEyePaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: rightEyeCenter, width: arcWidth, height: arcHeight),
          pi, pi, false, happyEyePaint,
        );
        break;
      case CharacterMood.neutral:
      case CharacterMood.talking:
        // Normal round eyes
        canvas.drawCircle(leftEyeCenter, eyeWidth, eyePaint);
        canvas.drawCircle(rightEyeCenter, eyeWidth, eyePaint);
        break;
    }
  }

  void _drawEyebrows(Canvas canvas, Offset center, double radius) {
    final browPaint = Paint()
      ..color = const Color(0xFF1C1B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final leftBrowStart = Offset(center.dx - radius * 0.42, center.dy - radius * 0.35);
    final leftBrowEnd = Offset(center.dx - radius * 0.18, center.dy - radius * 0.35);
    final rightBrowStart = Offset(center.dx + radius * 0.18, center.dy - radius * 0.35);
    final rightBrowEnd = Offset(center.dx + radius * 0.42, center.dy - radius * 0.35);

    switch (mood) {
      case CharacterMood.angry:
        // V-shaped angry eyebrows (angled down toward center)
        final leftAngryStart = Offset(leftBrowStart.dx, leftBrowStart.dy - radius * 0.05);
        final leftAngryEnd = Offset(leftBrowEnd.dx, leftBrowEnd.dy + radius * 0.08);
        final rightAngryStart = Offset(rightBrowStart.dx, rightBrowStart.dy + radius * 0.08);
        final rightAngryEnd = Offset(rightBrowEnd.dx, rightBrowEnd.dy - radius * 0.05);
        canvas.drawLine(leftAngryStart, leftAngryEnd, browPaint);
        canvas.drawLine(rightAngryStart, rightAngryEnd, browPaint);
        break;
      case CharacterMood.confused:
        // One raised eyebrow (left raised, right normal)
        final leftRaisedStart = Offset(leftBrowStart.dx, leftBrowStart.dy - radius * 0.12);
        final leftRaisedEnd = Offset(leftBrowEnd.dx, leftBrowEnd.dy - radius * 0.06);
        canvas.drawLine(leftRaisedStart, leftRaisedEnd, browPaint);
        canvas.drawLine(rightBrowStart, rightBrowEnd, browPaint);
        break;
      case CharacterMood.happy:
        // Slightly arched eyebrows
        final leftArchStart = Offset(leftBrowStart.dx, leftBrowStart.dy);
        final leftArchEnd = Offset(leftBrowEnd.dx, leftBrowEnd.dy);
        final leftArchMid = Offset(
          (leftArchStart.dx + leftArchEnd.dx) / 2,
          leftArchStart.dy - radius * 0.06,
        );
        final leftPath = Path()
          ..moveTo(leftArchStart.dx, leftArchStart.dy)
          ..quadraticBezierTo(leftArchMid.dx, leftArchMid.dy, leftArchEnd.dx, leftArchEnd.dy);
        canvas.drawPath(leftPath, browPaint);

        final rightArchStart = Offset(rightBrowStart.dx, rightBrowStart.dy);
        final rightArchEnd = Offset(rightBrowEnd.dx, rightBrowEnd.dy);
        final rightArchMid = Offset(
          (rightArchStart.dx + rightArchEnd.dx) / 2,
          rightArchStart.dy - radius * 0.06,
        );
        final rightPath = Path()
          ..moveTo(rightArchStart.dx, rightArchStart.dy)
          ..quadraticBezierTo(rightArchMid.dx, rightArchMid.dy, rightArchEnd.dx, rightArchEnd.dy);
        canvas.drawPath(rightPath, browPaint);
        break;
      case CharacterMood.neutral:
      case CharacterMood.talking:
        // Straight eyebrows
        canvas.drawLine(leftBrowStart, leftBrowEnd, browPaint);
        canvas.drawLine(rightBrowStart, rightBrowEnd, browPaint);
        break;
    }
  }

  void _drawMouth(Canvas canvas, Offset center, double radius) {
    final mouthPaint = Paint()
      ..color = const Color(0xFF1C1B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final mouthCenter = Offset(center.dx, center.dy + radius * 0.35);
    final mouthWidth = radius * 0.4;

    switch (mood) {
      case CharacterMood.angry:
        // Frown (downward curve - ends higher, control point lower)
        final path = Path()
          ..moveTo(mouthCenter.dx - mouthWidth, mouthCenter.dy + radius * 0.02)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy - radius * 0.18,
            mouthCenter.dx + mouthWidth,
            mouthCenter.dy + radius * 0.02,
          );
        canvas.drawPath(path, mouthPaint);
        break;
      case CharacterMood.happy:
        // Smile (upward curve - ends lower, control point higher)
        final path = Path()
          ..moveTo(mouthCenter.dx - mouthWidth, mouthCenter.dy - radius * 0.05)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy + radius * 0.15,
            mouthCenter.dx + mouthWidth,
            mouthCenter.dy - radius * 0.05,
          );
        canvas.drawPath(path, mouthPaint);
        break;
      case CharacterMood.confused:
        // Wavy mouth (S-curve)
        final path = Path()
          ..moveTo(mouthCenter.dx - mouthWidth, mouthCenter.dy)
          ..cubicTo(
            mouthCenter.dx - mouthWidth * 0.3, mouthCenter.dy - radius * 0.1,
            mouthCenter.dx + mouthWidth * 0.3, mouthCenter.dy + radius * 0.1,
            mouthCenter.dx + mouthWidth, mouthCenter.dy,
          );
        canvas.drawPath(path, mouthPaint);
        break;
      case CharacterMood.talking:
        // Open oval mouth (animated open/close)
        final ovalHeight = radius * 0.12 + (radius * 0.1 * talkProgress);
        final ovalWidth = radius * 0.2 + (radius * 0.05 * talkProgress);
        final ovalPaint = Paint()
          ..color = const Color(0xFF1C1B1B)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(
            center: mouthCenter,
            width: ovalWidth * 2,
            height: ovalHeight * 2,
          ),
          ovalPaint,
        );
        break;
      case CharacterMood.neutral:
        // Flat straight line
        canvas.drawLine(
          Offset(mouthCenter.dx - mouthWidth, mouthCenter.dy),
          Offset(mouthCenter.dx + mouthWidth, mouthCenter.dy),
          mouthPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CharacterFacePainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.moodProgress != moodProgress ||
        oldDelegate.talkProgress != talkProgress ||
        oldDelegate.faceTint != faceTint;
  }
}
