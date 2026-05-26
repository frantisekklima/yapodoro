import 'package:flutter/material.dart';

class ActivityGrid extends StatefulWidget {
  final Map<String, double> dailyMinutes;

  const ActivityGrid({
    super.key,
    required this.dailyMinutes,
  });

  @override
  State<ActivityGrid> createState() => _ActivityGridState();
}

class _ActivityGridState extends State<ActivityGrid> {
  final ScrollController _scrollController = ScrollController();
  late DateTime _startDate;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    // Go back 364 days (52 weeks) and align to the preceding Monday
    final startOfHistory = _today.subtract(const Duration(days: 364));
    final daysToSubtract = startOfHistory.weekday - 1; // 1 = Mon, 7 = Sun
    _startDate = DateTime(startOfHistory.year, startOfHistory.month, startOfHistory.day)
        .subtract(Duration(days: daysToSubtract));

    // Scroll to the end (most recent dates) after rendering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getCellColor(double minutes, bool isFuture) {
    if (isFuture) return Colors.transparent;
    if (minutes <= 0.0) return Colors.white.withOpacity(0.04);
    if (minutes <= 15.0) return const Color(0xFF10B981).withOpacity(0.25);
    if (minutes <= 30.0) return const Color(0xFF10B981).withOpacity(0.50);
    if (minutes <= 60.0) return const Color(0xFF10B981).withOpacity(0.75);
    return const Color(0xFF10B981); // Bright emerald for 60+ mins
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<String> _getMonthLabels() {
    final List<String> labels = List.filled(53, "");
    DateTime current = _startDate;
    int lastMonth = -1;

    for (int week = 0; week < 53; week++) {
      if (current.month != lastMonth) {
        labels[week] = _getMonthAbbreviation(current.month);
        lastMonth = current.month;
      }
      current = current.add(const Duration(days: 7));
    }
    return labels;
  }

  String _getMonthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final monthLabels = _getMonthLabels();
    const double cellSize = 11.0;
    const double cellSpacing = 3.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
          child: Row(
            children: [
              const Icon(Icons.grid_on, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                "Productivity Heatmap",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // Horizontally scrolling grid wrapper
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday Labels Column
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 18.0), // Padding to align with month headers
                  _buildWeekdayLabel("M"),
                  const SizedBox(height: cellSpacing * 2 + cellSize), // Skip Tue
                  _buildWeekdayLabel("W"),
                  const SizedBox(height: cellSpacing * 2 + cellSize), // Skip Thu
                  _buildWeekdayLabel("F"),
                  const SizedBox(height: cellSpacing + cellSize), // Skip Sat/Sun padding
                ],
              ),
              const SizedBox(width: 8.0),
              // Main Grid with Month Headers
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Labels row
                  Row(
                    children: List.generate(53, (weekIndex) {
                      final label = monthLabels[weekIndex];
                      return Container(
                        width: cellSize + cellSpacing,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 8.0,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6.0),
                  // The 7x53 grid of days
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(53, (weekIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(right: cellSpacing),
                        child: Column(
                          children: List.generate(7, (dayIndex) {
                            final cellDate = _startDate.add(Duration(days: (weekIndex * 7) + dayIndex));
                            final isFuture = cellDate.isAfter(_today);
                            final dateKey = _formatDateString(cellDate);
                            final mins = widget.dailyMinutes[dateKey] ?? 0.0;
                            final color = _getCellColor(mins, isFuture);

                            return GestureDetector(
                              onTap: isFuture
                                  ? null
                                  : () {
                                      final dateStr = "${cellDate.day}. ${_getMonthAbbreviation(cellDate.month)} ${cellDate.year}";
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "$dateStr: ${mins.toStringAsFixed(1)} mins focused",
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          backgroundColor: const Color(0xFF0F172A),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10.0),
                                            side: BorderSide(
                                              color: Colors.white.withOpacity(0.08),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              child: Container(
                                width: cellSize,
                                height: cellSize,
                                margin: const EdgeInsets.only(bottom: cellSpacing),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Legend Row
        Padding(
          padding: const EdgeInsets.only(top: 10.0, right: 24.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("Less", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9.0)),
              const SizedBox(width: 4.0),
              _buildLegendBox(Colors.white.withOpacity(0.04)),
              _buildLegendBox(const Color(0xFF10B981).withOpacity(0.25)),
              _buildLegendBox(const Color(0xFF10B981).withOpacity(0.50)),
              _buildLegendBox(const Color(0xFF10B981).withOpacity(0.75)),
              _buildLegendBox(const Color(0xFF10B981)),
              const SizedBox(width: 4.0),
              Text("More", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9.0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabel(String text) {
    return Container(
      height: 11.0,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 8.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 9.0,
      height: 9.0,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
