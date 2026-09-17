import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Camera setup modes
enum TrackingMode {
  sideProfile,  // Standard 3-point kinematic angle calculation (Shoulder-Elbow-Wrist)
  frontFloor,   // Zero-setup floor compression ratio (Chest-to-Wrist vertical distance)
  selfieCamera, // Wall-lean face tracking via normalized nose Y-position
}

/// Push-up rep lifecycle finite-state machine
enum RepState {
  waitingForPlank, // Waiting for athlete to establish high plank lockout (prevents false reps from lying down)
  top,             // Locked out at top position, ready to descend
  descending,      // Moving downwards towards floor
  bottom,          // Hit required full depth threshold
  ascending,       // Pushing back up towards top lockout
}

/// Biomechanical evaluation of plank hold posture
class PlankEvaluation {
  final bool isPlank;
  final String orientation; // 'Side View', 'Front View', 'Upright', 'None'
  final int formScore;      // 0–100% quality score
  final String feedback;    // Real-time coaching cue

  const PlankEvaluation({
    required this.isPlank,
    required this.orientation,
    required this.formScore,
    required this.feedback,
  });
}

/// Biomechanical analysis results returned for each processed video frame
class FrameAnalysis {
  final TrackingMode trackingMode;
  final RepState repState;
  final int repCount;
  final int? formScore;       // 0–100% quality score
  final String feedback;      // Real-time coaching cue
  final bool isGoodForm;      // False if hips sag, pike, or half-rep attempted
  final double currentAngle;  // Elbow angle in degrees (or normalized compression %)
  final Pose pose;
  final Size imageSize;
  final bool repJustCompleted;// True only on the exact frame a rep finishes
  final bool isPlank;         // True if user is actively holding a confirmed plank
  final String? plankOrientation; // 'Side View', 'Front View', or 'Upright'
  final int? plankFormScore;  // 0-100% plank posture quality score
  final String? plankFeedback; // Dedicated coaching cue for plank

  FrameAnalysis({
    required this.trackingMode,
    required this.repState,
    required this.repCount,
    this.formScore,
    required this.feedback,
    required this.isGoodForm,
    required this.currentAngle,
    required this.pose,
    required this.imageSize,
    this.repJustCompleted = false,
    this.isPlank = false,
    this.plankOrientation,
    this.plankFormScore,
    this.plankFeedback,
  });

  FrameAnalysis copyWith({
    TrackingMode? trackingMode,
    RepState? repState,
    int? repCount,
    int? formScore,
    String? feedback,
    bool? isGoodForm,
    double? currentAngle,
    Pose? pose,
    Size? imageSize,
    bool? repJustCompleted,
    bool? isPlank,
    String? plankOrientation,
    int? plankFormScore,
    String? plankFeedback,
  }) {
    return FrameAnalysis(
      trackingMode: trackingMode ?? this.trackingMode,
      repState: repState ?? this.repState,
      repCount: repCount ?? this.repCount,
      formScore: formScore ?? this.formScore,
      feedback: feedback ?? this.feedback,
      isGoodForm: isGoodForm ?? this.isGoodForm,
      currentAngle: currentAngle ?? this.currentAngle,
      pose: pose ?? this.pose,
      imageSize: imageSize ?? this.imageSize,
      repJustCompleted: repJustCompleted ?? this.repJustCompleted,
      isPlank: isPlank ?? this.isPlank,
      plankOrientation: plankOrientation ?? this.plankOrientation,
      plankFormScore: plankFormScore ?? this.plankFormScore,
      plankFeedback: plankFeedback ?? this.plankFeedback,
    );
  }
}

/// Continuous Biomechanical Push-up Tracking Engine
/// Combines scale-invariant kinematics with robust peak-to-valley inflection detection.
/// Never gets stuck, tracks smoothly at any camera angle, and strictly evaluates full vs half reps.
class PoseService {
  TrackingMode _mode = TrackingMode.sideProfile;
  int _repCount = 0;
  RepState _state = RepState.waitingForPlank;

  // Exponential Moving Average (EMA) smoothing buffers
  double? _filteredLeftElbowAngle;
  double? _filteredRightElbowAngle;
  double? _filteredCompressionRatio;
  double? _filteredNoseRatio;
  static const double _kEmaAlpha = 0.40;

  // Strict Top Plank Confirmation Buffers (prevents lying on floor from counting)
  int _topPlankHoldFrames = 0;
  static const int _kRequiredTopHoldFrames = 3; // ~100-150ms of stable top plank required

  // Dedicated Plank Workout Hold Buffers
  int _plankHoldFrames = 0;
  static const int _kRequiredPlankHoldFrames = 3; // ~100-150ms of sustained hold required

  // Continuous Stroke Extrema (Peak = Top Lockout, Valley = Deepest Bottom Point)
  double _strokePeakAngle = 0.0;
  double _strokeValleyAngle = 180.0;
  double _strokePeakRatio = 0.0;
  double _strokeValleyRatio = 1.0;
  bool _spineBrokenThisRep = false;
  int? _lastRepFormScore;
  bool _repJustCompleted = false;

  // Thresholds: Side Profile Mode (Elbow Degrees)
  static const double _kSideTopLockout = 148.0;        // Lockout threshold to trigger or complete rep
  static const double _kSideDescendingTrigger = 135.0; // Clean descent initiation
  static const double _kSideValidDepthCutoff = 102.0;  // Must reach at least 102° (ideally <= 90°)
  static const double _kSideMinRangeOfMotion = 38.0;   // Minimum required stroke delta (Peak - Valley >= 38°)

  // Thresholds: Front Floor Mode (Normalized Vertical Compression)
  static const double _kFrontTopLockout = 0.65;        // High plank lockout
  static const double _kFrontDescendingTrigger = 0.55;
  static const double _kFrontValidDepthCutoff = 0.40;  // Full chest-to-floor depth
  static const double _kFrontMinRangeOfMotion = 0.22;  // Minimum compression delta (Peak - Valley >= 0.22)

  // Thresholds: Selfie Camera Mode (Normalized Nose Y Position)
  static const double _kSelfieTopLockout = 0.35;        // Top lockout: nose Y ratio < 0.35
  static const double _kSelfieDescendingTrigger = 0.45; // Descending trigger: nose Y ratio > 0.45
  static const double _kSelfieValidDepthCutoff = 0.65;  // Valid depth: nose Y ratio > 0.65
  static const double _kSelfieMinRangeOfMotion = 0.25;  // Min range of motion: 0.25

  // Minimum confidence for key joint detection
  static const double _kMinConfidence = 0.30;

  // Getters & Setters
  int get repCount => _repCount;
  TrackingMode get mode => _mode;
  bool get isHoldingPlank => _plankHoldFrames >= _kRequiredPlankHoldFrames;
  set mode(TrackingMode newMode) {
    _mode = newMode;
    reset();
  }

  /// Reset session counters
  void reset() {
    _repCount = 0;
    _state = RepState.waitingForPlank;
    _topPlankHoldFrames = 0;
    _plankHoldFrames = 0;
    _filteredLeftElbowAngle = null;
    _filteredRightElbowAngle = null;
    _filteredCompressionRatio = null;
    _filteredNoseRatio = null;
    _strokePeakAngle = 0.0;
    _strokeValleyAngle = 180.0;
    _strokePeakRatio = 0.0;
    _strokeValleyRatio = 1.0;
    _spineBrokenThisRep = false;
    _lastRepFormScore = null;
    _repJustCompleted = false;
  }

  /// Main frame analysis entry point
  FrameAnalysis analyze(Pose pose, Size imageSize) {
    _repJustCompleted = false;

    // Extract landmarks
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    // Check if upper body / torso is visible
    final hasUpperBody = _conf(lShoulder) || _conf(rShoulder) || _conf(nose);

    // Evaluate plank posture with automatic multi-perspective detection
    final plankEval = evaluatePlankPose(pose, imageSize);
    if (plankEval.isPlank) {
      _plankHoldFrames++;
    } else {
      _plankHoldFrames = 0;
    }
    final bool confirmedPlank = _plankHoldFrames >= _kRequiredPlankHoldFrames;

    // Check spine / plank straightness
    final isSpineStraight = _checkPlankAlignment(
      lShoulder, rShoulder, lHip, rHip, lAnkle, rAnkle, imageSize,
    );
    if (!isSpineStraight) {
      _spineBrokenThisRep = true;
    }

    FrameAnalysis baseAnalysis;
    if (!hasUpperBody) {
      baseAnalysis = FrameAnalysis(
        trackingMode: _mode,
        repState: _state,
        repCount: _repCount,
        formScore: _lastRepFormScore,
        feedback: _mode == TrackingMode.selfieCamera ? 'Turn to face camera' : 'Position body in camera view',
        isGoodForm: false,
        currentAngle: 0.0,
        pose: pose,
        imageSize: imageSize,
      );
    } else if (_mode == TrackingMode.sideProfile) {
      baseAnalysis = _processSideProfile(
        pose: pose,
        imageSize: imageSize,
        lShoulder: lShoulder,
        lElbow: lElbow,
        lWrist: lWrist,
        rShoulder: rShoulder,
        rElbow: rElbow,
        rWrist: rWrist,
        lHip: lHip,
        rHip: rHip,
        nose: nose,
        isSpineStraight: isSpineStraight,
      );
    } else if (_mode == TrackingMode.frontFloor) {
      baseAnalysis = _processFrontFloor(
        pose: pose,
        imageSize: imageSize,
        lShoulder: lShoulder,
        rShoulder: rShoulder,
        lElbow: lElbow,
        rElbow: rElbow,
        lWrist: lWrist,
        rWrist: rWrist,
        lHip: lHip,
        rHip: rHip,
        nose: nose,
        isSpineStraight: isSpineStraight,
      );
    } else {
      baseAnalysis = _processSelfieCamera(
        pose: pose,
        imageSize: imageSize,
        nose: nose,
        isSpineStraight: isSpineStraight,
      );
    }

    final String plankFeedback = confirmedPlank
        ? 'Holding Plank Steady ✓ (${plankEval.orientation})'
        : plankEval.feedback;

    return baseAnalysis.copyWith(
      isPlank: confirmedPlank,
      plankOrientation: plankEval.orientation,
      plankFormScore: plankEval.formScore,
      plankFeedback: plankFeedback,
    );
  }

  /// Process Side Profile tracking using Continuous Peak-to-Valley Inflection Engine
  FrameAnalysis _processSideProfile({
    required Pose pose,
    required Size imageSize,
    PoseLandmark? lShoulder,
    PoseLandmark? lElbow,
    PoseLandmark? lWrist,
    PoseLandmark? rShoulder,
    PoseLandmark? rElbow,
    PoseLandmark? rWrist,
    PoseLandmark? lHip,
    PoseLandmark? rHip,
    PoseLandmark? nose,
    required bool isSpineStraight,
  }) {
    double? leftAngle;
    double? rightAngle;

    // 1. Primary Method: 3-Point Kinematic Angle (Shoulder - Elbow - Wrist)
    if (_conf(lShoulder) && _conf(lElbow) && _conf(lWrist)) {
      final rawAngle = _calculateAngle(lShoulder!, lElbow!, lWrist!);
      _filteredLeftElbowAngle = _applyEma(rawAngle, _filteredLeftElbowAngle);
      leftAngle = _filteredLeftElbowAngle;
    } else if (_conf(lShoulder) && _conf(lElbow) && _conf(lHip)) {
      // 2. Fallback Method A: Shoulder-Elbow-Hip Angle (When wrist is off-screen)
      final rawAngle = _calculateAngle(lElbow!, lShoulder!, lHip!);
      // In side profile: Top plank arm is perpendicular to torso (~90° -> 180° lockout)
      // Bottom depth arm flares back along torso (~15°-20° -> ~75°-85° depth)
      final mappedAngle = (60.0 + (rawAngle * 1.33)).clamp(60.0, 180.0);
      _filteredLeftElbowAngle = _applyEma(mappedAngle, _filteredLeftElbowAngle);
      leftAngle = _filteredLeftElbowAngle;
    } else if (_conf(lShoulder) && _conf(lElbow)) {
      // 3. Fallback Method B: Virtual Ground Anchor (Wrist planted on floor)
      final virtualWrist = PoseLandmark(
        type: PoseLandmarkType.leftWrist,
        x: lElbow!.x,
        y: max(lElbow.y + (lElbow.y - lShoulder!.y).abs() * 0.9, imageSize.height * 0.92),
        z: 0,
        likelihood: 0.8,
      );
      final rawAngle = _calculateAngle(lShoulder, lElbow, virtualWrist);
      _filteredLeftElbowAngle = _applyEma(rawAngle, _filteredLeftElbowAngle);
      leftAngle = _filteredLeftElbowAngle;
    }

    // Right Arm Processing
    if (_conf(rShoulder) && _conf(rElbow) && _conf(rWrist)) {
      final rawAngle = _calculateAngle(rShoulder!, rElbow!, rWrist!);
      _filteredRightElbowAngle = _applyEma(rawAngle, _filteredRightElbowAngle);
      rightAngle = _filteredRightElbowAngle;
    } else if (_conf(rShoulder) && _conf(rElbow) && _conf(rHip)) {
      final rawAngle = _calculateAngle(rElbow!, rShoulder!, rHip!);
      final mappedAngle = (60.0 + (rawAngle * 1.33)).clamp(60.0, 180.0);
      _filteredRightElbowAngle = _applyEma(mappedAngle, _filteredRightElbowAngle);
      rightAngle = _filteredRightElbowAngle;
    } else if (_conf(rShoulder) && _conf(rElbow)) {
      final virtualWrist = PoseLandmark(
        type: PoseLandmarkType.rightWrist,
        x: rElbow!.x,
        y: max(rElbow.y + (rElbow.y - rShoulder!.y).abs() * 0.9, imageSize.height * 0.92),
        z: 0,
        likelihood: 0.8,
      );
      final rawAngle = _calculateAngle(rShoulder, rElbow, virtualWrist);
      _filteredRightElbowAngle = _applyEma(rawAngle, _filteredRightElbowAngle);
      rightAngle = _filteredRightElbowAngle;
    }

    final double currentAngle = (leftAngle != null && rightAngle != null)
        ? (leftAngle + rightAngle) / 2
        : leftAngle ?? rightAngle ?? 180.0;

    String feedback = 'Good Form';

    // ─── Continuous Peak-to-Valley State Machine ───────────────────────
    switch (_state) {
      case RepState.waitingForPlank:
        if (currentAngle >= _kSideTopLockout) {
          _topPlankHoldFrames++;
          if (_topPlankHoldFrames >= _kRequiredTopHoldFrames) {
            _state = RepState.top;
            _strokePeakAngle = currentAngle;
            _strokeValleyAngle = currentAngle;
            feedback = 'Ready • Begin Push-ups!';
          } else {
            feedback = 'Hold Top Plank...';
          }
        } else {
          _topPlankHoldFrames = 0;
          feedback = 'Start in High Plank (Arms Straight)';
        }
        break;

      case RepState.top:
        _strokePeakAngle = max(_strokePeakAngle, currentAngle);
        if (currentAngle < _kSideDescendingTrigger) {
          _state = RepState.descending;
          _strokeValleyAngle = currentAngle;
          feedback = 'Going down...';
        } else {
          feedback = 'Ready • Lower chest to floor';
        }
        break;

      case RepState.descending:
        _strokeValleyAngle = min(_strokeValleyAngle, currentAngle);

        if (currentAngle <= _kSideValidDepthCutoff) {
          _state = RepState.bottom;
          feedback = 'Great depth! Now push up';
        } else if (currentAngle > _strokeValleyAngle + 12.0) {
          _state = RepState.ascending;
          feedback = 'Pushing up!';
        } else {
          feedback = 'Lower chest to floor';
        }
        break;

      case RepState.bottom:
        _strokeValleyAngle = min(_strokeValleyAngle, currentAngle);

        if (currentAngle > _strokeValleyAngle + 10.0) {
          _state = RepState.ascending;
          feedback = 'Pushing up!';
        } else {
          feedback = 'Full depth! Drive up';
        }
        break;

      case RepState.ascending:
        _strokePeakAngle = max(_strokePeakAngle, currentAngle);

        if (currentAngle >= _kSideTopLockout) {
          final double rangeOfMotion = _strokePeakAngle - _strokeValleyAngle;

          if (_strokeValleyAngle <= _kSideValidDepthCutoff && rangeOfMotion >= _kSideMinRangeOfMotion) {
            _repCount++;
            _repJustCompleted = true;
            _state = RepState.top;

            _lastRepFormScore = _computeFormScore(
              minAngle: _strokeValleyAngle,
              maxAngle: _strokePeakAngle,
              spineMaintained: !_spineBrokenThisRep,
            );
            feedback = '$_repCount ✓ ($_lastRepFormScore% Form)';
          } else {
            _state = RepState.top;
            feedback = '⚠️ Half Rep • Go deeper & lock out!';
          }

          _strokePeakAngle = currentAngle;
          _strokeValleyAngle = currentAngle;
          _spineBrokenThisRep = false;
        } else {
          feedback = 'Lock out arms at top';
        }
        break;
    }

    return FrameAnalysis(
      trackingMode: TrackingMode.sideProfile,
      repState: _state,
      repCount: _repCount,
      formScore: _lastRepFormScore,
      feedback: feedback,
      isGoodForm: isSpineStraight && (_state != RepState.descending || currentAngle < 130),
      currentAngle: currentAngle,
      pose: pose,
      imageSize: imageSize,
      repJustCompleted: _repJustCompleted,
    );
  }

  /// Process Front Floor tracking using Continuous Peak-to-Valley Inflection Engine
  FrameAnalysis _processFrontFloor({
    required Pose pose,
    required Size imageSize,
    PoseLandmark? lShoulder,
    PoseLandmark? rShoulder,
    PoseLandmark? lElbow,
    PoseLandmark? rElbow,
    PoseLandmark? lWrist,
    PoseLandmark? rWrist,
    PoseLandmark? lHip,
    PoseLandmark? rHip,
    PoseLandmark? nose,
    required bool isSpineStraight,
  }) {
    final double? shoulderY = _avgY(lShoulder, rShoulder) ?? nose?.y;
    double? wristY = _avgY(lWrist, rWrist);
    final double? hipY = _avgY(lHip, rHip);

    if (shoulderY == null) {
      return FrameAnalysis(
        trackingMode: TrackingMode.frontFloor,
        repState: _state,
        repCount: _repCount,
        formScore: _lastRepFormScore,
        feedback: 'Position upper body in frame',
        isGoodForm: false,
        currentAngle: 0.0,
        pose: pose,
        imageSize: imageSize,
      );
    }

    if (wristY == null) {
      final elbowY = _avgY(lElbow, rElbow);
      if (elbowY != null) {
        wristY = max(elbowY + (elbowY - shoulderY).abs() * 0.8, imageSize.height * 0.88);
      } else {
        wristY = imageSize.height * 0.90;
      }
    }

    final double verticalDelta = (wristY - shoulderY).abs();
    final double refScale = (hipY != null && (hipY - shoulderY).abs() > 20)
        ? (hipY - shoulderY).abs()
        : imageSize.height * 0.45;

    final double rawRatio = (verticalDelta / refScale).clamp(0.0, 1.2);
    _filteredCompressionRatio = _applyEma(rawRatio, _filteredCompressionRatio);
    final double currentRatio = _filteredCompressionRatio!;

    String feedback = 'Good Form';

    switch (_state) {
      case RepState.waitingForPlank:
        if (currentRatio >= _kFrontTopLockout) {
          _topPlankHoldFrames++;
          if (_topPlankHoldFrames >= _kRequiredTopHoldFrames) {
            _state = RepState.top;
            _strokePeakRatio = currentRatio;
            _strokeValleyRatio = currentRatio;
            feedback = 'Ready • Begin Push-ups!';
          } else {
            feedback = 'Hold High Plank...';
          }
        } else {
          _topPlankHoldFrames = 0;
          feedback = 'Set up in High Plank position';
        }
        break;

      case RepState.top:
        _strokePeakRatio = max(_strokePeakRatio, currentRatio);
        if (currentRatio < _kFrontDescendingTrigger) {
          _state = RepState.descending;
          _strokeValleyRatio = currentRatio;
          feedback = 'Lowering chest...';
        } else {
          feedback = 'Ready • Lower chest to floor';
        }
        break;

      case RepState.descending:
        _strokeValleyRatio = min(_strokeValleyRatio, currentRatio);

        if (currentRatio <= _kFrontValidDepthCutoff) {
          _state = RepState.bottom;
          feedback = 'Great depth! Push up';
        } else if (currentRatio > _strokeValleyRatio + 0.10) {
          _state = RepState.ascending;
          feedback = 'Pushing up!';
        } else {
          feedback = 'Go lower towards floor';
        }
        break;

      case RepState.bottom:
        _strokeValleyRatio = min(_strokeValleyRatio, currentRatio);

        if (currentRatio > _strokeValleyRatio + 0.08) {
          _state = RepState.ascending;
          feedback = 'Pushing up!';
        } else {
          feedback = 'Full depth! Push up';
        }
        break;

      case RepState.ascending:
        _strokePeakRatio = max(_strokePeakRatio, currentRatio);

        if (currentRatio >= _kFrontTopLockout) {
          final double compressionRange = _strokePeakRatio - _strokeValleyRatio;

          if (_strokeValleyRatio <= _kFrontValidDepthCutoff && compressionRange >= _kFrontMinRangeOfMotion) {
            _repCount++;
            _repJustCompleted = true;
            _state = RepState.top;

            _lastRepFormScore = _computeFrontFormScore(
              minRatio: _strokeValleyRatio,
              maxRatio: _strokePeakRatio,
              spineMaintained: !_spineBrokenThisRep,
            );
            feedback = '$_repCount ✓ ($_lastRepFormScore% Form)';
          } else {
            _state = RepState.top;
            feedback = '⚠️ Half Rep • Lower chest all the way!';
          }

          _strokePeakRatio = currentRatio;
          _strokeValleyRatio = currentRatio;
          _spineBrokenThisRep = false;
        } else {
          feedback = 'Push all the way up';
        }
        break;
    }

    return FrameAnalysis(
      trackingMode: TrackingMode.frontFloor,
      repState: _state,
      repCount: _repCount,
      formScore: _lastRepFormScore,
      feedback: feedback,
      isGoodForm: isSpineStraight,
      currentAngle: currentRatio * 100,
      pose: pose,
      imageSize: imageSize,
      repJustCompleted: _repJustCompleted,
    );
  }

  /// Process Selfie Camera tracking using normalized nose Y-position tracking
  FrameAnalysis _processSelfieCamera({
    required Pose pose,
    required Size imageSize,
    PoseLandmark? nose,
    required bool isSpineStraight,
  }) {
    if (!_conf(nose)) {
      return FrameAnalysis(
        trackingMode: TrackingMode.selfieCamera,
        repState: _state,
        repCount: _repCount,
        formScore: _lastRepFormScore,
        feedback: 'Turn to face camera',
        isGoodForm: false,
        currentAngle: 0.0,
        pose: pose,
        imageSize: imageSize,
      );
    }

    final double rawNoseRatio = (nose!.y / imageSize.height).clamp(0.0, 1.0);
    _filteredNoseRatio = _applyEma(rawNoseRatio, _filteredNoseRatio);
    final double currentNoseRatio = _filteredNoseRatio!;

    String feedback = 'Face visible ✓';

    switch (_state) {
      case RepState.waitingForPlank:
        if (currentNoseRatio <= _kSelfieTopLockout) {
          _topPlankHoldFrames++;
          if (_topPlankHoldFrames >= _kRequiredTopHoldFrames) {
            _state = RepState.top;
            _strokePeakRatio = currentNoseRatio;
            _strokeValleyRatio = currentNoseRatio;
            feedback = 'Face visible ✓';
          } else {
            feedback = 'Face visible ✓';
          }
        } else {
          _topPlankHoldFrames = 0;
          feedback = 'Face visible ✓';
        }
        break;

      case RepState.top:
        _strokePeakRatio = min(_strokePeakRatio, currentNoseRatio);
        if (currentNoseRatio > _kSelfieDescendingTrigger) {
          _state = RepState.descending;
          _strokeValleyRatio = currentNoseRatio;
          feedback = 'Lower your chest';
        } else {
          feedback = 'Face visible ✓';
        }
        break;

      case RepState.descending:
        _strokeValleyRatio = max(_strokeValleyRatio, currentNoseRatio);

        if (currentNoseRatio >= _kSelfieValidDepthCutoff) {
          _state = RepState.bottom;
          feedback = 'Push up!';
        } else if (currentNoseRatio < _strokeValleyRatio - 0.08) {
          _state = RepState.ascending;
          feedback = 'Push up!';
        } else {
          feedback = 'Lower your chest';
        }
        break;

      case RepState.bottom:
        _strokeValleyRatio = max(_strokeValleyRatio, currentNoseRatio);

        if (currentNoseRatio < _strokeValleyRatio - 0.06) {
          _state = RepState.ascending;
          feedback = 'Push up!';
        } else {
          feedback = 'Push up!';
        }
        break;

      case RepState.ascending:
        _strokePeakRatio = min(_strokePeakRatio, currentNoseRatio);

        if (currentNoseRatio <= _kSelfieTopLockout) {
          final double noseRange = _strokeValleyRatio - _strokePeakRatio;

          if (_strokeValleyRatio >= _kSelfieValidDepthCutoff && noseRange >= _kSelfieMinRangeOfMotion) {
            _repCount++;
            _repJustCompleted = true;
            _state = RepState.top;

            _lastRepFormScore = _computeFrontFormScore(
              minRatio: _strokePeakRatio,
              maxRatio: _strokeValleyRatio,
              spineMaintained: !_spineBrokenThisRep,
            );
            feedback = '$_repCount ✓ ($_lastRepFormScore% Form)';
          } else {
            _state = RepState.top;
            feedback = '⚠️ Half Rep • Lower your chest!';
          }

          _strokePeakRatio = currentNoseRatio;
          _strokeValleyRatio = currentNoseRatio;
          _spineBrokenThisRep = false;
        } else {
          feedback = 'Push up!';
        }
        break;
    }

    return FrameAnalysis(
      trackingMode: TrackingMode.selfieCamera,
      repState: _state,
      repCount: _repCount,
      formScore: _lastRepFormScore,
      feedback: feedback,
      isGoodForm: isSpineStraight,
      currentAngle: currentNoseRatio * 100,
      pose: pose,
      imageSize: imageSize,
      repJustCompleted: _repJustCompleted,
    );
  }

  // ─── Mathematical & Helper Utilities ────────────────────────────────

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final double v1x = a.x - b.x;
    final double v1y = a.y - b.y;
    final double v2x = c.x - b.x;
    final double v2y = c.y - b.y;

    final double dotProduct = (v1x * v2x) + (v1y * v2y);
    final double mag1 = sqrt((v1x * v1x) + (v1y * v2y));
    final double mag2 = sqrt((v2x * v2x) + (v2y * v2y));

    if (mag1 * mag2 == 0) return 180.0;

    final double cosine = (dotProduct / (mag1 * mag2)).clamp(-1.0, 1.0);
    return acos(cosine) * (180.0 / pi);
  }

  double _applyEma(double current, double? previous) {
    if (previous == null) return current;
    return (_kEmaAlpha * current) + ((1.0 - _kEmaAlpha) * previous);
  }

  bool _checkPlankAlignment(
    PoseLandmark? lS, PoseLandmark? rS,
    PoseLandmark? lH, PoseLandmark? rH,
    PoseLandmark? lA, PoseLandmark? rA,
    Size imageSize,
  ) {
    final sY = _avgY(lS, rS);
    final hY = _avgY(lH, rH);
    final aY = _avgY(lA, rA);

    if (sY == null || hY == null) return true;

    if (aY != null) {
      final double totalSpan = (aY - sY).abs();
      if (totalSpan > 30) {
        final double expectedHipY = sY + (totalSpan * 0.5);
        final double sagDistance = (hY - expectedHipY).abs();
        if (sagDistance / totalSpan > 0.25) {
          return false;
        }
      }
    }
    return true;
  }

  int _computeFormScore({
    required double minAngle,
    required double maxAngle,
    required bool spineMaintained,
  }) {
    int score = 100;
    if (minAngle > 85.0) {
      final penalty = ((minAngle - 85.0) * 1.5).round();
      score -= penalty.clamp(0, 30);
    }
    if (maxAngle < 165.0) {
      final penalty = ((165.0 - maxAngle) * 1.2).round();
      score -= penalty.clamp(0, 25);
    }
    if (!spineMaintained) {
      score -= 20;
    }
    return score.clamp(30, 100);
  }

  int _computeFrontFormScore({
    required double minRatio,
    required double maxRatio,
    required bool spineMaintained,
  }) {
    int score = 100;
    if (minRatio > 0.30) {
      score -= (((minRatio - 0.30) / 0.25) * 30).round().clamp(0, 30);
    }
    if (maxRatio < 0.80) {
      score -= (((0.80 - maxRatio) / 0.25) * 25).round().clamp(0, 25);
    }
    if (!spineMaintained) {
      score -= 20;
    }
    return score.clamp(30, 100);
  }

  bool _conf(PoseLandmark? lm) => lm != null && lm.likelihood >= _kMinConfidence;

  double? _avgY(PoseLandmark? a, PoseLandmark? b) {
    if (a != null && b != null && _conf(a) && _conf(b)) return (a.y + b.y) / 2;
    if (a != null && _conf(a)) return a.y;
    if (b != null && _conf(b)) return b.y;
    return null;
  }

  double? _avgX(PoseLandmark? a, PoseLandmark? b) {
    if (a != null && b != null && _conf(a) && _conf(b)) return (a.x + b.x) / 2;
    if (a != null && _conf(a)) return a.x;
    if (b != null && _conf(b)) return b.x;
    return null;
  }

  /// Automatically evaluates whether a pose is holding a valid plank,
  /// detecting perspective (Side Profile vs Front View) and rejecting upright postures.
  PlankEvaluation evaluatePlankPose(Pose pose, Size imageSize) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final lWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    final hasUpperBody = _conf(lShoulder) || _conf(rShoulder) || _conf(nose);
    if (!hasUpperBody) {
      return const PlankEvaluation(
        isPlank: false,
        orientation: 'None',
        formScore: 0,
        feedback: 'Position body in camera view',
      );
    }

    final sY = _avgY(lShoulder, rShoulder);
    final hY = _avgY(lHip, rHip);
    final sX = _avgX(lShoulder, rShoulder);
    final hX = _avgX(lHip, rHip);

    final double height = imageSize.height > 0 ? imageSize.height : 1280.0;
    final double width = imageSize.width > 0 ? imageSize.width : 720.0;

    // ── 1. Upright Elimination (Standing or Sitting) ──
    if (sY != null && hY != null) {
      final double dy = hY - sY; // Positive when hip is below shoulder
      final double dx = (sX != null && hX != null) ? (hX - sX).abs() : 0.0;
      final double verticalRatio = dy / height;

      // Torso is vertical: hips are clearly lower than shoulders
      if (verticalRatio > 0.12 && dy > dx * 1.25) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Upright',
          formScore: 0,
          feedback: 'Get down on floor in plank position',
        );
      }

      // Check knees below hips
      final kY = _avgY(lKnee, rKnee);
      if (kY != null && kY > hY && verticalRatio > 0.08 && dy > dx) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Upright',
          formScore: 0,
          feedback: 'Get down on floor in plank position',
        );
      }
    }

    // ── 2. Automatic Angle / Perspective Classification ──
    // In Side Profile: body is horizontal across screen with significant horizontal hip-to-shoulder span
    final double torsoDx = (sX != null && hX != null) ? (hX - sX).abs() : 0.0;
    final double torsoDy = (sY != null && hY != null) ? (hY - sY).abs() : 0.0;
    final double shoulderSpan = (_conf(lShoulder) && _conf(rShoulder))
        ? (lShoulder!.x - rShoulder!.x).abs()
        : 0.0;
    final aX = _avgX(lAnkle, rAnkle) ?? _avgX(lKnee, rKnee);
    final double legSpanX = (aX != null && hX != null) ? (aX - hX).abs() : 0.0;

    final bool isSideProfile = (torsoDx > torsoDy * 0.75 && torsoDx > width * 0.10) ||
        (legSpanX > width * 0.15 && (torsoDx > torsoDy * 0.6 || shoulderSpan < width * 0.18));

    if (isSideProfile) {
      return _evaluateSidePlank(
        pose: pose,
        sX: sX, sY: sY,
        hX: hX, hY: hY,
        torsoDx: torsoDx, torsoDy: torsoDy,
        lShoulder: lShoulder, rShoulder: rShoulder,
        lHip: lHip, rHip: rHip,
        lKnee: lKnee, rKnee: rKnee,
        lAnkle: lAnkle, rAnkle: rAnkle,
        lElbow: lElbow, rElbow: rElbow,
        lWrist: lWrist, rWrist: rWrist,
        width: width, height: height,
      );
    } else {
      return _evaluateFrontPlank(
        pose: pose,
        nose: nose,
        lShoulder: lShoulder, rShoulder: rShoulder,
        lElbow: lElbow, rElbow: rElbow,
        lWrist: lWrist, rWrist: rWrist,
        sX: sX, sY: sY,
        hX: hX, hY: hY,
        width: width, height: height,
      );
    }
  }

  PlankEvaluation _evaluateSidePlank({
    required Pose pose,
    required double? sX, required double? sY,
    required double? hX, required double? hY,
    required double torsoDx, required double torsoDy,
    required PoseLandmark? lShoulder, required PoseLandmark? rShoulder,
    required PoseLandmark? lHip, required PoseLandmark? rHip,
    required PoseLandmark? lKnee, required PoseLandmark? rKnee,
    required PoseLandmark? lAnkle, required PoseLandmark? rAnkle,
    required PoseLandmark? lElbow, required PoseLandmark? rElbow,
    required PoseLandmark? lWrist, required PoseLandmark? rWrist,
    required double width, required double height,
  }) {
    // 1. Torso must be predominantly horizontal
    if (torsoDx < torsoDy * 0.70) {
      return const PlankEvaluation(
        isPlank: false,
        orientation: 'Side View',
        formScore: 40,
        feedback: 'Keep body horizontal in plank line',
      );
    }

    final aY = _avgY(lAnkle, rAnkle) ?? _avgY(lKnee, rKnee);
    final aX = _avgX(lAnkle, rAnkle) ?? _avgX(lKnee, rKnee);

    if (aY != null && aX != null && sX != null && sY != null && hX != null && hY != null) {
      final double totalDx = (aX - sX).abs();
      if (totalDx < torsoDx * 0.8) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Side View',
          formScore: 40,
          feedback: 'Extend legs back into plank position',
        );
      }

      // Check alignment from shoulder through hip to foot
      final double t = (hX - sX).abs() / (totalDx > 0 ? totalDx : 1.0);
      final double expectedHipY = sY + t * (aY - sY);
      final double sagDeviation = hY - expectedHipY; // Positive = sag toward floor
      final double totalSpan = max(totalDx, (aY - sY).abs());
      final double sagRatio = sagDeviation.abs() / (totalSpan > 0 ? totalSpan : 1.0);

      if (sagRatio > 0.25) {
        if (sagDeviation > 0) {
          return const PlankEvaluation(
            isPlank: false,
            orientation: 'Side View',
            formScore: 45,
            feedback: 'Engage core • Lift hips',
          );
        } else {
          return const PlankEvaluation(
            isPlank: false,
            orientation: 'Side View',
            formScore: 50,
            feedback: 'Lower hips into straight line',
          );
        }
      }

      // Kinematic angle check: Shoulder -> Hip -> Ankle/Knee
      final shoulderLm = _conf(lShoulder) ? lShoulder! : rShoulder!;
      final hipLm = _conf(lHip) ? lHip! : rHip!;
      final footLm = (_conf(lAnkle) ? lAnkle : (_conf(rAnkle) ? rAnkle : (_conf(lKnee) ? lKnee : rKnee)))!;
      final double spineAngle = _calculateAngle(shoulderLm, hipLm, footLm);

      if (spineAngle < 145.0) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Side View',
          formScore: 50,
          feedback: 'Straighten body into straight line',
        );
      }

      final int score = (100 - ((180.0 - spineAngle).abs() * 1.2).round() - (sagRatio * 100).round()).clamp(55, 100);
      return PlankEvaluation(
        isPlank: true,
        orientation: 'Side View',
        formScore: score,
        feedback: 'Holding Plank Steady ✓ (Side View)',
      );
    }

    // If feet not fully visible but torso is strictly horizontal off the floor
    if (sY != null && hY != null && (sY - hY).abs() < height * 0.18) {
      return const PlankEvaluation(
        isPlank: true,
        orientation: 'Side View',
        formScore: 85,
        feedback: 'Holding Plank Steady ✓ (Side View)',
      );
    }

    return const PlankEvaluation(
      isPlank: false,
      orientation: 'Side View',
      formScore: 40,
      feedback: 'Get into plank position',
    );
  }

  PlankEvaluation _evaluateFrontPlank({
    required Pose pose,
    required PoseLandmark? nose,
    required PoseLandmark? lShoulder,
    required PoseLandmark? rShoulder,
    required PoseLandmark? lElbow,
    required PoseLandmark? rElbow,
    required PoseLandmark? lWrist,
    required PoseLandmark? rWrist,
    required double? sX, required double? sY,
    required double? hX, required double? hY,
    required double width, required double height,
  }) {
    if (!_conf(nose)) {
      return const PlankEvaluation(
        isPlank: false,
        orientation: 'Front View',
        formScore: 0,
        feedback: 'Position face in camera view',
      );
    }

    final double noseRatio = (nose!.y / height).clamp(0.0, 1.0);

    // Collapsed flat on floor: nose too close to bottom/floor
    if (noseRatio > 0.55) {
      return const PlankEvaluation(
        isPlank: false,
        orientation: 'Front View',
        formScore: 30,
        feedback: 'Push body off the floor',
      );
    }

    // Too high on frame (standing or camera pointing down from ceiling)
    if (noseRatio < 0.04) {
      return const PlankEvaluation(
        isPlank: false,
        orientation: 'Front View',
        formScore: 0,
        feedback: 'Get down on floor in plank position',
      );
    }

    // Check shoulder leveling (anti-rotation)
    double shoulderTilt = 0.0;
    if (_conf(lShoulder) && _conf(rShoulder)) {
      shoulderTilt = (lShoulder!.y - rShoulder!.y).abs() / height;
      if (shoulderTilt > 0.14) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Front View',
          formScore: 50,
          feedback: 'Level your shoulders evenly',
        );
      }
    }

    // If hips detected in front perspective, ensure they aren't hanging below shoulders
    if (sY != null && hY != null) {
      if (hY > sY + height * 0.12) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Front View',
          formScore: 40,
          feedback: 'Get down on floor in plank position',
        );
      }
    }

    // Require arms to be supporting the body
    // The elbows or wrists should be significantly lower (higher Y) than the shoulders.
    // If they just tilt their head back while sitting, their arms won't be planted below them.
    if (sY != null) {
      final eY = _avgY(lElbow, rElbow);
      final wY = _avgY(lWrist, rWrist);
      final lowestArmPoint = [eY, wY].where((y) => y != null).fold<double?>(null, (max, y) => (max == null || y! > max) ? y : max);
      
      if (lowestArmPoint == null || lowestArmPoint < sY + height * 0.10) {
        return const PlankEvaluation(
          isPlank: false,
          orientation: 'Front View',
          formScore: 20,
          feedback: 'Plant arms/hands on the floor',
        );
      }
    }

    final int score = (100 - (shoulderTilt * 100 * 2).round()).clamp(60, 100);
    return PlankEvaluation(
      isPlank: true,
      orientation: 'Front View',
      formScore: score,
      feedback: 'Holding Plank Steady ✓ (Front View)',
    );
  }
}