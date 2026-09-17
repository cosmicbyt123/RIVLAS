import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rivals/services/progression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressionService Tests', () {
    late ProgressionService progression;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      progression = ProgressionService.instance;
      progression.reset();
    });

    test('Initializes with 0 altitude and 0 reps', () {
      expect(progression.currentAltitude, 0.0);
      expect(progression.totalCareerReps, 0);
      expect(progression.workoutHistory.isEmpty, true);
    });

    test('addWorkoutReps correctly calculates elevation at 5m per rep', () {
      progression.addWorkoutReps(
        athleteName: 'Wasim',
        reps: 20,
        formScore: 92,
      );

      expect(progression.totalCareerReps, 20);
      expect(progression.currentAltitude, 100.0); // 20 * 5m = 100m
      expect(progression.previousAltitude, 0.0);
      expect(progression.workoutHistory.length, 1);
      expect(progression.workoutHistory.first.athleteName, 'Wasim');
    });

    test('Calculates next milestone correctly', () {
      // 0m => Next is Novice Plateau (50m)
      expect(progression.nextMilestone.name, 'Novice Plateau');

      // Add 12 reps => 60m => Current is Novice Plateau, Next is Warrior Ridge (250m)
      progression.addWorkoutReps(athleteName: 'Wasim', reps: 12, formScore: 90);
      expect(progression.currentMilestone?.name, 'Novice Plateau');
      expect(progression.nextMilestone.name, 'Warrior Ridge');
    });
  });
}
