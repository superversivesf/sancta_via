import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar_riverpod/liturgical_calendar_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: LiturgicalCalendarApp(),
    ),
  );
}

class LiturgicalCalendarApp extends ConsumerWidget {
  const LiturgicalCalendarApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use liturgical theme that adapts to current season
    final theme = ref.watch(liturgicalThemeProvider);

    return MaterialApp(
      title: 'Liturgical Calendar Riverpod Example',
      theme: theme,
      home: const LiturgicalHomePage(),
    );
  }
}

class LiturgicalHomePage extends ConsumerWidget {
  const LiturgicalHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liturgical Calendar'),
        backgroundColor: ref.watch(liturgicalColorProvider),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current day information
            CurrentDayCard(),
            SizedBox(height: 16),
            
            // Upcoming celebrations
            UpcomingCelebrationsCard(),
            SizedBox(height: 16),
            
            // This week's liturgical days
            ThisWeekCard(),
            SizedBox(height: 16),
            
            // Search functionality
            SearchCard(),
            SizedBox(height: 16),
            
            // Analytics
            AnalyticsCard(),
          ],
        ),
      ),
      floatingActionButton: const NotificationFab(),
    );
  }
}

/// Widget showing current liturgical day information
class CurrentDayCard extends ConsumerWidget {
  const CurrentDayCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDay = ref.watch(currentLiturgicalDayProvider);
    final liturgicalInfo = ref.watch(liturgicalInfoProvider);
    final seasonIcon = ref.watch(seasonIconProvider);
    final rankIcon = ref.watch(rankIconProvider);
    final color = ref.watch(liturgicalColorProvider);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(seasonIcon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Today - ${liturgicalInfo['date']}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(rankIcon, color: color),
              ],
            ),
            const SizedBox(height: 12),
            
            if (currentDay != null) ...[
              _InfoRow('Celebration', liturgicalInfo['celebration']!, color),
              _InfoRow('Season', liturgicalInfo['season']!, color),
              _InfoRow('Rank', liturgicalInfo['rank']!, color),
              _InfoRow('Color', liturgicalInfo['color']!, color),
              _InfoRow('Cycle', liturgicalInfo['cycle']!, color),
              _InfoRow('Psalter Week', liturgicalInfo['psalterWeek']!, color),
              
              if (currentDay.celebration.prioritized)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⭐ Prioritized Celebration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ] else
              const Text('No liturgical data available for today'),
          ],
        ),
      ),
    );
  }

  Widget _InfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Widget showing upcoming celebrations
class UpcomingCelebrationsCard extends ConsumerWidget {
  const UpcomingCelebrationsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingUI = ref.watch(upcomingCelebrationsUIProvider);
    final nextMajor = ref.watch(nextMajorCelebrationProvider);
    final daysUntil = ref.watch(daysUntilMajorCelebrationProvider);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Celebrations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            if (nextMajor != null && daysUntil != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Major: ${nextMajor.celebration.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('In $daysUntil days (${nextMajor.date})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            ...upcomingUI.take(5).map((celebration) => ListTile(
              dense: true,
              leading: Icon(
                celebration['rank'] == 'SOLEMNITY' ? Icons.star : Icons.event,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(celebration['name']!),
              subtitle: Text('${celebration['rank']} • ${celebration['date']}'),
              trailing: Text('${celebration['daysUntil']} days'),
            )),
          ],
        ),
      ),
    );
  }
}

/// Widget showing this week's liturgical days
class ThisWeekCard extends ConsumerWidget {
  const ThisWeekCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thisWeek = ref.watch(thisWeekProvider);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            ...thisWeek.map((day) {
              final dayDate = DateTime.parse(day.date);
              final isToday = dayDate.day == DateTime.now().day &&
                             dayDate.month == DateTime.now().month;
              final color = ref.watch(liturgicalColorByDateProvider(dayDate));
              
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isToday ? color.withOpacity(0.2) : null,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday ? Border.all(color: color) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        _getDayName(dayDate),
                        style: TextStyle(
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        day.celebration.name,
                        style: TextStyle(
                          fontWeight: day.celebration.prioritized 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        day.season,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]} ${date.day}';
  }
}

/// Widget for searching celebrations
class SearchCard extends ConsumerStatefulWidget {
  const SearchCard({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends ConsumerState<SearchCard> {
  final _controller = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final searchResults = _searchQuery.isNotEmpty
        ? ref.watch(searchCelebrationsProvider((query: _searchQuery, year: null)))
        : <LiturgicalDayData>[];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Celebrations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search for celebrations (e.g., "Mary", "Easter")',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            
            if (searchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Found ${searchResults.length} results:'),
              const SizedBox(height: 8),
              
              ...searchResults.take(5).map((result) => ListTile(
                dense: true,
                title: Text(result.celebration.name),
                subtitle: Text('${result.date} • ${result.season}'),
                trailing: Chip(
                  label: Text(result.celebration.rank),
                  backgroundColor: ref.watch(liturgicalColorByDateProvider(
                    DateTime.parse(result.date)
                  )).withOpacity(0.3),
                ),
              )),
              
              if (searchResults.length > 5)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('... and ${searchResults.length - 5} more'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Widget showing liturgical analytics
class AnalyticsCard extends ConsumerWidget {
  const AnalyticsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalStats = ref.watch(globalStatisticsProvider);
    final currentYear = DateTime.now().year;
    final yearAnalytics = ref.watch(liturgicalAnalyticsProvider(currentYear));
    final yearProgress = ref.watch(liturgicalYearProgressProvider);
    final liturgicalMode = ref.watch(liturgicalModeProvider);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liturgical Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Current liturgical mode
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    liturgicalMode['mode'] == 'celebration' ? Icons.celebration :
                    liturgicalMode['mode'] == 'preparation' ? Icons.schedule :
                    liturgicalMode['mode'] == 'penance' ? Icons.self_improvement :
                    Icons.calendar_today,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Mode: ${liturgicalMode['mode']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Emphasis: ${liturgicalMode['emphasis']}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Year progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liturgical Year Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: yearProgress['progress'],
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 4),
                Text(
                  'Day ${yearProgress['dayOfYear']} of ${yearProgress['totalDays']} '
                  '(${(yearProgress['progress'] * 100).toStringAsFixed(1)}%)',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Global statistics
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    'Total Years',
                    '${globalStats['totalYears']}',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    'Total Days',
                    '${globalStats['totalDays']}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    'Prioritized',
                    '${globalStats['totalPrioritizedCelebrations']}',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    'This Year',
                    '${yearAnalytics['prioritizedCount']}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _StatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

/// Floating action button showing liturgical notifications
class NotificationFab extends ConsumerWidget {
  const NotificationFab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(liturgicalRemindersProvider);
    final hasNotifications = reminders.isNotEmpty;

    return FloatingActionButton(
      onPressed: () {
        _showRemindersDialog(context, reminders);
      },
      backgroundColor: hasNotifications ? Colors.red : null,
      child: Stack(
        children: [
          const Icon(Icons.notifications),
          if (hasNotifications)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '${reminders.length}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRemindersDialog(BuildContext context, List<Map<String, dynamic>> reminders) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liturgical Reminders'),
        content: reminders.isEmpty
          ? const Text('No upcoming celebrations in the next 7 days.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: reminders.map((reminder) => ListTile(
                leading: Icon(
                  reminder['priority'] == 'high' ? Icons.star : Icons.event,
                  color: reminder['priority'] == 'high' ? Colors.amber : Colors.blue,
                ),
                title: Text(reminder['title']),
                subtitle: Text('${reminder['daysUntil']} days • ${reminder['rank']}'),
              )).toList(),
            ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
