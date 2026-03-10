import 'package:flutter/material.dart';

import '../../models/rosary_session.dart';

/// Widget displaying a list of recent prayer sessions
///
/// Shows up to 20 most recent completed sessions with
/// date, mystery set, and completion status.
class RecentSessionsList extends StatelessWidget {
  /// List of recent sessions to display
  final List<RosarySession> sessions;

  /// Callback when a session is tapped
  final Function(RosarySession)? onSessionTap;

  const RecentSessionsList({
    required this.sessions,
    this.onSessionTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Recent Sessions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sessions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final session = sessions[index];
            return _SessionListTile(
              session: session,
              onTap: () => onSessionTap?.call(session),
            );
          },
        ),
      ],
    );
  }
}

class _SessionListTile extends StatelessWidget {
  final RosarySession session;
  final VoidCallback? onTap;

  const _SessionListTile({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final endTime = session.endTime ?? session.startTime;
    final dateStr = _formatDate(endTime);
    final timeStr = _formatTime(endTime);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getMysteryColor(session.mysterySet).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getMysteryIcon(session.mysterySet),
          color: _getMysteryColor(session.mysterySet),
        ),
      ),
      title: Text(
        session.mysterySet.displayName,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '$dateStr · $timeStr',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: session.completed
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final hourDisplay = hour == 0 ? 12 : hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hourDisplay:$minute $period';
  }

  IconData _getMysteryIcon(dynamic mysterySet) {
    switch (mysterySet.toString()) {
      case 'MysterySet.joyful':
        return Icons.celebration;
      case 'MysterySet.sorrowful':
        return Icons.church;
      case 'MysterySet.glorious':
        return Icons.wb_sunny;
      case 'MysterySet.luminous':
        return Icons.lightbulb;
      default:
        return Icons.favorite;
    }
  }

  Color _getMysteryColor(dynamic mysterySet) {
    switch (mysterySet.toString()) {
      case 'MysterySet.joyful':
        return Colors.green;
      case 'MysterySet.sorrowful':
        return Colors.purple;
      case 'MysterySet.glorious':
        return Colors.amber;
      case 'MysterySet.luminous':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }
}
