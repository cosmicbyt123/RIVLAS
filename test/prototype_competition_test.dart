import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rivals/services/prototype_multi_tracker.dart';
import 'package:rivals/services/prototype_bot_engine.dart';
import 'package:rivals/services/pose_service.dart';

class MockPoseService extends PoseService {
  int _reps = 0;
  @override
  int get repCount => _reps;
  set mockReps(int r) => _reps = r;
}

void main() {
  group('PrototypeMultiTracker Engine Tests', () {
    late PrototypeMultiTracker tracker;

    setUp(() {
      tracker = PrototypeMultiTracker();
    });

    test('Initializes in selfieCamera mode with max 4 players support', () {
      expect(tracker.mode, TrackingMode.selfieCamera);
      expect(tracker.allPlayers.length, 1);
      expect(tracker.allPlayers.first.id, 1);
      expect(tracker.allPlayers.first.name, 'Player 1');
    });

    test('Persistent Reps & Anti-Swap: Adding new players never overwrites Player 1 reps', () {
      final mockP1 = MockPoseService()..mockReps = 8;
      tracker.setPlayerPoseServiceForTesting(0, mockP1);
      expect(tracker.allPlayers.first.repCount, 8);

      final posePlayer1 = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(
          type: PoseLandmarkType.nose,
          x: 200, y: 300, z: 0, likelihood: 0.95,
        ),
      });

      final posePlayer2 = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(
          type: PoseLandmarkType.nose,
          x: 500, y: 300, z: 0, likelihood: 0.95,
        ),
      });

      final updated = tracker.processFramePoses([posePlayer1, posePlayer2], const Size(720, 1280));

      expect(updated.length, 2);
      expect(updated[0].id, 1);
      expect(updated[0].name, 'Player 1');
      expect(updated[0].repCount, 8);
      expect(updated[1].id, 2);
      expect(updated[1].name, 'Player 2');
      expect(updated[1].repCount, 0);
    });

    test('Tracks up to 4 athletes simultaneously', () {
      final poses = List.generate(
        4,
        (i) => Pose(landmarks: {
          PoseLandmarkType.nose: PoseLandmark(
            type: PoseLandmarkType.nose,
            x: 100.0 + i * 150.0, y: 350, z: 0, likelihood: 0.9,
          ),
        }),
      );

      final players = tracker.processFramePoses(poses, const Size(720, 1280));
      expect(players.length, 4);
      expect(tracker.detectedPeopleCount, 4);
    });

    test('Rankings correctly sort by rep count descending', () {
      final mockP1 = MockPoseService()..mockReps = 5;
      tracker.setPlayerPoseServiceForTesting(0, mockP1);

      tracker.processFramePoses([
        Pose(landmarks: {PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 100, y: 300, z: 0, likelihood: 0.9)}),
        Pose(landmarks: {PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 300, y: 300, z: 0, likelihood: 0.9)}),
        Pose(landmarks: {PoseLandmarkType.nose: PoseLandmark(type: PoseLandmarkType.nose, x: 600, y: 300, z: 0, likelihood: 0.9)}),
      ], const Size(720, 1280));

      final mockP2 = MockPoseService()..mockReps = 14;
      final mockP3 = MockPoseService()..mockReps = 9;
      tracker.setPlayerPoseServiceForTesting(1, mockP2);
      tracker.setPlayerPoseServiceForTesting(2, mockP3);

      final ranked = tracker.getRankedPlayers();
      expect(ranked[0].repCount, 14);
      expect(ranked[1].repCount, 9);
      expect(ranked[2].repCount, 5);
    });
  });

  group('PrototypeBotEngine Tests', () {
    late PrototypeBotEngine bot;

    setUp(() {
      bot = PrototypeBotEngine();
    });

    tearDown(() {
      bot.dispose();
    });

    test('Initializes with default intermediate level and 0 reps', () {
      expect(bot.repCount, 0);
      expect(bot.level, BotLevel.intermediate);
      expect(bot.phase, BotPushupPhase.lockout);
      expect(bot.isRunning, false);
      expect(bot.hasSubmitted, false);
    });

    test('Starts and stops cleanly', () {
      bot.start();
      expect(bot.isRunning, true);
      expect(bot.hasSubmitted, false);
      bot.stop();
      expect(bot.isRunning, false);
    });

    test('Reset clears all state', () {
      bot.start();
      bot.reset();
      expect(bot.repCount, 0);
      expect(bot.isRunning, false);
      expect(bot.hasSubmitted, false);
    });

    test('Beginner bot targets 3-6 reps', () {
      bot.level = BotLevel.beginner;
      bot.start();
      // The target is set internally — we just verify it starts correctly
      expect(bot.isRunning, true);
      expect(bot.targetReps, inInclusiveRange(3, 6));
      bot.stop();
    });

    test('Advanced bot targets 8-15 reps', () {
      bot.level = BotLevel.advanced;
      bot.start();
      expect(bot.isRunning, true);
      expect(bot.targetReps, inInclusiveRange(8, 15));
      bot.stop();
    });
  });
}
