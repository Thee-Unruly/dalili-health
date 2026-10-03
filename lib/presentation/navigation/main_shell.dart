import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../providers/navigation_provider.dart';

// Screens
import '../../services/triage_service.dart';
import '../screens/triage/triage_screen.dart';
import '../screens/tutor/tutor_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/settings/settings_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: IndexedStack(
                  index: navProvider.selectedIndex,
                  children: const [
                    // Swap FakeTriageService for the real pipeline here.
                    _TriageTab(service: FakeTriageService()),
                    TutorScreen(),
                    LibraryScreen(),
                    SettingsScreen(),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomNav(
                selectedIndex: navProvider.selectedIndex,
                onTap: (index) => navProvider.setIndex(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Triage uses a high-contrast dark Material theme (the app root theme is
/// light-schemed with a dark scaffold, which would give dark-on-dark text).
class _TriageTab extends StatelessWidget {
  final TriageService service;

  const _TriageTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.indigo,
          brightness: Brightness.dark,
          contrastLevel: 1.0,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: TriageScreen(service: service),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;

  const _BottomNavItem({
    required this.icon,
    required this.label,
  });
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const List<_BottomNavItem> _navItems = [
    _BottomNavItem(icon: Icons.medical_services_outlined, label: 'Triage'),
    _BottomNavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Ask'),
    _BottomNavItem(icon: Icons.menu_book_outlined, label: 'Guidelines'),
    _BottomNavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          top: BorderSide(color: AppColors.bgCard, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final active = i == selectedIndex;
              final item = _navItems[i];

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: active ? AppColors.indigo : AppColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTypography.label.copyWith(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? AppColors.indigo : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
