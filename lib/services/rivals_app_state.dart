import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progression_service.dart';

class RivalsPost {
  final String id;
  final String authorName;
  final String authorHandle;
  final String timeAgo;
  final String content;
  final String exercise;
  final String? badgeText;
  int likes;
  bool isLiked;
  final List<String> comments;

  RivalsPost({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.timeAgo,
    required this.content,
    required this.exercise,
    this.badgeText,
    required this.likes,
    this.isLiked = false,
    required this.comments,
  });
}

class GymLocation {
  final String id;
  final String name;
  final double rating;
  final String distance;
  final int activeMembers;
  final int liveChallenges;
  final String featuredActivity;
  final double mapX; // 0.0 to 1.0 relative map position
  final double mapY;

  const GymLocation({
    required this.id,
    required this.name,
    required this.rating,
    required this.distance,
    required this.activeMembers,
    required this.liveChallenges,
    required this.featuredActivity,
    required this.mapX,
    required this.mapY,
  });
}

class RivalsAppState extends ChangeNotifier {
  static final RivalsAppState instance = RivalsAppState._internal();
  RivalsAppState._internal() {
    _initRestTimer();
    _loadSavedUserData();
  }

  // Athlete Profile State
  String userName = 'Wasim R.';
  String userAvatar = '⚡';
  int level = 14;
  int xp = 12500;
  int nextLevelXp = 15000;
  int overallFitnessScore = 84;
  int dayStreak = 34;
  int cityRank = 18;
  int activeChallengesCount = 3;
  int weeklyGoalCurrent = 84;
  int weeklyGoalTarget = 1000;
  int personalBest = 238;
  int wins = 8;
  int losses = 2;
  int badgesCount = 24;
  int totalHours = 207;

  // Active Workout Session State
  String selectedExercise = 'Squat';
  final List<String> exercisesList = const [
    'Squat',
    'Push-ups',
    'Bench Press',
    'Deadlift',
    'Pull-ups',
  ];

  int currentSet = 3;
  int totalSets = 5;
  int goalReps = 8;
  String lastSetSummary = '100kg x 8';
  double selectedWeight = 100.0;
  List<double> adaptiveWeights = [90.0, 100.0, 110.0];

  // Rest Timer State
  int restDuration = 90;
  int restRemaining = 90;
  bool isRestTimerRunning = false;
  Timer? _restTimer;

  // 1v1 Battle State (Realistic Gym Data)
  String battleExercise = 'Squat';
  String battleTitle = 'DEEP SQUAT DUEL';
  String opponentName = 'Rohan Sharma';
  String opponentAvatar = '🦁';
  // Realistic Metrics for 1v1 Battle
  int userWeightLifted = 110; // kg
  int opponentWeightLifted = 115;
  int userReps = 22;
  int opponentReps = 20;
  int userVolume = 2420; // 22 reps * 110kg = 2420kg volume
  int opponentVolume = 2300; // 20 reps * 115kg = 2300kg volume
  int userProgress = 86; // 86° depth (below parallel)
  int opponentProgress = 89; // 89° depth
  String battleTimeRemaining = '2H 14M';

  // Persistence
  Future<void> _loadSavedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('rivals_user_name');
      final savedAvatar = prefs.getString('rivals_user_avatar');
      if (savedName != null && savedName.isNotEmpty) {
        userName = savedName;
      }
      if (savedAvatar != null && savedAvatar.isNotEmpty) {
        userAvatar = savedAvatar;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateProfile({required String name, String? avatar}) async {
    if (name.trim().isNotEmpty) {
      userName = name.trim();
    }
    if (avatar != null && avatar.isNotEmpty) {
      userAvatar = avatar;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rivals_user_name', userName);
      await prefs.setString('rivals_user_avatar', userAvatar);
    } catch (_) {}
  }

  void setBattleExercise(String exercise) {
    battleExercise = exercise;
    if (exercise == 'Squat') {
      battleTitle = 'DEEP SQUAT DUEL';
      userWeightLifted = 110;
      opponentWeightLifted = 115;
      userReps = 22;
      opponentReps = 20;
      userVolume = 2420;
      opponentVolume = 2300;
      userProgress = 86;
      opponentProgress = 89;
    } else if (exercise == 'Push-ups') {
      battleTitle = 'PUSH-UP ARENA DUEL';
      userWeightLifted = 72; // bodyweight
      opponentWeightLifted = 75;
      userReps = 48;
      opponentReps = 44;
      userVolume = 3456;
      opponentVolume = 3300;
      userProgress = 94; // form quality %
      opponentProgress = 91;
    } else {
      battleTitle = 'BENCH PRESS BATTLE';
      userWeightLifted = 90;
      opponentWeightLifted = 95;
      userReps = 18;
      opponentReps = 16;
      userVolume = 1620;
      opponentVolume = 1520;
      userProgress = 92;
      opponentProgress = 90;
    }
    notifyListeners();
  }

  // Gym Discovery State
  int selectedGymIndex = 0;
  final List<GymLocation> gyms = const [
    GymLocation(
      id: 'metroflex',
      name: 'MetroFlex Gym',
      rating: 4.8,
      distance: '0.8 mi',
      activeMembers: 112,
      liveChallenges: 3,
      featuredActivity: 'Dawson N. hit a new 150kg Bench PR!',
      mapX: 0.52,
      mapY: 0.44,
    ),
    GymLocation(
      id: 'iron_temple',
      name: 'Iron Temple Hub',
      rating: 4.9,
      distance: '1.4 mi',
      activeMembers: 89,
      liveChallenges: 2,
      featuredActivity: 'Elena R. dominated the 3-minute Plank!',
      mapX: 0.28,
      mapY: 0.32,
    ),
    GymLocation(
      id: 'olympus',
      name: 'Olympus Fitness Club',
      rating: 4.7,
      distance: '2.1 mi',
      activeMembers: 145,
      liveChallenges: 4,
      featuredActivity: 'Marcus V. completed 450 Pull-ups challenge.',
      mapX: 0.74,
      mapY: 0.62,
    ),
  ];

  final Set<String> joinedChallengeGymIds = {};

  // Social Feed Posts
  final List<RivalsPost> posts = [
    RivalsPost(
      id: 'p1',
      authorName: 'Rohan Sharma',
      authorHandle: '@rohan_squats',
      timeAgo: '2 hrs ago',
      content: 'Rohan Sharma hit 140kg x 8 Deep Squats! (AI Verified parallel depth)',
      exercise: 'Squat',
      badgeText: 'Verified Depth',
      likes: 38,
      isLiked: false,
      comments: [
        'Insane hip drive bhai!',
        'Let\'s do a 1v1 Squat battle tomorrow 🔥',
      ],
    ),
    RivalsPost(
      id: 'p2',
      authorName: 'Priya Nair',
      authorHandle: '@priya_athlete',
      timeAgo: '4 hrs ago',
      content: 'Priya Nair won the 50 Bodyweight Squats Sprint in 82 sec!',
      exercise: 'Squat',
      badgeText: 'Champion',
      likes: 54,
      isLiked: true,
      comments: [
        'Unreal speed and lockout ⚡',
        'Consistency beast!',
      ],
    ),
    RivalsPost(
      id: 'p3',
      authorName: 'Vikram Rathore',
      authorHandle: '@vikram_iron',
      timeAgo: '6 hrs ago',
      content: 'Vikram logged 48 clean Push-ups with chest-to-deck lockout.',
      exercise: 'Push-ups',
      badgeText: 'Form 98%',
      likes: 29,
      isLiked: false,
      comments: [
        'Challenge him to a 1v1 duel bro!',
      ],
    ),
  ];

  // Workout Actions
  void setExercise(String exercise) {
    selectedExercise = exercise;
    if (exercise == 'Bench Press') {
      selectedWeight = 80.0;
      adaptiveWeights = [75.0, 80.0, 85.0];
      lastSetSummary = '80kg x 6';
    } else if (exercise == 'Squat') {
      selectedWeight = 110.0;
      adaptiveWeights = [100.0, 110.0, 120.0];
      lastSetSummary = '110kg x 5';
    } else if (exercise == 'Deadlift') {
      selectedWeight = 140.0;
      adaptiveWeights = [130.0, 140.0, 150.0];
      lastSetSummary = '140kg x 4';
    } else {
      selectedWeight = 0.0;
      adaptiveWeights = [15.0, 20.0, 25.0];
      lastSetSummary = 'Bodyweight x 25';
    }
    notifyListeners();
  }

  void selectWeight(double weight) {
    selectedWeight = weight;
    notifyListeners();
  }

  void adjustWeight(double delta) {
    selectedWeight = (selectedWeight + delta).clamp(0.0, 500.0);
    notifyListeners();
  }

  void recordCompletedSet({required int reps, double? weight, int formScore = 94}) {
    lastSetSummary = '${weight ?? selectedWeight}kg x $reps';
    if (currentSet < totalSets) {
      currentSet++;
    }
    xp += 150;
    weeklyGoalCurrent = (weeklyGoalCurrent + reps).clamp(0, weeklyGoalTarget);
    overallFitnessScore = (overallFitnessScore + 1).clamp(0, 100);

    // Sync with ProgressionService
    ProgressionService.instance.addWorkoutReps(
      athleteName: userName,
      reps: reps,
      formScore: formScore,
    );

    startRestTimer();
    notifyListeners();
  }

  // Rest Timer Control
  void _initRestTimer() {
    restRemaining = restDuration;
  }

  void startRestTimer() {
    _restTimer?.cancel();
    restRemaining = restDuration;
    isRestTimerRunning = true;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restRemaining > 0) {
        restRemaining--;
        notifyListeners();
      } else {
        isRestTimerRunning = false;
        timer.cancel();
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void toggleRestTimer() {
    if (isRestTimerRunning) {
      _restTimer?.cancel();
      isRestTimerRunning = false;
    } else {
      if (restRemaining == 0) restRemaining = restDuration;
      isRestTimerRunning = true;
      _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (restRemaining > 0) {
          restRemaining--;
          notifyListeners();
        } else {
          isRestTimerRunning = false;
          timer.cancel();
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void resetRestTimer() {
    _restTimer?.cancel();
    restRemaining = restDuration;
    isRestTimerRunning = false;
    notifyListeners();
  }

  // 1v1 Battle Rematch Simulation
  void challengeAgainRematch() {
    userReps += 5;
    userWeightLifted += 8;
    userVolume += 40;
    userProgress += 18;
    xp += 250;
    if (userProgress > opponentProgress) {
      wins++;
    }
    notifyListeners();
  }

  // Gym Discovery
  void selectGym(int index) {
    if (index >= 0 && index < gyms.length) {
      selectedGymIndex = index;
      notifyListeners();
    }
  }

  void toggleJoinGymChallenge(String gymId) {
    if (joinedChallengeGymIds.contains(gymId)) {
      joinedChallengeGymIds.remove(gymId);
    } else {
      joinedChallengeGymIds.add(gymId);
      xp += 100;
    }
    notifyListeners();
  }

  bool isGymChallengeJoined(String gymId) => joinedChallengeGymIds.contains(gymId);

  // Social Actions
  void togglePostLike(String postId) {
    final postIndex = posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      post.isLiked = !post.isLiked;
      post.likes += post.isLiked ? 1 : -1;
      notifyListeners();
    }
  }

  void addPostComment(String postId, String comment) {
    if (comment.trim().isEmpty) return;
    final postIndex = posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      posts[postIndex].comments.add(comment.trim());
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }
}
