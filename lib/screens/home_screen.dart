import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import 'workout_screen.dart';
import 'video_verification_screen.dart';
import 'challenge_battle_screen.dart';
import 'prototype_competition_screen.dart';
import 'game_mode_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RivalsTheme.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: RivalsAppState.instance,
          builder: (context, _) {
            final state = RivalsAppState.instance;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Top User Bar
                _buildTopUserBar(context, state),

                const SizedBox(height: 20),

                // 2. Ready to compete? Header
                const Text(
                  'Ready to compete?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Fitness Score Dial & Today's Workout Card
                _buildFitnessScoreCard(context, state),

                const SizedBox(height: 20),

                // 4. 4-Card Stats Grid (Streak, XP, Rank, Challenges)
                _buildStatsGrid(state),

                const SizedBox(height: 18),

                // 5. Friend PR Highlight Banner
                _buildFriendPRBanner(context),

                const SizedBox(height: 18),

                // 6. Weekly Goal Progress Bar
                _buildWeeklyGoalCard(state),

                const SizedBox(height: 24),

                // 7. Quick Arena Modes Carousel
                _buildArenaModesCarousel(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopUserBar(BuildContext context, RivalsAppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => _showEditProfileDialog(context, state),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RivalsTheme.surfaceHighlight,
                  border: Border.all(color: RivalsTheme.neonLime, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: RivalsTheme.neonLime.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(state.userAvatar, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        state.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, color: RivalsTheme.neonLime, size: 14),
                    ],
                  ),
                  const Text(
                    'Overall',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildRoundIconBtn(
              icon: Icons.edit_note_rounded,
              onTap: () => _showEditProfileDialog(context, state),
            ),
            const SizedBox(width: 8),
            _buildRoundIconBtn(
              icon: Icons.notifications_none_rounded,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundIconBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: RivalsTheme.surfaceElevated,
          shape: BoxShape.circle,
          border: Border.all(color: RivalsTheme.borderLight),
        ),
        child: Icon(icon, color: Colors.white70, size: 19),
      ),
    );
  }

  Widget _buildFitnessScoreCard(BuildContext context, RivalsAppState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: RivalsTheme.cardDecoration(
        color: RivalsTheme.surfaceElevated,
        glow: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Fitness score',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Radial Gauge
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _RadialScoreGaugePainter(
                    score: state.overallFitnessScore,
                  ),
                  child: Center(
                    child: Text(
                      '${state.overallFitnessScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),

              // Today's Workout Card
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WorkoutScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RivalsTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: RivalsTheme.neonLime.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Workout:",
                              style: TextStyle(
                                color:
                                    RivalsTheme.neonLime.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: RivalsTheme.neonLime, size: 12),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Upper Body\nStrength',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '5 Sets • Bench & Arms',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(RivalsAppState state) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatTile(
          value: '${state.dayStreak}',
          label: 'Day Streak',
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFFF8800),
        ),
        _buildStatTile(
          value: '${state.xp}',
          label: 'XP',
          icon: Icons.bolt_rounded,
          iconColor: RivalsTheme.neonLime,
        ),
        _buildStatTile(
          value: 'Rank ${state.cityRank}',
          label: '(City)',
          icon: Icons.shield_rounded,
          iconColor: RivalsTheme.trophyGold,
        ),
        _buildStatTile(
          value: '${state.activeChallengesCount}',
          label: 'Challenges Active',
          icon: Icons.sports_mma_rounded,
          iconColor: Colors.cyanAccent,
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: RivalsTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendPRBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChallengeBattleScreen(
              opponentName: 'Rohan Sharma',
              battleTitle: 'DEEP SQUAT DUEL',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: RivalsTheme.cardDecoration(
          color: RivalsTheme.surfaceElevated,
          activeBorder: true,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: RivalsTheme.surfaceHighlight,
              ),
              child: const Center(
                child: Text('🦁', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Friends Activity',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  Text(
                    'Rohan Sharma hit 140kg Squat PR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: RivalsTheme.neonLime, size: 14),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, RivalsAppState state) {
    final controller = TextEditingController(text: state.userName);
    String selectedAvatar = state.userAvatar;
    final avatars = ['⚡', '🦁', '🥊', '🔥', '👑', '🦾', '🏆', '🎯'];

    showModalBottomSheet(
      context: context,
      backgroundColor: RivalsTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Athlete Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CHOOSE AVATAR',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: avatars.map((av) {
                      final isSel = av == selectedAvatar;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedAvatar = av),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSel ? RivalsTheme.neonLime.withValues(alpha: 0.25) : RivalsTheme.surfaceHighlight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? RivalsTheme.neonLime : Colors.white12,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(av, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ATHLETE NAME',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: RivalsTheme.surfaceHighlight,
                      hintText: 'Enter your name (e.g. Wasim, Rohan, Alex)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.person, color: RivalsTheme.neonLime),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      if (controller.text.trim().isNotEmpty) {
                        state.updateProfile(
                          name: controller.text.trim(),
                          avatar: selectedAvatar,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: RivalsTheme.surfaceHighlight,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: RivalsTheme.neonLime),
                            ),
                            content: Text(
                              'Profile updated: ${controller.text.trim()}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: RivalsTheme.neonLime,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: RivalsTheme.neonLime.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'SAVE PROFILE',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeeklyGoalCard(RivalsAppState state) {
    final progress =
        (state.weeklyGoalCurrent / state.weeklyGoalTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RivalsTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Goal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${state.weeklyGoalCurrent} / ${state.weeklyGoalTarget}',
                style: const TextStyle(
                  color: RivalsTheme.neonLime,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF222822),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(RivalsTheme.neonLime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaModesCarousel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured AI Modes',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildArenaModeCard(
                title: 'Video Verification',
                subtitle: 'Live Barbell & Squat Tracking',
                badge: 'AI COMPUTER VISION',
                icon: Icons.videocam_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VideoVerificationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildArenaModeCard(
                title: 'Push-Up Arena',
                subtitle: 'Multiplayer 1-4 Athletes / Bot',
                badge: 'MULTIPLAYER ARENA',
                icon: Icons.sports_mma_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrototypeCompetitionScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildArenaModeCard(
                title: 'Flappy Push-Up',
                subtitle: 'Arcade Isometric Depth Control',
                badge: 'GAMIFIED TRAINING',
                icon: Icons.sports_esports_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GameModeScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArenaModeCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: RivalsTheme.cardDecoration(
          color: RivalsTheme.surfaceElevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: RivalsTheme.neonLime, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: RivalsTheme.neonLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: RivalsTheme.neonLime,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Painter for the circular radial fitness gauge
class _RadialScoreGaugePainter extends CustomPainter {
  final int score;

  _RadialScoreGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFF222B22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Neon Lime Progress Arc
    final progressPaint = Paint()
      ..color = RivalsTheme.neonLime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100.0) * 2 * pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialScoreGaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}