import 'dart:ui';
import 'package:flutter/material.dart';
import '../providers/timer_provider.dart';
import 'timer_page.dart';
import 'stats_page.dart';
import 'settings_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Check and request notifications, exact alarm, and battery exemption permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TimerProvider.instance.checkAndRequestPermissions(context);
    });
  }

  final List<Widget> _pages = const [
    TimerPage(),
    StatsPage(),
    SettingsPage(),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = TimerProvider.instance;

    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final currentTimerState = provider.state;

        // Break and Work phase checks
        final bool isBreak = currentTimerState == AppTimerState.breakTime ||
            (currentTimerState == AppTimerState.paused && provider.pausedState == AppTimerState.breakTime);

        // Dynamic Material 3 Expressive colors derived from system settings
        final Color modePrimaryColor = isBreak ? theme.colorScheme.tertiary : theme.colorScheme.primary;

        final Color baseColor = Color.alphaBlend(
          modePrimaryColor.withOpacity(isDark ? 0.08 : 0.05),
          theme.colorScheme.surface,
        );

        return Scaffold(
          backgroundColor: baseColor,
          extendBody: true, // Content flows behind navigation bar
          body: Stack(
            children: [
              // Dynamic solid flat background
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                color: baseColor,
              ),

              // Main Pages View
              SafeArea(
                bottom: false,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  physics: const NeverScrollableScrollPhysics(),
                  children: _pages,
                ),
              ),
            ],
          ),
          // Floating Solid Material 3 Bottom Navigation Bar
          bottomNavigationBar: _buildExpressiveNavigationBar(theme, isDark, modePrimaryColor, isBreak),
        );
      },
    );
  }

  Widget _buildExpressiveNavigationBar(ThemeData theme, bool isDark, Color activeColor, bool isBreak) {
    // Dynamic solid background matching theme and phase (slightly lighter/darker flat shade)
    final Color navBg = isDark
        ? Color.alphaBlend(activeColor.withOpacity(0.08), theme.colorScheme.surfaceVariant)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
      child: Container(
        height: 76.0,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(38.0), // Fully rounded pill shape
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.hourglass_empty_rounded, Icons.hourglass_full_rounded, "Timer", theme, isDark, activeColor),
            _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart_rounded, "Stats", theme, isDark, activeColor),
            _buildNavItem(2, Icons.settings_outlined, Icons.settings_rounded, "Settings", theme, isDark, activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label, ThemeData theme, bool isDark, Color activeColor) {
    final isSelected = _currentIndex == index;
    final Color itemColor = isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(0.5);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected 
                    ? activeColor.withOpacity(isDark ? 0.16 : 0.10) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20.0), // Rounded active indicator pill
              ),
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: itemColor,
                size: 24.0,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
