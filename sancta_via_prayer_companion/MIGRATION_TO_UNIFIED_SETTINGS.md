# Prayer Metadata Consolidation Migration

This document describes the migration from using a separate `prayers_metadata.json` file to consolidating all prayer data into individual JSON files.

## What Changed

### Before (Old Structure)
- **Prayer files**: Contained only basic prayer content (id, title, text, translation, attribution, notes)
- **Metadata file**: `prayers_metadata.json` contained categorization, tags, liturgical information
- **Repository**: Loaded metadata file first, then individual prayer files

### After (New Structure)
- **Prayer files**: Now contain ALL prayer data including metadata
- **No metadata file**: All information is consolidated into individual files
- **Repository**: Loads prayers directly from individual files

## Files Modified

### 1. Prayer Model (`lib/models/prayer.dart`)
- ✅ **UPDATED**: Added metadata fields (categories, description, tags, isLiturgical, liturgicalPriority, liturgicalSeason)
- ✅ **UPDATED**: Updated fromJson/toJson methods to handle new fields

### 2. Prayer Repository (`lib/repositories/prayer_repository.dart`)
- ✅ **UPDATED**: Removed dependency on `prayers_metadata.json`
- ✅ **UPDATED**: Added hardcoded category groups and categories (relatively static data)
- ✅ **UPDATED**: Added list of prayer file names to load
- ✅ **UPDATED**: Modified all methods to work with unified Prayer objects
- ✅ **UPDATED**: Added caching for better performance

### 3. Prayer Files
- ✅ **UPDATED**: `sign_of_the_cross.json` - Added metadata
- ✅ **UPDATED**: `our_father.json` - Added metadata  
- ✅ **UPDATED**: `hail_mary.json` - Added metadata
- ✅ **UPDATED**: `glory_be.json` - Added metadata
- ✅ **UPDATED**: `apostles_creed.json` - Added metadata
- ✅ **UPDATED**: `act_of_contrition.json` - Added metadata
- ⏳ **REMAINING**: ~50+ other prayer files need to be updated

### 4. Migration Scripts
- ✅ **CREATED**: `scripts/migrate_prayers.dart` - Dart migration script
- ✅ **CREATED**: `scripts/migrate_prayers.sh` - Shell script with jq
- ✅ **UPDATED**: `Makefile` - Added `migrate-prayers` target

## Migration Steps

### Step 1: Run Migration Script

Choose one of these options:

**Option A: Using Make (Recommended)**
```bash
make migrate-prayers
```

**Option B: Using Shell Script Directly**
```bash
chmod +x scripts/migrate_prayers.sh
./scripts/migrate_prayers.sh
```

**Option C: Using Dart Script**
```bash
cd scripts
dart migrate_prayers.dart
```

### Step 2: Verify Migration
1. Check that all prayer files now contain the metadata fields
2. Run the app to ensure it still works correctly
3. Test prayer loading, categorization, and search functionality

### Step 3: Clean Up
Once verified, you can safely delete:
- `assets/prayers/prayers_metadata.json`
- `lib/models/prayer_metadata.dart` (if no longer needed elsewhere)

### Step 4: Update Any Remaining Code
Search for any remaining references to:
- `PrayerMetadata` class
- `prayers_metadata.json`
- `getPrayerMetadata()` method calls

## New Prayer File Structure

Each prayer file now has this structure:

```json
{
  "id": "prayer_id",
  "title": "Prayer Title",
  "text": "Prayer text content...",
  "translation": {
    "latin": "Latin translation..."
  },
  "attribution": "Source or author",
  "notes": "Additional notes...",
  
  // NEW METADATA FIELDS
  "categories": ["category1", "category2"],
  "description": "Brief description of the prayer",
  "tags": ["tag1", "tag2", "tag3"],
  "isLiturgical": true,
  "liturgicalPriority": 8,
  "liturgicalSeason": null
}
```

## Benefits of This Change

1. **Simplified Architecture**: No need to manage separate metadata file
2. **Easier Maintenance**: All prayer information is in one place
3. **Better Performance**: No need to load separate metadata file
4. **Reduced Complexity**: Fewer files to manage and sync
5. **Self-Contained**: Each prayer file contains all its data

## Potential Issues

1. **Code Dependencies**: Any code directly referencing `PrayerMetadata` will need updates
2. **File Size**: Prayer files are slightly larger (but negligible impact)
3. **Migration Required**: Existing installations need migration

## Testing Checklist

After migration, test these features:
- [ ] Prayer loading and display
- [ ] Category browsing
- [ ] Search functionality  
- [ ] Prayer of the day
- [ ] Favorites and recent prayers
- [ ] Liturgical season filtering

## Rollback Plan

If issues arise, you can rollback by:
1. Restoring the original `prayers_metadata.json`
2. Reverting the Prayer model changes
3. Reverting the repository changes
4. Removing metadata fields from individual prayer files

However, this migration is designed to be safe and backwards-compatible where possible.
