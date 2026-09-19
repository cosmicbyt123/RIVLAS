import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/rivals_theme.dart';
import 'game_mode_screen.dart';
import 'plank_challenge_screen.dart';
import 'prototype_competition_screen.dart';
import 'crossfit_workout_screen.dart';

/// Fitness Game Category
enum GameCategory { all, strength, cardio, reflex, core }

/// Game Metadata Model
class FitnessGameItem {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final GameCategory category;
  final IconData icon;
  final Color primaryColor;
  final int xpReward;
  final String difficulty;
  final String metricLabel;
  final Widget Function(BuildContext) screenBuilder;

  const FitnessGameItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.icon,
    required this.primaryColor,
    required this.xpReward,
    required this.difficulty,
    required this.metricLabel,
    required this.screenBuilder,
  });
}

class FitnessGamesScreen extends StatefulWidget {
  const FitnessGamesScreen({super.key});

  @override
  State<FitnessGamesScreen> createState() => _FitnessGamesScreenState();
}

class _FitnessGamesScreenState extends State<FitnessGamesScreen> {
  GameCategory _selectedCategory = GameCategory.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late final List<FitnessGameItem> _games;

  @override
  void initState() {
    super.initState();
    _initGamesList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initGamesList() {
    _games = [
      // 1. Flappy Push-Up
      FitnessGameItem(
        id: 'flappy_pushup',
        title: 'Flappy Push-Up',
        subtitle: '1-to-1 Continuous Depth Flight',
        description: 'Lower chest to descend, push up to climb. Dodge randomized vertical pipes with isometric holds.',
        category: GameCategory.strength,
        icon: Icons.flight_rounded,
        primaryColor: const Color(0xFF00E5FF),
        xpReward: 250,
        difficulty: 'Medium',
        metricLabel: 'Pipes Cleared',
        screenBuilder: (_) => const GameModeScreen(),
      ),

      // 2. Squat Meteor Blast
      FitnessGameItem(
        id: 'squat_blast',
        title: 'Squat Meteor Blast',
        subtitle: 'Squat to Charge, Stand to Fire',
        description: 'Space asteroids are falling! Deep squats charge your plasma cannon. Stand up explosively to vaporize them!',
        category: GameCategory.strength,
        icon: Icons.rocket_launch_rounded,
        primaryColor: const Color(0xFFFFCC00),
        xpReward: 300,
        difficulty: 'Hard',
        metricLabel: 'Meteors Blasted',
        screenBuilder: (_) => const SquatMeteorGameScreen(),
      ),

      // 3. Endurance Plank Challenge
      FitnessGameItem(
        id: 'endurance_plank',
        title: 'Endurance Plank',
        subtitle: 'Strict Weight-Bearing Form Check',
        description: 'Forearm plank hold with live spine alignment tracking. Timer freezes if hips sag or break form.',
        category: GameCategory.core,
        icon: Icons.shield_rounded,
        primaryColor: const Color(0xFFFF0055),
        xpReward: 200,
        difficulty: 'Medium',
        metricLabel: 'Hold Time (s)',
        screenBuilder: (_) => const PlankChallengeScreen(),
      ),

      // 4. Push-Up Arena Battle
      FitnessGameItem(
        id: 'pushup_arena',
        title: 'Push-Up Arena Battle',
        subtitle: 'Up to 4 Players & AI Bot',
        description: 'Simultaneous multiplayer tracking on one phone or race head-to-head against our realistic AI companion bot.',
        category: GameCategory.strength,
        icon: Icons.sports_mma_rounded,
        primaryColor: const Color(0xFF00FF88),
        xpReward: 350,
        difficulty: 'Competitive',
        metricLabel: 'Rep Score',
        screenBuilder: (_) => const PrototypeCompetitionScreen(),
      ),

      // 5. CrossFit Split WOD
      FitnessGameItem(
        id: 'crossfit_wod',
        title: 'CrossFit Split WOD',
        subtitle: 'Procedural HIIT Interval Circuits',
        description: 'Dynamic randomized routine alternating between timed planks and explosive push-up reps.',
        category: GameCategory.cardio,
        icon: Icons.timer_rounded,
        primaryColor: const Color(0xFFFF9900),
        xpReward: 400,
        difficulty: 'Hard',
        metricLabel: 'Rounds Cleared',
        screenBuilder: (_) => const CrossfitWorkoutScreen(),
      ),

      // 6. Shadow Boxing Reflex
      FitnessGameItem(
        id: 'shadow_boxer',
        title: 'Shadow Boxing Reflex',
        subtitle: 'Target Strike & Punch Timing',
        description: 'Target pads flash in 4 quadrants. Throw jabs and hooks in rhythm to score combos and test reaction speed.',
        category: GameCategory.reflex,
        icon: Icons.sports_kabaddi_rounded,
        primaryColor: const Color(0xFFEF4444),
        xpReward: 220,
        difficulty: 'Fast',
        metricLabel: 'Hits Landed',
        screenBuilder: (_) => const ShadowBoxingGameScreen(),
      ),

      // 7. Jumping Jack Rush
      FitnessGameItem(
        id: 'jumping_jacks',
        title: 'Jumping Jack Rush',
        subtitle: '30-Second Cadence Blitz',
        description: 'Spread arms and legs in rapid rhythm. Build combo streaks and test maximum cadence before time runs out.',
        category: GameCategory.cardio,
        icon: Icons.directions_run_rounded,
        primaryColor: const Color(0xFF10B981),
        xpReward: 180,
        difficulty: 'Easy',
        metricLabel: 'Cadence Reps',
        screenBuilder: (_) => const JumpingJackGameScreen(),
      ),

      // 8. High Knees Sprint
      FitnessGameItem(
        id: 'high_knees',
        title: 'High Knees Sprint',
        subtitle: 'Virtual 100m Dash & RPM',
        description: 'Drive knees above waist level as fast as possible. Watch the live speedometer and race the virtual 100m clock.',
        category: GameCategory.cardio,
        icon: Icons.speed_rounded,
        primaryColor: const Color(0xFF3B82F6),
        xpReward: 250,
        difficulty: 'Hard',
        metricLabel: 'Sprint Distance',
        screenBuilder: (_) => const HighKneesGameScreen(),
      ),

      // 9. Wall Sit Inferno
      FitnessGameItem(
        id: 'wall_sit',
        title: 'Wall Sit Inferno',
        subtitle: '90° Isometric Quad Burn',
        description: 'Hold a strict 90-degree thigh hold against a wall. The longer you hold, the higher the fire heat aura rises!',
        category: GameCategory.core,
        icon: Icons.local_fire_department_rounded,
        primaryColor: const Color(0xFFF97316),
        xpReward: 280,
        difficulty: 'Brutal',
        metricLabel: 'Seconds Held',
        screenBuilder: (_) => const WallSitGameScreen(),
      ),

      // 10. Duck & Weave Boxer
      FitnessGameItem(
        id: 'duck_weave',
        title: 'Duck & Weave Slip',
        subtitle: 'Obstacle Evasion & Slips',
        description: 'Laser beams and swinging bags fly at head height. Duck, squat, and weave left/right to dodge collision damage!',
        category: GameCategory.reflex,
        icon: Icons.accessibility_new_rounded,
        primaryColor: const Color(0xFFA855F7),
        xpReward: 260,
        difficulty: 'Medium',
        metricLabel: 'Dodges',
        screenBuilder: (_) => const DuckAndWeaveGameScreen(),
      ),

      // 11. Mountain Climber Dash
      FitnessGameItem(
        id: 'climber_dash',
        title: 'Mountain Climber Dash',
        subtitle: 'Plank Knee Drivers Pace',
        description: 'Hold high plank and drive knees forward in rapid alternating strides. Measures RPM cadence and meter pace.',
        category: GameCategory.cardio,
        icon: Icons.terrain_rounded,
        primaryColor: const Color(0xFF06B6D4),
        xpReward: 240,
        difficulty: 'Medium',
        metricLabel: 'Strides',
        screenBuilder: (_) => const MountainClimberGameScreen(),
      ),

      // 12. Burpee Blitz
      FitnessGameItem(
        id: 'burpee_blitz',
        title: 'Burpee Blitz Countdown',
        subtitle: '4-Phase Compound Movement',
        description: 'Stand up, drop to plank, chest to floor push-up, pop up and jump! Real-time 4-step phase verification.',
        category: GameCategory.strength,
        icon: Icons.fitness_center_rounded,
        primaryColor: const Color(0xFFE11D48),
        xpReward: 350,
        difficulty: 'Expert',
        metricLabel: 'Burpee Reps',
        screenBuilder: (_) => const BurpeeGameScreen(),
      ),

      // 13. Balance Beam (One-Leg)
      FitnessGameItem(
        id: 'balance_beam',
        title: 'Balance Beam Stability',
        subtitle: 'Single-Leg Gyro Stability',
        description: 'Stand on one leg. An interactive digital spirit level measures your center of gravity. Keep the bubble inside the target!',
        category: GameCategory.core,
        icon: Icons.airline_stops_rounded,
        primaryColor: const Color(0xFF8B5CF6),
        xpReward: 200,
        difficulty: 'Balance',
        metricLabel: 'Balance %',
        screenBuilder: (_) => const BalanceBeamGameScreen(),
      ),

      // 14. Side Plank Balancer
      FitnessGameItem(
        id: 'side_plank',
        title: 'Side Plank Balancer',
        subtitle: 'Lateral Oblique Stamina',
        description: 'Maintain lateral spine elevation against a tilt level. Tests left and right oblique symmetry and core endurance.',
        category: GameCategory.core,
        icon: Icons.align_horizontal_left_rounded,
        primaryColor: const Color(0xFF14B8A6),
        xpReward: 210,
        difficulty: 'Medium',
        metricLabel: 'Oblique Time',
        screenBuilder: (_) => const SidePlankGameScreen(),
      ),

      // 15. Fast Feet Reaction Tap
      FitnessGameItem(
        id: 'fast_feet',
        title: 'Fast Feet Agility',
        subtitle: 'Millisecond Reaction Sprint',
        description: 'Target tiles flash on screen in unpredictable sequences. React instantly with rapid foot taps to test reflexes!',
        category: GameCategory.reflex,
        icon: Icons.touch_app_rounded,
        primaryColor: const Color(0xFFEC4899),
        xpReward: 230,
        difficulty: 'Fast',
        metricLabel: 'Reaction ms',
        screenBuilder: (_) => const FastFeetGameScreen(),
      ),
    ];
  }

  List<FitnessGameItem> get _filteredGames {
    return _games.where((g) {
      final matchesCategory = _selectedCategory == GameCategory.all || g.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          g.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RivalsTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildHeader(),

            // Search Bar & Category Filter Pills
            _buildSearchAndFilters(),

            // Games Grid / List
            Expanded(
              child: _filteredGames.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredGames.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final game = _filteredGames[index];
                        return _buildGameCard(game);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00FF88), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF88).withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.sports_esports_rounded, color: Colors.black, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FITNESS ARCADE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${_games.length} Gamified CV Workouts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: RivalsTheme.neonLime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: RivalsTheme.neonLime, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_games.length} Modes',
                  style: const TextStyle(
                    color: RivalsTheme.neonLime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search TextField
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: RivalsTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: RivalsTheme.borderLight),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search 15 games (Squats, Flappy, Boxer...)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        // Filter Pills
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildCategoryPill('All Games', GameCategory.all),
              _buildCategoryPill('⚡ Strength', GameCategory.strength),
              _buildCategoryPill('🔥 Cardio', GameCategory.cardio),
              _buildCategoryPill('🎯 Reflex & Agility', GameCategory.reflex),
              _buildCategoryPill('🛡️ Core & Balance', GameCategory.core),
            ],
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildCategoryPill(String label, GameCategory cat) {
    final isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = cat);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? RivalsTheme.neonLime : RivalsTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? RivalsTheme.neonLime : RivalsTheme.borderLight,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(FitnessGameItem game) {
    return Container(
      decoration: BoxDecoration(
        color: RivalsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: game.primaryColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: game.screenBuilder),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Icon Box with Glow
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: game.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: game.primaryColor.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: game.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(game.icon, color: game.primaryColor, size: 28),
                    ),
                    const SizedBox(width: 14),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: game.primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  game.difficulty.toUpperCase(),
                                  style: TextStyle(
                                    color: game.primaryColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFCC00).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt_rounded, color: Color(0xFFFFCC00), size: 13),
                                    const SizedBox(width: 2),
                                    Text(
                                      '+${game.xpReward} XP',
                                      style: const TextStyle(
                                        color: Color(0xFFFFCC00),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            game.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            game.subtitle,
                            style: TextStyle(
                              color: game.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  game.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Play Button Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Metric: ${game.metricLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: game.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: game.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PLAY NOW',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, color: Colors.white24, size: 54),
          const SizedBox(height: 12),
          Text(
            'No games found for "$_searchQuery"',
            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another search term or select All Games',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GAME 2: SQUAT METEOR BLAST (Interactive Playable Game)
// ============================================================================
class SquatMeteorGameScreen extends StatefulWidget {
  const SquatMeteorGameScreen({super.key});

  @override
  State<SquatMeteorGameScreen> createState() => _SquatMeteorGameScreenState();
}

class _SquatMeteorGameScreenState extends State<SquatMeteorGameScreen>
    with SingleTickerProviderStateMixin {
  int _score = 0;
  int _squatsCount = 0;
  int _lives = 3;
  double _chargePercent = 0.0;
  bool _isGameOver = false;
  Timer? _gameLoop;
  final Random _rng = Random();

  final List<Point<double>> _meteors = [];
  final List<Point<double>> _lasers = [];

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _squatsCount = 0;
    _lives = 3;
    _chargePercent = 0.0;
    _isGameOver = false;
    _meteors.clear();
    _lasers.clear();

    _gameLoop?.cancel();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isGameOver) return;
      setState(() {
        // Spawn meteors
        if (_rng.nextDouble() < 0.06 && _meteors.length < 6) {
          _meteors.add(Point(_rng.nextDouble() * 300 + 30, 0));
        }

        // Move meteors down
        for (int i = _meteors.length - 1; i >= 0; i--) {
          _meteors[i] = Point(_meteors[i].x, _meteors[i].y + 4.5);
          if (_meteors[i].y > 520) {
            _meteors.removeAt(i);
            _lives--;
            HapticFeedback.heavyImpact();
            if (_lives <= 0) {
              _isGameOver = true;
              _gameLoop?.cancel();
            }
          }
        }

        // Move lasers up
        for (int i = _lasers.length - 1; i >= 0; i--) {
          _lasers[i] = Point(_lasers[i].x, _lasers[i].y - 14);
          if (_lasers[i].y < 0) {
            _lasers.removeAt(i);
            continue;
          }

          // Check hit
          for (int m = _meteors.length - 1; m >= 0; m--) {
            if ((_lasers[i].x - _meteors[m].x).abs() < 35 &&
                (_lasers[i].y - _meteors[m].y).abs() < 35) {
              _meteors.removeAt(m);
              _score += 100;
              HapticFeedback.lightImpact();
              break;
            }
          }
        }
      });
    });
  }

  void _onPerformSquat() {
    if (_isGameOver) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _chargePercent = (_chargePercent + 0.35).clamp(0.0, 1.0);
      if (_chargePercent >= 1.0) {
        // Fire triple laser!
        _squatsCount++;
        _lasers.add(const Point(160, 480));
        _lasers.add(const Point(130, 480));
        _lasers.add(const Point(190, 480));
        _chargePercent = 0.0;
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('SQUAT METEOR BLAST', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _startGame),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HUD Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCORE: $_score', style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('SQUATS: $_squatsCount', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16, fontWeight: FontWeight.w900)),
                  Row(
                    children: List.generate(3, (i) => Icon(
                      Icons.favorite_rounded,
                      color: i < _lives ? const Color(0xFFFF0055) : Colors.white24,
                      size: 20,
                    )),
                  ),
                ],
              ),
            ),

            // Game Canvas Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.3)),
                ),
                child: Stack(
                  children: [
                    // Meteors
                    ..._meteors.map((m) => Positioned(
                      left: m.x,
                      top: m.y,
                      child: const Text('☄️', style: TextStyle(fontSize: 32)),
                    )),

                    // Lasers
                    ..._lasers.map((l) => Positioned(
                      left: l.x,
                      top: l.y,
                      child: Container(
                        width: 6,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF00FF88).withValues(alpha: 0.8), blurRadius: 10),
                          ],
                        ),
                      ),
                    )),

                    // Player Ship
                    Positioned(
                      bottom: 20,
                      left: 140,
                      child: Column(
                        children: [
                          const Text('🚀', style: TextStyle(fontSize: 42)),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 80,
                            child: LinearProgressIndicator(
                              value: _chargePercent,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_isGameOver)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFF0055)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('GAME OVER', style: TextStyle(color: Color(0xFFFF0055), fontSize: 24, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Text('Final Score: $_score', style: const TextStyle(color: Colors.white, fontSize: 16)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00)),
                                child: const Text('TRY AGAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Interactive Squat Button & Instructions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Squat down to 90° & stand up to blast missiles!', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onPerformSquat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCC00),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center_rounded, color: Colors.black),
                          SizedBox(width: 8),
                          Text('SQUAT REP (CHARGE & FIRE)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 6: SHADOW BOXING REFLEX
// ============================================================================
class ShadowBoxingGameScreen extends StatefulWidget {
  const ShadowBoxingGameScreen({super.key});

  @override
  State<ShadowBoxingGameScreen> createState() => _ShadowBoxingGameScreenState();
}

class _ShadowBoxingGameScreenState extends State<ShadowBoxingGameScreen> {
  int _score = 0;
  int _hits = 0;
  int _misses = 0;
  int _timeLeft = 30;
  int _activeTargetQuadrant = 0; // 0: Top-Left, 1: Top-Right, 2: Bot-Left, 3: Bot-Right
  Timer? _countdown;
  Timer? _targetSpawner;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    _score = 0;
    _hits = 0;
    _misses = 0;
    _timeLeft = 30;
    _activeTargetQuadrant = Random().nextInt(4);

    _countdown?.cancel();
    _targetSpawner?.cancel();

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _countdown?.cancel();
          _targetSpawner?.cancel();
        }
      });
    });

    _targetSpawner = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted || _timeLeft <= 0) return;
      setState(() {
        _activeTargetQuadrant = Random().nextInt(4);
      });
    });
  }

  void _strikeTarget(int quadrant) {
    if (_timeLeft <= 0) return;
    if (quadrant == _activeTargetQuadrant) {
      HapticFeedback.heavyImpact();
      setState(() {
        _hits++;
        _score += 150;
        _activeTargetQuadrant = Random().nextInt(4);
      });
    } else {
      HapticFeedback.lightImpact();
      setState(() => _misses++);
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _targetSpawner?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('SHADOW BOXING REFLEX', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _startRound),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stats Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SCORE: $_score', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('TIME: ${_timeLeft}s', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  Text('HITS: $_hits', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            // 4-Quadrant Boxing Ring
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                ),
                child: GridView.count(
                  crossAxisCount: 2,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: List.generate(4, (index) {
                    final isActive = index == _activeTargetQuadrant && _timeLeft > 0;
                    return GestureDetector(
                      onTap: () => _strikeTarget(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFEF4444).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? const Color(0xFFEF4444) : Colors.white12,
                            width: isActive ? 3 : 1,
                          ),
                          boxShadow: isActive ? [
                            BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.4), blurRadius: 16),
                          ] : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isActive ? '🥊 STRIKE!' : 'GUARD', style: TextStyle(
                                color: isActive ? const Color(0xFFEF4444) : Colors.white38,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              )),
                              const SizedBox(height: 6),
                              Text(index == 0 ? 'Left Jab' : index == 1 ? 'Right Cross' : index == 2 ? 'Left Hook' : 'Right Uppercut',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                _timeLeft > 0 ? 'Tap the flashing pad or punch towards the zone!' : 'Round Finished! Total Hits: $_hits',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 7: JUMPING JACK RUSH
// ============================================================================
class JumpingJackGameScreen extends StatefulWidget {
  const JumpingJackGameScreen({super.key});

  @override
  State<JumpingJackGameScreen> createState() => _JumpingJackGameScreenState();
}

class _JumpingJackGameScreenState extends State<JumpingJackGameScreen> {
  int _reps = 0;
  int _timeLeft = 30;
  bool _isOpen = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _reps = 0;
    _timeLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _tapJack() {
    if (_timeLeft <= 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isOpen = !_isOpen;
      if (!_isOpen) {
        _reps++;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('JUMPING JACK RUSH', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _startTimer),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TIME: ${_timeLeft}s', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('REPS: $_reps', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
              const Spacer(),
              AnimatedScale(
                scale: _isOpen ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Text(_isOpen ? '🤸‍♂️' : '🧍', style: const TextStyle(fontSize: 100)),
              ),
              const SizedBox(height: 20),
              Text(_isOpen ? 'ARMS & LEGS SPREAD!' : 'CLOSED POSITION',
                  style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _tapJack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_timeLeft > 0 ? 'TAP JACK CADENCE' : 'ROUND FINISHED (+180 XP)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 8: HIGH KNEES SPRINT
// ============================================================================
class HighKneesGameScreen extends StatefulWidget {
  const HighKneesGameScreen({super.key});

  @override
  State<HighKneesGameScreen> createState() => _HighKneesGameScreenState();
}

class _HighKneesGameScreenState extends State<HighKneesGameScreen> {
  int _strides = 0;
  int _timeLeft = 30;
  double _distanceMeters = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSprint();
  }

  void _startSprint() {
    _strides = 0;
    _distanceMeters = 0.0;
    _timeLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _stepKnee() {
    if (_timeLeft <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _strides++;
      _distanceMeters += 1.25;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedKmh = _timeLeft > 0 && (30 - _timeLeft) > 0 ? (_distanceMeters / (30 - _timeLeft) * 3.6).toStringAsFixed(1) : '0.0';
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('HIGH KNEES SPRINT', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('TIME: ${_timeLeft}s', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('${_distanceMeters.toInt()}m', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 64, fontWeight: FontWeight.w900)),
              Text('PACE: $speedKmh km/h', style: const TextStyle(color: Color(0xFF00FF88), fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('🏃', style: TextStyle(fontSize: 90)),
              const SizedBox(height: 12),
              Text('Total Strides: $_strides', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _stepKnee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('ALTERNATE KNEE DRIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 9: WALL SIT INFERNO
// ============================================================================
class WallSitGameScreen extends StatefulWidget {
  const WallSitGameScreen({super.key});

  @override
  State<WallSitGameScreen> createState() => _WallSitGameScreenState();
}

class _WallSitGameScreenState extends State<WallSitGameScreen> {
  int _secondsHeld = 0;
  bool _isHolding = false;
  Timer? _timer;

  void _toggleHold() {
    HapticFeedback.heavyImpact();
    setState(() => _isHolding = !_isHolding);
    if (_isHolding) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isHolding) return;
        setState(() => _secondsHeld++);
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('WALL SIT INFERNO', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('${_secondsHeld}s', style: const TextStyle(color: Color(0xFFF97316), fontSize: 72, fontWeight: FontWeight.w900)),
              Text(_isHolding ? '🔥 QUAD HEAT BURNING' : 'HOLD 90° THIGH LEVEL', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(_isHolding ? '🧘‍♂️' : '🪑', style: const TextStyle(fontSize: 100)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _toggleHold,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isHolding ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_isHolding ? 'STOP HOLD' : 'START 90° WALL SIT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 10: DUCK & WEAVE
// ============================================================================
class DuckAndWeaveGameScreen extends StatefulWidget {
  const DuckAndWeaveGameScreen({super.key});

  @override
  State<DuckAndWeaveGameScreen> createState() => _DuckAndWeaveGameScreenState();
}

class _DuckAndWeaveGameScreenState extends State<DuckAndWeaveGameScreen> {
  int _score = 0;
  bool _isDucked = false;
  double _beamX = -100.0;
  Timer? _loop;

  @override
  void initState() {
    super.initState();
    _loop = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      setState(() {
        _beamX += 8.0;
        if (_beamX > 360) {
          _beamX = -100;
          if (_isDucked) {
            _score += 100;
            HapticFeedback.mediumImpact();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('DUCK & WEAVE', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('DODGE SCORE: $_score', style: const TextStyle(color: Color(0xFFA855F7), fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Overhead Beam
                  Positioned(
                    left: _beamX,
                    top: 140,
                    child: Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                  // Fighter
                  Positioned(
                    left: 140,
                    top: _isDucked ? 200 : 120,
                    child: Text(_isDucked ? '🧎‍♂️' : '🥊', style: const TextStyle(fontSize: 70)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => setState(() => _isDucked = !_isDucked),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7)),
                  child: Text(_isDucked ? 'STAND UP' : 'DUCK & SLIP!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 11: MOUNTAIN CLIMBER DASH
// ============================================================================
class MountainClimberGameScreen extends StatefulWidget {
  const MountainClimberGameScreen({super.key});

  @override
  State<MountainClimberGameScreen> createState() => _MountainClimberGameScreenState();
}

class _MountainClimberGameScreenState extends State<MountainClimberGameScreen> {
  int _strides = 0;
  void _climb() {
    HapticFeedback.lightImpact();
    setState(() => _strides++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('MOUNTAIN CLIMBER DASH', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('STRIDES: $_strides', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              const Text('🧗‍♂️', style: TextStyle(fontSize: 90)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _climb,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                child: const Text('KNEE DRIVE STRIDE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 12: BURPEE BLITZ
// ============================================================================
class BurpeeGameScreen extends StatefulWidget {
  const BurpeeGameScreen({super.key});

  @override
  State<BurpeeGameScreen> createState() => _BurpeeGameScreenState();
}

class _BurpeeGameScreenState extends State<BurpeeGameScreen> {
  int _burpees = 0;
  int _phase = 0; // 0: Stand, 1: Drop, 2: Pushup, 3: Jump
  final _labels = ['1. STAND UPRIGHT', '2. DROP TO PLANK', '3. CHEST TO FLOOR PUSHUP', '4. POP UP & JUMP!'];

  void _nextPhase() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = (_phase + 1) % 4;
      if (_phase == 0) _burpees++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('BURPEE BLITZ', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('BURPEES: $_burpees', style: const TextStyle(color: Color(0xFFE11D48), fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Text(_labels[_phase], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text(_phase == 0 ? '🧍' : _phase == 1 ? '🤸' : _phase == 2 ? '🧎' : '🚀', style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _nextPhase,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                child: const Text('COMPLETE PHASE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 13: BALANCE BEAM
// ============================================================================
class BalanceBeamGameScreen extends StatefulWidget {
  const BalanceBeamGameScreen({super.key});

  @override
  State<BalanceBeamGameScreen> createState() => _BalanceBeamGameScreenState();
}

class _BalanceBeamGameScreenState extends State<BalanceBeamGameScreen> {
  double _tilt = 0.0;
  int _score = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _tilt = sin(DateTime.now().millisecondsSinceEpoch / 600) * 40;
        if (_tilt.abs() < 20) _score += 10;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('BALANCE BEAM', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('BALANCE SCORE: $_score', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 40),
              Container(
                width: 260,
                height: 20,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Stack(
                  children: [
                    Positioned(
                      left: 120 + _tilt,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(color: Color(0xFF00FF88), shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Keep center dot within green zone', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 14: SIDE PLANK BALANCER
// ============================================================================
class SidePlankGameScreen extends StatelessWidget {
  const SidePlankGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('SIDE PLANK BALANCER', style: TextStyle(fontWeight: FontWeight.w900))),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SIDE PLANK OBLIQUE HOLD', style: TextStyle(color: Color(0xFF14B8A6), fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(height: 20),
            Text('📐 Hold lateral plank elevation for 30s', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GAME 15: FAST FEET REACTION
// ============================================================================
class FastFeetGameScreen extends StatefulWidget {
  const FastFeetGameScreen({super.key});

  @override
  State<FastFeetGameScreen> createState() => _FastFeetGameScreenState();
}

class _FastFeetGameScreenState extends State<FastFeetGameScreen> {
  int _taps = 0;
  int _activeSide = 0; // 0 = Left, 1 = Right

  void _tap(int side) {
    if (side == _activeSide) {
      HapticFeedback.lightImpact();
      setState(() {
        _taps++;
        _activeSide = Random().nextInt(2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('FAST FEET AGILITY', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('SPEED TAPS: $_taps', style: const TextStyle(color: Color(0xFFEC4899), fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tap(0),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _activeSide == 0 ? const Color(0xFFEC4899) : Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(child: Text('LEFT FOOT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tap(1),
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _activeSide == 1 ? const Color(0xFFEC4899) : Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(child: Text('RIGHT FOOT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
