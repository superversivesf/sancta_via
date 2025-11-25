import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DateChangeService extends ChangeNotifier {
  static final DateChangeService _instance = DateChangeService._internal();
  factory DateChangeService() => _instance;
  DateChangeService._internal();

  DateTime _currentDate = DateTime.now();
  Timer? _timer;

  DateTime get currentDate => _currentDate;

  void startListening() {
    _timer?.cancel();

    // Check every minute for date changes
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      final currentDateOnly = DateTime(now.year, now.month, now.day);
      final previousDateOnly = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day,
      );

      if (!currentDateOnly.isAtSameMomentAs(previousDateOnly)) {
        _currentDate = now;
        notifyListeners();
      }
    });
  }

  void stopListening() {
    _timer?.cancel();
  }

  void forceRefresh() {
    _currentDate = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// Provider for the date change service
final dateChangeServiceProvider = ChangeNotifierProvider<DateChangeService>((
  ref,
) {
  final service = DateChangeService();
  service.startListening();
  return service;
});

// Provider that watches for date changes
final currentDateProvider = Provider<DateTime>((ref) {
  final service = ref.watch(dateChangeServiceProvider);
  return service.currentDate;
});
