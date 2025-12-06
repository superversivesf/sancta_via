import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/rosary_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerController = ref.watch(prayerControllerProvider);
    final dailyMystery = ref.watch(dailyMysteryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rosary Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => context.go('/statistics'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Today\'s Mystery',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${dailyMystery.displayName} (${_getDayName()})',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        prayerController.startNewSession(
                          dailyMystery.displayName,
                        );
                        context.go('/pray');
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text('Start Rosary'),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose Mystery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMysteryButtons(context, prayerController),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName() {
    final today = DateTime.now();
    final weekday = today.weekday;

    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Today';
    }
  }

  Widget _buildMysteryButtons(
    BuildContext context,
    PrayerController controller,
  ) {
    final mysteries = [
      'Joyful Mysteries',
      'Sorrowful Mysteries',
      'Glorious Mysteries',
      'Luminous Mysteries',
    ];

    return Column(
      children: mysteries.map((mystery) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: ElevatedButton(
            onPressed: () {
              controller.startNewSession(mystery);
              context.go('/pray');
            },
            child: Text(mystery),
          ),
        );
      }).toList(),
    );
  }
}
