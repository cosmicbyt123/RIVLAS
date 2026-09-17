import 'package:flutter/material.dart';
import '../theme/rivals_theme.dart';

class NavItem {
  final IconData icon;
  final String label;
  final int index;
  final bool isCenter;

  const NavItem({
    required this.icon,
    required this.label,
    required this.index,
    this.isCenter = false,
  });
}

const List<NavItem> kNavItems = [
  NavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
  NavItem(icon: Icons.leaderboard_rounded, label: 'Ranks', index: 1),
  NavItem(icon: Icons.add_rounded, label: '', index: 2, isCenter: true),
  NavItem(icon: Icons.forum_rounded, label: 'Feed', index: 3),
  NavItem(icon: Icons.person_rounded, label: 'Profile', index: 4),
];

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: RivalsTheme.surfaceElevated.withValues(alpha: 0.98),
        border: const Border(
          top: BorderSide(color: RivalsTheme.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: kNavItems.map((item) {
          if (item.isCenter) {
            // Center Floating Action Button (+)
            return GestureDetector(
              onTap: () => onTap(item.index),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: RivalsTheme.neonLime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: RivalsTheme.neonLime.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.black,
                  size: 30,
                ),
              ),
            );
          }

          // Regular nav icon
          final isActive = currentIndex == item.index;
          return GestureDetector(
            onTap: () => onTap(item.index),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? RivalsTheme.neonLime.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: isActive ? RivalsTheme.neonLime : Colors.white38,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}