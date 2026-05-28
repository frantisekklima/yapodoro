import 'package:flutter/material.dart';
import 'package:button_m3e/button_m3e.dart';
import '../providers/timer_provider.dart';
import '../widgets/circular_progress.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  // Helper to determine the ordinal suffix (1st, 2nd, 3rd, 4th, etc.)
  String _getOrdinal(int number) {
    if (number <= 0) return "1st";
    if (number % 100 >= 11 && number % 100 <= 13) {
      return "${number}th";
    }
    switch (number % 10) {
      case 1:
        return "${number}st";
      case 2:
        return "${number}nd";
      case 3:
        return "${number}rd";
      default:
        return "${number}th";
    }
  }

  // Material 3 Expressive helper to guarantee high contrast between focus and break colors
  Color _getBreakColor(ThemeData theme) {
    return theme.colorScheme.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final provider = TimerProvider.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final currentTimerState = provider.state;
        final currentTimerMode = provider.mode;

        // Break and Work phase checks
        final bool isBreak = currentTimerState == AppTimerState.breakTime ||
            (currentTimerState == AppTimerState.paused && provider.pausedState == AppTimerState.breakTime);

        final bool isWork = currentTimerState == AppTimerState.working ||
            (currentTimerState == AppTimerState.paused && provider.pausedState == AppTimerState.working);

        final bool isIdle = currentTimerState == AppTimerState.idle;

        // Expressive Material 3 Dynamic Colors derived entirely from system settings
        final Color modePrimaryColor = isBreak ? _getBreakColor(theme) : theme.colorScheme.primary;

        final themeColors = [modePrimaryColor, modePrimaryColor.withOpacity(0.85)];

        // Calculate today's completed focus sessions count
        final today = DateTime.now();
        final int todayFocusCount = provider.sessions
            .where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day)
            .length;

        // Compute session indicators (Ordinal Flow and Daily Total)
        String sessionIndicator = "";
        String dailyIndicator = "";
        
        if (isBreak) {
          sessionIndicator = "${_getOrdinal(provider.currentFlowSessionIndex)} Break";
          dailyIndicator = "${_getOrdinal(todayFocusCount)} Break of the day";
        } else {
          sessionIndicator = "${_getOrdinal(provider.currentFlowSessionIndex + 1)} Focus";
          dailyIndicator = "${_getOrdinal(todayFocusCount + 1)} Focus of the day";
        }

        // Split sessionIndicator to style the ordinal part in italic & larger size
        final parts = sessionIndicator.split(' ');
        final String ordinalPart = parts.isNotEmpty ? parts[0] : '';
        final String phasePart = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        // Timer string
        String timerString = "00:00";
        if (isIdle) {
          timerString = currentTimerMode == AppTimerMode.classic
              ? '${provider.classicWorkMinutes.toString().padLeft(2, '0')}:00'
              : '00:00';
        } else if (isWork) {
          timerString = currentTimerMode == AppTimerMode.dynamicMode
              ? _formatDuration(provider.elapsedSeconds)
              : _formatDuration(provider.remainingSeconds);
        } else if (isBreak) {
          timerString = _formatDuration(provider.remainingSeconds);
        }

        // 1. Running: progress bar is beautifully squiggly and animated
        // 2. Stopped/Paused: progress bar freezes instantly into a solid rounded M3E broken arc
        // 3. Dynamic Focus: 1.0 (completely filled) progress ring
        double progress = 0.0;
        bool isWavy = false;

        if (currentTimerState == AppTimerState.idle) {
          progress = 0.0;
          isWavy = false;
        } else if (currentTimerState == AppTimerState.working) {
          isWavy = true; // Wavy when running
          progress = currentTimerMode == AppTimerMode.dynamicMode ? 1.0 : provider.progressPercentage;
        } else if (currentTimerState == AppTimerState.breakTime) {
          isWavy = true; // Wavy when running
          progress = provider.progressPercentage;
        } else if (currentTimerState == AppTimerState.paused) {
          isWavy = false; // Freeze and solidify instantly when paused
          if (provider.pausedState == AppTimerState.working) {
            progress = currentTimerMode == AppTimerMode.dynamicMode ? 1.0 : provider.progressPercentage;
          } else if (provider.pausedState == AppTimerState.breakTime) {
            progress = provider.progressPercentage;
          }
        }



        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // Ordinal Session Indicator - fun typography
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                    ),
                    children: [
                      TextSpan(
                        text: "$ordinalPart ",
                        style: TextStyle(
                          color: modePrimaryColor,
                          fontSize: 32.0,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(
                        text: phasePart,
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.8),
                          fontSize: 24.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Daily Session Indicator
                Text(
                  dailyIndicator,
                  style: TextStyle(
                    color: theme.colorScheme.onBackground.withOpacity(0.45),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
 
                // Circular Timer Display
                Center(
                  child: SizedBox(
                    width: (MediaQuery.of(context).size.width * 0.72).clamp(200.0, 300.0),
                    height: (MediaQuery.of(context).size.width * 0.72).clamp(200.0, 300.0),
                    child: CircularTimerProgress(
                      progress: progress,
                      gradientColors: themeColors,
                      isWavy: isWavy,
                      strokeWidth: 12.0,
                      child: Text(
                        timerString,
                        style: TextStyle(
                          color: theme.colorScheme.onBackground,
                          fontSize: 54.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                if (provider.enableBreakRollover && provider.carryOverBreakSeconds > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 14.0,
                        color: modePrimaryColor.withOpacity(0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "+${provider.carryOverBreakSeconds ~/ 60}:${(provider.carryOverBreakSeconds % 60).toString().padLeft(2, '0')} overflow will be added to next break",
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.65),
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Mode Switcher (Classic vs Dynamic)
                _buildModeSwitcher(provider, isIdle, theme, modePrimaryColor),

                const SizedBox(height: 24),

                // Action Buttons Control Board
                _buildControlBoard(provider, theme, isIdle, isWork, isBreak, modePrimaryColor),

                const SizedBox(height: 40), // Balanced space for bottom nav
              ],
            ),
          ),
        );
      },
    );
  }

  // Pill Mode Switcher Widget (No glassmorphism, solid M3 surfaces, no border)
  Widget _buildModeSwitcher(TimerProvider provider, bool isIdle, ThemeData theme, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            provider,
            AppTimerMode.classic,
            "Classic",
            isIdle,
            provider.mode == AppTimerMode.classic,
            true, // isLeft = true
            theme,
            primaryColor,
          ),
          const SizedBox(width: 2),
          _buildModeButton(
            provider,
            AppTimerMode.dynamicMode,
            "Dynamic",
            isIdle,
            provider.mode == AppTimerMode.dynamicMode,
            false, // isLeft = false
            theme,
            primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    TimerProvider provider,
    AppTimerMode targetMode,
    String text,
    bool isIdle,
    bool isSelected,
    bool isLeft,
    ThemeData theme,
    Color primaryColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    // Morphing BorderRadius:
    // Selected button: fully rounded pill (28.0)
    // Unselected left button: fully rounded outer (left) edge, partially rounded inner (right) edge
    // Unselected right button: partially rounded inner (left) edge, fully rounded outer (right) edge
    final BorderRadius borderRadius = isSelected
        ? BorderRadius.circular(28.0)
        : (isLeft
            ? const BorderRadius.only(
                topLeft: Radius.circular(28.0),
                bottomLeft: Radius.circular(28.0),
                topRight: Radius.circular(12.0),
                bottomRight: Radius.circular(12.0),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                bottomLeft: Radius.circular(12.0),
                topRight: Radius.circular(28.0),
                bottomRight: Radius.circular(28.0),
              ));

    // Dynamic backgrounds
    final Color bgColor = isSelected
        ? primaryColor
        : (isDark
            ? theme.colorScheme.surfaceVariant.withOpacity(0.35)
            : primaryColor.withOpacity(0.08));

    // Dynamic text and icon colors
    final Color contentColor = isSelected
        ? Colors.white
        : (isIdle
            ? primaryColor.withOpacity(0.85)
            : primaryColor.withOpacity(0.35));

    return GestureDetector(
      onTap: isIdle ? () => provider.setMode(targetMode) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  color: contentColor,
                  size: 16.0,
                ),
                const SizedBox(width: 8.0),
              ],
              Text(
                text,
                style: TextStyle(
                  color: contentColor,
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // M3 Expressive Symmetric Control Board (Left: circle Stop | Center: rectangular Action | Right: circle Pause)
  Widget _buildControlBoard(TimerProvider provider, ThemeData theme, bool isIdle, bool isWork, bool isBreak, Color primaryColor) {
    if (isIdle) {
      return Column(
        children: [
          _buildStartButton(provider, theme, primaryColor),
          const SizedBox(height: 12),
        ],
      );
    }

    final state = provider.state;
    final isPaused = state == AppTimerState.paused;

    final Color buttonBgActive = primaryColor;
    final Color buttonBgInactive = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceVariant
        : primaryColor.withOpacity(0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. LEFT Button: Stop (Symmetric rounded circle, inactive background, no glow)
          IconButton(
            onPressed: () => provider.stopTimer(),
            icon: const Icon(Icons.stop_rounded, size: 28.0),
            style: IconButton.styleFrom(
              backgroundColor: buttonBgInactive,
              foregroundColor: primaryColor,
              minimumSize: const Size(64, 64),
              maximumSize: const Size(64, 64),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 8),

          // 2. CENTER Button: Primary Action (Symmetric rounded rectangle, active accent background, no glow)
          if (isWork)
            if (provider.mode == AppTimerMode.dynamicMode)
              FilledButton(
                onPressed: () => provider.triggerDynamicBreak(),
                child: const Icon(Icons.coffee_rounded, size: 28.0),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBgActive,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 64),
                  maximumSize: const Size(64, 64),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 0.0,
                ),
              )
            else
              FilledButton(
                onPressed: () => provider.skipToClassicBreak(),
                child: const Icon(Icons.skip_next_rounded, size: 28.0),
                style: FilledButton.styleFrom(
                  backgroundColor: buttonBgActive,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 64),
                  maximumSize: const Size(64, 64),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 0.0,
                ),
              )
          else if (isBreak)
            FilledButton(
              onPressed: () => provider.resumeWorkEarly(),
              child: const Icon(Icons.local_fire_department_rounded, size: 28.0),
              style: FilledButton.styleFrom(
                backgroundColor: buttonBgActive,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 64),
                maximumSize: const Size(64, 64),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 0.0,
              ),
            ),
          const SizedBox(width: 8),

          // 3. RIGHT Button: Pause/Resume Toggle (Symmetric rounded circle, inactive background, no glow)
          IconButton(
            onPressed: isPaused ? () => provider.resumeTimer() : () => provider.pauseTimer(),
            icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 28.0),
            style: IconButton.styleFrom(
              backgroundColor: buttonBgInactive,
              foregroundColor: primaryColor,
              minimumSize: const Size(64, 64),
              maximumSize: const Size(64, 64),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(TimerProvider provider, ThemeData theme, Color primaryColor) {
    // Compact, highly aesthetic symmetrical round play button (no text, zero navigation overlap)
    return FilledButton(
      onPressed: () => provider.startTimer(),
      child: const Icon(Icons.play_arrow_rounded, size: 36.0),
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 64),
        maximumSize: const Size(64, 64),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        elevation: 0.0,
      ),
    );
  }
}
