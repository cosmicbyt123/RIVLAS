import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import 'workout_screen.dart';
import 'video_verification_screen.dart';
import 'challenge_battle_screen.dart';
import 'prototype_competition_screen.dart';
import 'game_mode_screen.dart';
import 'profile_screen.dart';

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

                const SizedBox(height: 14),

                // 2. RIVALS Pitch Deck Motto & Philosophy Banner
                _buildRivalsMottoBanner(context),

                const SizedBox(height: 18),

                // 3. Ready to compete? Header
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

                // 4. Fitness Score Dial & Today's Workout Card
                _buildFitnessScoreCard(context, state),

                const SizedBox(height: 20),

                // 5. 4-Card Stats Grid (Streak, XP, Rank, Challenges)
                _buildStatsGrid(state),

                const SizedBox(height: 18),

                // 6. RIVALS Manifesto: Why Conventional Fitness Apps Fail
                _buildCompetitorTeardownCard(context),

                const SizedBox(height: 18),

                // 7. Friend PR Highlight Banner
                _buildFriendPRBanner(context),

                const SizedBox(height: 18),

                // 8. Weekly Goal Progress Bar
                _buildWeeklyGoalCard(state),

                const SizedBox(height: 24),

                // 9. Quick Arena Modes Carousel
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
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
                      const Icon(Icons.verified_user_rounded, color: RivalsTheme.neonLime, size: 14),
                    ],
                  ),
                  const Text(
                    'Tap to view Profile',
                    style: TextStyle(color: RivalsTheme.neonLime, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildRoundIconBtn(
              icon: Icons.person_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _buildRoundIconBtn(
              icon: Icons.edit_note_rounded,
              onTap: () => _showEditProfileDialog(context, state),
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

  /// Slogan & Brand Vision Banner from Rival.pdf
  Widget _buildRivalsMottoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RivalsTheme.neonLime.withValues(alpha: 0.14),
            const Color(0xFF141914),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: RivalsTheme.neonLime.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RivalsTheme.neonLime.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: RivalsTheme.neonLime, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: RivalsTheme.neonLime.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'THE HUB OF FITNESS',
                        style: TextStyle(
                          color: RivalsTheme.neonLime,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AI-VERIFIED',
                      style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Every one day has a day one',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Grind Together • Grow Together',
                  style: TextStyle(color: RivalsTheme.neonLime, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showRivalsManifestoModal(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: RivalsTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: RivalsTheme.neonLime, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Vision',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Competitor Teardown Card (Slide 8 & Slide 2 of Rival.pdf)
  Widget _buildCompetitorTeardownCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RivalsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RivalsTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE RIVALS REVOLUTION',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Why Other Apps Fail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showRivalsManifestoModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RivalsTheme.neonLime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Read PPT →',
                    style: TextStyle(
                      color: RivalsTheme.neonLime,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Conventional fitness apps track data but never create true motivation. Hollow streaks & badges don\'t care if you completed the workout. RIVALS brings verified social competition.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          // 4 Competitor Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCompetitorMiniBadge('Cult.fit', 'Subscription Traps', Colors.deepOrangeAccent),
              _buildCompetitorMiniBadge('Healthify', 'Calorie Burnout', Colors.tealAccent),
              _buildCompetitorMiniBadge('Strava', 'Solo Running Loops', Colors.orangeAccent),
              _buildCompetitorMiniBadge('Hevy', 'Repetitive Logging', Colors.lightBlueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitorMiniBadge(String name, String flaw, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF161C16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Text(
            '• $flaw',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Full RIVALS Pitch Deck Manifesto Modal (Slides 1–9 from Rival.pdf)
  void _showRivalsManifestoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101510),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.3)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: RivalsTheme.neonLime.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RivalsTheme.neonLime),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: RivalsTheme.neonLime, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RIVALS PITCH DECK & VISION',
                          style: TextStyle(
                            color: RivalsTheme.neonLime,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'The Hub Of Fitness',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Slogan Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      RivalsTheme.neonLime.withValues(alpha: 0.2),
                      const Color(0xFF172017),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“Every one day has a day one”',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Grind Together • Grow Together',
                      style: TextStyle(
                        color: RivalsTheme.neonLime,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Section 1: Problem Statement (Slide 2)
              _buildManifestoSectionHeader('THE PROBLEM STATEMENT', Icons.error_outline_rounded, Colors.redAccent),
              const SizedBox(height: 10),
              _buildManifestoCard(
                title: 'Conventional Fitness Apps Lack Real Motivation',
                body: '• Most fitness apps just track numbers without creating motivation.\n'
                    '• Generic workout and diet plans that treat every human like a robot.\n'
                    '• Existing gamification is mostly empty streaks and badges—they never care if you completed the task or cheated.\n'
                    '• Logging sets manually feels like an endless chore with no real accountability.',
              ),
              const SizedBox(height: 18),

              // Section 2: Competitor Teardowns (Slide 8)
              _buildManifestoSectionHeader('OUR RIVALS & THEIR FLAWS', Icons.compare_arrows_rounded, Colors.amber),
              const SizedBox(height: 10),
              _buildCompetitorQuoteCard('CULT.FIT', '“Come for fitness, stay for subscriptions, classes, and notifications.”', Colors.deepOrangeAccent),
              const SizedBox(height: 8),
              _buildCompetitorQuoteCard('HEALTHIFY', '“Count every calorie until you forget why you started.”', Colors.tealAccent),
              const SizedBox(height: 8),
              _buildCompetitorQuoteCard('STRAVA', '“Because apparently your morning run needs a leaderboard.”', Colors.orangeAccent),
              const SizedBox(height: 8),
              _buildCompetitorQuoteCard('HEVY', '“Log the workout, admire the numbers, repeat the same grind.”', Colors.lightBlueAccent),
              const SizedBox(height: 18),

              // Section 3: The Solution (Slides 3 & 4)
              _buildManifestoSectionHeader('THE RIVALS SOLUTION (USP)', Icons.verified_rounded, RivalsTheme.neonLime),
              const SizedBox(height: 10),
              _buildManifestoCard(
                title: 'We Turn Fitness Into a Verified Social Competition',
                body: '1. Real-Time Fitness Competition: Compete head-to-head live.\n'
                    '2. AI-Verified Performance: Computer vision (Google ML Kit BlazePose) tracks biomechanics with zero cheating.\n'
                    '3. Fitness As a Game: Mountain ascent, bot races, and Flappy Push-Up arcade.\n'
                    '4. Connect the Digital & Physical Fitness World: Bridge home workouts, gym communities, trainers, and friends.',
              ),
              const SizedBox(height: 18),

              // Section 4: Value Proposition Matrix (Slide 5)
              _buildManifestoSectionHeader('STAKEHOLDER VALUE ECOSYSTEM', Icons.groups_rounded, Colors.cyanAccent),
              const SizedBox(height: 10),
              _buildStakeholderRow('Users / Athletes', 'Motivation, competition, recognition, measurable verified improvement.'),
              _buildStakeholderRow('Friends', 'Grind Together: A way to challenge, race, and compete with each other.'),
              _buildStakeholderRow('Gyms', 'Community engagement, customer acquisition, visibility, and member retention.'),
              _buildStakeholderRow('Creators & Trainers', 'Audience, credibility, and competitive verified AI challenges.'),
              _buildStakeholderRow('Brands', 'Access to an active, fitness-focused, anti-cheat verified community.'),
              const SizedBox(height: 18),

              // Section 5: Market Opportunity (Slide 6)
              _buildManifestoSectionHeader('MARKET OPPORTUNITIES', Icons.trending_up_rounded, RivalsTheme.neonLime),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RivalsTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RivalsTheme.borderLight),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MarketStatWidget('TAM', '₹20–30 Cr', 'Total Market'),
                    _MarketStatWidget('SAM', '₹5–8 Cr', 'Active Youth'),
                    _MarketStatWidget('SOM', '₹50L–1.5 Cr', 'Years 2–3'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManifestoSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildManifestoCard({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RivalsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RivalsTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitorQuoteCard(String name, String quote, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141914),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              name,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quote,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontStyle: FontStyle.italic, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStakeholderRow(String role, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RivalsTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role,
              style: const TextStyle(color: RivalsTheme.neonLime, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketStatWidget extends StatelessWidget {
  final String label;
  final String value;
  final String desc;

  const _MarketStatWidget(this.label, this.value, this.desc);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: RivalsTheme.neonLime, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }
}
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