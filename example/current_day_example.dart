/// Example demonstrating the currentLiturgicalDayProvider
/// 
/// This example shows how to use the main provider that returns 
/// the current liturgical calendar for the day, as requested.
///
/// Run with: dart run example/current_day_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar_riverpod/liturgical_calendar_riverpod.dart';

void main() {
  runApp(
    ProviderScope(
      child: LiturgicalCalendarApp(),
    ),
  );
}

class LiturgicalCalendarApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Current Liturgical Day Example',
      home: CurrentDayDemo(),
    );
  }
}

/// Main widget demonstrating the currentLiturgicalDayProvider
class CurrentDayDemo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⭐ MAIN FEATURE: Provider that returns current liturgical calendar for the day
    final currentDay = ref.watch(currentLiturgicalDayProvider);
    final liturgicalColor = ref.watch(liturgicalColorProvider);
    final seasonIcon = ref.watch(seasonIconProvider);
    final liturgicalInfo = ref.watch(liturgicalInfoProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Current Liturgical Day'),
        backgroundColor: liturgicalColor,
        foregroundColor: _getContrastingColor(liturgicalColor),
      ),
      body: currentDay == null 
        ? Center(child: Text('No liturgical data available'))
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main liturgical day card
                Card(
                  elevation: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          liturgicalColor.withOpacity(0.1),
                          liturgicalColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: liturgicalColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(seasonIcon, color: liturgicalColor, size: 32),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentDay.celebration.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: liturgicalColor,
                                      ),
                                    ),
                                    Text(
                                      currentDay.season,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (currentDay.celebration.prioritized)
                                Icon(Icons.star, color: Colors.amber, size: 24),
                            ],
                          ),
                          SizedBox(height: 16),
                          _buildInfoRow('Date', liturgicalInfo['date']!),
                          _buildInfoRow('Rank', liturgicalInfo['rank']!),
                          _buildInfoRow('Color', liturgicalInfo['color']!),
                          _buildInfoRow('Liturgical Cycle', liturgicalInfo['cycle']!),
                          _buildInfoRow('Psalter Week', liturgicalInfo['psalterWeek']!),
                        ],
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Additional provider examples
                Text(
                  'Additional Provider Examples',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                
                _buildProviderExample(
                  'Current Season',
                  ref.watch(currentLiturgicalSeasonProvider) ?? 'Unknown',
                ),
                
                _buildProviderExample(
                  'Current Color', 
                  ref.watch(currentLiturgicalColorProvider) ?? 'Unknown',
                ),
                
                _buildProviderExample(
                  'Is Prioritized Celebration',
                  ref.watch(todayHasPrioritizedCelebrationProvider) ? 'Yes' : 'No',
                ),
                
                // Upcoming feasts example
                SizedBox(height: 24),
                Text(
                  'Upcoming Feasts (Next 7 Days)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                _buildUpcomingFeasts(ref),
                
                // Direct service usage example
                SizedBox(height: 24),
                Text(
                  'Direct Service Usage (No Provider)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                _buildDirectServiceExample(),
              ],
            ),
          ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProviderExample(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
        leading: Icon(Icons.code),
      ),
    );
  }
  
  Widget _buildUpcomingFeasts(WidgetRef ref) {
    final upcomingFeasts = ref.watch(upcomingFeastsProvider(7));
    
    if (upcomingFeasts.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No upcoming feasts in the next 7 days'),
        ),
      );
    }
    
    return Column(
      children: upcomingFeasts.map((feast) {
        final daysUntil = DateTime.parse(feast.date).difference(DateTime.now()).inDays;
        return Card(
          child: ListTile(
            title: Text(feast.celebration.name),
            subtitle: Text('${feast.season} • ${feast.celebration.rank}'),
            trailing: Text('${daysUntil} days'),
            leading: CircleAvatar(
              backgroundColor: _getLiturgicalColor(feast.celebration.color),
              child: Text(
                daysUntil.toString(),
                style: TextStyle(
                  color: _getContrastingColor(_getLiturgicalColor(feast.celebration.color)),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildDirectServiceExample() {
    // Example of using the service directly without providers
    final currentDay = LiturgicalCalendarService.getCurrentDay();
    final christmas2025 = LiturgicalCalendarService.getDayForDate(DateTime(2025, 12, 25));
    final easterSearchResults = LiturgicalCalendarService.searchCelebrations('Easter');
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Direct Service Calls:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('getCurrentDay(): ${currentDay?.celebration.name ?? "null"}'),
            Text('Christmas 2025: ${christmas2025?.celebration.name ?? "not found"}'),
            Text('Easter search results: ${easterSearchResults.length} found'),
            SizedBox(height: 12),
            Text(
              'Code Example:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '''
// No providers needed - direct service access
final today = LiturgicalCalendarService.getCurrentDay();
final christmas = LiturgicalCalendarService.getDayForDate(
  DateTime(2025, 12, 25)
);
final results = LiturgicalCalendarService.searchCelebrations('Easter');
                '''.trim(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getLiturgicalColor(String? colorString) {
    switch (colorString?.toUpperCase()) {
      case 'WHITE': return Colors.grey.shade100;
      case 'RED': return Colors.red.shade700;
      case 'GREEN': return Colors.green.shade700;
      case 'PURPLE': return Colors.purple.shade700;
      case 'ROSE': return Colors.pink.shade300;
      case 'GOLD': return Colors.amber.shade600;
      default: return Colors.grey.shade500;
    }
  }
  
  Color _getContrastingColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
