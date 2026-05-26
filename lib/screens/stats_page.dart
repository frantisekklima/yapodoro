import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/timer_provider.dart';
import '../widgets/activity_grid.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  String _formatTotalTime(int totalSeconds) {
    if (totalSeconds == 0) return "0m";
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      if (minutes > 0) {
        return "${hours}h ${minutes}m";
      }
      return "${hours}h";
    }
    return "${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    final provider = TimerProvider.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color focusColor = isDark ? const Color(0xFF8FBC8F) : const Color(0xFF1E5631);
    final Color breakColor = isDark ? const Color(0xFF78A1BB) : const Color(0xFF2E5B70);

    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final todayFocus = _formatTotalTime(provider.todayWorkSeconds);
        final todayBreak = _formatTotalTime(provider.carryOverBreakSeconds);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100.0), // Space for bottom nav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Center(
                child: Text(
                  "Stats",
                  style: TextStyle(
                    color: focusColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 1. Today split block widgets (Solid M3 Colors)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today",
                      style: TextStyle(
                        color: theme.colorScheme.onBackground.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSplitBlockCard(
                            title: "Focus",
                            value: todayFocus,
                            bgColor: isDark ? const Color(0xFF162D1F) : const Color(0xFFEBF4EE),
                            textColor: focusColor,
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSplitBlockCard(
                            title: "Break",
                            value: todayBreak,
                            bgColor: isDark ? const Color(0xFF13232E) : const Color(0xFFEAF1F5),
                            textColor: breakColor,
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Weekly Productivity Analysis (Capsule Bar Chart)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildWeeklyAnalysis(provider, theme, focusColor, isDark),
              ),

              const SizedBox(height: 24),

              // 3. Monthly Consistency Chart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildMonthlyAnalysis(provider, theme, focusColor, isDark),
              ),

              const SizedBox(height: 24),

              // 4. Activity Grid (Horizontal Heatmap)
              _buildExpressivePanel(
                child: ActivityGrid(dailyMinutes: provider.dailyMinutesMap),
                theme: theme,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // 5. Recent Sessions Log
              _buildRecentSessionsLog(provider, theme, focusColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSplitBlockCard({
    required String title,
    required String value,
    required Color bgColor,
    required Color textColor,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor.withOpacity(0.85),
              fontSize: 12.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 22.0,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyAnalysis(TimerProvider provider, ThemeData theme, Color focusColor, bool isDark) {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysToSubtract));

    final List<double> weeklyHours = List.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      final targetDate = monday.add(Duration(days: i));
      final daySessions = provider.sessions.where((s) =>
          s.date.year == targetDate.year &&
          s.date.month == targetDate.month &&
          s.date.day == targetDate.day);
      final double totalSecs = daySessions.fold(0.0, (sum, s) => sum + s.durationSeconds);
      weeklyHours[i] = totalSecs / 3600.0;
    }

    final double maxVal = weeklyHours.reduce(max);
    final double yMax = max(maxVal, 3.0);
    final weekdays = ["M", "T", "W", "T", "F", "S", "S"];

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.35 : 0.45),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly productivity analysis",
            style: TextStyle(
              color: theme.colorScheme.onBackground,
              fontSize: 14.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            "Focus durations at different days of the week",
            style: TextStyle(
              color: theme.colorScheme.onBackground.withOpacity(0.4),
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  final double labelVal = yMax * (3 - index) / 3.0;
                  return Container(
                    height: 32.0,
                    alignment: Alignment.centerRight,
                    width: 24.0,
                    child: Text(
                      "${labelVal.toStringAsFixed(0)}h",
                      style: TextStyle(
                        color: theme.colorScheme.onBackground.withOpacity(0.45),
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final double hours = weeklyHours[index];
                    final double pct = (hours / yMax).clamp(0.02, 1.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          hours > 0 ? "${hours.toStringAsFixed(1)}h" : "",
                          style: TextStyle(
                            color: focusColor,
                            fontSize: 8.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Container(
                          height: 110.0 * pct,
                          width: 20.0,
                          decoration: BoxDecoration(
                            color: hours > 0 ? focusColor : focusColor.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          weekdays[index],
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(0.55),
                            fontSize: 9.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAnalysis(TimerProvider provider, ThemeData theme, Color focusColor, bool isDark) {
    final List<double> dailyHours = List.filled(30, 0.0);
    final today = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final targetDate = today.subtract(Duration(days: 29 - i));
      final daySessions = provider.sessions.where((s) =>
          s.date.year == targetDate.year &&
          s.date.month == targetDate.month &&
          s.date.day == targetDate.day);
      final double totalSecs = daySessions.fold(0.0, (sum, s) => sum + s.durationSeconds);
      dailyHours[i] = totalSecs / 3600.0;
    }

    final double maxVal = dailyHours.reduce(max);
    final double yMax = max(maxVal, 3.0);

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.35 : 0.45),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly focus consistency",
            style: TextStyle(
              color: theme.colorScheme.onBackground,
              fontSize: 14.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            "Last 30 days active focus minutes per day",
            style: TextStyle(
              color: theme.colorScheme.onBackground.withOpacity(0.4),
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  final double labelVal = yMax * (3 - index) / 3.0;
                  return Container(
                    height: 22.0,
                    alignment: Alignment.centerRight,
                    width: 24.0,
                    child: Text(
                      "${labelVal.toStringAsFixed(0)}h",
                      style: TextStyle(
                        color: theme.colorScheme.onBackground.withOpacity(0.45),
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  height: 70.0,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(30, (index) {
                      final double hours = dailyHours[index];
                      final double pct = (hours / yMax).clamp(0.02, 1.0);

                      return Container(
                        height: 60.0 * pct,
                        width: 5.0,
                        decoration: BoxDecoration(
                          color: hours > 0 ? focusColor : focusColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpressivePanel({required Widget child, required ThemeData theme, required bool isDark}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.35 : 0.45),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }

  Widget _buildRecentSessionsLog(TimerProvider provider, ThemeData theme, Color focusColor) {
    final recent = provider.sessions.reversed.take(5).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.45),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RECENT FOCUS LOGS",
            style: TextStyle(
              color: theme.colorScheme.onBackground.withOpacity(0.4),
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12.0),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                "No sessions logged yet. Complete focus flows to view them here!",
                style: TextStyle(
                  color: theme.colorScheme.onBackground.withOpacity(0.3),
                  fontSize: 12.0,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (context, index) => Divider(
                color: theme.colorScheme.outline.withOpacity(0.08),
                height: 16,
              ),
              itemBuilder: (context, index) {
                final session = recent[index];
                final durationMin = (session.durationSeconds / 60).toStringAsFixed(1);
                final dateStr = "${session.date.day}. ${session.date.month}.";
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: focusColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: focusColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Focus Session",
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "$durationMin min",
                          style: TextStyle(
                            color: theme.colorScheme.onBackground,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
