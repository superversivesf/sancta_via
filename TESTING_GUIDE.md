# Testing Guide for New Bible Reading App Features

## Quick Test Steps

### 1. Test the New Home Screen
- ✅ Run the app and verify the new home screen loads
- ✅ Check that the liturgical season card still appears (if applicable)
- ✅ Verify all 4 navigation cards are visible:
  - Bible Lookup
  - Reading Plans
  - Continue Reading
  - Search Bible

### 2. Test Bible Lookup
- ✅ Tap "Bible Lookup" from home screen
- ✅ Select a book from the dropdown
- ✅ Change the chapter number
- ✅ Verify the +/- buttons work
- ✅ Tap "Read Chapter" and confirm it navigates to the chapter screen
- ✅ Test the translation selector

### 3. Test Reading Plans
- ✅ Tap "Reading Plans" from home screen
- ✅ Try different book collections (Whole Bible, New Testament, etc.)
- ✅ Test different reading frequencies (Daily, Weekdays, etc.)
- ✅ Adjust chapters per day with +/- buttons
- ✅ Toggle reminders on/off
- ✅ Set a reminder time (if reminders enabled)
- ✅ Tap "Create Plan" and verify success message
- ✅ Go back and verify the current plan shows

### 4. Test Continue Reading
- ✅ **Without a plan**: Should show "No Reading Plan Set" with create button
- ✅ **With a plan**: Should show today's reading or schedule status
- ✅ Test "Mark Today's Reading Complete" if available
- ✅ Test "Read Anyway" if not scheduled for today
- ✅ Verify progress bar displays correctly
- ✅ Test Quick Actions (modify plan, reset progress)

### 5. Test Bible Search
- ✅ Tap "Search Bible" from home screen
- ✅ Try searching for common terms like "love" or "peace"
- ✅ Verify mock results appear (5 sample verses)
- ✅ Tap on a search result to navigate to that chapter
- ✅ Test the popular search term chips
- ✅ Try searching for a term that won't match anything

### 6. Test Navigation
- ✅ Verify back buttons work from all screens
- ✅ Test settings access from each screen
- ✅ Confirm the original chapter reading screen still works
- ✅ Test swiping between chapters in the reading screen

## Common Issues to Check

### If the app doesn't compile:
1. Run `flutter pub get` to ensure dependencies are updated
2. Check that all imports are correct
3. Verify Flutter version compatibility

### If reading plans don't save:
- Check SharedPreferences permissions
- Verify JSON serialization works correctly

### If liturgical theming doesn't work:
- Ensure the liturgical calendar provider is working
- Check that theme colors propagate correctly

### If navigation feels broken:
- Test the back button behavior
- Verify route names match the implementations

## Expected Behavior

### Reading Plan Flow:
1. Create plan → Shows in Continue Reading
2. Mark complete → Progress advances
3. Reading frequency affects "should read today" logic

### Data Persistence:
- Reading plans should persist between app restarts
- Bible translation settings should be remembered
- Progress should be maintained

### Visual Polish:
- Liturgical colors should theme the interface
- Text scaling should work throughout
- Cards should have consistent styling

## Quick Commands

```bash
# Clean and rebuild if needed
flutter clean
flutter pub get
flutter run

# Test on specific platform
flutter run -d ios
flutter run -d android
```

## Notes
- The Bible search currently uses mock data for demonstration
- Reading plan chapter counts use simplified averages
- All liturgical theming from the original app is preserved
- Settings screen functionality remains unchanged
