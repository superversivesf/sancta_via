import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// FIXED: Memory-safe user message service
class UserMessageService {
  static final UserMessageService _instance = UserMessageService._internal();
  factory UserMessageService() => _instance;
  UserMessageService._internal();

  // FIXED: Use WeakReference instead of static reference
  static WeakReference<GlobalKey<NavigatorState>>? _navigatorKeyRef;

  // Message queue to prevent overlapping snackbars
  final List<_QueuedMessage> _messageQueue = [];
  bool _isShowingMessage = false;

  /// FIXED: Safe navigator key setting
  static set navigatorKey(GlobalKey<NavigatorState>? key) {
    if (key != null) {
      _navigatorKeyRef = WeakReference(key);
    } else {
      _navigatorKeyRef = null;
    }
  }

  /// FIXED: Safe navigator key access
  static GlobalKey<NavigatorState>? get navigatorKey {
    return _navigatorKeyRef?.target;
  }

  /// FIXED: Queue-based message showing
  void showSuccess(String message, {Color? backgroundColor}) {
    _queueMessage(
      _QueuedMessage(
        message: message,
        backgroundColor: backgroundColor ?? Colors.green,
        icon: Icons.check_circle,
      ),
    );
  }

  /// Show info message
  void showInfo(String message) {
    _queueMessage(
      _QueuedMessage(
        message: message,
        backgroundColor: Colors.blue,
        icon: Icons.info,
      ),
    );
  }

  /// Show warning message
  void showWarning(String message) {
    _queueMessage(
      _QueuedMessage(
        message: message,
        backgroundColor: Colors.orange,
        icon: Icons.warning,
      ),
    );
  }

  /// Show error message
  void showError(String message) {
    _queueMessage(
      _QueuedMessage(
        message: message,
        backgroundColor: Colors.red,
        icon: Icons.error,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Show detailed error dialog
  void showErrorDialog(String title, String message) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog
  Future<bool> showConfirmation(String title, String message) async {
    final context = navigatorKey?.currentContext;
    if (context == null) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// NEW: Message queuing system
  void _queueMessage(_QueuedMessage message) {
    _messageQueue.add(message);
    _processMessageQueue();
  }

  /// NEW: Process message queue safely
  Future<void> _processMessageQueue() async {
    if (_isShowingMessage || _messageQueue.isEmpty) return;

    _isShowingMessage = true;

    try {
      while (_messageQueue.isNotEmpty) {
        final message = _messageQueue.removeAt(0);
        await _showSnackBarSafe(message);

        // Wait for current message to finish before showing next
        await Future.delayed(message.duration);
      }
    } finally {
      _isShowingMessage = false;
    }
  }

  /// FIXED: Safe snackbar showing with error handling
  Future<void> _showSnackBarSafe(_QueuedMessage message) async {
    try {
      final context = navigatorKey?.currentContext;
      if (context == null) {
        AppLogger.warning(
          'Cannot show message: No navigator context available',
        );
        return;
      }

      if (!context.mounted) {
        AppLogger.warning('Cannot show message: Context not mounted');
        return;
      }

      final scaffold = ScaffoldMessenger.of(context);
      scaffold.clearSnackBars();

      scaffold.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(message.icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: message.backgroundColor,
          duration: message.duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      AppLogger.error('Error showing snackbar', e);
    }
  }

  /// NEW: Clear all queued messages
  void clearQueue() {
    _messageQueue.clear();
    _isShowingMessage = false;
  }
}

/// NEW: Message queue data structure
class _QueuedMessage {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;

  _QueuedMessage({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    this.duration = const Duration(seconds: 3),
  });
}
