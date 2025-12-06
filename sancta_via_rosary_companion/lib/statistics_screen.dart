import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with real data from database
    final sessions = _getSampleSessions();
    final stats = _calculateStatistics(sessions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatsRow(
                      'Prayers Completed',
                      '${stats.totalSessions}',
                    ),
                    _buildStatsRow('Time Spent', _formatTime(stats.totalTime)),
                    _buildStatsRow(
                      'Average Time',
                      _formatTime(stats.averageTime),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mystery Distribution',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMysteryStats('Joyful', stats.joyfulCount),
                    _buildMysteryStats('Sorrowful', stats.sorrowfulCount),
                    _buildMysteryStats('Glorious', stats.gloriousCount),
                    _buildMysteryStats('Luminous', stats.luminousCount),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (sessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No recent prayers to display',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Column(
                        children: sessions.take(5).map((session) {
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.favorite, color: Colors.white),
                            ),
                            title: Text('Prayed ${session.type} Mysteries'),
                            subtitle: Text(_formatDate(session.date)),
                            trailing: Text(_formatDuration(session.duration)),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMysteryStats(String mystery, int count) {
    final total = count + 5; // Add some baseline for demo
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$mystery Mysteries',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text('$count'),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getMysteryColor(mystery),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getMysteryColor(String mystery) {
    switch (mystery) {
      case 'Joyful':
        return Colors.green;
      case 'Sorrowful':
        return Colors.red;
      case 'Glorious':
        return Colors.yellow.shade700;
      case 'Luminous':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  String _formatDuration(int minutes) {
    if (minutes < 10) return '5-10m';
    return '${((minutes ~/ 5) * 5).toString()}m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} weeks ago';
    return '${difference.inDays ~/ 30} months ago';
  }

  List<SessionData> _getSampleSessions() {
    final now = DateTime.now();
    return [
      SessionData(
        'Joyful Mysteries',
        now.subtract(const Duration(days: 1)),
        18,
      ),
      SessionData(
        'Sorrowful Mysteries',
        now.subtract(const Duration(days: 2)),
        22,
      ),
      SessionData(
        'Glorious Mysteries',
        now.subtract(const Duration(days: 3)),
        15,
      ),
      SessionData(
        'Luminous Mysteries',
        now.subtract(const Duration(days: 5)),
        20,
      ),
      SessionData(
        'Joyful Mysteries',
        now.subtract(const Duration(days: 7)),
        17,
      ),
    ];
  }

  StatsData _calculateStatistics(List<SessionData> sessions) {
    final totalSessions = sessions.length;
    final totalTime = sessions.fold(
      0,
      (sum, session) => sum + session.duration,
    );
    final averageTime = totalSessions > 0 ? totalTime ~/ totalSessions : 0;

    final joyfulCount = sessions.where((s) => s.type.contains('Joyful')).length;
    final sorrowfulCount = sessions
        .where((s) => s.type.contains('Sorrowful'))
        .length;
    final gloriousCount = sessions
        .where((s) => s.type.contains('Glorious'))
        .length;
    final luminousCount = sessions
        .where((s) => s.type.contains('Luminous'))
        .length;

    return StatsData(
      totalSessions: totalSessions,
      totalTime: totalTime,
      averageTime: averageTime,
      joyfulCount: joyfulCount,
      sorrowfulCount: sorrowfulCount,
      gloriousCount: gloriousCount,
      luminousCount: luminousCount,
    );
  }
}

class SessionData {
  final String type;
  final DateTime date;
  final int duration;

  SessionData(this.type, this.date, this.duration);
}

class StatsData {
  final int totalSessions;
  final int totalTime;
  final int averageTime;
  final int joyfulCount;
  final int sorrowfulCount;
  final int gloriousCount;
  final int luminousCount;

  StatsData({
    required this.totalSessions,
    required this.totalTime,
    required this.averageTime,
    required this.joyfulCount,
    required this.sorrowfulCount,
    required this.gloriousCount,
    required this.luminousCount,
  });
}
