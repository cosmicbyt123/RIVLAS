import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import '../services/progression_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          'PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: RivalsAppState.instance,
          builder: (context, _) {
            final state = RivalsAppState.instance;

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Profile Header Card (Avatar, Alex R., Level 14, XP Bar)
                        _buildProfileHero(state),

                        const SizedBox(height: 16),

                        // Segmented Tab Switcher: [ OVERVIEW ] [ CONSISTENCY ] [ STATS ]
                        Container(
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: RivalsTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: RivalsTheme.borderLight),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: RivalsTheme.neonLime,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.white70,
                            labelStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'OVERVIEW'),
                              Tab(text: 'CONSISTENCY'),
                              Tab(text: 'STATS'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(state),
                  _buildConsistencyTab(state),
                  _buildStatsTab(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHero(RivalsAppState state) {
    final xpProgress = (state.xp % 2500) / 2500.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: RivalsTheme.cardDecoration(
        color: RivalsTheme.surfaceElevated,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showEditProfileDialog(context, state),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RivalsTheme.surfaceHighlight,
                    border: Border.all(color: RivalsTheme.neonLime, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: RivalsTheme.neonLime.withValues(alpha: 0.3),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(state.userAvatar, style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            state.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('👑', style: TextStyle(fontSize: 14)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: RivalsTheme.neonLime.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit_rounded, color: RivalsTheme.neonLime, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(color: RivalsTheme.neonLime, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    const Text(
                      'Overall Fitness',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: RivalsTheme.neonLime.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: RivalsTheme.neonLime
                                    .withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            'Level: ${state.level}',
                            style: const TextStyle(
                              color: RivalsTheme.neonLime,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.xp} XP',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 6,
              backgroundColor: const Color(0xFF222B22),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(RivalsTheme.neonLime),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Overview Tab
  Widget _buildOverviewTab(RivalsAppState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
      physics: const BouncingScrollPhysics(),
      children: [
        // Fitness Score Radial Dial & Personal Best
        Container(
          padding: const EdgeInsets.all(18),
          decoration: RivalsTheme.cardDecoration(),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _RadialDialPainter(score: state.overallFitnessScore),
                  child: Center(
                    child: Text(
                      '${state.overallFitnessScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Fitness Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMiniStat('PERSONAL', '${state.personalBest}'),
                        const SizedBox(width: 24),
                        _buildMiniStat(
                            'WIN / LOSS', '${state.wins} / ${state.losses}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Badges Section
        const Text(
          'BADGES',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBadgeCard(
              title: '100G',
              subtitle: '100KG CLUB',
              icon: Icons.shield_rounded,
              color: RivalsTheme.trophyGold,
            ),
            _buildBadgeCard(
              title: '30 DAY',
              subtitle: '30 DAY STREAK',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF8800),
            ),
            _buildBadgeCard(
              title: 'CHAMP',
              subtitle: 'CHALLENGE WINNER',
              icon: Icons.emoji_events_rounded,
              color: RivalsTheme.neonLime,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Challenge Activity Section
        const Text(
          'CHALLENGE ACTIVITY',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildActivityRow('Arjun B.', '5 ★★★★★ • Bench Rivalry', '2h 14m left'),
        _buildActivityRow('Sprint Champion', '5K Sprint & Burpees', 'Completed'),
        _buildActivityRow('Challenge Champion', 'Push-Up Arena Bot Defeated', 'Won 1st'),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: RivalsTheme.neonLime,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: RivalsTheme.cardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(String title, String subtitle, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: RivalsTheme.cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: RivalsTheme.neonLime.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: RivalsTheme.neonLime,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Consistency Tab (Mockup Screen 10 & 11)
  Widget _buildConsistencyTab(RivalsAppState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
      physics: const BouncingScrollPhysics(),
      children: [
        // Top 3 Stats: Badges, Hours, Reps
        Row(
          children: [
            _buildPeriodStatCard('${state.badgesCount}', 'Badges'),
            _buildPeriodStatCard('${state.totalHours}', 'Hours'),
            _buildPeriodStatCard('3,420', 'Reps'),
          ],
        ),

        const SizedBox(height: 16),

        // Challenge Win/Loss ratio card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: RivalsTheme.cardDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('CHALLENGE',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    '${state.activeChallengesCount} / 37',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 28, color: Colors.white10),
              Column(
                children: [
                  const Text('WIN / LOSS',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    '${state.wins} / ${state.losses}',
                    style: const TextStyle(
                      color: RivalsTheme.neonLime,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Weekly Consistency Bar Chart
        Container(
          padding: const EdgeInsets.all(18),
          decoration: RivalsTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONSISTENCY (WEEKLY VOLUME)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: _ConsistencyBarChartPainter(),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('M', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('T', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('W', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('T', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('F', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('S', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  Text('S', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 30-Day Fitness Wave Curve
        Container(
          padding: const EdgeInsets.all(18),
          decoration: RivalsTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FITNESS TREND (30 DAYS)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: CustomPaint(
                  painter: _WaveLineChartPainter(),
                  child: Container(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodStatCard(String val, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: RivalsTheme.cardDecoration(),
        child: Column(
          children: [
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Stats Tab (Mountain Altitude & Progression)
  Widget _buildStatsTab(RivalsAppState state) {
    return ListenableBuilder(
      listenable: ProgressionService.instance,
      builder: (context, _) {
        final prog = ProgressionService.instance;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
          physics: const BouncingScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: RivalsTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MOUNTAIN EXPEDITION ALTITUDE',
                    style: TextStyle(
                      color: RivalsTheme.neonLime,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${prog.currentAltitude.toStringAsFixed(0)} Meters',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Checkpoint: ${prog.currentMilestone?.name ?? "Base Camp"}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'RECENT WORKOUT LOGS',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (prog.workoutHistory.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: RivalsTheme.cardDecoration(),
                child: const Center(
                  child: Text(
                    'No logged workouts yet. Complete a set in Workout or Video Verification to record your history!',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...prog.workoutHistory.reversed.take(5).map(
                    (log) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: RivalsTheme.cardDecoration(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${log.reps} Reps • Form ${log.formScore}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '+${log.altitudeGained.toStringAsFixed(0)}m vertical gain',
                                style: const TextStyle(
                                    color: RivalsTheme.neonLime, fontSize: 11),
                              ),
                            ],
                          ),
                          Text(
                            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RivalsTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings & Preferences',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_rounded,
                    color: RivalsTheme.neonLime),
                title: const Text('Athlete Profile',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text('${RivalsAppState.instance.userName} • Level 14',
                    style: const TextStyle(color: Colors.white38)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditProfileDialog(context, RivalsAppState.instance);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded,
                    color: RivalsTheme.neonLime),
                title: const Text('Rival Challenge Notifications',
                    style: TextStyle(color: Colors.white)),
                trailing: Switch(
                  value: true,
                  activeThumbColor: RivalsTheme.neonLime,
                  onChanged: (val) {},
                ),
              ),
            ],
          ),
        );
      },
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
}

/// Dial gauge
class _RadialDialPainter extends CustomPainter {
  final int score;
  _RadialDialPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final trackPaint = Paint()
      ..color = const Color(0xFF222B22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final arcPaint = Paint()
      ..color = RivalsTheme.neonLime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    final sweep = (score / 100.0) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialDialPainter oldDelegate) =>
      oldDelegate.score != score;
}

/// Consistency vertical bars painter
class _ConsistencyBarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final barValues = [0.4, 0.65, 0.3, 0.85, 0.95, 0.7, 0.5];
    final barWidth = size.width / (barValues.length * 2.2);

    for (int i = 0; i < barValues.length; i++) {
      final x = (i * (size.width / barValues.length)) + (barWidth * 0.7);
      final barHeight = barValues[i] * size.height;
      final y = size.height - barHeight;

      final isHigh = barValues[i] > 0.7;

      final paint = Paint()
        ..color = isHigh ? RivalsTheme.neonLime : const Color(0xFF334033)
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(6),
      );

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wave line chart painter
class _WaveLineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final fillPath = Path();

    final points = [
      Offset(0, size.height * 0.75),
      Offset(size.width * 0.2, size.height * 0.55),
      Offset(size.width * 0.4, size.height * 0.65),
      Offset(size.width * 0.6, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.15),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // Gradient fill under wave
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          RivalsTheme.neonLime.withValues(alpha: 0.3),
          RivalsTheme.neonLime.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = RivalsTheme.neonLime
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}