import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:rivals/services/multi_pose_tracker.dart';

void main() {
  group('MultiPoseTracker Engine Tests', () {
    late MultiPoseTracker tracker;

    setUp(() {
      tracker = MultiPoseTracker();
    });

    test('Initializes with default Player 1 in Solo Mode', () {
      expect(tracker.allPlayers.length, 1);
      expect(tracker.allPlayers.first.name, 'Player 1');
      expect(tracker.allPlayers.first.repCount, 0);
    });

    test('Dynamic Auto-Joining: Expands to 2 players when 2 poses detected', () {
      final poseLeft = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(
          type: PoseLandmarkType.nose,
          x: 150, // Left side
          y: 300,
          z: 0,
          likelihood: 0.9,
        ),
      });

      final poseRight = Pose(landmarks: {
        PoseLandmarkType.nose: PoseLandmark(
          type: PoseLandmarkType.nose,
          x: 550, // Right side
          y: 300,
          z: 0,
          likelihood: 0.9,
        ),
      });

      final players = tracker.processFramePoses([poseLeft, poseRight], const Size(720, 1280));

      expect(players.length, 2);
      expect(players[0].name, 'Player 1');
      expect(players[1].name, 'Player 2');
      expect(players[0].isPresent, true);
      expect(players[1].isPresent, true);
    });

    test('Custom player renaming works properly', () {
      tracker.setPlayerName(0, 'Wasim');
      expect(tracker.allPlayers[0].name, 'Wasim');
    });

    test('1-Tap Slot Swapping works properly', () {
      // Add second player
      tracker.processFramePoses([
        Pose(landmarks: {}),
        Pose(landmarks: {}),
      ], const Size(720, 1280));

      tracker.setPlayerName(0, 'Player A');
      tracker.setPlayerName(1, 'Player B');

      tracker.swapPlayers(0, 1);

      expect(tracker.allPlayers[0].name, 'Player B');
      expect(tracker.allPlayers[1].name, 'Player A');
    });
  });
}
