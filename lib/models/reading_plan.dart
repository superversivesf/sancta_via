import 'package:flutter/material.dart';

/// Maximum number of simultaneous reading plans allowed
const int maxSimultaneousPlans = 5;

enum BookCollection {
  wholeBible,
  newTestament,
  oldTestament,
  gospels,
  paulineEpistles,
  pastoralEpistles,
  generalEpistles,
  psalmsProverbs,
  majorProphets,
  minorProphets,
  wisdom,
  history;

  String get displayName {
    switch (this) {
      case BookCollection.wholeBible:
        return 'Whole Bible';
      case BookCollection.newTestament:
        return 'New Testament';
      case BookCollection.oldTestament:
        return 'Old Testament';
      case BookCollection.gospels:
        return 'Gospels';
      case BookCollection.paulineEpistles:
        return 'Pauline Epistles';
      case BookCollection.pastoralEpistles:
        return 'Pastoral Epistles';
      case BookCollection.generalEpistles:
        return 'General Epistles';
      case BookCollection.psalmsProverbs:
        return 'Psalms & Proverbs';
      case BookCollection.majorProphets:
        return 'Major Prophets';
      case BookCollection.minorProphets:
        return 'Minor Prophets';
      case BookCollection.wisdom:
        return 'Wisdom Books';
      case BookCollection.history:
        return 'Historical Books';
    }
  }

  String get description {
    switch (this) {
      case BookCollection.wholeBible:
        return 'Read through the entire Bible from Genesis to Revelation of John';
      case BookCollection.newTestament:
        return 'Focus on the New Testament books (Matthew to Revelation of John)';
      case BookCollection.oldTestament:
        return 'Focus on the Old Testament books (Genesis to Malachi)';
      case BookCollection.gospels:
        return 'Read the four Gospels: Matthew, Mark, Luke, and John';
      case BookCollection.paulineEpistles:
        return 'Paul\'s letters: Romans through Philemon';
      case BookCollection.pastoralEpistles:
        return 'Paul\'s letters to pastors: 1 Timothy, 2 Timothy, and Titus';
      case BookCollection.generalEpistles:
        return 'Non-Pauline letters: Hebrews, James, Peter, John, and Jude';
      case BookCollection.psalmsProverbs:
        return 'Devotional reading through Psalms and Proverbs';
      case BookCollection.majorProphets:
        return 'Isaiah, Jeremiah, Lamentations, Ezekiel, and Daniel';
      case BookCollection.minorProphets:
        return 'The twelve minor prophets: Hosea through Malachi';
      case BookCollection.wisdom:
        return 'Job, Psalms, Proverbs, Ecclesiastes, and Song of Songs';
      case BookCollection.history:
        return 'Historical books from Joshua through Esther';
    }
  }

  List<String> get bookNames {
    switch (this) {
      case BookCollection.wholeBible:
        return [
          // Old Testament
          'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
          'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
          '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
          'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs',
          'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
          // New Testament
          'Matthew', 'Mark', 'Luke', 'John',
          'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
          'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation of John'
        ];
      case BookCollection.newTestament:
        return [
          'Matthew', 'Mark', 'Luke', 'John',
          'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
          'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation of John'
        ];
      case BookCollection.oldTestament:
        return [
          'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
          'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
          '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
          'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs',
          'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'
        ];
      case BookCollection.gospels:
        return ['Matthew', 'Mark', 'Luke', 'John'];
      case BookCollection.paulineEpistles:
        return [
          'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
          'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
          '1 Timothy', '2 Timothy', 'Titus', 'Philemon'
        ];
      case BookCollection.pastoralEpistles:
        return [
          '1 Timothy', '2 Timothy', 'Titus'
        ];
      case BookCollection.generalEpistles:
        return [
          'Hebrews', 'James', '1 Peter', '2 Peter', 
          '1 John', '2 John', '3 John', 'Jude'
        ];
      case BookCollection.psalmsProverbs:
        return ['Psalms', 'Proverbs'];
      case BookCollection.majorProphets:
        return ['Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel'];
      case BookCollection.minorProphets:
        return [
          'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
          'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'
        ];
      case BookCollection.wisdom:
        return ['Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Songs'];
      case BookCollection.history:
        return [
          'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
          '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther'
        ];
    }
  }
}

enum ReadingFrequency {
  daily,
  weekdays,
  weekends,
  weekly;

  String get displayName {
    switch (this) {
      case ReadingFrequency.daily:
        return 'Daily';
      case ReadingFrequency.weekdays:
        return 'Weekdays Only';
      case ReadingFrequency.weekends:
        return 'Weekends Only';
      case ReadingFrequency.weekly:
        return 'Weekly';
    }
  }

  String get description {
    switch (this) {
      case ReadingFrequency.daily:
        return 'Read every day of the week';
      case ReadingFrequency.weekdays:
        return 'Read Monday through Friday only';
      case ReadingFrequency.weekends:
        return 'Read Saturday and Sunday only';
      case ReadingFrequency.weekly:
        return 'Read once per week';
    }
  }

  bool shouldReadToday(DateTime date) {
    switch (this) {
      case ReadingFrequency.daily:
        return true;
      case ReadingFrequency.weekdays:
        return date.weekday >= 1 && date.weekday <= 5; // Monday to Friday
      case ReadingFrequency.weekends:
        return date.weekday == 6 || date.weekday == 7; // Saturday and Sunday
      case ReadingFrequency.weekly:
        return true; // Let user decide when to read weekly
    }
  }
}

/// Days of the week for scheduling reading plans
enum DayOfWeek {
  monday(1),
  tuesday(2),
  wednesday(3),
  thursday(4),
  friday(5),
  saturday(6),
  sunday(7);

  const DayOfWeek(this.value);
  final int value;

  String get displayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }

  String get shortName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Mon';
      case DayOfWeek.tuesday:
        return 'Tue';
      case DayOfWeek.wednesday:
        return 'Wed';
      case DayOfWeek.thursday:
        return 'Thu';
      case DayOfWeek.friday:
        return 'Fri';
      case DayOfWeek.saturday:
        return 'Sat';
      case DayOfWeek.sunday:
        return 'Sun';
    }
  }

  static DayOfWeek fromDateTime(DateTime date) {
    return DayOfWeek.values.firstWhere((day) => day.value == date.weekday);
  }

  static List<DayOfWeek> fromFrequency(ReadingFrequency frequency) {
    switch (frequency) {
      case ReadingFrequency.daily:
        return DayOfWeek.values;
      case ReadingFrequency.weekdays:
        return [DayOfWeek.monday, DayOfWeek.tuesday, DayOfWeek.wednesday, DayOfWeek.thursday, DayOfWeek.friday];
      case ReadingFrequency.weekends:
        return [DayOfWeek.saturday, DayOfWeek.sunday];
      case ReadingFrequency.weekly:
        return [DayOfWeek.sunday]; // Default to Sunday, user can change
    }
  }
}

class ReadingProgress {
  final String currentBook;
  final int currentChapter;
  final int bookIndex;
  final List<String> books;
  final bool isCompleted;
  final DateTime? lastReadDate;

  const ReadingProgress({
    required this.currentBook,
    required this.currentChapter,
    required this.bookIndex,
    required this.books,
    this.isCompleted = false,
    this.lastReadDate,
  });

  factory ReadingProgress.start(BookCollection collection) {
    final books = collection.bookNames;
    return ReadingProgress(
      currentBook: books.first,
      currentChapter: 1,
      bookIndex: 0,
      books: books,
      isCompleted: false,
      lastReadDate: null,
    );
  }

  ReadingProgress copyWith({
    String? currentBook,
    int? currentChapter,
    int? bookIndex,
    List<String>? books,
    bool? isCompleted,
    DateTime? lastReadDate,
  }) {
    return ReadingProgress(
      currentBook: currentBook ?? this.currentBook,
      currentChapter: currentChapter ?? this.currentChapter,
      bookIndex: bookIndex ?? this.bookIndex,
      books: books ?? this.books,
      isCompleted: isCompleted ?? this.isCompleted,
      lastReadDate: lastReadDate ?? this.lastReadDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentBook': currentBook,
      'currentChapter': currentChapter,
      'bookIndex': bookIndex,
      'books': books,
      'isCompleted': isCompleted,
      'lastReadDate': lastReadDate?.toIso8601String(),
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      currentBook: json['currentBook'],
      currentChapter: json['currentChapter'],
      bookIndex: json['bookIndex'],
      books: List<String>.from(json['books']),
      isCompleted: json['isCompleted'] ?? false,
      lastReadDate: json['lastReadDate'] != null ? DateTime.parse(json['lastReadDate']) : null,
    );
  }
}

class ReadingPlan {
  final String id;
  final String name; // User-defined name for the plan
  final BookCollection collection;
  final ReadingFrequency frequency;
  final Set<DayOfWeek> scheduledDays; // Days when this plan is active
  final int chaptersPerDay;
  final bool remindersEnabled;
  final TimeOfDay? reminderTime;
  final ReadingProgress progress;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isActive; // Whether this plan is currently active
  final bool hasReadToday; // Whether this plan has been read today

  const ReadingPlan({
    required this.id,
    required this.name,
    required this.collection,
    required this.frequency,
    required this.scheduledDays,
    required this.chaptersPerDay,
    required this.remindersEnabled,
    required this.progress, 
    required this.createdAt, 
    this.reminderTime,
    this.completedAt,
    this.isActive = true,
    this.hasReadToday = false,
  });

  ReadingPlan copyWith({
    String? id,
    String? name,
    BookCollection? collection,
    ReadingFrequency? frequency,
    Set<DayOfWeek>? scheduledDays,
    int? chaptersPerDay,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
    ReadingProgress? progress,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isActive,
    bool? hasReadToday,
  }) {
    return ReadingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      collection: collection ?? this.collection,
      frequency: frequency ?? this.frequency,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      chaptersPerDay: chaptersPerDay ?? this.chaptersPerDay,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      isActive: isActive ?? this.isActive,
      hasReadToday: hasReadToday ?? this.hasReadToday,
    );
  }

  bool get isCompleted => progress.isCompleted;

  bool shouldReadToday([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final dayOfWeek = DayOfWeek.fromDateTime(targetDate);
    return isActive && 
           !isCompleted && 
           scheduledDays.contains(dayOfWeek) &&
           frequency.shouldReadToday(targetDate);
  }

  double get progressPercentage {
    if (progress.books.isEmpty) return 0.0;
    
    // Calculate total chapters read vs total chapters in collection
    // This is a simplified calculation - in a real app you'd want to know exact chapter counts
    final totalBooks = progress.books.length;
    final completedBooks = progress.bookIndex;
    final currentBookProgress = progress.currentChapter / 30.0; // Assume average 30 chapters per book
    
    return (completedBooks + currentBookProgress) / totalBooks;
  }

  String get scheduledDaysText {
    if (scheduledDays.length == 7) {
      return 'Every day';
    } else if (scheduledDays.length == 5 && 
               scheduledDays.containsAll([DayOfWeek.monday, DayOfWeek.tuesday, DayOfWeek.wednesday, DayOfWeek.thursday, DayOfWeek.friday])) {
      return 'Weekdays';
    } else if (scheduledDays.length == 2 && 
               scheduledDays.containsAll([DayOfWeek.saturday, DayOfWeek.sunday])) {
      return 'Weekends';
    } else {
      return scheduledDays.map((day) => day.shortName).join(', ');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'collection': collection.name,
      'frequency': frequency.name,
      'scheduledDays': scheduledDays.map((day) => day.name).toList(),
      'chaptersPerDay': chaptersPerDay,
      'remindersEnabled': remindersEnabled,
      'reminderTime': reminderTime != null ? {
        'hour': reminderTime!.hour,
        'minute': reminderTime!.minute,
      } : null,
      'progress': progress.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isActive': isActive,
      'hasReadToday': hasReadToday,
    };
  }

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    return ReadingPlan(
      id: json['id'],
      name: json['name'] ?? 'Reading Plan', // Default name for backward compatibility
      collection: BookCollection.values.firstWhere((e) => e.name == json['collection']),
      frequency: ReadingFrequency.values.firstWhere((e) => e.name == json['frequency']),
      scheduledDays: json['scheduledDays'] != null 
        ? Set<DayOfWeek>.from(
            (json['scheduledDays'] as List).map((dayName) => 
              DayOfWeek.values.firstWhere((day) => day.name == dayName)
            )
          )
        : DayOfWeek.fromFrequency(ReadingFrequency.values.firstWhere((e) => e.name == json['frequency'])).toSet(),
      chaptersPerDay: json['chaptersPerDay'],
      remindersEnabled: json['remindersEnabled'],
      reminderTime: json['reminderTime'] != null 
        ? TimeOfDay(
            hour: json['reminderTime']['hour'],
            minute: json['reminderTime']['minute'],
          )
        : null,
      progress: ReadingProgress.fromJson(json['progress']),
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      isActive: json['isActive'] ?? true,
      hasReadToday: json['hasReadToday'] ?? false,
    );
  }
}

/// Manager class for handling multiple reading plans
class ReadingPlanManager {
  final List<ReadingPlan> plans;
  final DateTime lastUpdated;
  final DateTime lastDailyReset; // Track when we last reset daily status

  const ReadingPlanManager({
    required this.plans,
    required this.lastUpdated,
    required this.lastDailyReset,
  });

  factory ReadingPlanManager.empty() {
    final now = DateTime.now();
    return ReadingPlanManager(
      plans: [],
      lastUpdated: now,
      lastDailyReset: _normalizeToMidnight(now),
    );
  }
  
  /// Helper method to normalize DateTime to midnight of the same day
  /// 
  /// **FIX FOR DAY ADVANCEMENT BUG:**
  /// Reading plans should start at midnight of the creation day, not at the exact
  /// creation time. This ensures that daily reset logic works predictably and
  /// plans advance at consistent times (midnight) rather than at the time the
  /// plan was created (e.g., 3 PM).
  /// 
  /// This fixes the issue where plans created during the day wouldn't reset
  /// properly until the following day, causing unpredictable advancement timing.
  static DateTime _normalizeToMidnight(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  List<ReadingPlan> get activePlans => plans.where((plan) => plan.isActive && !plan.isCompleted).toList();
  List<ReadingPlan> get completedPlans => plans.where((plan) => plan.isCompleted).toList();
  List<ReadingPlan> get pausedPlans => plans.where((plan) => !plan.isActive && !plan.isCompleted).toList();

  List<ReadingPlan> getPlansForToday([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    return activePlans.where((plan) => plan.shouldReadToday(targetDate)).toList();
  }

  List<ReadingPlan> getTodaysUnreadPlans([DateTime? date]) {
    return getPlansForToday(date).where((plan) => !plan.hasReadToday).toList();
  }

  List<ReadingPlan> getTodaysReadPlans([DateTime? date]) {
    return getPlansForToday(date).where((plan) => plan.hasReadToday).toList();
  }

  /// Get today's reading plans sorted by status (unread first, then read)
  List<ReadingPlan> getTodaysPlansOrderedByStatus([DateTime? date]) {
    final unreadPlans = getTodaysUnreadPlans(date);
    final readPlans = getTodaysReadPlans(date);
    return [...unreadPlans, ...readPlans];
  }

  bool canAddNewPlan() {
    return activePlans.length < maxSimultaneousPlans;
  }

  ReadingPlanManager addPlan(ReadingPlan plan) {
    if (!canAddNewPlan()) {
      throw Exception('Maximum number of simultaneous plans ($maxSimultaneousPlans) reached');
    }
    
    return copyWith(
      plans: [...plans, plan],
      lastUpdated: DateTime.now(),
    );
  }

  ReadingPlanManager updatePlan(ReadingPlan updatedPlan) {
    final updatedPlans = plans.map((plan) {
      return plan.id == updatedPlan.id ? updatedPlan : plan;
    }).toList();

    return copyWith(
      plans: updatedPlans,
      lastUpdated: DateTime.now(),
    );
  }

  ReadingPlanManager removePlan(String planId) {
    return copyWith(
      plans: plans.where((plan) => plan.id != planId).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  ReadingPlanManager copyWith({
    List<ReadingPlan>? plans,
    DateTime? lastUpdated,
    DateTime? lastDailyReset,
  }) {
    return ReadingPlanManager(
      plans: plans ?? this.plans,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastDailyReset: lastDailyReset ?? this.lastDailyReset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plans': plans.map((plan) => plan.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'lastDailyReset': lastDailyReset.toIso8601String(),
    };
  }

  factory ReadingPlanManager.fromJson(Map<String, dynamic> json) {
    final lastUpdated = DateTime.parse(json['lastUpdated']);
    return ReadingPlanManager(
      plans: (json['plans'] as List)
          .map((planJson) => ReadingPlan.fromJson(planJson))
          .toList(),
      lastUpdated: lastUpdated,
      // For backward compatibility, use lastUpdated if lastDailyReset doesn't exist
      lastDailyReset: json['lastDailyReset'] != null 
          ? DateTime.parse(json['lastDailyReset']) 
          : lastUpdated,
    );
  }

  /// Check if we need to reset daily status (new day detected)
  bool get needsDailyReset {
    final now = DateTime.now();
    final resetDate = DateTime(lastDailyReset.year, lastDailyReset.month, lastDailyReset.day);
    final currentDate = DateTime(now.year, now.month, now.day);
    return currentDate.isAfter(resetDate);
  }
}