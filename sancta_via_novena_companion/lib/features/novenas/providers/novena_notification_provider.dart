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

/// Provider to check if notifications are ready.
///
/// Watches `notificationServiceStatusProvider` so the service's `initialize()`
/// (and therefore the system permission prompt) runs when the Configure Novena
/// screen renders — the point of value, not app startup. Once initialization
/// completes, `isReady` reflects the actual state.
final notificationsReadyProvider = FutureProvider<bool>((ref) async {
  await ref.watch(notificationServiceStatusProvider.future);
  return ref.read(novenaNotificationServiceProvider).isReady;
});
