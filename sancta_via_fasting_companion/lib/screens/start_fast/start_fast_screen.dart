import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/fast_type.dart';
import '../../models/fast_type_category.dart';
import '../../providers/fast_session_providers.dart';
import '../../providers/fast_type_providers.dart';

class StartFastScreen extends ConsumerStatefulWidget {
  const StartFastScreen({super.key});

  @override
  ConsumerState<StartFastScreen> createState() => _StartFastScreenState();
}

class _StartFastScreenState extends ConsumerState<StartFastScreen> {
  FastType? _selectedFastType;
  int? _customDurationMinutes;
  final _notesController = TextEditingController();
  bool _isStarting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFastTypesAsync = ref.watch(allFastTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start a Fast'),
      ),
      body: allFastTypesAsync.when(
        data: (fastTypes) => _buildContent(fastTypes),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(error: error),
      ),
    );
  }

  Widget _buildContent(List<FastType> allFastTypes) {
    // Group fast types by category
    final flexibleTypes = allFastTypes
        .where((ft) => ft.category == FastTypeCategory.flexible)
        .toList();
    final intermittentTypes = allFastTypes
        .where((ft) => ft.category == FastTypeCategory.intermittent)
        .toList();
    final daily24hrTypes = allFastTypes
        .where((ft) => ft.category == FastTypeCategory.daily24hr)
        .toList();
    final liturgicalTypes = allFastTypes
        .where((ft) => ft.category == FastTypeCategory.liturgical)
        .toList();
    final multiDayTypes = allFastTypes
        .where((ft) => ft.category == FastTypeCategory.multiDay)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Instructions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Choose Your Fast',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Select a fasting type below to begin. You can customize the duration or add personal notes.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Flexible/Open-Ended Fasting (Featured)
        if (flexibleTypes.isNotEmpty) ...[
          _ProminentFastTypeCard(
            fastType: flexibleTypes.first,
            isSelected: _selectedFastType?.id == flexibleTypes.first.id,
            onTap: () => _selectFastType(flexibleTypes.first),
          ),
          const SizedBox(height: 24),
        ],

        // Intermittent Fasting
        if (intermittentTypes.isNotEmpty) ...[
          _SectionHeader(
            title: 'Intermittent Fasting',
            icon: Icons.schedule,
          ),
          const SizedBox(height: 12),
          ...intermittentTypes.map((ft) => _FastTypeCard(
                fastType: ft,
                isSelected: _selectedFastType?.id == ft.id,
                onTap: () => _selectFastType(ft),
              )),
          const SizedBox(height: 24),
        ],

        // 24-Hour Fasts
        if (daily24hrTypes.isNotEmpty) ...[
          _SectionHeader(
            title: '24-Hour Fasts',
            icon: Icons.today,
          ),
          const SizedBox(height: 12),
          ...daily24hrTypes.map((ft) => _FastTypeCard(
                fastType: ft,
                isSelected: _selectedFastType?.id == ft.id,
                onTap: () => _selectFastType(ft),
              )),
          const SizedBox(height: 24),
        ],

        // Liturgical Fasts
        if (liturgicalTypes.isNotEmpty) ...[
          _SectionHeader(
            title: 'Liturgical Fasts',
            icon: Icons.church,
          ),
          const SizedBox(height: 12),
          ...liturgicalTypes.map((ft) => _FastTypeCard(
                fastType: ft,
                isSelected: _selectedFastType?.id == ft.id,
                onTap: () => _selectFastType(ft),
              )),
          const SizedBox(height: 24),
        ],

        // Multi-Day Fasts
        if (multiDayTypes.isNotEmpty) ...[
          _SectionHeader(
            title: 'Multi-Day Fasts',
            icon: Icons.calendar_month,
          ),
          const SizedBox(height: 12),
          ...multiDayTypes.map((ft) => _FastTypeCard(
                fastType: ft,
                isSelected: _selectedFastType?.id == ft.id,
                onTap: () => _selectFastType(ft),
              )),
          const SizedBox(height: 24),
        ],

        // Custom Duration Section (only for non-open-ended fasts)
        if (_selectedFastType != null &&
            _selectedFastType!.targetDurationHours != null &&
            _selectedFastType!.targetDurationHours! > 0) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Duration (Optional)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Hours',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 16',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final hours = int.tryParse(value);
                            if (hours != null) {
                              setState(() {
                                _customDurationMinutes = hours * 60;
                              });
                            } else {
                              setState(() {
                                _customDurationMinutes = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Default: ${_selectedFastType!.targetDurationHours} hours',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Notes Section
        if (_selectedFastType != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes (Optional)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Add any notes about this fast...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Start Button
        if (_selectedFastType != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isStarting ? null : _startFast,
              icon: _isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isStarting ? 'Starting...' : 'Start Fast'),
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  void _selectFastType(FastType fastType) {
    setState(() {
      _selectedFastType = fastType;
      _customDurationMinutes = null;
    });
  }

  Future<void> _startFast() async {
    if (_selectedFastType == null) return;

    setState(() {
      _isStarting = true;
    });

    try {
      final notifier = ref.read(activeFastSessionProvider.notifier);

      // For open-ended fasts (targetDurationHours = 0), use a very large duration
      // This will be updated when the user completes/categorizes the fast
      final isOpenEnded = _selectedFastType!.targetDurationHours == 0;
      final targetMinutes = isOpenEnded
          ? (365 * 24 * 60) // 1 year max (placeholder for open-ended)
          : (_customDurationMinutes ??
              (_selectedFastType!.targetDurationHours! * 60));

      final notificationWarning = await notifier.startFast(
        fastTypeId: _selectedFastType!.id,
        targetDurationMinutes: targetMinutes,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (!mounted) return;

      // Navigate to active fast screen
      context.go('/');

      // Show success message or warning if there were notification issues
      if (notificationWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notificationWarning),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                context.push('/settings');
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOpenEnded
                  ? 'Open-ended fast started! Fast until you\'re ready.'
                  : 'Fast started! Good luck!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting fast: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _FastTypeCard extends StatelessWidget {
  final FastType fastType;
  final bool isSelected;
  final VoidCallback onTap;

  const _FastTypeCard({
    required this.fastType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: Colors.grey[400],
                  size: 28,
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fastType.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fastType.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withAlpha(200)
                                : Colors.grey[600],
                          ),
                    ),
                    if (fastType.targetDurationHours != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fastType.targetDurationHours} hours',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProminentFastTypeCard extends StatelessWidget {
  final FastType fastType;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProminentFastTypeCard({
    required this.fastType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 8 : 4,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fastType.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'FLEXIBLE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                fastType.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withAlpha(220)
                          : Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer
                              .withAlpha(220),
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Counts up - no set target',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.label_outline,
                    size: 18,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Categorize when done',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error Loading Fast Types',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
