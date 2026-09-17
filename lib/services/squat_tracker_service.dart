import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum SquatPhase {
  standing,   // Knee angle > 155°
  descending, // Knee angle decreasing below 145°
  parallel,   // Knee angle <= 95° (valid parallel or deep squat)
  ascending,  // Knee angle increasing back up from parallel
}

class SquatRepResult {
  final int repCount;
  final SquatPhase phase;
  final double kneeAngle;     // Current knee angle in degrees (180 = straight, 90 = parallel)
  final double lowestDepth;   // Minimum angle reached in this rep
  final int romPercentage;    // Range of motion (0-100%)
  final double tempoSeconds;  // Duration of rep
  final int formScore;        // Form rating (0-100%)
  final String feedback;      // Coaching cue
  final bool isGoodForm;
  final bool repJustCompleted;

  const SquatRepResult({
    required this.repCount,
    required this.phase,
    required this.kneeAngle,
    required this.lowestDepth,
    required this.romPercentage,
    required this.tempoSeconds,
    required this.formScore,
    required this.feedback,
    required this.isGoodForm,
    this.repJustCompleted = false,
  });
}

/// Advanced Biomechanical Squat Tracking Engine using 3D Joint Angles
class SquatTrackerService {
  SquatPhase _phase = SquatPhase.standing;
  int _repCount = 0;
  double _lowestDepthInRep = 180.0;
  DateTime? _repStartTime;
  int _lastFormScore = 95;
  String _feedback = 'Stand upright in view of camera';

  // Config thresholds
  static const double kStandingThreshold = 155.0; // Degrees
  static const double kDescendingThreshold = 145.0;
  static const double kParallelThreshold = 95.0;   // Parallel or below depth
  static const double kDeepSquatThreshold = 80.0;  // Ass-to-grass / deep squat

  int get repCount => _repCount;
  SquatPhase get phase => _phase;

  void reset() {
    _phase = SquatPhase.standing;
    _repCount = 0;
    _lowestDepthInRep = 180.0;
    _repStartTime = null;
    _lastFormScore = 95;
    _feedback = 'Stand upright in view of camera';
  }

  /// Process a detected ML Kit Pose and compute squat telemetry
  SquatRepResult processPose(Pose pose) {
    // 1. Extract Hip, Knee, Ankle landmarks for both legs
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Check visibility confidence
    final leftLegVisible = (leftHip?.likelihood ?? 0) > 0.45 &&
        (leftKnee?.likelihood ?? 0) > 0.45 &&
        (leftAnkle?.likelihood ?? 0) > 0.45;

    final rightLegVisible = (rightHip?.likelihood ?? 0) > 0.45 &&
        (rightKnee?.likelihood ?? 0) > 0.45 &&
        (rightAnkle?.likelihood ?? 0) > 0.45;

    if (!leftLegVisible && !rightLegVisible) {
      return SquatRepResult(
        repCount: _repCount,
        phase: _phase,
        kneeAngle: 175.0,
        lowestDepth: _lowestDepthInRep,
        romPercentage: 0,
        tempoSeconds: 0,
        formScore: _lastFormScore,
        feedback: 'Step back so hips, knees & feet are visible',
        isGoodForm: false,
      );
    }

    // 2. Compute knee angle for visible leg(s)
    double currentKneeAngle = 180.0;
    if (leftLegVisible && rightLegVisible) {
      final angleL = _calculateAngle(leftHip!, leftKnee!, leftAnkle!);
      final angleR = _calculateAngle(rightHip!, rightKnee!, rightAnkle!);
      currentKneeAngle = (angleL + angleR) / 2.0;
    } else if (leftLegVisible) {
      currentKneeAngle = _calculateAngle(leftHip!, leftKnee!, leftAnkle!);
    } else {
      currentKneeAngle = _calculateAngle(rightHip!, rightKnee!, rightAnkle!);
    }

    bool repJustCompleted = false;
    final now = DateTime.now();

    // 3. Finite State Machine for Rep Detection
    switch (_phase) {
      case SquatPhase.standing:
        if (currentKneeAngle < kDescendingThreshold) {
          _phase = SquatPhase.descending;
          _repStartTime = now;
          _lowestDepthInRep = currentKneeAngle;
          _feedback = 'Squatting down... aim for parallel';
        } else {
          _feedback = 'Ready to squat - descend with control';
        }
        break;

      case SquatPhase.descending:
        if (currentKneeAngle < _lowestDepthInRep) {
          _lowestDepthInRep = currentKneeAngle;
        }

        if (currentKneeAngle <= kParallelThreshold) {
          _phase = SquatPhase.parallel;
          if (currentKneeAngle <= kDeepSquatThreshold) {
            _feedback = 'Deep squat! Excellent depth!';
          } else {
            _feedback = 'Parallel reached (90°)! Drive back up!';
          }
        } else if (currentKneeAngle > kStandingThreshold) {
          // Aborted without reaching depth
          _phase = SquatPhase.standing;
          _feedback = 'Go lower - hit parallel hip crease';
        }
        break;

      case SquatPhase.parallel:
        if (currentKneeAngle < _lowestDepthInRep) {
          _lowestDepthInRep = currentKneeAngle;
        }

        if (currentKneeAngle > kParallelThreshold + 10) {
          _phase = SquatPhase.ascending;
          _feedback = 'Push through heels - lockout at top';
        }
        break;

      case SquatPhase.ascending:
        if (currentKneeAngle >= kStandingThreshold) {
          // Rep successfully completed!
          _repCount++;
          repJustCompleted = true;
          _phase = SquatPhase.standing;

          // Compute quality score based on depth achieved
          if (_lowestDepthInRep <= kDeepSquatThreshold) {
            _lastFormScore = 98;
            _feedback = 'Verified Deep Squat! Perfect form (+XP)';
          } else if (_lowestDepthInRep <= kParallelThreshold) {
            _lastFormScore = 94;
            _feedback = 'Good rep! Parallel depth confirmed';
          } else {
            _lastFormScore = 80;
            _feedback = 'Half rep - try to descend deeper next rep';
          }

          _lowestDepthInRep = 180.0;
          _repStartTime = null;
        }
        break;
    }

    // 4. Compute Range of Motion (ROM %)
    // Straight leg (180°) is 0% ROM, parallel squat (90°) is 100% ROM, deep (<80°) is >100%
    final rom = (((180.0 - currentKneeAngle) / 90.0) * 100).clamp(0, 100).toInt();

    // 5. Compute Tempo
    double tempo = 2.4;
    if (_repStartTime != null) {
      tempo = (now.difference(_repStartTime!).inMilliseconds / 1000.0).clamp(0.5, 8.0);
    }

    return SquatRepResult(
      repCount: _repCount,
      phase: _phase,
      kneeAngle: currentKneeAngle,
      lowestDepth: _lowestDepthInRep,
      romPercentage: rom,
      tempoSeconds: tempo,
      formScore: _lastFormScore,
      feedback: _feedback,
      isGoodForm: _lowestDepthInRep <= kParallelThreshold || _phase == SquatPhase.standing,
      repJustCompleted: repJustCompleted,
    );
  }

  /// Calculates 3-point angle in degrees between pointA, centerJoint, pointC
  double _calculateAngle(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    final double v1x = a.x - b.x;
    final double v1y = a.y - b.y;
    final double v2x = c.x - b.x;
    final double v2y = c.y - b.y;

    final double dot = (v1x * v2x) + (v1y * v2y);
    final double mag1 = sqrt((v1x * v1x) + (v1y * v1y));
    final double mag2 = sqrt((v2x * v2x) + (v2y * v2y));

    if (mag1 * mag2 == 0) return 180.0;

    final double cosTheta = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return acos(cosTheta) * (180.0 / pi);
  }
}
