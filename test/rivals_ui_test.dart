import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rivals/screens/home_screen.dart';
import 'package:rivals/screens/workout_screen.dart';
import 'package:rivals/screens/video_verification_screen.dart';
import 'package:rivals/screens/challenge_battle_screen.dart';
import 'package:rivals/screens/ranks_screen.dart';
import 'package:rivals/screens/community_screen.dart';
import 'package:rivals/screens/profile_screen.dart';
import 'package:rivals/services/rivals_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Rivals Working Model & State Tests', () {
    test('Initial user and workout state is consistent', () {
      final state = RivalsAppState.instance;
      expect(state.userName, 'Wasim R.');
      expect(state.level, 14);
      expect(state.overallFitnessScore, 84);
      expect(state.selectedExercise, 'Squat');
      expect(state.selectedWeight, 100.0);
    });

    testWidgets('Selecting weight and logging completed set increments XP and sets',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = RivalsAppState.instance;
      final initialXp = state.xp;
      final initialSet = state.currentSet;

      state.adjustWeight(5.0);
      expect(state.selectedWeight, 105.0);

      await tester.runAsync(() async {
        state.recordCompletedSet(reps: 6, weight: 105.0, formScore: 95);
        await Future.delayed(const Duration(milliseconds: 100));
      });

      expect(state.xp, initialXp + 150);
      expect(state.currentSet, initialSet < 5 ? initialSet + 1 : 5);
      expect(state.lastSetSummary, '105.0kg x 6');
    });

    test('1v1 rematch updates stats and rewards XP', () {
      final state = RivalsAppState.instance;
      final initialReps = state.userReps;
      final initialXp = state.xp;

      state.challengeAgainRematch();
      expect(state.userReps, initialReps + 5);
      expect(state.xp, initialXp + 250);
    });

    test('Gym challenge joining and social feed liking works', () {
      final state = RivalsAppState.instance;
      expect(state.isGymChallengeJoined('metroflex'), isFalse);

      state.toggleJoinGymChallenge('metroflex');
      expect(state.isGymChallengeJoined('metroflex'), isTrue);

      final post = state.posts.first;
      final initialLikes = post.likes;
      state.togglePostLike(post.id);
      expect(post.isLiked, isTrue);
      expect(post.likes, initialLikes + 1);
    });
  });

  group('Rivals UI Screen Rendering Tests', () {
    testWidgets('Renders HomeScreen with key elements from mockup 1',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ready to compete?'), findsOneWidget);
      expect(find.text('Overall Fitness score'), findsOneWidget);
      expect(find.text('Day Streak'), findsOneWidget);
      expect(find.text('Upper Body\nStrength'), findsOneWidget);
      expect(find.text('Weekly Goal'), findsOneWidget);
    });

    testWidgets('Renders WorkoutScreen with Set 3 of 5, weights and START SET',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: WorkoutScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('WORKOUT'), findsOneWidget);
      expect(find.text('START SET'), findsOneWidget);
      expect(find.text('Adaptive weight recommendations'), findsOneWidget);
      expect(find.text('PR Indicator'), findsOneWidget);
    });

    testWidgets('Renders VideoVerificationScreen with live telemetry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VideoVerificationScreen()),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('VIDEO VERIFICATION'), findsOneWidget);
      expect(find.text('Valid Reps: '), findsOneWidget);
      expect(find.textContaining('Angle'), findsOneWidget);
      expect(find.text('Full ROM'), findsOneWidget);
      expect(find.text('Tempo Pace'), findsOneWidget);
      expect(find.textContaining('FINISH SET'), findsOneWidget);
    });

    testWidgets('Renders ChallengeBattleScreen with 1v1 comparison',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ChallengeBattleScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHALLENGE'), findsOneWidget);
      expect(find.text('DEEP SQUAT DUEL'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(find.textContaining('START LIVE AI'), findsOneWidget);
      expect(find.text('Load Weight'), findsOneWidget);
      expect(find.text('Total Volume'), findsOneWidget);
    });

    testWidgets('Renders RanksScreen with City Fitness Rankings',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: RanksScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('CITY FITNESS RANKINGS'), findsOneWidget);
      expect(find.text('STRENGTH'), findsOneWidget);
      expect(find.text('CONSISTENCY'), findsOneWidget);
      expect(find.text('IMPROVEMENT'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
    });

    testWidgets('Renders CommunityScreen with Gym Discovery & Feed',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: CommunityScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gym Discovery'), findsOneWidget);
      expect(find.text('Activity Feed'), findsOneWidget);
      expect(find.text('MetroFlex Gym'), findsOneWidget);
    });

    testWidgets('Renders ProfileScreen with Level 14 and tabs',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: ProfileScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Level: 14'), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('CONSISTENCY'), findsOneWidget);
      expect(find.text('STATS'), findsOneWidget);
    });
  });
}
