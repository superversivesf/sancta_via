import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_change_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  final ProviderContainer _container;
  
  AppLifecycleService(this._container);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      AppLogger.debug("App resumed - performing maintenance tasks", 'APP_LIFECYCLE');
      
      // App came back to foreground - check if date changed
      final dateChangeService = _container.read(dateChangeServiceProvider);
      dateChangeService.forceRefresh();
      
      // Clear PIN lockout on app restart for casual security
      final authService = _container.read(authServiceProvider);
      authService.clearLockoutOnRestart().catchError((e) {
        AppLogger.error("Failed to clear lockout on app resume", e, null, 'APP_LIFECYCLE');
      });
    }
  }

  void startListening() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

// Provider for the app lifecycle service
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  final service = AppLifecycleService(ref.container);
  service.startListening();
  
  ref.onDispose(() {
    service.stopListening();
  });
  
  return service;
});