import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/ranks_screen.dart';
import 'screens/video_verification_screen.dart';
import 'screens/community_screen.dart';
import 'screens/profile_screen.dart';
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
  final List<Widget> _screens = const [
    HomeScreen(),
    RanksScreen(),
    SizedBox.shrink(), // Placeholder for center button
    CommunityScreen(),
    ProfileScreen(),
  ];

  void _onNavTap(int index) {
    if (index == 2) {
      // Center (+) button launches AI Video Verification directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const VideoVerificationScreen(),
        ),
      );
      return;
    }
    setState(() => _currentIndex = index);
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