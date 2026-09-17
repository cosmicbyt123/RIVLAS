import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rivals/services/pose_service.dart';

void main() {
  group('PoseService Engine Tests', () {
    late PoseService poseService;

    setUp(() {
      poseService = PoseService();
    });

    test('Initial state is correct and repCount starts at 0', () {
      expect(poseService.repCount, 0);
      expect(poseService.mode, TrackingMode.sideProfile);
    });

    test('Mode switcher updates tracking mode and resets counters', () {
      poseService.mode = TrackingMode.frontFloor;
      expect(poseService.mode, TrackingMode.frontFloor);
      expect(poseService.repCount, 0);

      poseService.mode = TrackingMode.selfieCamera;
      expect(poseService.mode, TrackingMode.selfieCamera);
      expect(poseService.repCount, 0);
    });

    test('Analyze returns waiting feedback when no landmarks visible', () {
      final emptyPose = Pose(landmarks: {});
      final analysis = poseService.analyze(emptyPose, const Size(720, 1280));

      expect(analysis.repCount, 0);
      expect(analysis.isGoodForm, false);
      expect(analysis.feedback, contains('Position body'));
    });

    test('Lying on floor initially does NOT count a rep when standing up', () {
      final floorPose = _createArmPose(
        shoulder: const Offset(100, 200),
        elbow: const Offset(150, 200),
        wrist: const Offset(150, 150),
      );

      for (int i = 0; i < 5; i++) {
        final analysis = poseService.analyze(floorPose, const Size(720, 1280));
        expect(analysis.repCount, 0);
        expect(analysis.feedback, contains('Start in High Plank'));
      }

      final topPose = _createArmPose(
        shoulder: const Offset(100, 200),
        elbow: const Offset(100, 300),
        wrist: const Offset(100, 400),
      );
      for (int i = 0; i < 5; i++) {
        poseService.analyze(topPose, const Size(720, 1280));
      }

      expect(poseService.repCount, 0);
    });

    test('Cropped hands / missing wrists still track pushups via Fallback Kinematics', () {
      final topPoseNoWrists = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 200, y: 200, z: 0, likelihood: 0.99),
        PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: 200, y: 350, z: 0, likelihood: 0.99),
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 500, y: 200, z: 0, likelihood: 0.99),
      });

      for (int i = 0; i < 6; i++) {
        poseService.analyze(topPoseNoWrists, const Size(720, 1280));
      }

      final bottomPoseNoWrists = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 200, y: 200, z: 0, likelihood: 0.99),
        PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: 350, y: 220, z: 0, likelihood: 0.99),
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 500, y: 200, z: 0, likelihood: 0.99),
      });

      for (int i = 0; i < 10; i++) {
        poseService.analyze(bottomPoseNoWrists, const Size(720, 1280));
      }

      for (int i = 0; i < 10; i++) {
        poseService.analyze(topPoseNoWrists, const Size(720, 1280));
      }

      expect(poseService.repCount, 1);
    });

    test('SelfieCamera Mode: Tracks pushups by nose Y position and provides exact feedback', () {
      poseService.mode = TrackingMode.selfieCamera;

      // 1. Missing nose gives warning "Turn to face camera"
      final emptyPose = Pose(landmarks: {});
      final noNoseAnalysis = poseService.analyze(emptyPose, const Size(720, 1280));
      expect(noNoseAnalysis.feedback, 'Turn to face camera');

      // 2. High plank top lockout: Nose high on screen (Y = 0.20 * 1280 = 256)
      final topNosePose = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 360, y: 256, z: 0, likelihood: 0.99),
      });

      for (int i = 0; i < 6; i++) {
        final analysis = poseService.analyze(topNosePose, const Size(720, 1280));
        expect(analysis.feedback, 'Face visible ✓');
      }

      // 3. Descending: Nose moves down on screen (Y = 0.50 * 1280 = 640)
      final descendingNosePose = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 360, y: 640, z: 0, likelihood: 0.99),
      });
      for (int i = 0; i < 6; i++) {
        poseService.analyze(descendingNosePose, const Size(720, 1280));
      }
      final descAnalysis = poseService.analyze(descendingNosePose, const Size(720, 1280));
      expect(descAnalysis.feedback, 'Lower your chest');

      // 4. Bottom depth: Nose drops low on screen (Y = 0.75 * 1280 = 960)
      final bottomNosePose = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 360, y: 960, z: 0, likelihood: 0.99),
      });
      late FrameAnalysis bottomAnalysis;
      for (int i = 0; i < 8; i++) {
        bottomAnalysis = poseService.analyze(bottomNosePose, const Size(720, 1280));
      }
      expect(bottomAnalysis.feedback, contains('Push up!'));

      // 5. Ascend back to top lockout (Y = 0.20 * 1280 = 256)
      for (int i = 0; i < 10; i++) {
        poseService.analyze(topNosePose, const Size(720, 1280));
      }

      // 6. Rep successfully counted!
      expect(poseService.repCount, 1);
    });

    group('Automatic Plank Detection Tests', () {
      test('Standing/Sitting upright pose rejects plank', () {
        // Person standing in front of camera: shoulders high, hips middle, knees low
        final uprightPose = Pose(landmarks: {
          PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 300, y: 300, z: 0, likelihood: 0.99),
          PoseLandmarkType.rightShoulder: PoseLandmark(type: PoseLandmarkType.rightShoulder, x: 420, y: 300, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 320, y: 650, z: 0, likelihood: 0.99),
          PoseLandmarkType.rightHip: PoseLandmark(type: PoseLandmarkType.rightHip, x: 400, y: 650, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 320, y: 900, z: 0, likelihood: 0.99),
          PoseLandmarkType.rightKnee: PoseLandmark(type: PoseLandmarkType.rightKnee, x: 400, y: 900, z: 0, likelihood: 0.99),
          PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 360, y: 200, z: 0, likelihood: 0.99),
        });

        for (int i = 0; i < 5; i++) {
          final analysis = poseService.analyze(uprightPose, const Size(720, 1280));
          expect(analysis.isPlank, false);
          expect(analysis.plankOrientation, 'Upright');
        }
        expect(poseService.isHoldingPlank, false);
      });

      test('Side Profile plank: Detects valid horizontal straight spine hold', () {
        // User horizontally across screen: shoulder at (150, 500), hip at (400, 510), ankle at (650, 520)
        final sidePlankPose = Pose(landmarks: {
          PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 150, y: 500, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: 150, y: 650, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftWrist: PoseLandmark(type: PoseLandmarkType.leftWrist, x: 150, y: 780, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 400, y: 510, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 525, y: 515, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 650, y: 520, z: 0, likelihood: 0.99),
          PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 100, y: 500, z: 0, likelihood: 0.99),
        });

        late FrameAnalysis analysis;
        for (int i = 0; i < 5; i++) {
          analysis = poseService.analyze(sidePlankPose, const Size(720, 1280));
        }

        expect(analysis.isPlank, true);
        expect(analysis.plankOrientation, 'Side View');
        expect(analysis.plankFormScore, greaterThanOrEqualTo(80));
        expect(poseService.isHoldingPlank, true);
      });

      test('Side Profile plank: Severe hip sag rejects plank', () {
        // Hips sagged down to y = 700 (well below expected 510)
        final saggyPlankPose = Pose(landmarks: {
          PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 150, y: 500, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 400, y: 700, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 650, y: 520, z: 0, likelihood: 0.99),
          PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 100, y: 500, z: 0, likelihood: 0.99),
        });

        for (int i = 0; i < 5; i++) {
          final analysis = poseService.analyze(saggyPlankPose, const Size(720, 1280));
          expect(analysis.isPlank, false);
          expect(analysis.plankFeedback, contains('core'));
        }
      });

      test('Front View plank: Detects valid floor hold facing camera', () {
        // User on floor facing front camera: shoulders level and wide, nose elevated
        final frontPlankPose = Pose(landmarks: {
          PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 240, y: 400, z: 0, likelihood: 0.99),
          PoseLandmarkType.rightShoulder: PoseLandmark(type: PoseLandmarkType.rightShoulder, x: 480, y: 400, z: 0, likelihood: 0.99),
          PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 360, y: 320, z: 0, likelihood: 0.99),
          PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 280, y: 410, z: 0, likelihood: 0.90),
          PoseLandmarkType.rightHip: PoseLandmark(type: PoseLandmarkType.rightHip, x: 440, y: 410, z: 0, likelihood: 0.90),
        });

        late FrameAnalysis analysis;
        for (int i = 0; i < 5; i++) {
          analysis = poseService.analyze(frontPlankPose, const Size(720, 1280));
        }

        expect(analysis.isPlank, true);
        expect(analysis.plankOrientation, 'Front View');
        expect(analysis.plankFeedback, contains('Holding Plank Steady'));
        expect(poseService.isHoldingPlank, true);
      });

      test('Front View plank: Collapsed on floor rejects plank', () {
        // Nose collapsed near floor (y = 800 / 1280 = 0.625)
        final collapsedPose = Pose(landmarks: {
          PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 240, y: 750, z: 0, likelihood: 0.99),
          PoseLandmarkType.rightShoulder: PoseLandmark(type: PoseLandmarkType.rightShoulder, x: 480, y: 750, z: 0, likelihood: 0.99),
          PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 360, y: 800, z: 0, likelihood: 0.99),
        });

        final analysis = poseService.analyze(collapsedPose, const Size(720, 1280));
        expect(analysis.isPlank, false);
      });
    });
  });
}

Pose _createArmPose({required Offset shoulder, required Offset elbow, required Offset wrist}) {
  return Pose(landmarks: {
    PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: shoulder.dx, y: shoulder.dy, z: 0, likelihood: 0.99),
    PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: elbow.dx, y: elbow.dy, z: 0, likelihood: 0.99),
    PoseLandmarkType.leftWrist: PoseLandmark(type: PoseLandmarkType.leftWrist, x: wrist.dx, y: wrist.dy, z: 0, likelihood: 0.99),
  });
}
