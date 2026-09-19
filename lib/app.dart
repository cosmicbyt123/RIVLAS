import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/ranks_screen.dart';
import 'screens/video_verification_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/community_screen.dart';
import 'screens/fitness_games_screen.dart';
import 'widgets/bottom_nav.dart';
import 'theme/rivals_theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  // Screens mapped to bottom nav index
  // Index 2 is the center action button (+) which pushes full-screen Video Verification
  // Index 4 is Fitness Games Arcade (Replaces old Profile; Profile is accessible from top-right icon on Home)
  final List<Widget> _screens = const [
    HomeScreen(),
    RanksScreen(),
    SizedBox.shrink(), // Placeholder for center button
    CommunityScreen(),
    FitnessGamesScreen(),
  ];

  void _onNavTap(int index) {
    if (index == 2) {
      _showExercisePicker();
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF141914),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'CHOOSE EXERCISE TO VERIFY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an exercise to launch real-time AI computer vision & biomechanics validation.',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildExerciseOption(
              ctx: ctx,
              title: 'Squats AI Verification',
              subtitle: 'Knee angle & parallel hip crease tracking (≤90°)',
              icon: Icons.fitness_center_rounded,
              tag: 'POPULAR',
              exercise: 'Squat',
            ),
            const SizedBox(height: 12),
            _buildExerciseOption(
              ctx: ctx,
              title: 'Push-Ups AI Verification',
              subtitle: 'Selfie camera nose & chest tracking with AR skeleton',
              icon: Icons.bolt_rounded,
              tag: 'CLASSIC',
              exercise: 'Push-Up',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseOption({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required String tag,
    required String exercise,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        if (exercise == 'Push-Up') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CameraScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoVerificationScreen(exerciseTitle: exercise),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RivalsTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: RivalsTheme.neonLime.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RivalsTheme.neonLime.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: RivalsTheme.neonLime, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: RivalsTheme.neonLime.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: RivalsTheme.neonLime,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RivalsTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}