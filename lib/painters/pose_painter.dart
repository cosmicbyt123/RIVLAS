import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/multi_pose_tracker.dart';

class PosePainter extends CustomPainter {
  final List<PlayerTrack> players;
  final Size imageSize;
  final bool isFrontCamera;

  PosePainter({
    required this.players,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    for (final player in players) {
      final pose = player.currentPose;
      if (pose == null) continue;

      final Color baseColor = player.themeColor;
      final bool isGoodForm = player.isGoodForm;
      final Color strokeColor = isGoodForm ? baseColor : const Color(0xFFFF385C);

      // Skeletons Paints
      final activeLinePaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.85)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final glowLinePaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.30)
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final dimLinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final jointCenterPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final jointRingPaint = Paint()
        ..color = strokeColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      final jointGlowPaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;

      // 1. Draw glowing lines & crisp inner lines
      _drawConnections(canvas, size, pose, glowLinePaint, dimLinePaint);
      _drawConnections(canvas, size, pose, activeLinePaint, dimLinePaint);

      // 2. Draw styled joint circles
      _drawDots(canvas, size, pose, jointCenterPaint, jointRingPaint, jointGlowPaint);

      // 3. Draw Floating AR Nametag only in Multiplayer mode (2+ people in frame)
      final activeCount = players.where((p) => p.currentPose != null).length;
      if (activeCount >= 2) {
        _drawFloatingNametag(canvas, size, player, pose, strokeColor);
      }
    }
  }

  void _drawConnections(Canvas canvas, Size size, Pose pose, Paint active, Paint dim) {
    // Arms (Primary push-up chain)
    _line(canvas, size, pose, active, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    _line(canvas, size, pose, active, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    _line(canvas, size, pose, active, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    _line(canvas, size, pose, active, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Shoulders
    _line(canvas, size, pose, active, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);

    // Torso / Spine
    _line(canvas, size, pose, active, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    _line(canvas, size, pose, active, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    _line(canvas, size, pose, active, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Legs
    _line(canvas, size, pose, dim, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    _line(canvas, size, pose, dim, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    _line(canvas, size, pose, dim, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    _line(canvas, size, pose, dim, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Head
    _line(canvas, size, pose, dim, PoseLandmarkType.nose, PoseLandmarkType.leftShoulder);
    _line(canvas, size, pose, dim, PoseLandmarkType.nose, PoseLandmarkType.rightShoulder);
  }

  void _drawDots(Canvas canvas, Size size, Pose pose, Paint center, Paint ring, Paint glow) {
    final landmarks = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    for (final type in landmarks) {
      final landmark = pose.landmarks[type];
      if (landmark == null || landmark.likelihood < 0.35) continue;
      final point = _translate(landmark.x, landmark.y, size);

      canvas.drawCircle(point, 8.5, glow);
      canvas.drawCircle(point, 5.0, ring);
      canvas.drawCircle(point, 2.5, center);
    }
  }

  void _line(Canvas canvas, Size size, Pose pose, Paint paint,
      PoseLandmarkType a, PoseLandmarkType b) {
    final lA = pose.landmarks[a];
    final lB = pose.landmarks[b];
    if (lA == null || lB == null) return;
    if (lA.likelihood < 0.35 || lB.likelihood < 0.35) return;

    canvas.drawLine(
      _translate(lA.x, lA.y, size),
      _translate(lB.x, lB.y, size),
      paint,
    );
  }

  /// Draw floating holographic name badge above athlete's head
  void _drawFloatingNametag(Canvas canvas, Size size, PlayerTrack player, Pose pose, Color themeColor) {
    final headLandmark = pose.landmarks[PoseLandmarkType.nose] ?? 
                         pose.landmarks[PoseLandmarkType.leftShoulder] ??
                         pose.landmarks[PoseLandmarkType.rightShoulder];
    if (headLandmark == null || headLandmark.likelihood < 0.30) return;

    final headPos = _translate(headLandmark.x, headLandmark.y, size);
    final tagCenter = Offset(headPos.dx, headPos.dy - 38);

    // Text configuration
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '${player.name}  ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        TextSpan(
          text: '• ${player.repCount} Reps',
          style: TextStyle(
            color: themeColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final pillWidth = textPainter.width + 24;
    final pillHeight = 26.0;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: tagCenter, width: pillWidth, height: pillHeight),
      const Radius.circular(13),
    );

    // Background pill
    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.65)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(pillRect, bgPaint);
    canvas.drawRRect(pillRect, borderPaint);

    // Render text
    textPainter.paint(
      canvas,
      Offset(tagCenter.dx - (textPainter.width / 2), tagCenter.dy - (textPainter.height / 2)),
    );
  }

  /// Exact BoxFit.cover screen coordinate transformation
  Offset _translate(double x, double y, Size size) {
    final double scale = max(size.width / imageSize.width, size.height / imageSize.height);
    final double scaledWidth = imageSize.width * scale;
    final double scaledHeight = imageSize.height * scale;
    final double offsetX = (size.width - scaledWidth) / 2;
    final double offsetY = (size.height - scaledHeight) / 2;

    final double effectiveX = isFrontCamera ? (imageSize.width - x) : x;

    return Offset(
      offsetX + (effectiveX * scale),
      offsetY + (y * scale),
    );
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}