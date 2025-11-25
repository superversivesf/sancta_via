import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/novena_notification_service.dart';

/// Provider for the novena notification service
final novenaNotificationServiceProvider = Provider<NovenaNotificationService>((
  ref,
) {
  return NovenaNotificationService();
});

/// Provider for notification service status
final notificationServiceStatusProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(novenaNotificationServiceProvider);
  return await service.initialize();
});

/// Provider to check if notifications are ready
final notificationsReadyProvider = Provider<bool>((ref) {
  final service = ref.read(novenaNotificationServiceProvider);
  return service.isReady;
});
