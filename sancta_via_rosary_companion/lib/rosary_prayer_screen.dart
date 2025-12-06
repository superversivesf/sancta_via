import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/rosary_providers.dart';
import 'models/rosary_bead.dart';
import 'models/bead_type.dart';

class RosaryPrayerScreen extends ConsumerWidget {
  const RosaryPrayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerController = ref.watch(prayerControllerProvider);
    final currentBead = ref.watch(currentBeadProvider);
    final currentBeadIndex = ref.watch(currentBeadIndexProvider);
    final totalBeads = ref.watch(totalBeadsProvider);
    final isPrayerComplete = ref.watch(isPrayerCompleteProvider);
    final currentDecade = ref.watch(currentDecadeProvider);
    final currentMysteriesAsync = ref.watch(currentMysteriesProvider);
    final currentMysteryIndex = ref.watch(currentMysteryIndexProvider);
    final settings = ref.watch(rosarySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pray the Rosary'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () {
              // TODO: Pause functionality
            },
          ),
        ],
      ),
      body: currentMysteriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
        data: (mysteries) {
          if (mysteries.isEmpty || currentMysteryIndex >= mysteries.length) {
            return const Center(child: Text('No mysteries available'));
          }

          final currentMystery = mysteries[currentMysteryIndex];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mystery display with image
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Mystery image (if available and settings enabled)
                        if (currentMystery.imagePath != null &&
                            settings.showImagery) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.asset(
                              currentMystery.imagePath!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Image not available',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Mystery ${currentMysteryIndex + 1}: ${currentMystery.title}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentMystery.description,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentMystery.scriptureText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Progress indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bead ${currentBeadIndex + 1} of $totalBeads',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Decade: ${currentDecade == 0 ? 'Intro' : currentDecade}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Bead grid
                _buildBeadDisplay(currentBeadIndex, totalBeads),
                const SizedBox(height: 20),

                // Prayer text
                _buildPrayerDisplay(
                  currentBead,
                  isPrayerComplete,
                  prayerController,
                ),
                const SizedBox(height: 20),

                // Navigation buttons
                _buildMysteryNavigation(
                  prayerController,
                  currentMysteryIndex,
                  currentBeadIndex,
                  totalBeads,
                ),

                // Complete prayer button if done
                if (isPrayerComplete) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      prayerController.resetPrayer();
                      context.go('/home');
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Return to Home'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBeadDisplay(int currentIndex, int totalBeads) {
    const int beadsPerRow = 10;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(beadsPerRow, (index) {
            final beadNumber = index;
            final isCurrent = beadNumber == currentIndex % beadsPerRow;

            return Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent ? Colors.blue : Colors.grey.shade300,
                border: Border.all(color: Colors.grey.shade500, width: 1),
              ),
              child: Center(
                child: Text(
                  '${beadNumber + 1}',
                  style: TextStyle(
                    color: isCurrent ? Colors.white : Colors.grey.shade700,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Decade ${(currentIndex ~/ 10) + 1} of 5',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPrayerDisplay(
    RosaryBead currentBead,
    bool isComplete,
    PrayerController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _getPrayerTitle(currentBead.type),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isComplete ? currentBead.prayerText : currentBead.prayerText,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: isComplete ? null : controller.previousBead,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
                ElevatedButton.icon(
                  onPressed: isComplete ? null : controller.nextBead,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMysteryNavigation(
    PrayerController controller,
    int currentMystery,
    int currentBead,
    int totalBeads,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton.icon(
          onPressed: currentMystery > 0 ? controller.previousMystery : null,
          icon: const Icon(Icons.skip_previous),
          label: const Text('Previous Mystery'),
        ),
        ElevatedButton.icon(
          onPressed: currentMystery < 4 ? controller.nextMystery : null,
          icon: const Icon(Icons.skip_next),
          label: const Text('Next Mystery'),
        ),
      ],
    );
  }

  String _getPrayerTitle(BeadType type) {
    switch (type) {
      case BeadType.apostlesCreed:
        return 'Apostles\' Creed';
      case BeadType.ourFather:
        return 'Our Father';
      case BeadType.hailMary:
        return 'Hail Mary';
      case BeadType.gloryBe:
        return 'Glory Be';
      case BeadType.hailHolyQueen:
        return 'Hail Holy Queen';
      default:
        return 'Prayer';
    }
  }
}
