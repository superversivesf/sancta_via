import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:sancta_via_shared_ui/sancta_via_shared_ui.dart';
import 'package:sancta_via_liturgical_calendar/sancta_via_liturgical_calendar.dart';
import '../../providers/calendar_providers.dart' as local_providers;
import '../../widgets/liturgical_day_card.dart';
import '../../widgets/upcoming_feasts_list.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayedMonth = ref.watch(local_providers.displayedMonthProvider);
    final monthDays = ref.watch(local_providers.monthLiturgicalDaysProvider);
    final selectedDate = ref.watch(local_providers.selectedDateProvider);
    final upcomingFeasts = ref.watch(local_providers.upcomingFeastsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liturgical Calendar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              ref.read(local_providers.displayedMonthProvider.notifier).state =
                  DateTime(now.year, now.month, 1);
              ref.read(local_providers.selectedDateProvider.notifier).state =
                  today;
            },
            tooltip: 'Go to today',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        top: false, // Let AppBar handle top
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Month navigation
              _buildMonthNavigation(context, ref, displayedMonth),

              // Calendar grid - no constraints, natural size
              _buildCalendarGrid(
                context,
                ref,
                displayedMonth,
                monthDays,
                selectedDate,
              ),

              // Selected day info
              _buildSelectedDayInfo(context, ref, selectedDate),

              // Upcoming feasts - natural height
              UpcomingFeastsList(feasts: upcomingFeasts),

              // Bottom padding for better scrolling
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/search'),
        tooltip: 'Search celebrations',
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildMonthNavigation(
    BuildContext context,
    WidgetRef ref,
    DateTime displayedMonth,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              ref.read(local_providers.displayedMonthProvider.notifier).state =
                  DateTime(displayedMonth.year, displayedMonth.month - 1, 1);
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(displayedMonth),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              ref.read(local_providers.displayedMonthProvider.notifier).state =
                  DateTime(displayedMonth.year, displayedMonth.month + 1, 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    WidgetRef ref,
    DateTime displayedMonth,
    Map<int, LiturgicalDayData> monthDays,
    DateTime selectedDate,
  ) {
    final theme = Theme.of(context);

    // Calculate days in month
    final daysInMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    ).day;

    // Calculate the weekday of the first day (1 = Monday, 7 = Sunday)
    final firstDayWeekday = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    ).weekday;

    // Adjust for Sunday being the first day of the week (0 = Sunday, 6 = Saturday)
    final firstDayOffset = firstDayWeekday % 7;

    // Calculate the number of rows needed for this month
    // Last day position = firstDayOffset + daysInMonth - 1
    // Rows needed = (last day position / 7) + 1
    final rowsNeeded = ((firstDayOffset + daysInMonth - 1) ~/ 7) + 1;
    final gridItemCount = rowsNeeded * 7;

    // Days of the week header
    const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Days of week header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek
                .map(
                  (day) => SizedBox(
                    width: 40,
                    child: Text(
                      day,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // Calendar grid - dynamic height based on rows needed
        GridView.builder(
          shrinkWrap: true, // Size to content
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
          ),
          itemCount: gridItemCount, // Dynamic: rowsNeeded * 7
          itemBuilder: (context, index) {
            // Calculate the day number (1-based)
            final dayNumber = index - firstDayOffset + 1;

            // Check if this grid position is part of the current month
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            // Get liturgical day info if available
            final liturgicalDay = monthDays[dayNumber];

            // Current date
            final currentDate = DateTime(
              displayedMonth.year,
              displayedMonth.month,
              dayNumber,
            );

            // Check if this is the selected date
            final isSelected =
                selectedDate.year == currentDate.year &&
                selectedDate.month == currentDate.month &&
                selectedDate.day == currentDate.day;

            // Check if this is today's date
            final now = DateTime.now();
            final isToday =
                now.year == currentDate.year &&
                now.month == currentDate.month &&
                now.day == currentDate.day;

            return _buildCalendarDay(
              context,
              ref,
              dayNumber,
              currentDate,
              liturgicalDay,
              isSelected,
              isToday,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCalendarDay(
    BuildContext context,
    WidgetRef ref,
    int dayNumber,
    DateTime currentDate,
    LiturgicalDayData? liturgicalDay,
    bool isSelected,
    bool isToday,
  ) {
    final theme = Theme.of(context);
    final colorIntensity = ref.watch(colorIntensityProvider);

    // Default color is theme surface color
    Color dayColor = theme.colorScheme.surface;

    // Use liturgical color if available
    if (liturgicalDay != null) {
      dayColor = liturgicalDay.celebration.color.toLiturgicalColorWithOpacity(
        0.2,
        colorIntensity,
      );
    }

    return GestureDetector(
      onTap: () {
        ref.read(local_providers.selectedDateProvider.notifier).state =
            currentDate;
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: dayColor,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNumber.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (liturgicalDay != null &&
                _isSignificantCelebration(liturgicalDay))
              Icon(
                _getCelebrationIcon(liturgicalDay),
                size: 12,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayInfo(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) {
    final liturgicalDay = ref.watch(
      local_providers.liturgicalDayForDateProvider(selectedDate),
    );

    if (liturgicalDay != null) {
      return LiturgicalDayCard(
        liturgicalDay: liturgicalDay,
        selectedDate: selectedDate,
        onTap: () => context.push(
          '/day/${selectedDate.toIso8601String().split('T')[0]}',
        ),
      );
    } else {
      return Container(
        height: 120,
        margin: const EdgeInsets.all(8),
        child: const Center(
          child: Text('No liturgical data available for this date'),
        ),
      );
    }
  }

  // Helper function to determine if a day has a significant celebration
  bool _isSignificantCelebration(LiturgicalDayData liturgicalDay) {
    return liturgicalDay.celebration.prioritized ||
        liturgicalDay.celebration.isSolemnity ||
        liturgicalDay.celebration.isFeast ||
        liturgicalDay.celebration.isMemorial;
  }

  // Helper function to get appropriate icon for celebration type
  IconData _getCelebrationIcon(LiturgicalDayData liturgicalDay) {
    switch (liturgicalDay.celebration.rank) {
      case 'SOLEMNITY':
        return Icons.star;
      case 'FEAST':
        return Icons.star_half;
      case 'MEMORIAL':
        return Icons.circle;
      case 'OPT_MEMORIAL':
        return Icons.circle_outlined;
      default:
        return liturgicalDay.celebration.prioritized
            ? Icons.star_outline
            : Icons.circle_outlined;
    }
  }
}
