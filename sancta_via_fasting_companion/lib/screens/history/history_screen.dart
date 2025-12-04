import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/fast_session.dart';
import '../../models/fast_status.dart';
import '../../models/fast_type.dart';
import '../../providers/fast_session_providers.dart';
import '../../providers/fast_type_providers.dart';
import '../../services/timer_service.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedFastTypeId;
  FastStatus? _selectedStatus;

  void _showFilterDialog() async {
    final allFastTypesAsync = ref.read(allFastTypesProvider);
    final fastTypes = allFastTypesAsync.valueOrNull ?? [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FilterDialog(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        initialFastTypeId: _selectedFastTypeId,
        initialStatus: _selectedStatus,
        fastTypes: fastTypes,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result['startDate'] as DateTime?;
        _endDate = result['endDate'] as DateTime?;
        _selectedFastTypeId = result['fastTypeId'] as String?;
        _selectedStatus = result['status'] as FastStatus?;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedFastTypeId = null;
      _selectedStatus = null;
    });
  }

  bool get _hasActiveFilters =>
      _startDate != null ||
      _endDate != null ||
      _selectedFastTypeId != null ||
      _selectedStatus != null;

  List<FastSession> _applyFilters(List<FastSession> sessions) {
    var filtered = sessions;

    if (_startDate != null) {
      filtered = filtered.where((session) {
        return session.startTime.isAfter(_startDate!) ||
            session.startTime.isAtSameMomentAs(_startDate!);
      }).toList();
    }

    if (_endDate != null) {
      final endOfDay = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );
      filtered = filtered.where((session) {
        return session.startTime.isBefore(endOfDay) ||
            session.startTime.isAtSameMomentAs(endOfDay);
      }).toList();
    }

    if (_selectedFastTypeId != null) {
      filtered = filtered
          .where((session) => session.fastTypeId == _selectedFastTypeId)
          .toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((session) => session.status == _selectedStatus)
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(fastHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting History'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
          IconButton(
            icon: Icon(
              _hasActiveFilters ? Icons.filter_alt : Icons.filter_list,
            ),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fastHistoryProvider);
        },
        child: historyAsync.when(
          data: (history) {
            final filteredHistory = _applyFilters(history);

            if (filteredHistory.isEmpty) {
              return _hasActiveFilters
                  ? _NoResultsView(onClearFilters: _clearFilters)
                  : _EmptyHistoryView();
            }
            return _HistoryList(sessions: filteredHistory);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorView(error: error),
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final List<FastSession> sessions;

  const _HistoryList({required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerService = ref.watch(timerServiceProvider);

    // Group sessions by date
    final Map<String, List<FastSession>> groupedSessions = {};
    for (final session in sessions) {
      final dateKey = _formatDateKey(session.startTime);
      groupedSessions.putIfAbsent(dateKey, () => []).add(session);
    }

    final sortedKeys = groupedSessions.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final sessionsForDate = groupedSessions[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDateHeader(dateKey),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),

            // Sessions for this date
            ...sessionsForDate.map((session) =>
                _HistoryCard(session: session, timerService: timerService)),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateHeader(String dateKey) {
    final parts = dateKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    final date = DateTime(year, month, day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      final monthNames = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${monthNames[month]} $day, $year';
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final FastSession session;
  final TimerService timerService;

  const _HistoryCard({
    required this.session,
    required this.timerService,
  });

  @override
  Widget build(BuildContext context) {
    final duration = session.endTime != null
        ? session.endTime!.difference(session.startTime)
        : Duration.zero;

    final targetDuration = Duration(minutes: session.targetDurationMinutes);
    final completionPercentage =
        (duration.inMinutes / targetDuration.inMinutes * 100).clamp(0, 100);

    final isCompleted = session.status.toString().contains('completed');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          context.push('/fast-detail/${session.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.cancel,
                      color: isCompleted ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Fast type and duration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.fastTypeId
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map((word) =>
                                  word[0].toUpperCase() + word.substring(1))
                              .join(' '),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timerService.formatDurationHuman(duration),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Completion percentage
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${completionPercentage.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.green : Colors.orange,
                            ),
                      ),
                      Text(
                        isCompleted ? 'Completed' : 'Broken',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar
              LinearProgressIndicator(
                value: completionPercentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.green : Colors.orange,
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),

              const SizedBox(height: 12),

              // Time details
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatTime(session.startTime)} - ${session.endTime != null ? _formatTime(session.endTime!) : "N/A"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.flag, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Goal: ${timerService.formatDurationHuman(targetDuration)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              if (session.notes != null && session.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _FilterDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialFastTypeId;
  final FastStatus? initialStatus;
  final List<FastType> fastTypes;

  const _FilterDialog({
    this.initialStartDate,
    this.initialEndDate,
    this.initialFastTypeId,
    this.initialStatus,
    required this.fastTypes,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedFastTypeId;
  FastStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _selectedFastTypeId = widget.initialFastTypeId;
    _selectedStatus = widget.initialStatus;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter History'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range
            Text(
              'Date Range',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _startDate != null
                          ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'
                          : 'Start Date',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _endDate != null
                          ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'
                          : 'End Date',
                    ),
                  ),
                ),
              ],
            ),
            if (_startDate != null || _endDate != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear Dates'),
              ),

            const SizedBox(height: 16),

            // Fast Type
            Text(
              'Fast Type',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedFastTypeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'All Fast Types',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Fast Types'),
                ),
                ...widget.fastTypes.map((ft) => DropdownMenuItem<String>(
                      value: ft.id,
                      child: Text(ft.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedFastTypeId = value);
              },
            ),

            const SizedBox(height: 16),

            // Status
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedStatus == null,
                  onSelected: (selected) {
                    setState(() => _selectedStatus = null);
                  },
                ),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _selectedStatus == FastStatus.completed,
                  onSelected: (selected) {
                    setState(() => _selectedStatus =
                        selected ? FastStatus.completed : null);
                  },
                ),
                FilterChip(
                  label: const Text('Broken'),
                  selected: _selectedStatus == FastStatus.broken,
                  onSelected: (selected) {
                    setState(() =>
                        _selectedStatus = selected ? FastStatus.broken : null);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'startDate': _startDate,
              'endDate': _endDate,
              'fastTypeId': _selectedFastTypeId,
              'status': _selectedStatus,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _NoResultsView extends StatelessWidget {
  final VoidCallback onClearFilters;

  const _NoResultsView({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Results Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_list_off),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Fast History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first fast to see it here',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
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
            'Error Loading History',
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
