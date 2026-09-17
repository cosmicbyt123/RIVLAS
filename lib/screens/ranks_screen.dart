import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';
import '../services/rivals_app_state.dart';
import 'challenge_battle_screen.dart';

class RanksScreen extends StatefulWidget {
  const RanksScreen({super.key});

  @override
  State<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends State<RanksScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['STRENGTH', 'CONSISTENCY', 'IMPROVEMENT'];

  final List<Map<String, dynamic>> _athletes = [
    {'rank': 1, 'name': 'Vikram Rathore', 'score': 98, 'streak': '52d', 'avatar': '👑', 'specialty': 'Squats: 160kg'},
    {'rank': 2, 'name': 'Rohan Sharma', 'score': 95, 'streak': '41d', 'avatar': '🥈', 'specialty': 'Push-ups: 74'},
    {'rank': 3, 'name': 'Arjun Verma', 'score': 92, 'streak': '38d', 'avatar': '🥉', 'specialty': 'Squats: 140kg'},
    {'rank': 4, 'name': 'Priya Nair', 'score': 90, 'streak': '36d', 'avatar': '⚡', 'specialty': 'Squats: 110kg'},
    {'rank': 5, 'name': 'Aditya Deshmukh', 'score': 88, 'streak': '33d', 'avatar': '🔥', 'specialty': 'Bench: 120kg'},
    {'rank': 6, 'name': 'Samira Khan', 'score': 87, 'streak': '29d', 'avatar': '🎯', 'specialty': 'Push-ups: 58'},
    {'rank': 7, 'name': 'Kabir Chawla', 'score': 86, 'streak': '24d', 'avatar': '🦾', 'specialty': 'Squats: 130kg'},
    {'rank': 8, 'name': 'Ananya Roy', 'score': 85, 'streak': '21d', 'avatar': '🏆', 'specialty': 'Squats: 95kg'},
  ];

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
          'CITY FITNESS RANKINGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: RivalsTheme.neonLime),
            tooltip: '1v1 Battle Hub',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChallengeBattleScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: RivalsAppState.instance,
          builder: (context, _) {
            final state = RivalsAppState.instance;

            return Column(
              children: [
                const SizedBox(height: 8),

                // Category Filter Pills: [ STRENGTH ] [ CONSISTENCY ] [ IMPROVEMENT ]
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(_filters.length, (index) {
                      final isSelected = _selectedFilter == index;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFilter = index),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? RivalsTheme.neonLime
                                    : RivalsTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? RivalsTheme.neonLime
                                      : RivalsTheme.borderLight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _filters[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                // Ranked Athlete List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _athletes.length,
                    itemBuilder: (context, index) {
                      final athlete = _athletes[index];
                      return _buildAthleteRankRow(athlete, state);
                    },
                  ),
                ),

                // Pinned User Card (Rank 18 Alex R.)
                _buildPinnedUserCard(state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAthleteRankRow(
      Map<String, dynamic> athlete, RivalsAppState state) {
    final rank = athlete['rank'] as int;
    final name = athlete['name'] as String;
    final score = athlete['score'] as int;
    final avatar = athlete['avatar'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: RivalsTheme.cardDecoration(),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 24,
            child: Text(
              '$rank.',
              style: TextStyle(
                color: rank <= 3 ? RivalsTheme.neonLime : Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: RivalsTheme.surfaceHighlight,
            ),
            child: Center(
              child: Text(avatar, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),

          // Name and subtext
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  athlete['specialty'] ?? 'Strength & Mobility',
                  style: const TextStyle(color: RivalsTheme.neonLime, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Score
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(width: 12),

          // Challenge button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChallengeBattleScreen(
                    opponentName: name,
                    battleTitle: '1v1 BATTLE vs $name',
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: RivalsTheme.neonLime.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: RivalsTheme.neonLime.withValues(alpha: 0.6),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded,
                      color: RivalsTheme.neonLime, size: 14),
                  SizedBox(width: 2),
                  Text(
                    'VS',
                    style: TextStyle(
                      color: RivalsTheme.neonLime,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedUserCard(RivalsAppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: RivalsTheme.surfaceElevated,
        border: const Border(
          top: BorderSide(color: RivalsTheme.neonLime, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: RivalsTheme.neonLime.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User Rank
          Text(
            '${state.cityRank}.',
            style: const TextStyle(
              color: RivalsTheme.neonLime,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RivalsTheme.surfaceHighlight,
              border: Border.all(color: RivalsTheme.neonLime, width: 1.5),
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),

          // User Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      state.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: RivalsTheme.neonLime.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: RivalsTheme.neonLime,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Fitness Score (Rank 18 City)',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          // User Score
          Text(
            '${state.overallFitnessScore}',
            style: const TextStyle(
              color: RivalsTheme.neonLime,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}