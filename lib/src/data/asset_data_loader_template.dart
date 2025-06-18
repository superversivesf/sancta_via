// Auto-generated data loader template for Flutter/Dart
// This shows how to create a data loader for the liturgical_calendar package

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:liturgical_calendar/liturgical_calendar.dart';

/// Flutter asset-based data loader for liturgical calendar
class AssetLiturgicalDataLoader implements LiturgicalDataLoader {
  static const String _assetBase = 'assets/liturgical';
  
  @override
  Future<bool> hasData(String filename) async {
    try {
      await rootBundle.loadString('$_assetBase/$filename');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<String> loadIndexData() async {
    return await rootBundle.loadString('$_assetBase/index.json');
  }
  
  @override
  Future<String> loadYearData(String filename) async {
    return await rootBundle.loadString('$_assetBase/$filename');
  }
}

// Usage example:
// final dataLoader = AssetLiturgicalDataLoader();
// await LiturgicalCalendarService.initialize(dataLoader);

// Available years: 2024, 2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035
// Total data size: ~4383 days
