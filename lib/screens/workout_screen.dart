import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import 'video_verification_screen.dart';
import 'prototype_competition_screen.dart';
import 'game_mode_screen.dart';
import 'crossfit_workout_screen.dart';
import 'plank_challenge_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RivalsTheme.background,
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'WORKOUT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
            onPressed: () => _showExerciseOptions(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: RivalsAppState.instance,
          builder: (context, _) {
            final state = RivalsAppState.instance;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Exercise Switcher Card
                _buildExerciseSwitcherCard(context, state),

                const SizedBox(height: 20),

                // 2. Big Set Counter ("Set 3 of 5")
                _buildSetHeader(state),

                const SizedBox(height: 18),

                // 3. Goal & Last Set Stats Row
                _buildSetStatsRow(state),

                const SizedBox(height: 14),

                // 4. PR Indicator & Rest Timer Banner
                _buildRestTimerBanner(state),

                const SizedBox(height: 24),

                // 5. Adaptive Weight Recommendations
                _buildAdaptiveWeightSection(state),

                const SizedBox(height: 28),

                // 6. Big Neon Lime "START SET" Button
                _buildStartSetButton(context, state),

                const SizedBox(height: 32),

                // 7. Arena & Computer Vision Training Suites
                _buildTrainingSuitesSection(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildExerciseSwitcherCard(
      BuildContext context, RivalsAppState state) {
    return GestureDetector(
      onTap: () => _showExercisePicker(context, state),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: RivalsTheme.cardDecoration(
          color: RivalsTheme.surfaceElevated,
          glow: true,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RivalsTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: RivalsTheme.neonLime.withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: RivalsTheme.neonLime,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT EXERCISE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.selectedExercise,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: RivalsTheme.neonLime, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSetHeader(RivalsAppState state) {
    return Center(
      child: Column(
        children: [
          Text(
            'Set ${state.currentSet} of ${state.totalSets}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(state.totalSets, (index) {
              final isCompleted = index < state.currentSet - 1;
              final isCurrent = index == state.currentSet - 1;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 24 : 14,
                height: 6,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? RivalsTheme.neonLime
                      : (isCompleted
                          ? RivalsTheme.neonLime.withValues(alpha: 0.4)
                          : const Color(0xFF2B322B)),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSetStatsRow(RivalsAppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: RivalsTheme.cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Goal:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.goalReps} Reps',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Container(width: 1, height: 32, color: Colors.white10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Last Set:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                state.lastSetSummary,
                style: const TextStyle(
                  color: RivalsTheme.neonLime,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerBanner(RivalsAppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: RivalsTheme.cardDecoration(
        color: RivalsTheme.surfaceElevated,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // PR Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: RivalsTheme.neonLime.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: RivalsTheme.neonLime.withValues(alpha: 0.6),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up_rounded,
                    color: RivalsTheme.neonLime, size: 14),
                SizedBox(width: 6),
                Text(
                  'PR Indicator',
                  style: TextStyle(
                    color: RivalsTheme.neonLime,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Rest Timer
          GestureDetector(
            onTap: () => state.toggleRestTimer(),
            child: Row(
              children: [
                Icon(
                  state.isRestTimerRunning
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: RivalsTheme.neonLime,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Wait: ${state.restRemaining} sec',
                  style: TextStyle(
                    color: state.isRestTimerRunning
                        ? RivalsTheme.neonLime
                        : Colors.white70,
                    fontSize: 13,
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

  Widget _buildAdaptiveWeightSection(RivalsAppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Adaptive weight recommendations',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.white54, size: 20),
                  onPressed: () => state.adjustWeight(-2.5),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 6),
                Text(
                  '${state.selectedWeight.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    color: RivalsTheme.neonLime,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white54, size: 20),
                  onPressed: () => state.adjustWeight(2.5),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: state.adaptiveWeights.map((w) {
            final isSelected = (state.selectedWeight - w).abs() < 0.1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => state.selectWeight(w),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? RivalsTheme.neonLime
                          : RivalsTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? RivalsTheme.neonLime
                            : RivalsTheme.borderLight,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: RivalsTheme.neonLime
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${w.toInt()}kg',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartSetButton(BuildContext context, RivalsAppState state) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoVerificationScreen(
              exerciseTitle: state.selectedExercise,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: RivalsTheme.neonLime,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: RivalsTheme.neonLime.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'START SET',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrainingSuitesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'More Training Arenas',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _buildArenaTile(
          context: context,
          title: 'Push-Up Arena',
          subtitle: 'Multiplayer 1-4 Athletes or Battle Bot',
          icon: Icons.sports_mma_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PrototypeCompetitionScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildArenaTile(
          context: context,
          title: 'Flappy Push-Up',
          subtitle: 'Gamified depth control arcade',
          icon: Icons.sports_esports_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GameModeScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildArenaTile(
          context: context,
          title: 'Crossfit AMRAP & EMOM',
          subtitle: 'Interval computer vision tracker',
          icon: Icons.timer_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CrossfitWorkoutScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildArenaTile(
          context: context,
          title: 'Plank Isometric Challenge',
          subtitle: 'Spine line angle and core stability tracker',
          icon: Icons.accessibility_new_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PlankChallengeScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildArenaTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: RivalsTheme.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: RivalsTheme.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: RivalsTheme.neonLime, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  void _showExercisePicker(BuildContext context, RivalsAppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RivalsTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Exercise',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ...state.exercisesList.map(
                (ex) {
                  final isSelected = ex == state.selectedExercise;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: isSelected
                        ? RivalsTheme.neonLime.withValues(alpha: 0.15)
                        : null,
                    leading: Icon(
                      Icons.fitness_center_rounded,
                      color: isSelected
                          ? RivalsTheme.neonLime
                          : Colors.white60,
                    ),
                    title: Text(
                      ex,
                      style: TextStyle(
                        color: isSelected ? RivalsTheme.neonLime : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: RivalsTheme.neonLime)
                        : null,
                    onTap: () {
                      state.setExercise(ex);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExerciseOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RivalsTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: Colors.white),
                title: const Text('Reset Set Progression',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  RivalsAppState.instance.currentSet = 1;
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined,
                    color: RivalsTheme.neonLime),
                title: const Text('Reset Rest Timer (90s)',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  RivalsAppState.instance.resetRestTimer();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}