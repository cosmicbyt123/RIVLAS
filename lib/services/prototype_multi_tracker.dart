import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_service.dart';
import 'multi_pose_tracker.dart';

/// Prototype Multi-Athlete Tracking Engine for up to 4 Athletes
/// Uses Selfie Camera Mode tracking without altering any core pose code.
/// Features Anti-Swap Centroid Proximity Matching so existing players' reps
/// are strictly preserved when new participants join the frame.
class PrototypeMultiTracker {
  static const int kMaxPlayers = 4;

  // Distinct Cyber-Athletic Neon Themes for up to 4 athletes
  static const List<Color> kPlayerColors = [
    Color(0xFF00FF88), // Player 1: Neon Emerald
    Color(0xFFFFCC00), // Player 2: Cyber Amber
    Color(0xFF00E5FF), // Player 3: Electric Cyan
    Color(0xFFE040FB), // Player 4: Neon Magenta
  ];

  final List<PlayerTrack> _players = [];
  TrackingMode _mode = TrackingMode.selfieCamera;

  // Maximum duration to retain an athlete's slot and reps if they step away
  static const Duration _kAbsenceGracePeriod = Duration(seconds: 60);

  PrototypeMultiTracker() {
    // Initialize default Player 1
    _players.add(PlayerTrack(
      id: 1,
      name: 'Player 1',
      themeColor: kPlayerColors[0],
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

  /// Process all poses detected by ML Kit in the current camera frame.
  /// Uses Proximity-Based Centroid Association to prevent slot swapping.
  List<PlayerTrack> processFramePoses(List<Pose> detectedPoses, Size imageSize) {
    final now = DateTime.now();

    // 1. If no poses detected, mark all current players as resting/absent
    if (detectedPoses.isEmpty) {
      for (final player in _players) {
        player.currentPose = null;
        if (now.difference(player.lastSeen) > _kAbsenceGracePeriod) {
          player.isPresent = false;
        }
      }
      return _players;
    }

    // 2. Compute the horizontal X-centroid (0.0 to 1.0) of each detected pose
    final List<_DetectedPose> poseCandidates = [];
    for (final pose in detectedPoses) {
      final cx = _computePoseCentroidX(pose, imageSize.width);
      poseCandidates.add(_DetectedPose(pose: pose, centroidX: cx));
    }

    // Limit to max 4 detectable candidates
    if (poseCandidates.length > kMaxPlayers) {
      poseCandidates.removeRange(kMaxPlayers, poseCandidates.length);
    }

    // 3. Proximity-Based Bipartite Association
    // Existing active players with reps > 0 or recent presence get priority
    // to match with the closest detected pose so reps are NEVER swapped.
    final Set<int> matchedPoseIndices = {};
    final Set<int> matchedPlayerIndices = {};

    // Sort existing players: prioritize those with reps > 0
    final List<int> playerIndicesByPriority = List.generate(_players.length, (i) => i);
    playerIndicesByPriority.sort((a, b) {
      final repDiff = _players[b].repCount.compareTo(_players[a].repCount);
      if (repDiff != 0) return repDiff;
      return _players[b].isPresent ? 1 : -1;
    });

    for (final pIdx in playerIndicesByPriority) {
      final player = _players[pIdx];
      double closestDistance = double.infinity;
      int bestPoseIdx = -1;

      for (int i = 0; i < poseCandidates.length; i++) {
        if (matchedPoseIndices.contains(i)) continue;

        final double distance = (poseCandidates[i].centroidX - player.centroidX).abs();
        if (distance < closestDistance) {
          closestDistance = distance;
          bestPoseIdx = i;
        }
      }

      // If reasonably close (within 0.40 screen width) or if it's the only pose available
      if (bestPoseIdx != -1 && (closestDistance <= 0.40 || poseCandidates.length == 1)) {
        matchedPoseIndices.add(bestPoseIdx);
        matchedPlayerIndices.add(pIdx);

        final matched = poseCandidates[bestPoseIdx];
        player.currentPose = matched.pose;
        player.centroidX = matched.centroidX;
        player.lastSeen = now;
        player.isPresent = true;

        // Run independent rep analysis
        player.lastAnalysis = player.poseService.analyze(matched.pose, imageSize);
      }
    }

    // 4. Handle Unmatched Poses (New players joining the frame)
    for (int i = 0; i < poseCandidates.length; i++) {
      if (matchedPoseIndices.contains(i)) continue;

      final newPose = poseCandidates[i];

      // Try to find an existing empty or inactive player slot without reps
      int slotIdx = -1;
      for (int p = 0; p < _players.length; p++) {
        if (!matchedPlayerIndices.contains(p) && !_players[p].isPresent && _players[p].repCount == 0) {
          slotIdx = p;
          break;
        }
      }

      // If no reusable slot and we haven't hit max 4 players, create a new slot
      if (slotIdx == -1 && _players.length < kMaxPlayers) {
        final newId = _players.length + 1;
        final color = kPlayerColors[(newId - 1) % kPlayerColors.length];
        _players.add(PlayerTrack(
          id: newId,
          name: 'Player $newId',
          themeColor: color,
          poseService: PoseService()..mode = _mode,
          lastSeen: now,
          centroidX: newPose.centroidX,
        ));
        slotIdx = _players.length - 1;
      }

      if (slotIdx != -1) {
        matchedPlayerIndices.add(slotIdx);
        final player = _players[slotIdx];
        player.currentPose = newPose.pose;
        player.centroidX = newPose.centroidX;
        player.lastSeen = now;
        player.isPresent = true;
        player.lastAnalysis = player.poseService.analyze(newPose.pose, imageSize);
      }
    }

    // 5. Mark remaining unmatched players as absent for this frame
    for (int p = 0; p < _players.length; p++) {
      if (!matchedPlayerIndices.contains(p)) {
        final player = _players[p];
        player.currentPose = null;
        if (now.difference(player.lastSeen) > _kAbsenceGracePeriod) {
          player.isPresent = false;
        }
      }
    }

    return _players;
  }

  /// Helper: Calculate horizontal X-centroid (0.0 - 1.0) of a person's upper body
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
      if (lm != null && lm.likelihood > 0.25) {
        sumX += lm.x;
        count++;
      }
    }

    if (count == 0) return 0.5;
    return ((sumX / count) / imageWidth).clamp(0.0, 1.0);
  }

  /// Change a player's display name
  void setPlayerName(int playerIndex, String newName) {
    if (playerIndex >= 0 && playerIndex < _players.length) {
      _players[playerIndex].name = newName.trim().isEmpty
          ? 'Player ${playerIndex + 1}'
          : newName.trim();
    }
  }

  /// Get ranked participants (sorted by rep count descending, then form score)
  List<PlayerTrack> getRankedPlayers() {
    final ranked = List<PlayerTrack>.from(_players);
    ranked.sort((a, b) {
      final repCmp = b.repCount.compareTo(a.repCount);
      if (repCmp != 0) return repCmp;
      final formA = a.formScore ?? 80;
      final formB = b.formScore ?? 80;
      return formB.compareTo(formA);
    });
    return ranked;
  }

  /// Reset all player workout counts
  void resetAll() {
    for (final player in _players) {
      player.poseService.reset();
      player.lastAnalysis = null;
    }
  }

  /// Testing helper: inject custom/mock pose service for a player slot
  void setPlayerPoseServiceForTesting(int index, PoseService service) {
    if (index >= 0 && index < _players.length) {
      final old = _players[index];
      _players[index] = PlayerTrack(
        id: old.id,
        name: old.name,
        themeColor: old.themeColor,
        poseService: service,
        lastSeen: old.lastSeen,
        isPresent: old.isPresent,
        currentPose: old.currentPose,
        lastAnalysis: old.lastAnalysis,
        centroidX: old.centroidX,
      );
    }
  }
}

class _DetectedPose {
  final Pose pose;
  final double centroidX;
  _DetectedPose({required this.pose, required this.centroidX});
}
