# Sancta Via Codebase Analysis - Action Items

**Generated:** 2026-02-20  
**Updated:** 2026-02-21  
**Total Issues:** 25  
**Status:** ✅ COMPLETED

---

## Summary Table

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 CRITICAL | 6 | ✅ Fixed |
| 🟠 HIGH | 9 | ✅ Fixed |
| 🟡 MEDIUM | 6 | ✅ Fixed |
| 🔵 MONOREPO | 4 | ✅ Fixed |
| **TOTAL** | **25** | **✅ ALL COMPLETE** |

---

## Completed Issues

### 🔴 CRITICAL (All Fixed)

| # | Issue | Fix Commit |
|---|-------|------------|
| 1 | BibleVerse.toString() crash | Guard against empty text |
| 2 | _generateBookId crash | Bounds check for short names |
| 3 | OT/NT book split inconsistency | Centralized `isOldTestament` helpers |
| 4 | Boolean logic error in prayer_detail_screen | Changed `\|\|` to `&&` |
| 5 | Duplicate examinationRepositoryProvider | Removed duplicate |
| 6 | Wrong APP_NAME in Makefiles | Fixed 3 Makefiles |

### 🟠 HIGH (All Fixed)

| # | Issue | Fix Commit |
|---|-------|------------|
| 1 | Missing analysis_options.yaml | `00f64c7` |
| 2 | SDK version inconsistency | `06e7ba2` |
| 3 | No tests in shared_ui | `4d3083f` (32 tests) |
| 4 | No tests in liturgical_calendar_riverpod | `d5de4ce` (31 tests) |
| 5 | Dead code files | `d39b8e6` |
| 6 | Debug logging in production | `d1ae15f` |
| 7 | Unused LiturgicalCalendarException | `3ce80a3` |
| 8 | Duplicate providers/classes | `73a6485` |
| 9 | Static cache without synchronization | `3084f98` |

### 🟡 MEDIUM (All Fixed)

| # | Issue | Fix Commit |
|---|-------|------------|
| 1 | Inconsistent rank comparisons | `d3c8fd7` |
| 2 | Hardcoded debug mode flag | Already using `kDebugMode` |
| 3 | Missing persistence for favorites/history | Already implemented |
| 4 | Code duplication (AppLogger) | `6fc98a9` |
| 5 | Remaining print() statements | `c36e92b` |
| 6 | Missing Catholic books | `64be0bd` |

### 🔵 MONOREPO (All Fixed)

| # | Issue | Fix Commit |
|---|-------|------------|
| 1 | Missing update_build_info.sh scripts | `dd39562` |
| 2 | Incorrect Makefile header comments | `73fb4f4` |
| 3 | Hardcoded path in build-release.sh | `992c86f` |
| 4 | Dependency version mismatches | Already aligned |

---

## Notes

- **Catholic Canon:** This project uses the Catholic canon including deuterocanonical books
- **Liturgical Theming:** All apps use dynamic theming based on liturgical calendar
- **Monorepo:** Path dependencies between packages require `flutter pub get` after changes

---

*All issues in this document have been resolved. This file is retained for historical reference.*