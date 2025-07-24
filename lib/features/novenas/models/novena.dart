import 'package:flutter/material.dart';

// Basic Novena models for fresh restart
// You can expand these as needed for your new implementation

class NovenaMetadata {
  final String id;
  final String title;
  final String description;
  final String saint;
  final String feastDay;
  final String intentionCategory;
  final String difficulty;
  final int durationMinutes;

  const NovenaMetadata({
    required this.id,
    required this.title,
    required this.description,
    required this.saint,
    required this.feastDay,
    required this.intentionCategory,
    required this.difficulty,
    required this.durationMinutes,
  });

  factory NovenaMetadata.fromJson(Map<String, dynamic> json) {
    return NovenaMetadata(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      saint: json['saint'] as String,
      feastDay: json['feast_day'] as String,
      intentionCategory: json['intention_category'] as String,
      difficulty: json['difficulty'] as String,
      durationMinutes: json['duration_minutes'] as int,
    );
  }
}

class NovenaDay {
  final int day;
  final String title;
  final String openingPrayer;
  final String dailyPrayer;
  final String closingPrayer;
  final String reflection;
  final String intentionPrayer;
  final String? scripture;

  const NovenaDay({
    required this.day,
    required this.title,
    required this.openingPrayer,
    required this.dailyPrayer,
    required this.closingPrayer,
    required this.reflection,
    required this.intentionPrayer,
    this.scripture,
  });

  factory NovenaDay.fromJson(Map<String, dynamic> json) {
    return NovenaDay(
      day: json['day'] as int,
      title: json['title'] as String,
      openingPrayer: json['opening_prayer'] as String,
      dailyPrayer: json['daily_prayer'] as String,
      closingPrayer: json['closing_prayer'] as String,
      reflection: json['reflection'] as String,
      intentionPrayer: json['intention_prayer'] as String,
      scripture: json['scripture'] as String?,
    );
  }
}

class Novena {
  final String id;
  final String title;
  final String description;
  final String saint;
  final String feastDay;
  final String intention;
  final String instructions;
  final String? backgroundInfo;
  final List<NovenaDay> days;
  final String source;
  final String? notes;

  const Novena({
    required this.id,
    required this.title,
    required this.description,
    required this.saint,
    required this.feastDay,
    required this.intention,
    required this.instructions,
    required this.days,
    required this.source,
    this.backgroundInfo,
    this.notes,
  });

  factory Novena.fromJson(Map<String, dynamic> json) {
    return Novena(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      saint: json['saint'] as String,
      feastDay: json['feast_day'] as String,
      intention: json['intention'] as String,
      instructions: json['instructions'] as String,
      backgroundInfo: json['background_info'] as String?,
      days: (json['days'] as List<dynamic>)
          .map((dayJson) => NovenaDay.fromJson(dayJson as Map<String, dynamic>))
          .toList(),
      source: json['source'] as String,
      notes: json['notes'] as String?,
    );
  }
}

// Active novena state management models
enum ReminderInterval {
  oneHour(1, 'Every hour'),
  threeHours(3, 'Every 3 hours'), 
  sixHours(6, 'Every 6 hours'),
  twelveHours(12, 'Every 12 hours');

  const ReminderInterval(this.hours, this.displayName);
  final int hours;
  final String displayName;
}

class ActiveNovena {
  final String novenaId;
  final DateTime startDate;
  final TimeOfDay reminderTime;
  final ReminderInterval reminderFrequency;
  final String? personalIntention;
  final List<bool> completedDays; // 9 booleans for each day
  final DateTime? lastCompletedDate;

  const ActiveNovena({
    required this.novenaId,
    required this.startDate,
    required this.reminderTime,
    required this.reminderFrequency,
    required this.completedDays,
    this.personalIntention,
    this.lastCompletedDate,
  });

  factory ActiveNovena.fromJson(Map<String, dynamic> json) {
    return ActiveNovena(
      novenaId: json['novena_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      reminderTime: TimeOfDay(
        hour: json['reminder_hour'] as int,
        minute: json['reminder_minute'] as int,
      ),
      reminderFrequency: ReminderInterval.values.firstWhere(
        (interval) => interval.hours == (json['reminder_frequency_hours'] as int),
        orElse: () => ReminderInterval.threeHours,
      ),
      personalIntention: json['personal_intention'] as String?,
      completedDays: (json['completed_days'] as List<dynamic>)
          .map((completed) => completed as bool)
          .toList(),
      lastCompletedDate: json['last_completed_date'] != null
          ? DateTime.parse(json['last_completed_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'novena_id': novenaId,
      'start_date': startDate.toIso8601String(),
      'reminder_hour': reminderTime.hour,
      'reminder_minute': reminderTime.minute,
      'reminder_frequency_hours': reminderFrequency.hours,
      'personal_intention': personalIntention,
      'completed_days': completedDays,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
    };
  }

  // Helper methods
  
  /// The spiritual day the user should be on based on calendar time
  /// This is the primary day calculation - what day they "should" be on
  int get spiritualDay {
    final today = DateTime.now();
    final daysSinceStart = today.difference(startDate).inDays;
    return (daysSinceStart + 1).clamp(1, 9);
  }
  
  /// Check if a specific day can be accessed (up to current spiritual day)
  bool canAccessDay(int dayNumber) {
    return dayNumber >= 1 && dayNumber <= spiritualDay && dayNumber <= 9;
  }
  
  /// Check if a specific day is completed
  bool isDayComplete(int dayNumber) {
    if (dayNumber < 1 || dayNumber > 9) return false;
    return dayNumber <= completedDays.length && completedDays[dayNumber - 1];
  }
  
  /// Check if today's spiritual day is complete
  bool get isTodayComplete {
    return isDayComplete(spiritualDay);
  }
  
  /// Get the next incomplete day that can be accessed
  int get nextIncompleteDay {
    for (int day = 1; day <= spiritualDay && day <= 9; day++) {
      if (!isDayComplete(day)) {
        return day;
      }
    }
    // If all accessible days are complete, return current spiritual day
    return spiritualDay;
  }
  
  /// Get count of completed days that are accessible (up to spiritual day)
  int get accessibleCompletedCount {
    int count = 0;
    for (int day = 1; day <= spiritualDay && day <= 9; day++) {
      if (isDayComplete(day)) {
        count++;
      }
    }
    return count;
  }

  bool get isComplete => completedDays.length >= 9 && completedDays.every((day) => day);

  double get progressPercentage {
    if (completedDays.isEmpty) return 0.0;
    
    // Count only completed days that are accessible (up to spiritual day)
    int accessibleCompletedCount = 0;
    for (int day = 1; day <= spiritualDay && day <= 9; day++) {
      if (isDayComplete(day)) {
        accessibleCompletedCount++;
      }
    }
    
    return accessibleCompletedCount / 9.0;
  }

  ActiveNovena copyWith({
    String? novenaId,
    DateTime? startDate,
    TimeOfDay? reminderTime,
    ReminderInterval? reminderFrequency,
    String? personalIntention,
    List<bool>? completedDays,
    DateTime? lastCompletedDate,
  }) {
    return ActiveNovena(
      novenaId: novenaId ?? this.novenaId,
      startDate: startDate ?? this.startDate,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      personalIntention: personalIntention ?? this.personalIntention,
      completedDays: completedDays ?? this.completedDays,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }
}
