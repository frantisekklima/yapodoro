import 'package:flutter/material.dart';
import '../providers/timer_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = TimerProvider.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Accent color derived dynamically from system settings color scheme
    final Color primaryColor = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final isTimerActive = provider.state != AppTimerState.idle;

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
                  "Settings",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (isTimerActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Timer is active. Settings are locked.",
                            style: TextStyle(
                              color: Colors.amber.withOpacity(0.9),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 1. Durations Display Block (Material 3 Expressive, huge numbers side-by-side)
              _buildSectionHeader("Durations", theme, primaryColor),
              _buildExpressiveDurationsCard(context, provider, theme, isTimerActive, primaryColor, isDark),

              // 2. Interval Config Card (Session Length slider)
              _buildSectionHeader("Session length", theme, primaryColor),
              _buildExpressiveSessionLengthCard(context, provider, theme, isTimerActive, primaryColor, isDark),

              // 3. Dynamic Mode Config Card
              _buildSectionHeader("Dynamic Divisor", theme, primaryColor),
              _buildExpressiveDynamicDivisorCard(context, provider, theme, isTimerActive, primaryColor, isDark),

              // 4. Break Settings Config Card (Switch toggle)
              _buildSectionHeader("Break Settings", theme, primaryColor),
              _buildBreakSettingsCard(context, provider, theme, isTimerActive, primaryColor, isDark),

              // 5. Danger Zone Card
              _buildSectionHeader("Danger Zone", theme, primaryColor),
              _buildSettingsCard(
                theme: theme,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Clear All Local Data",
                                style: TextStyle(
                                  color: theme.colorScheme.onBackground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Deletes all focus history logs and resets carry-over times.",
                                style: TextStyle(
                                  color: theme.colorScheme.onBackground.withOpacity(0.4),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error.withOpacity(0.08),
                            shadowColor: Colors.transparent,
                            side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          onPressed: () => _confirmClearData(context, provider, theme),
                          child: Text(
                            "RESET",
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 20.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: primaryColor,
          fontSize: 10.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildExpressiveDurationsCard(
    BuildContext context,
    TimerProvider provider,
    ThemeData theme,
    bool isDisabled,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: primaryColor.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Column 1: Focus
          Column(
            children: [
              _buildDurationSubLabel("Focus", theme),
              const SizedBox(height: 12.0),
              _buildDurationNumberBox(
                context: context,
                label: "Focus",
                value: provider.classicWorkMinutes,
                min: 1,
                max: 120,
                isDisabled: isDisabled,
                onChanged: (val) => provider.saveSettings(workMin: val),
                theme: theme,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ],
          ),
          // Column 2: Short break
          Column(
            children: [
              _buildDurationSubLabel("Short break", theme),
              const SizedBox(height: 12.0),
              _buildDurationNumberBox(
                context: context,
                label: "Short Break",
                value: provider.classicShortBreakMinutes,
                min: 1,
                max: 45,
                isDisabled: isDisabled,
                onChanged: (val) => provider.saveSettings(shortBreakMin: val),
                theme: theme,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ],
          ),
          // Column 3: Long break
          Column(
            children: [
              _buildDurationSubLabel("Long break", theme),
              const SizedBox(height: 12.0),
              _buildDurationNumberBox(
                context: context,
                label: "Long Break",
                value: provider.classicLongBreakMinutes,
                min: 1,
                max: 60,
                isDisabled: isDisabled,
                onChanged: (val) => provider.saveSettings(longBreakMin: val),
                theme: theme,
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSubLabel(String label, ThemeData theme) {
    return Text(
      label,
      style: TextStyle(
        color: theme.colorScheme.onBackground.withOpacity(0.55),
        fontSize: 12.0,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDurationNumberBox({
    required BuildContext context,
    required String label,
    required int value,
    required int min,
    required int max,
    required bool isDisabled,
    required ValueChanged<int> onChanged,
    required ThemeData theme,
    required Color primaryColor,
    required bool isDark,
  }) {
    final displayStr = value.toString().padLeft(2, '0');

    return Column(
      children: [
        // Up Arrow
        GestureDetector(
          onTap: (isDisabled || value >= max) ? null : () => onChanged(value + 1),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 20.0,
            color: (isDisabled || value >= max) ? theme.colorScheme.onBackground.withOpacity(0.1) : primaryColor,
          ),
        ),
        const SizedBox(height: 2.0),
        // Huge expressive capsule box - Clickable to open text keyboard input dialog
        GestureDetector(
          onTap: isDisabled ? null : () {
            _showNumberInputDialog(
              context: context,
              title: "Edit $label Time",
              currentValue: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              isDecimal: false,
              onSubmit: (val) => onChanged(val.round()),
              theme: theme,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: primaryColor.withOpacity(0.12),
                width: 1.5,
              ),
            ),
            child: Text(
              displayStr,
              style: TextStyle(
                color: theme.colorScheme.onBackground,
                fontSize: 32.0,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        // Down Arrow
        GestureDetector(
          onTap: (isDisabled || value <= min) ? null : () => onChanged(value - 1),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20.0,
            color: (isDisabled || value <= min) ? theme.colorScheme.onBackground.withOpacity(0.1) : primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildExpressiveSessionLengthCard(
    BuildContext context,
    TimerProvider provider,
    ThemeData theme,
    bool isDisabled,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: primaryColor.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Focus intervals in one session",
                style: TextStyle(
                  color: theme.colorScheme.onBackground.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: isDisabled ? null : () {
                  _showNumberInputDialog(
                    context: context,
                    title: "Edit Session Length",
                    currentValue: provider.classicLongBreakInterval.toDouble(),
                    min: 1.0,
                    max: 12.0,
                    isDecimal: false,
                    onSubmit: (val) => provider.saveSettings(longBreakInterval: val.round()),
                    theme: theme,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    provider.classicLongBreakInterval.toString(),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Thick Expressive Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: primaryColor.withOpacity(0.12),
              thumbColor: primaryColor,
              overlayColor: primaryColor.withOpacity(0.12),
              trackHeight: 6, // Thick track
            ),
            child: Slider(
              value: provider.classicLongBreakInterval.toDouble(),
              min: 1.0,
              max: 12.0,
              divisions: 11,
              onChanged: isDisabled
                  ? null
                  : (val) => provider.saveSettings(longBreakInterval: val.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpressiveDynamicDivisorCard(
    BuildContext context,
    TimerProvider provider,
    ThemeData theme,
    bool isDisabled,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: primaryColor.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Break Divisor",
                style: TextStyle(
                  color: theme.colorScheme.onBackground.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: isDisabled ? null : () {
                  _showNumberInputDialog(
                    context: context,
                    title: "Edit Break Divisor",
                    currentValue: provider.dynamicDivisor,
                    min: 1.5,
                    max: 8.0,
                    isDecimal: true,
                    onSubmit: (val) => provider.saveSettings(divisor: val),
                    theme: theme,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    provider.dynamicDivisor.toStringAsFixed(1),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Dividing dynamic focus minutes by this divisor to auto-calculate breaks (e.g. 60m focus / 4.0 = 15m break)",
            style: TextStyle(
              color: theme.colorScheme.onBackground.withOpacity(0.4),
              fontSize: 11,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: primaryColor.withOpacity(0.12),
              thumbColor: primaryColor,
              overlayColor: primaryColor.withOpacity(0.12),
              trackHeight: 6,
            ),
            child: Slider(
              value: provider.dynamicDivisor,
              min: 1.5,
              max: 8.0,
              divisions: 13,
              onChanged: isDisabled
                  ? null
                  : (val) => provider.saveSettings(divisor: val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children, required ThemeData theme}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
          width: 1.0,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      color: theme.colorScheme.outline.withOpacity(0.08),
      height: 1.0,
    );
  }

  void _confirmClearData(BuildContext context, TimerProvider provider, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
            side: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          title: Text(
            "Reset all data?",
            style: TextStyle(color: theme.colorScheme.onBackground, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "This will delete your entire session log history, reset all preferences, and clear carry-over break times. This action cannot be undone.",
            style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.6), fontSize: 13.0, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "CANCEL",
                style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.4), fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              onPressed: () {
                provider.clearAllData();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("All data has been cleared."),
                    backgroundColor: theme.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  ),
                );
              },
              child: const Text(
                "RESET DATA",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Break Settings Card containing early exit rollover toggle switch
  Widget _buildBreakSettingsCard(
    BuildContext context,
    TimerProvider provider,
    ThemeData theme,
    bool isDisabled,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: primaryColor.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Carry-over early break exit",
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Adds remaining break seconds to your next break if you return to work early.",
                  style: TextStyle(
                    color: theme.colorScheme.onBackground.withOpacity(0.4),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: provider.enableBreakRollover,
            activeColor: primaryColor,
            onChanged: isDisabled
                ? null
                : (val) => provider.setEnableBreakRollover(val),
          ),
        ],
      ),
    );
  }

  // Material 3 premium keyboard number input dialog helper
  void _showNumberInputDialog({
    required BuildContext context,
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required bool isDecimal,
    required ValueChanged<double> onSubmit,
    required ThemeData theme,
  }) {
    final controller = TextEditingController(
      text: isDecimal ? currentValue.toStringAsFixed(1) : currentValue.round().toString(),
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
            side: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(color: theme.colorScheme.onBackground, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter a value between ${isDecimal ? min.toStringAsFixed(1) : min.round()} and ${isDecimal ? max.toStringAsFixed(1) : max.round()}:",
                style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.6), fontSize: 12.0),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
                autofocus: true,
                style: TextStyle(color: theme.colorScheme.onBackground, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "CANCEL",
                style: TextStyle(color: theme.colorScheme.onBackground.withOpacity(0.5), fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              ),
              onPressed: () {
                final double? parsedVal = double.tryParse(controller.text);
                if (parsedVal != null && parsedVal >= min && parsedVal <= max) {
                  onSubmit(parsedVal);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Please enter a valid number between ${isDecimal ? min.toStringAsFixed(1) : min.round()} and ${isDecimal ? max.toStringAsFixed(1) : max.round()}"),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text(
                "SAVE",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
