import '../models/rosary_mystery.dart';
import '../models/rosary_bead.dart';

abstract class RosaryRepository {
  Future<List<RosaryMystery>> getAllMysteries();
  
  Future<List<RosaryMystery>> getMysteriesByType(String type);
  
  Future<RosaryMystery?> getMysteryById(String id);
  
  Future<List<RosaryBead>> getBeads();
  
  Future<List<RosaryBead>> getBeadsByType(String type);
  
  Future<void> createMystery(RosaryMystery mystery);
  
  Future<void> createBead(RosaryBead bead);
  
  Future<void> updateMystery(RosaryMystery mystery);
  
  Future<void> updateBead(RosaryBead bead);
  
  Future<void> deleteMystery(String id);
  
  Future<void> deleteBead(String id);
  
  Future<void> clearAllData();
  
  Future<bool> isDataSeeded();
  
  Future<void> seedInitialData();
}