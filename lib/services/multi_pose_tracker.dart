import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_service.dart';

/// Represents a single tracked athlete in the workout session
class PlayerTrack {
  final int id;
  String name;
  final Color themeColor;
  final PoseService poseService;
  
  // Tracking state
  DateTime lastSeen;
  bool isPresent;
  Pose? currentPose;
  FrameAnalysis? lastAnalysis;
  double centroidX; // Normalized X position (0.0 = Left, 1.0 = Right)

  PlayerTrack({
    required this.id,
    required this.name,
    required this.themeColor,
    required this.poseService,
    required this.lastSeen,
    this.isPresent = true,
    this.currentPose,
    this.lastAnalysis,
    this.centroidX = 0.5,
  });

  int get repCount => poseService.repCount;
  int? get formScore => lastAnalysis?.formScore;
  String get feedback => lastAnalysis?.feedback ?? 'Ready';
  bool get isGoodForm => lastAnalysis?.isGoodForm ?? true;
}

/// Multi-Person Pose Tracker Engine
/// Dynamically tracks 1, 2, or more athletes in real-time, matching poses
/// to spatial slots (Left vs Right) so nobody loses their reps when resting.
class MultiPoseTracker {
  // Pre-configured player theme colors (Emerald, Amber, Cyan)
  static const List<Color> _kPlayerColors = [
    Color(0xFF00FF88), // Player 1: Neon Emerald
    Color(0xFFFFCC00), // Player 2: Cyber Amber
    Color(0xFF00E5FF), // Player 3: Electric Cyan
    Color(0xFFFF3D00), // Player 4: Deep Orange
  ];

  final List<PlayerTrack> _players = [];
  TrackingMode _mode = TrackingMode.sideProfile;

  // Maximum duration (seconds) to hold a player's score if they leave the camera frame
  static const Duration _kAbsenceGracePeriod = Duration(seconds: 45);

  MultiPoseTracker() {
    // Initialize default Player 1
    _players.add(PlayerTrack(
      id: 1,
      name: 'Player 1',
      themeColor: _kPlayerColors[0],
      poseService: PoseService()..mode = _mode,
      lastSeen: DateTime.now(),
      centroidX: 0.5,
    ));
  }

  // Getters
  List<PlayerTrack> get allPlayers => List.unmodifiable(_players);
  List<PlayerTrack> get activePlayers => _players.where((p) => p.isPresent || p.repCount > 0).toList();
  int get detectedPeopleCount => _players.where((p) => p.isPresent).length;
  TrackingMode get mode => _mode;

  set mode(TrackingMode newMode) {
    _mode = newMode;
    for (final player in _players) {
      player.poseService.mode = newMode;
    }
  }

  /// Process all poses detected by Google ML Kit in the current camera frame
  List<PlayerTrack> processFramePoses(List<Pose> detectedPoses, Size imageSize) {
    final now = DateTime.now();

    // Reset currentPose for all players so we only mark the ones actually detected this frame
    for (final player in _players) {
      player.currentPose = null;
    }

    if (detectedPoses.isNotEmpty) {
      for (final pose in detectedPoses) {
        final cx = _computePoseCentroidX(pose, imageSize.width);
        
        // Find closest existing player
        PlayerTrack? closestPlayer;
        double minDistance = double.infinity;
        
        for (final p in _players) {
          final dist = (p.centroidX - cx).abs();
          if (dist < minDistance) {
            minDistance = dist;
            closestPlayer = p;
          }
        }

        // If no player is close enough (e.g. > 0.2 screen width away) and we have < 4 players, create a new one!
        if ((closestPlayer == null || minDistance > 0.2) && _players.length < 4) {
          final newId = _players.length + 1;
          final color = _kPlayerColors[(newId - 1) % _kPlayerColors.length];
          final newPlayer = PlayerTrack(
            id: newId,
            name: 'Player $newId',
            themeColor: color,
            poseService: PoseService()..mode = _mode,
            lastSeen: now,
            centroidX: cx,
          );
          _players.add(newPlayer);
          closestPlayer = newPlayer;
        }

        // Assign the pose to the matched player
        if (closestPlayer != null) {
          closestPlayer.currentPose = pose;
          // Smooth the centroid update slightly so they don't jump around wildly
          closestPlayer.centroidX = (closestPlayer.centroidX * 0.7) + (cx * 0.3);
          closestPlayer.lastSeen = now;
          closestPlayer.isPresent = true;
          closestPlayer.lastAnalysis = closestPlayer.poseService.analyze(pose, imageSize);
        }
      }
    }

    // Sort players so Player 1 is visually on the left, Player 2 is next, etc.
    _players.sort((a, b) => a.centroidX.compareTo(b.centroidX));
    // Reassign IDs based on their left-to-right position to keep colors consistent
    for (int i = 0; i < _players.length; i++) {
      _players[i].name = 'Player ${i + 1}';
    }

    // Mark missing players as absent if they've been gone too long
    for (final player in _players) {
      if (player.currentPose == null) {
        if (now.difference(player.lastSeen) > _kAbsenceGracePeriod) {
          player.isPresent = false;
        }
      }
    }

    return _players;
  }

  /// Helper: Calculate the horizontal X-center of a person's body (normalized 0.0 - 1.0)
  double _computePoseCentroidX(Pose pose, double imageWidth) {
    if (imageWidth <= 0) return 0.5;

    final keyLandmarks = [
      pose.landmarks[PoseLandmarkType.nose],
      pose.landmarks[PoseLandmarkType.leftShoulder],
      pose.landmarks[PoseLandmarkType.rightShoulder],
      pose.landmarks[PoseLandmarkType.leftHip],
      pose.landmarks[PoseLandmarkType.rightHip],
    ];

    double sumX = 0;
    int count = 0;
    for (final lm in keyLandmarks) {
      if (lm != null && lm.likelihood > 0.3) {
        sumX += lm.x;
        count++;
      }
    }

    if (count == 0) return 0.5;
    return (sumX / count) / imageWidth;
  }

  /// Change a player's display name
  void setPlayerName(int playerIndex, String newName) {
    if (playerIndex >= 0 && playerIndex < _players.length) {
      _players[playerIndex].name = newName.trim().isEmpty 
          ? 'Player ${playerIndex + 1}' 
          : newName.trim();
    }
  }

  /// 1-Tap Swap: Swap Player 1 and Player 2 (in case athletes switch physical sides)
  void swapPlayers(int indexA, int indexB) {
    if (indexA >= 0 && indexA < _players.length && 
        indexB >= 0 && indexB < _players.length && 
        indexA != indexB) {
      final temp = _players[indexA];
      _players[indexA] = _players[indexB];
      _players[indexB] = temp;
    }
  }

  /// Reset all player workout counts
  void resetAll() {
    for (final player in _players) {
      player.poseService.reset();
      player.lastAnalysis = null;
    }
  }

  /// Reset a specific player's count
  void resetPlayer(int playerIndex) {
    if (playerIndex >= 0 && playerIndex < _players.length) {
      _players[playerIndex].poseService.reset();
      _players[playerIndex].lastAnalysis = null;
    }
  }
}
