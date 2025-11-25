import 'package:uuid/uuid.dart';
import 'examination_response_status.dart';
import 'examination_model.dart';

// Model to track user's current examination session
class ExaminationSession {
  final String id;
  final String examinationId;
  final DateTime createdAt;

  final Map<String, ExaminationResponseStatus>
  itemResponses; // Track status of each item
  final Map<String, String> notes; // User notes for specific items

  // Current position tracking
  String? currentCategoryId;
  String? currentItemId;

  bool isCompleted;

  ExaminationSession({
    required this.examinationId,
    String? id,
    Map<String, ExaminationResponseStatus>? itemResponses,
    Map<String, String>? notes,
    DateTime? createdAt,
    this.currentCategoryId,
    this.currentItemId,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4(),
       itemResponses = itemResponses ?? {},
       notes = notes ?? {},
       createdAt = createdAt ?? DateTime.now();

  // Calculate progress as percentage
  double getProgress(ExaminationModel examination) {
    final int totalItems = examination.totalItems;
    final int reviewedItems = itemResponses.values
        .where(
          (status) =>
              status == ExaminationResponseStatus.needConfess ||
              status == ExaminationResponseStatus.noIssue,
        )
        .length;
    return totalItems > 0 ? reviewedItems / totalItems : 0.0;
  }

  int getCategoryReviewedCount(ExaminationCategory category) {
    int count = 0;
    for (final item in category.items) {
      if (itemResponses[item.id] == ExaminationResponseStatus.needConfess ||
          itemResponses[item.id] == ExaminationResponseStatus.noIssue) {
        count++;
      }
    }
    return count;
  }

  List<String> getItemsToConfessIds() {
    return itemResponses.entries
        .where((entry) => entry.value == ExaminationResponseStatus.needConfess)
        .map((entry) => entry.key)
        .toList();
  }

  void setResponseStatus(String itemId, ExaminationResponseStatus status) {
    itemResponses[itemId] = status;
  }

  void setNote(String itemId, String note) {
    if (note.isNotEmpty) {
      notes[itemId] = note;
    } else {
      notes.remove(itemId);
    }
  }

  void updatePosition(String categoryId, String itemId) {
    currentCategoryId = categoryId;
    currentItemId = itemId;
  }

  // Get all marked items
  List<String> getMarkedItemIds() {
    return itemResponses.entries
        .where((entry) => entry.value == ExaminationResponseStatus.needConfess)
        .map((entry) => entry.key)
        .toList();
  }

  // Factory method to create from JSON
  factory ExaminationSession.fromJson(Map<String, dynamic> json) {
    // Convert the old responses format if present
    final Map<String, ExaminationResponseStatus> convertedResponses = {};

    if (json.containsKey('responses')) {
      // Use Map.from for safer conversion
      final Map<String, dynamic> oldResponses = Map<String, dynamic>.from(
        json['responses'] as Map,
      );
      oldResponses.forEach((key, value) {
        convertedResponses[key] = (value as bool)
            ? ExaminationResponseStatus.needConfess
            : ExaminationResponseStatus.noIssue;
      });
    } else if (json.containsKey('itemResponses')) {
      // Use Map.from for safer conversion
      final Map<String, dynamic> savedResponses = Map<String, dynamic>.from(
        json['itemResponses'] as Map,
      );
      savedResponses.forEach((key, value) {
        convertedResponses[key] =
            ExaminationResponseStatus.values[value as int];
      });
    }

    return ExaminationSession(
      id: json['id'] as String,
      examinationId: json['examinationId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      itemResponses: convertedResponses,
      notes: Map<String, String>.from(json['notes'] as Map),
      currentCategoryId: json['currentCategoryId'] as String?,
      currentItemId: json['currentItemId'] as String?,
      isCompleted: json['isCompleted'] as bool,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    // Convert enum values to integers for storage
    final Map<String, int> serializedResponses = {};
    itemResponses.forEach((key, value) {
      serializedResponses[key] = value.index;
    });

    return {
      'id': id,
      'examinationId': examinationId,
      'createdAt': createdAt.toIso8601String(),
      'itemResponses': serializedResponses,
      'notes': notes,
      'currentCategoryId': currentCategoryId,
      'currentItemId': currentItemId,
      'isCompleted': isCompleted,
    };
  }

  // Create a copy with updated fields
  ExaminationSession copyWith({
    String? id,
    String? examinationId,
    DateTime? createdAt,
    Map<String, ExaminationResponseStatus>? itemResponses,
    Map<String, String>? notes,
    String? currentCategoryId,
    String? currentItemId,
    bool? isCompleted,
  }) {
    return ExaminationSession(
      id: id ?? this.id,
      examinationId: examinationId ?? this.examinationId,
      createdAt: createdAt ?? this.createdAt,
      itemResponses: itemResponses ?? Map.from(this.itemResponses),
      notes: notes ?? Map.from(this.notes),
      currentCategoryId: currentCategoryId ?? this.currentCategoryId,
      currentItemId: currentItemId ?? this.currentItemId,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
