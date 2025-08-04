# Reading Plan Bug Fix

## Problem Description

The app had a bug where "today's reading" would show the wrong chapter if a user read ahead in their reading plan. 

**Example of the bug:**
1. Day 1: User's plan says to read Genesis 1
2. User reads Genesis 1, then reads ahead to Genesis 2
3. Day 2: App shows "Today's reading: Genesis 2" (wrong!)
4. The correct behavior: Day 2 should show "Today's reading: Genesis 2" (what was always scheduled for day 2)

## Root Cause

The bug was caused by conflating two different concepts:
- **Today's Scheduled Reading**: What should be read today according to the original plan schedule
- **Current Reading Position**: Where the user has actually read up to

The old code always used the current reading position for "today's reading", which broke when users read ahead.

## Solution

### 1. Separate Tracking
Added new fields to `ReadingProgress`:
- `scheduledBook`, `scheduledChapter`, `scheduledBookIndex`: Track what should be read today
- `currentBook`, `currentChapter`, `bookIndex`: Track where user actually is

### 2. New Classes
- `TodaysReading`: Shows what should be read today (uses scheduled position)
- `ContinueReading`: Shows where user should continue reading (uses current position)

### 3. Smart Daily Reset
When a new day starts (`resetDailyStatus()`):
- Advances `scheduledChapter` by `chaptersPerDay` (moves the schedule forward)
- Keeps `currentChapter` unchanged (preserves where user actually is)
- Resets `hasReadToday` to `false`

## Usage

### For UI Components

**Show today's scheduled reading:**
```dart
final todaysReadings = ref.watch(todaysReadingsProvider);
// This will show what should be read today according to schedule
```

**Show where user should continue reading:**
```dart
final continueReadings = ref.watch(continueReadingPositionProvider);
// This will show where the user actually left off
```

### For Reading Plan Cards

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final todaysReading = TodaysReading.fromPlan(plan);
  
  return Card(
    child: Column(
      children: [
        // Show scheduled reading
        Text('Today\'s Reading: ${todaysReading.displayText}'),
        
        if (todaysReading.hasReadAhead) 
          Text('You\'re ahead! Continue at: ${todaysReading.currentPositionText}'),
          
        if (todaysReading.hasReadToday)
          Text('✓ Completed for today')
        else
          ElevatedButton(
            onPressed: () => navigateToChapter(todaysReading.book, todaysReading.startChapter),
            child: Text('Start Reading'),
          ),
      ],
    ),
  );
}
```

## Migration

The fix includes backward compatibility:
- Existing reading plans will automatically use `currentChapter` for `scheduledChapter` initially
- No data loss or plan corruption
- App will work immediately after the update

## Benefits

1. **Predictable Schedule**: Today's reading always follows the original plan schedule
2. **Read Ahead Freedom**: Users can read as far ahead as they want without breaking future readings
3. **Flexible Catching Up**: Users can see both what they should read today and where they left off
4. **Better User Experience**: Clear distinction between scheduled vs. actual reading progress

## Example Flow

```
Day 1 (Plan Created):
- Scheduled: Genesis 1
- Current: Genesis 1
- Display: "Today's reading: Genesis 1"

Day 1 (After reading Genesis 1-3):
- Scheduled: Genesis 1  
- Current: Genesis 4
- Display: "Today's reading: Genesis 1 ✓ (You're ahead! Continue at Genesis 4)"

Day 2 (After daily reset):
- Scheduled: Genesis 2 (advanced by 1 chapter)
- Current: Genesis 4 (unchanged)
- Display: "Today's reading: Genesis 2 (already read yesterday)"

Day 2 (User choice):
- Can click "Mark Genesis 2 as complete" (hasReadToday = true)
- Or click "Continue reading Genesis 4" (read more ahead)
```

This ensures that users can read ahead as much as they want while maintaining a consistent daily reading schedule.
