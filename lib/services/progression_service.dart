import 'package:flutter/foundation.dart';
import 'stats_service.dart';

/// Milestone checkpoint on the Mountain
class MountainMilestone {
  final double altitudeMeters;
  final String name;
  final String description;
  final String emoji;

  const MountainMilestone({
    required this.altitudeMeters,
    required this.name,
    required this.description,
    required this.emoji,
  });
}

/// A logged workout entry in the athlete's career history
class WorkoutLog {
  final String id;
  final String athleteName;
  final int reps;
  final int plankSeconds;
  final int formScore;
  final double altitudeGained;
  final DateTime timestamp;

  const WorkoutLog({
    required this.id,
    required this.athleteName,
    required this.reps,
    this.plankSeconds = 0,
    required this.formScore,
    required this.altitudeGained,
    required this.timestamp,
  });
}

/// Singleton Progression Service
/// Converts push-ups into mountain climbing elevation (1 Rep = 5 Meters)
/// and manages streak, altitude state, and unlockable milestones.
class ProgressionService extends ChangeNotifier {
  static final ProgressionService _instance = ProgressionService._internal();
  static ProgressionService get instance => _instance;

  ProgressionService._internal();

  // Metrics
  int _totalCareerReps = 0;
  double _currentAltitude = 0.0;
  double _previousAltitude = 0.0; // Used to animate from old altitude to new altitude
  int _streakDays = 1;
  DateTime? _lastWorkoutDate;
  final List<WorkoutLog> _workoutHistory = [];

  // Elevation scale: 1 Push-up = 5 Meters of vertical climb
  static const double kMetersPerRep = 5.0;

  // Mountain Milestones
  static const List<MountainMilestone> kMilestones = [
    MountainMilestone(
      altitudeMeters: 50.0,
      name: 'Novice Plateau',
      description: 'First steps on the mountain base',
      emoji: '🏕️',
    ),
    MountainMilestone(
      altitudeMeters: 250.0,
      name: 'Warrior Ridge',
      description: 'Climbing above the alpine tree line',
      emoji: '🌲',
    ),
    MountainMilestone(
      altitudeMeters: 1000.0,
      name: 'Cloud Break Summit',
      description: 'Piercing through the dense cloud blanket',
      emoji: '☁️',
    ),
    MountainMilestone(
      altitudeMeters: 3000.0,
      name: 'Stratosphere Gate',
      description: 'High altitude mountain crown',
      emoji: '🏔️',
    ),
    MountainMilestone(
      altitudeMeters: 8000.0,
      name: 'Everest Crown',
      description: 'Highest peak on earth',
      emoji: '👑',
    ),
    MountainMilestone(
      altitudeMeters: 15000.0,
      name: 'Celestial Orbit',
      description: 'Climbing into the cosmic stars',
      emoji: '✨',
    ),
  ];

  // Getters
  int get totalCareerReps => _totalCareerReps;
  double get currentAltitude => _currentAltitude;
  double get previousAltitude => _previousAltitude;
  int get streakDays => _streakDays;
  List<WorkoutLog> get workoutHistory => List.unmodifiable(_workoutHistory);

  MountainMilestone? get currentMilestone {
    for (int i = kMilestones.length - 1; i >= 0; i--) {
      if (_currentAltitude >= kMilestones[i].altitudeMeters) {
        return kMilestones[i];
      }
    }
    return null;
  }

  MountainMilestone get nextMilestone {
    for (final m in kMilestones) {
      if (_currentAltitude < m.altitudeMeters) {
        return m;
      }
    }
    return kMilestones.last;
  }

  /// Adds a completed workout and calculates elevation gained
  void addWorkoutReps({
    required String athleteName,
    required int reps,
    required int formScore,
    int plankSeconds = 0,
  }) {
    if (reps <= 0 && plankSeconds <= 0) return;

    _previousAltitude = _currentAltitude;
    final double gained = reps * kMetersPerRep;

    _totalCareerReps += reps;
    _currentAltitude += gained;

    // Save to persistent storage
    StatsService.addPushups(reps);

    // Update streak
    final now = DateTime.now();
    if (_lastWorkoutDate == null) {
      _streakDays = 1;
    } else {
      final daysDiff = now.difference(_lastWorkoutDate!).inDays;
      if (daysDiff == 1) {
        _streakDays += 1;
      } else if (daysDiff > 1) {
        _streakDays = 1; // Streak reset
      }
    }
    _lastWorkoutDate = now;

    // Log entry
    _workoutHistory.insert(0, WorkoutLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      athleteName: athleteName,
      reps: reps,
      plankSeconds: plankSeconds,
      formScore: formScore,
      altitudeGained: gained,
      timestamp: now,
    ));

    notifyListeners();
  }

  /// Set base altitude for testing/initial state
  void setAltitude(double newAltitude) {
    _previousAltitude = _currentAltitude;
    _currentAltitude = newAltitude;
    _totalCareerReps = (newAltitude / kMetersPerRep).round();
    notifyListeners();
  }

  /// Reset altitude
  void reset() {
    _totalCareerReps = 0;
    _currentAltitude = 0.0;
    _previousAltitude = 0.0;
    _streakDays = 1;
    _workoutHistory.clear();
    notifyListeners();
  }
}
