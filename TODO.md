# Sancta Via Codebase Analysis - Action Items

**Generated:** 2026-02-20  
**Total Issues:** 32  
**Status:** Action Required

---

## Summary Table

| Severity | Count | Impact |
|----------|-------|--------|
| 🔴 CRITICAL | 6 | Runtime crashes, data corruption |
| 🟠 HIGH | 9 | Maintainability, reliability, performance |
| 🟡 MEDIUM | 6 | Code quality, technical debt |
| 🔵 MONOREPO | 4 | Build consistency, deployment |
| **TOTAL** | **25** | |

---

## 🔴 CRITICAL Issues

> **Fix Immediately** - These cause runtime crashes or data corruption

### 1. BibleVerse.toString() Crash
**File:** `sancta_via_bible_data/lib/src/models/bible_verse.dart:56`  
**Problem:** Empty `text` field crashes with `substring()` call
```dart
// Current (crashes on empty text):
text.substring(0, text.length > 50 ? 50 : text.length)
```
**Fix:**
```dart
text.isEmpty ? '' : text.substring(0, text.length > 50 ? 50 : text.length)
```
**Impact:** App crash when displaying verses with empty text fields

---

### 2. _generateBookId Index Out of Bounds
**File:** `sancta_via_bible_data/lib/src/services/sqlite_bible_loader.dart:283-287`  
**Problem:** Short book names (1-2 chars) cause index out of bounds
```dart
// Current (crashes on short names):
String bookId = bookName.substring(0, 3).toLowerCase();
```
**Fix:**
```dart
String bookId = bookName.length >= 3 
    ? bookName.substring(0, 3).toLowerCase() 
    : bookName.toLowerCase();
```
**Impact:** Crash when loading certain Bible book formats

---

### 3. OT/NT Book Split Inconsistency
**File:** `sancta_via_bible_data/lib/src/utils/book_utils.dart` (estimated)  
**Problem:** Using `< 46` vs `<= 46` produces wrong Old/New Testament categorization
- Book 46 could be incorrectly categorized
- Inconsistency across codebase

**Fix:**
- Standardize: OT = books 1-46, NT = books 47-73 (Catholic canon)
- Create single source of truth: `isOldTestament(bookId)` function
- Replace all inline comparisons

**Impact:** Wrong testament categorization breaks navigation, filtering

---

### 4. Boolean Logic Error in Prayer Detail Screen
**File:** `sancta_via_prayer_companion/lib/screens/prayer/prayer_detail_screen.dart:200-201`  
**Problem:** Wrong logical operator - `||` should be `&&`
```dart
// Current (possibly wrong):
if (condition1 || condition2) // Should be &&?
```
**Fix:** Review logic intent and correct operator
**Impact:** Incorrect conditional behavior, potential UI/data bugs

---

### 5. Duplicate examinationRepositoryProvider
**File:** 
- `sancta_via_confession_companion/lib/providers/examination_provider.dart`
- `sancta_via_confession_companion/lib/repositories/examination_repository.dart`

**Problem:** Same provider defined in two locations causes conflicts
**Fix:**
- Keep single definition in repository file
- Remove from provider file
- Update imports across codebase

**Impact:** Provider resolution conflicts, unpredictable state

---

### 6. Wrong APP_NAME in Makefiles
**Files:**
- `sancta_via_prayer_companion/Makefile`
- `sancta_via_confession_companion/Makefile`
- `sancta_via_bible_data_explorer/Makefile`

**Problem:** All have `APP_NAME := bible_reading_app` (copy-paste error)
**Fix:** Update to correct app names:
```makefile
# prayer_companion
APP_NAME := prayer_companion

# confession_companion
APP_NAME := confession_companion

# bible_data_explorer
APP_NAME := bible_data_explorer
```
**Impact:** Wrong app names in build artifacts, version info

---

## 🟠 HIGH Priority

> **Fix Soon** - Affects maintainability, reliability, or performance

### 1. Missing analysis_options.yaml
**Packages:**
- `sancta_via_shared_ui`
- `sancta_via_liturgical_calendar_riverpod`
- `sancta_via_bible_data_riverpod`
- Any other packages without lint config

**Fix:** Add `analysis_options.yaml` with project standards:
```yaml
include: package:lints/recommended.yaml
analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
linter:
  rules:
    - prefer_const_constructors
    - prefer_final_locals
    - sort_pub_dependencies
```
**Impact:** No lint enforcement, inconsistent code style

---

### 2. SDK Version Inconsistency
**Problem:** Different SDK constraints across packages
**Action:**
1. Audit all `pubspec.yaml` files
2. Standardize to minimum supported SDK
3. Document SDK policy in README

**Impact:** Dependency resolution issues, CI failures

---

### 3. No Tests in sancta_via_shared_ui
**File:** `sancta_via_shared_ui/test/` (empty or missing)  
**Problem:** Critical UI package has zero test coverage
**Action:**
1. Add widget tests for all components
2. Test liturgical theming logic
3. Test responsive layouts

**Impact:** Regressions in shared components affect all apps

---

### 4. No Tests in liturgical_calendar_riverpod
**File:** `sancta_via_liturgical_calendar_riverpod/test/` (empty or missing)  
**Problem:** Provider package lacks tests
**Action:**
1. Add provider unit tests
2. Mock liturgical calendar data
3. Test state transitions

**Impact:** Provider bugs could break dependent apps

---

### 5. Dead Code Files
**Files to Remove:**
- Any `*_old.dart` files
- Any `*_REMOVED.dart` files
- Unused backup files

**Action:**
```bash
# Find all dead code files
find . -name "*_old.dart" -o -name "*_REMOVED.dart"
# Remove after verification
```
**Impact:** Code bloat, confusion, maintenance burden

---

### 6. Debug Logging in Production
**Problem:** Excessive `print()` statements in production code paths  
**Files:** Multiple files in bible_reading_app (26+ occurrences)
**Action:**
1. Replace `print()` with `AppLogger.debug()`
2. Ensure logger respects debug flag
3. Remove sensitive data logging

**Impact:** Performance overhead, potential data leakage

---

### 7. Unused LiturgicalCalendarException
**File:** `sancta_via_liturgical_calendar/lib/src/exceptions/liturgical_calendar_exception.dart`  
**Problem:** Exception class defined but never thrown
**Action:**
1. Either use it in error handling
2. Or remove if truly unused

**Impact:** Dead code, misleading codebase

---

### 8. Duplicate Providers and Classes
**Files:**
- `fontSizeProvider` - defined twice (needs audit)
- `ReadingPlanException` - defined twice (needs audit)

**Action:**
1. Find all duplicate definitions
2. Consolidate to single location
3. Update all imports

**Impact:** Confusion, potential bugs from wrong import

---

### 9. Static Cache Without Synchronization
**File:** `sancta_via_bible_data/lib/src/services/sqlite_bible_loader.dart`  
**Problem:** Static caches without synchronization can cause race conditions
```dart
static List<BibleBook>? _cachedBooks;
static Map<String, BibleVerse>? _cachedVerses;
```
**Fix:**
```dart
// Use async initialization with Completer
static Completer<void>? _initCompleter;

Future<void> _ensureInitialized() async {
  if (_initCompleter == null) {
    _initCompleter = Completer();
    await _doInitialization();
    _initCompleter!.complete();
  }
  return _initCompleter!.future;
}
```
**Impact:** Potential race conditions, data corruption in concurrent access

---

## 🟡 MEDIUM Priority

> **Fix Eventually** - Technical debt and code quality issues

### 1. Inconsistent Rank String Comparisons
**Problem:** Mixing string comparisons with `CelebrationRank` enum
**Action:**
1. Standardize on enum comparisons
2. Add `fromString()` factory to enum
3. Replace all string-based comparisons

---

### 2. Hardcoded Debug Mode Flag
**Problem:** `_isDebugMode = true` hardcoded
**Action:**
1. Use `kDebugMode` constant from Flutter
2. Or load from environment/config
```dart
// Instead of:
const bool _isDebugMode = true;

// Use:
import 'package:flutter/foundation.dart';
if (kDebugMode) { ... }
```

---

### 3. Missing Persistence for Favorites/History
**File:** `sancta_via_bible_data/lib/src/services/`  
**Problem:** Favorites and history not persisted
**Action:**
1. Add SharedPreferences persistence
2. Use repository pattern
3. Sync on app lifecycle changes

---

### 4. Code Duplication Across Apps
**Problems:**
- Duplicate helper functions
- Duplicate color definitions
- Duplicate utility methods

**Action:**
1. Extract to shared packages
2. Create `sancta_via_core` utilities package
3. Document shared patterns

---

### 5. Excessive Print Statements
**File:** `sancta_via_bible_reading_app/` (26+ occurrences)  
**Action:**
```bash
# Find all print statements:
rg "print\(" --type dart sancta_via_bible_reading_app/
```
Replace with structured logging via `AppLogger`

---

### 6. Missing Catholic Books in Chapter Count Map
**File:** `sancta_via_bible_data/lib/src/utils/book_utils.dart` (estimated)  
**Problem:** Chapter count map missing deuterocanonical books
**Action:**
1. Add Tobit, Judith, Wisdom, Sirach, Baruch, 1-2 Maccabees
2. Verify chapter counts match Catholic canon
3. Add tests for all book IDs

---

## 🔵 MONOREPO-WIDE Issues

> **Build & Deployment** - Consistency across all packages

### 1. Missing update_build_info.sh Script
**Apps Missing Script:**
- `sancta_via_prayer_companion/scripts/`
- `sancta_via_confession_companion/scripts/`
- `sancta_via_bible_data_explorer/scripts/`
- `sancta_via_shared_ui/scripts/` (if needed)

**Action:**
1. Find template in bible_reading_app
2. Copy to other apps
3. Customize for each app

---

### 2. Incorrect Makefile Header Comments
**Problem:** Copy-paste errors in header comments
**Files:** Multiple Makefiles with wrong app names in comments
**Action:** Audit and correct all Makefile headers

---

### 3. Hardcoded Path in build-release.sh
**File:** `build-release.sh`  
**Problem:** Hardcoded absolute path
**Action:**
1. Use relative paths
2. Use `$(dirname "$0")` for script location
3. Make portable across machines

---

### 4. Dependency Version Mismatches
**Problem:** Different versions of same package across apps
**Action:**
1. Create dependency matrix
2. Align versions across all apps
3. Consider using workspace/melos for management

---

## Component Breakdown

### sancta_via_bible_data
| Issue | Severity | File |
|-------|----------|------|
| toString() crash | 🔴 CRITICAL | `models/bible_verse.dart:56` |
| _generateBookId crash | 🔴 CRITICAL | `services/sqlite_bible_loader.dart:283-287` |
| OT/NT split inconsistency | 🔴 CRITICAL | `utils/book_utils.dart` |
| Static cache race condition | 🟠 HIGH | `services/sqlite_bible_loader.dart` |
| Missing Catholic books | 🟡 MEDIUM | `utils/book_utils.dart` |

### sancta_via_bible_data_riverpod
| Issue | Severity | File |
|-------|----------|------|
| No lint config | 🟠 HIGH | `analysis_options.yaml` |
| No tests | 🟠 HIGH | `test/` |

### sancta_via_shared_ui
| Issue | Severity | File |
|-------|----------|------|
| No lint config | 🟠 HIGH | `analysis_options.yaml` |
| No tests | 🟠 HIGH | `test/` |

### sancta_via_liturgical_calendar
| Issue | Severity | File |
|-------|----------|------|
| Unused exception | 🟠 HIGH | `exceptions/liturgical_calendar_exception.dart` |

### sancta_via_liturgical_calendar_riverpod
| Issue | Severity | File |
|-------|----------|------|
| No lint config | 🟠 HIGH | `analysis_options.yaml` |
| No tests | 🟠 HIGH | `test/` |

### sancta_via_prayer_companion
| Issue | Severity | File |
|-------|----------|------|
| Wrong APP_NAME | 🔴 CRITICAL | `Makefile` |
| Boolean logic error | 🔴 CRITICAL | `screens/prayer/prayer_detail_screen.dart:200-201` |
| Missing script | 🔵 MONOREPO | `scripts/update_build_info.sh` |

### sancta_via_confession_companion
| Issue | Severity | File |
|-------|----------|------|
| Wrong APP_NAME | 🔴 CRITICAL | `Makefile` |
| Duplicate provider | 🔴 CRITICAL | `providers/`, `repositories/` |
| Missing script | 🔵 MONOREPO | `scripts/update_build_info.sh` |

### sancta_via_bible_reading_app
| Issue | Severity | File |
|-------|----------|------|
| Excessive print() | 🟡 MEDIUM | Multiple files (26+) |

### sancta_via_bible_data_explorer
| Issue | Severity | File |
|-------|----------|------|
| Wrong APP_NAME | 🔴 CRITICAL | `Makefile` |
| Missing script | 🔵 MONOREPO | `scripts/update_build_info.sh` |

---

## Recommended Fix Order

### Phase 1: Critical Fixes (Week 1)
1. Fix BibleVerse.toString() crash
2. Fix _generateBookId index bounds
3. Standardize OT/NT split
4. Fix boolean logic error
5. Remove duplicate examinationRepositoryProvider
6. Correct APP_NAME in all Makefiles

### Phase 2: High Priority (Week 2)
1. Add analysis_options.yaml to all packages
2. Standardize SDK versions
3. Add tests to shared_ui
4. Add tests to liturgical_calendar_riverpod
5. Remove dead code files
6. Replace print() with AppLogger
7. Fix static cache synchronization

### Phase 3: Medium Priority (Week 3-4)
1. Standardize rank comparisons
2. Remove hardcoded debug flags
3. Add favorites/history persistence
4. Extract shared code to common package
5. Add missing Catholic books

### Phase 4: Monorepo Cleanup (Ongoing)
1. Add missing scripts
2. Fix Makefile comments
3. Make build-release.sh portable
4. Align dependency versions

---

## Verification Checklist

After fixing each issue:
- [ ] Run `flutter analyze` - no warnings
- [ ] Run `flutter test` - all tests pass
- [ ] Run `dart format .` - code formatted
- [ ] Manual test of affected feature
- [ ] Update documentation if needed

---

## Notes

- **Catholic Canon:** This project uses the Catholic canon including deuterocanonical books
- **Liturgical Theming:** All apps use dynamic theming based on liturgical calendar
- **Monorepo:** Path dependencies between packages require `flutter pub get` after changes

---

*This TODO.md should be updated as issues are resolved. Remove fixed items and update counts.*