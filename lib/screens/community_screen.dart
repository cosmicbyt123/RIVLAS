import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import 'challenge_battle_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedChipIndex = 0;
  final List<String> _chips = ['Community', 'Live Challenges', 'Teams / Gyms'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    // Top App Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: RivalsTheme.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: RivalsTheme.borderLight),
                          ),
                          child: const Icon(Icons.menu_rounded,
                              color: Colors.white, size: 20),
                        ),
                        // Segmented Switcher
                        Container(
                          height: 38,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: RivalsTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: RivalsTheme.borderLight),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: RivalsTheme.neonLime,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.white70,
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Gym Discovery'),
                              Tab(text: 'Activity Feed'),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: RivalsTheme.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: RivalsTheme.borderLight),
                          ),
                          child: const Icon(Icons.search_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_chips.length, (idx) {
                          final isSelected = _selectedChipIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedChipIndex = idx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? RivalsTheme.neonLime
                                      : RivalsTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? RivalsTheme.neonLime
                                        : RivalsTheme.borderLight,
                                  ),
                                ),
                                child: Text(
                                  _chips[idx],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildGymDiscoveryTab(),
              _buildSocialFeedTab(),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Gym Discovery Map View (Mockup Screen 8)
  Widget _buildGymDiscoveryTab() {
    return ListenableBuilder(
      listenable: RivalsAppState.instance,
      builder: (context, _) {
        final state = RivalsAppState.instance;
        final selectedGym = state.gyms[state.selectedGymIndex];
        final isJoined = state.isGymChallengeJoined(selectedGym.id);

        return Stack(
          children: [
            // Dark Stylized Map Canvas
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: _StylizedGymMapPainter(
                    gyms: state.gyms,
                    selectedGymIndex: state.selectedGymIndex,
                  ),
                ),
              ),
            ),

            // Interactive Gym Markers Overlay
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: List.generate(state.gyms.length, (index) {
                    final gym = state.gyms[index];
                    final isSel = state.selectedGymIndex == index;
                    final posX = gym.mapX * constraints.maxWidth;
                    final posY = gym.mapY * (constraints.maxHeight - 200);

                    return Positioned(
                      left: posX - 22,
                      top: posY - 22,
                      child: GestureDetector(
                        onTap: () => state.selectGym(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isSel ? 50 : 40,
                          height: isSel ? 50 : 40,
                          decoration: BoxDecoration(
                            color: isSel
                                ? RivalsTheme.neonLime
                                : RivalsTheme.surfaceHighlight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel
                                  ? Colors.white
                                  : RivalsTheme.neonLime.withValues(alpha: 0.6),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isSel
                                        ? RivalsTheme.neonLime
                                        : Colors.black)
                                    .withValues(alpha: 0.5),
                                blurRadius: isSel ? 14 : 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.fitness_center_rounded,
                              color: isSel ? Colors.black : RivalsTheme.neonLime,
                              size: isSel ? 24 : 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            // Bottom Gym Information Card
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: RivalsTheme.cardDecoration(
                  color: RivalsTheme.surfaceElevated.withValues(alpha: 0.96),
                  glow: true,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gym Title & Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedGym.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.navigation_rounded,
                                color: RivalsTheme.neonLime, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              selectedGym.distance,
                              style: const TextStyle(
                                color: RivalsTheme.neonLime,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: RivalsTheme.trophyGold, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${selectedGym.rating}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${selectedGym.activeMembers} Members',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const Text('•', style: TextStyle(color: Colors.white24)),
                        Text(
                          '${selectedGym.liveChallenges} Live Challenges',
                          style: const TextStyle(
                            color: RivalsTheme.neonLime,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Community Activity Snippet
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: RivalsTheme.surfaceHighlight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedGym.featuredActivity,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Join Challenge Button
                    GestureDetector(
                      onTap: () {
                        state.toggleJoinGymChallenge(selectedGym.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: RivalsTheme.surfaceHighlight,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                  color: RivalsTheme.neonLime),
                            ),
                            content: Text(
                              isJoined
                                  ? 'Left challenge at ${selectedGym.name}'
                                  : 'Joined live challenge at ${selectedGym.name}! (+100 XP)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isJoined
                              ? RivalsTheme.surfaceHighlight
                              : RivalsTheme.neonLime,
                          borderRadius: BorderRadius.circular(14),
                          border: isJoined
                              ? Border.all(color: RivalsTheme.neonLime)
                              : null,
                          boxShadow: [
                            if (!isJoined)
                              BoxShadow(
                                color:
                                    RivalsTheme.neonLime.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isJoined ? 'CHALLENGE JOINED ✓' : 'JOIN CHALLENGE',
                            style: TextStyle(
                              color: isJoined
                                  ? RivalsTheme.neonLime
                                  : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
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

  // 2. Social Feed View (Mockup Screen 9)
  Widget _buildSocialFeedTab() {
    return ListenableBuilder(
      listenable: RivalsAppState.instance,
      builder: (context, _) {
        final state = RivalsAppState.instance;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          physics: const BouncingScrollPhysics(),
          itemCount: state.posts.length,
          itemBuilder: (context, index) {
            final post = state.posts[index];
            return _buildSocialPostCard(post, state);
          },
        );
      },
    );
  }

  Widget _buildSocialPostCard(RivalsPost post, RivalsAppState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: RivalsTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: RivalsTheme.surfaceHighlight,
                      border: Border.all(
                        color: RivalsTheme.neonLime.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        post.authorName.isNotEmpty
                            ? post.authorName.substring(0, 1)
                            : 'A',
                        style: const TextStyle(
                          color: RivalsTheme.neonLime,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        post.timeAgo,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (post.badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RivalsTheme.neonLime.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RivalsTheme.neonLime.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    post.badgeText!,
                    style: const TextStyle(
                      color: RivalsTheme.neonLime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Post Content
          Text(
            post.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // Barbell / Workout Media Preview
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F140F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          color: RivalsTheme.neonLime, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        'AI Pose Verified Lift • ${post.exercise}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HD 60FPS',
                      style: TextStyle(
                        color: RivalsTheme.neonLime,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Social Interactions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like
              GestureDetector(
                onTap: () => state.togglePostLike(post.id),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      post.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: post.isLiked
                          ? RivalsTheme.dangerRed
                          : Colors.white60,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.likes}',
                      style: TextStyle(
                        color: post.isLiked
                            ? RivalsTheme.dangerRed
                            : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Challenge Rival Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChallengeBattleScreen(
                        opponentName: post.authorName,
                        battleTitle: '${post.exercise.toUpperCase()} BATTLE',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: RivalsTheme.neonLime.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: RivalsTheme.neonLime.withValues(alpha: 0.8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: RivalsTheme.neonLime, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Challenge',
                        style: TextStyle(
                          color: RivalsTheme.neonLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Comment
              GestureDetector(
                onTap: () => _showCommentsSheet(context, post, state),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    const Icon(Icons.mode_comment_outlined,
                        color: Colors.white60, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${post.comments.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCommentsSheet(
      BuildContext context, RivalsPost post, RivalsAppState state) {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: RivalsTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments (${post.comments.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...post.comments.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RivalsTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      c,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a cheer or comment...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: RivalsTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      state.addPostComment(post.id, textController.text);
                      textController.clear();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: RivalsTheme.neonLime,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom Painter for stylized dark mode GPS radar map
class _StylizedGymMapPainter extends CustomPainter {
  final List<GymLocation> gyms;
  final int selectedGymIndex;

  _StylizedGymMapPainter({
    required this.gyms,
    required this.selectedGymIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF090C09),
    );

    // 2. Street Grid Lines
    final roadPaint = Paint()
      ..color = const Color(0xFF141C14)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final secondaryRoadPaint = Paint()
      ..color = const Color(0xFF101710)
      ..strokeWidth = 3.0;

    // Grid lines
    for (double x = 40; x < size.width; x += 90) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (double y = 40; y < size.height; y += 90) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }

    // Diagonal arterial roads
    canvas.drawLine(
      const Offset(0, 100),
      Offset(size.width, size.height * 0.7),
      secondaryRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.9, size.height),
      secondaryRoadPaint,
    );

    // 3. User Radar Pulse (Center)
    final userX = size.width * 0.5;
    final userY = size.height * 0.38;

    final radarPaint = Paint()
      ..color = RivalsTheme.neonLime.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final radarRing = Paint()
      ..color = RivalsTheme.neonLime.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(Offset(userX, userY), 85, radarPaint);
    canvas.drawCircle(Offset(userX, userY), 85, radarRing);
    canvas.drawCircle(Offset(userX, userY), 50, radarRing);

    // User Location Dot
    canvas.drawCircle(
      Offset(userX, userY),
      8,
      Paint()..color = RivalsTheme.neonLime,
    );
    canvas.drawCircle(
      Offset(userX, userY),
      12,
      Paint()
        ..color = RivalsTheme.neonLime.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _StylizedGymMapPainter oldDelegate) {
    return oldDelegate.selectedGymIndex != selectedGymIndex;
  }
}
