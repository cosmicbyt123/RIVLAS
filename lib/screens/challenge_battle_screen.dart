import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import 'video_verification_screen.dart';

class ChallengeBattleScreen extends StatefulWidget {
  final String? opponentName;
  final String? battleTitle;

  const ChallengeBattleScreen({
    super.key,
    this.opponentName,
    this.battleTitle,
  });

  @override
  State<ChallengeBattleScreen> createState() => _ChallengeBattleScreenState();
}

class _ChallengeBattleScreenState extends State<ChallengeBattleScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isRematching = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onChallengeAgain() {
    setState(() => _isRematching = true);
    final state = RivalsAppState.instance;
    state.challengeAgainRematch();

    _animController.reset();
    _animController.forward();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: RivalsTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: RivalsTheme.neonLime, width: 1.5),
        ),
        content: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: RivalsTheme.neonLime),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rematch round registered! +5 Reps, +250 XP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isRematching = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RivalsTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CHALLENGE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: RivalsAppState.instance,
        builder: (context, _) {
          final state = RivalsAppState.instance;
          final oppName = widget.opponentName ?? state.opponentName;
          final title = widget.battleTitle ?? state.battleTitle;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Exercise Battle Mode Switcher
                  Container(
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: RivalsTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RivalsTheme.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['Squat', 'Push-ups', 'Bench Press'].map((ex) {
                        final isSel = state.battleExercise == ex;
                        return GestureDetector(
                          onTap: () {
                            state.setBattleExercise(ex);
                            _animController.reset();
                            _animController.forward();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? RivalsTheme.neonLime : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              ex == 'Squat'
                                  ? '🏋️ SQUATS'
                                  : (ex == 'Push-ups' ? '🥊 PUSH-UPS' : '⚡ BENCH'),
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Battle Header
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.userName} vs $oppName',
                    style: const TextStyle(
                      color: RivalsTheme.neonLime,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 1v1 Versus Cards
                  _buildVersusSection(state, oppName),

                  const SizedBox(height: 28),

                  // Comparative Battle Progress Bars
                  _buildComparisonMetrics(state),

                  const SizedBox(height: 24),

                  // Countdown Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: RivalsTheme.neonLime, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'ENDS IN: ${state.battleTimeRemaining}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Primary: Live Camera Verification Challenge Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoVerificationScreen(
                            exerciseTitle: state.battleExercise,
                            isChallengeMode: true,
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
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, color: Colors.black, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'START LIVE AI ${state.battleExercise.toUpperCase()} CHALLENGE',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secondary: Instant Rematch Simulation Button
                  GestureDetector(
                    onTap: _isRematching ? null : _onChallengeAgain,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: RivalsTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.6)),
                      ),
                      child: Center(
                        child: _isRematching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: RivalsTheme.neonLime,
                                ),
                              )
                            : const Text(
                                'QUICK REMATCH SIMULATOR (+5 Reps, +250 XP)',
                                style: TextStyle(
                                  color: RivalsTheme.neonLime,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVersusSection(RivalsAppState state, String oppName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // User
        _buildPlayerCard(
          name: state.userName,
          isUser: true,
          badgeColor: RivalsTheme.neonLime,
          avatarEmoji: state.userAvatar,
        ),

        // Neon VS Badge
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: RivalsTheme.surfaceHighlight,
            shape: BoxShape.circle,
            border: Border.all(
              color: RivalsTheme.neonLime.withValues(alpha: 0.7),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: RivalsTheme.neonLime.withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'VS',
              style: TextStyle(
                color: RivalsTheme.neonLime,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),

        // Opponent
        _buildPlayerCard(
          name: oppName,
          isUser: false,
          badgeColor: Colors.cyanAccent,
          avatarEmoji: state.opponentAvatar,
        ),
      ],
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required bool isUser,
    required Color badgeColor,
    required String avatarEmoji,
  }) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RivalsTheme.surfaceHighlight,
            border: Border.all(
              color: badgeColor,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withValues(alpha: 0.3),
                blurRadius: 14,
              ),
            ],
          ),
          child: Center(
            child: Text(
              avatarEmoji,
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonMetrics(RivalsAppState state) {
    final isSquat = state.battleExercise == 'Squat';
    final isPushup = state.battleExercise == 'Push-ups';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: RivalsTheme.cardDecoration(
        color: RivalsTheme.surfaceElevated,
      ),
      child: Column(
        children: [
          _buildDualBar(
            title: isPushup ? 'Body Weight' : 'Load Weight',
            leftVal: '${state.userWeightLifted} kg',
            rightVal: '${state.opponentWeightLifted} kg',
            leftRatio: state.userWeightLifted /
                (state.userWeightLifted + state.opponentWeightLifted),
          ),
          const SizedBox(height: 18),
          _buildDualBar(
            title: 'Valid Reps',
            leftVal: '${state.userReps}',
            rightVal: '${state.opponentReps}',
            leftRatio: state.userReps / (state.userReps + state.opponentReps),
          ),
          const SizedBox(height: 18),
          _buildDualBar(
            title: isSquat ? 'Parallel Depth' : 'Form Score',
            leftVal: isSquat ? '${state.userProgress}°' : '${state.userProgress}%',
            rightVal: isSquat ? '${state.opponentProgress}°' : '${state.opponentProgress}%',
            leftRatio: state.userProgress /
                (state.userProgress + state.opponentProgress),
          ),
          const SizedBox(height: 18),
          _buildDualBar(
            title: 'Total Volume',
            leftVal: '${state.userVolume} kg',
            rightVal: '${state.opponentVolume} kg',
            leftRatio:
                state.userVolume / (state.userVolume + state.opponentVolume),
          ),
        ],
      ),
    );
  }

  Widget _buildDualBar({
    required String title,
    required String leftVal,
    required String rightVal,
    required double leftRatio,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftVal,
              style: const TextStyle(
                color: RivalsTheme.neonLime,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              rightVal,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final t = _animController.value;
            final currentRatio = (leftRatio * t).clamp(0.05, 0.95);

            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (currentRatio * 100).toInt(),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: RivalsTheme.neonLime,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      flex: ((1.0 - currentRatio) * 100).toInt(),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF333E33),
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
