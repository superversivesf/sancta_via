/// Abstract interface for loading liturgical data
/// This allows different implementations for different platforms (Flutter, web, etc.)
abstract class LiturgicalDataLoader {
  /// Load the index JSON data
  Future<String> loadIndexData();
  
  /// Load the year data JSON for a specific filename
  Future<String> loadYearData(String filename);
  
  /// Optional: Check if data exists before loading
  Future<bool> hasData(String filename) async => true;
}