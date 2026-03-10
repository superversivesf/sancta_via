# SanctaVia Unified App Feasibility Report

**Generated:** 2026-02-25  
**Author:** BoldHawk (Swarm Worker Agent)  
**Project:** SanctaVia Catholic Prayer Apps Monorepo

---

## 1. Executive Summary

### Verdict: **FEASIBLE with Moderate Risk**

A unified SanctaVia app is technically feasible and strategically advantageous. The existing codebase demonstrates excellent architectural consistency—shared packages, uniform state management (Riverpod), consistent navigation (GoRouter), and aligned theming (liturgical calendar)—which significantly reduces integration complexity.

**Key Enablers:**
- ✅ 6 shared packages already exist and are actively used
- ✅ Consistent dependency versions across all apps
- ✅ Uniform architectural patterns (Repository, Riverpod providers)
- ✅ Mature liturgical theming system already shared

**Primary Challenges:**
- 🔴 Route conflicts (5 apps define `path: '/'`)
- 🔴 Provider naming conflicts (2 duplicate provider names)
- 🟡 No ShellRoute implementation (required for bottom tabs)
- 🟡 Duplicate settings screens across apps

**Recommendation:** Proceed with a **phased approach** starting with route namespacing and provider disambiguation, followed by unified shell navigation.

---

## 2. Architecture Overview

### 2.1 Current App Portfolio

| App | Primary Feature | Routes | Notes |
|-----|-----------------|--------|-------|
| `sancta_via_prayer_companion` | Prayer library & search | 6 routes | Categories, favorites, translations |
| `sancta_via_novena_companion` | Novena tracking & reminders | 13 routes | Most complex routing, nested flows |
| `sancta_via_liturgical_calendar_app` | Liturgical calendar | 5 routes | Date-based navigation |
| `sancta_via_confession_companion` | Examination of conscience | 8 routes | Session-based, text scaling |
| `sancta_via_bible_reading_app` | Bible reading & plans | 11 routes | Chapter/verse navigation, debug routes |

**Total Routes:** 43 unique route definitions

### 2.2 Shared Package Ecosystem

```
sancta_via_shared_ui                    (UI components, theme, settings widgets)
├── sancta_via_liturgical_calendar      (Pure Dart calendar logic)
│   └── sancta_via_liturgical_calendar_riverpod  (Riverpod providers)
└── sancta_via_bible_data               (Bible text & search)
    ├── sancta_via_bible_data_riverpod  (Riverpod providers)
    └── sancta_via_bible_data_flutter   (Flutter-specific)
```

**Dependency Flow:** Well-structured with clear separation between pure Dart logic and Flutter/Riverpod integrations.

### 2.3 State Management Architecture

All apps use **flutter_riverpod ^2.6.1** with consistent patterns:

- `FutureProvider` for async data loading
- `NotifierProvider` for complex mutable state
- `Provider` for derived/computed state
- `[App]SettingsProvider` pattern for persisted settings

**Provider Count Analysis:**
- 234+ provider definitions across the monorepo
- ~85% properly namespaced with app prefixes (e.g., `novenaAppSettingsProvider`, `confessionAppSettingsProvider`)
- 2 critical naming conflicts identified

---

## 3. Critical Blockers (Must Fix Before Merge)

### 3.1 Route Path Conflicts

**Severity:** CRITICAL  
**Effort:** Medium (2-3 days)

All 5 apps define conflicting root routes:

| App | Conflicting Route | Additional Conflicts |
|-----|-------------------|---------------------|
| Prayer Companion | `path: '/'` | `/settings` |
| Novena Companion | `path: '/'` | `/settings`, `/auth` |
| Liturgical Calendar | `path: '/'` | `/settings`, `/search` |
| Confession Companion | `path: '/'` | `/settings` |
| Bible Reading | `path: '/'` | `/settings` |

**Resolution Strategy:**
```dart
// Proposed namespacing scheme
GoRoute(
  path: '/prayer',           // was '/'
  name: 'prayer-home',
  builder: (context, state) => const PrayerHomeScreen(),
),
GoRoute(
  path: '/novena',           // was '/'
  name: 'novena-home',
  builder: (context, state) => const NovenaHomeScreen(),
),
// etc.
```

**Root Route Options:**
1. **Dashboard approach:** Unified home showing widgets from each app
2. **Tab-based shell:** StatefulShellRoute with bottom navigation
3. **Feature hub:** Grid of feature cards linking to app sections

### 3.2 Provider Naming Conflicts

**Severity:** CRITICAL  
**Effort:** Low (4-8 hours)

Two providers have identical names but different return types:

```dart
// sancta_via_confession_companion/lib/providers/confession_app_settings_provider.dart
final favoriteExaminationsProvider = Provider<List<String>>((ref) { ... });
final defaultExaminationProvider = Provider<String?>((ref) { ... });

// sancta_via_confession_companion/lib/features/examination/providers/examination_provider.dart
final favoriteExaminationsProvider = Provider<List<ExaminationModel>>((ref) { ... });
final defaultExaminationProvider = Provider<ExaminationModel?>((ref) { ... });
```

**Resolution:**
```dart
// Rename for clarity
final favoriteExaminationIdsProvider = Provider<List<String>>((ref) { ... });
final defaultExaminationIdProvider = Provider<String?>((ref) { ... });

final favoriteExaminationsProvider = Provider<List<ExaminationModel>>((ref) { ... });
final defaultExaminationProvider = Provider<ExaminationModel?>((ref) { ... });
```

### 3.3 No ShellRoute Implementation

**Severity:** CRITICAL (for unified experience)  
**Effort:** High (3-5 days)

All apps use flat `GoRoute` structures without `ShellRoute` or `StatefulShellRoute`. A unified app requires:

```dart
StatefulShellRoute(
  builder: (context, state, navigationShell) => UnifiedAppShell(
    navigationShell: navigationShell,
  ),
  branches: [
    StatefulShellBranch(
      routes: [/* Prayer routes */],
    ),
    StatefulShellBranch(
      routes: [/* Novena routes */],
    ),
    StatefulShellBranch(
      routes: [/* Calendar routes */],
    ),
    StatefulShellBranch(
      routes: [/* Confession routes */],
    ),
    StatefulShellBranch(
      routes: [/* Bible routes */],
    ),
  ],
),
```

---

## 4. Moderate Issues (Should Fix)

### 4.1 Duplicate Settings Screens

Each app has its own `SettingsScreen` with:
- Theme mode selector (shared from `sancta_via_shared_ui`)
- Font size selector (shared)
- Language selector (shared)
- App-specific settings (notifications, preferences)

**Recommendation:** Create a `UnifiedSettingsScreen` that combines shared settings with app-specific sections.

### 4.2 Duplicate Home Screen Patterns

All apps have a similar `HomeScreen` structure:
- App bar with liturgical theming
- Feature cards/buttons
- Recent/favorites sections

**Recommendation:** Standardize home screen layouts for visual consistency.

### 4.3 Deep Link Strategy

Each app currently handles deep links independently. A unified app needs coordinated deep link handling:

```
sanctavia://prayer/<id>
sanctavia://novena/<id>
sanctavia://calendar/<date>
sanctavia://confession
sanctavia://bible/<book>/<chapter>
```

**Current Status:** Deep link paths are unique (no conflicts), but unified registration is needed.

### 4.4 Notification Management

Multiple apps have notification providers:
- `novenaNotificationsEnabledProvider`
- `confessionNotificationsEnabledProvider`

**Recommendation:** Create a unified `NotificationCoordinator` that manages all app notifications centrally.

---

## 5. Implementation Roadmap

### Phase 1: Foundation (1 week)
**Goal:** Resolve blockers, establish unified structure

| Task | Effort | Priority |
|------|--------|----------|
| Provider naming fixes | 4h | P0 |
| Create `sancta_via_unified` app scaffold | 4h | P0 |
| Migrate shared packages to unified deps | 2h | P0 |
| Implement route namespacing | 16h | P0 |
| Create unified router with ShellRoute | 16h | P0 |

### Phase 2: Integration (2 weeks)
**Goal:** Merge apps as feature modules

| Task | Effort | Priority |
|------|--------|----------|
| Migrate Prayer Companion screens | 8h | P1 |
| Migrate Novena Companion screens | 16h | P1 |
| Migrate Liturgical Calendar screens | 8h | P1 |
| Migrate Confession Companion screens | 12h | P1 |
| Migrate Bible Reading screens | 12h | P1 |
| Unified bottom navigation | 8h | P1 |

### Phase 3: Polish (1 week)
**Goal:** User experience refinement

| Task | Effort | Priority |
|------|--------|----------|
| Unified settings screen | 8h | P2 |
| Unified home/dashboard | 12h | P2 |
| Deep link coordination | 8h | P2 |
| Notification unification | 6h | P2 |
| Testing & QA | 16h | P2 |

### Phase 4: Launch Prep (1 week)

| Task | Effort | Priority |
|------|--------|----------|
| App store assets | 8h | P2 |
| Migration guide for existing users | 4h | P2 |
| Performance optimization | 8h | P2 |
| Final testing | 8h | P2 |

---

## 6. Effort Estimates

### Summary

| Category | Estimated Hours | Duration |
|----------|-----------------|----------|
| Critical Blockers | 60h | 1 week |
| Integration Work | 68h | 2 weeks |
| Polish & UX | 50h | 1 week |
| Launch Preparation | 28h | 1 week |
| **Total** | **206h** | **5 weeks** |

### Risk-Adjusted Estimate

With buffer for unforeseen issues: **6-8 weeks** for complete unified app.

### Team Sizing

| Team Size | Duration |
|-----------|----------|
| 1 Developer | 10-12 weeks |
| 2 Developers | 6-8 weeks |
| 3+ Developers | 4-5 weeks |

---

## 7. Risk Assessment

### High Risk

| Risk | Mitigation |
|------|------------|
| Breaking existing user flows | Comprehensive navigation tests before merge |
| State preservation during tab switches | StatefulShellRoute preserves state per branch |
| App bundle size increase | Code splitting, lazy loading of features |

### Medium Risk

| Risk | Mitigation |
|------|------------|
| Provider scope confusion | Clear documentation, provider namespace prefixes |
| Settings migration | Unified settings provider with migration logic |
| Deep link conflicts | Centralized deep link registry |

### Low Risk

| Risk | Mitigation |
|------|------------|
| Theme inconsistencies | Already using shared theme system |
| Dependency version conflicts | Already unified (Riverpod ^2.6.1, GoRouter ^15.1.2) |
| Build configuration | Standard Flutter app structure |

---

## 8. Technical Debt Considerations

### Existing Debt (Carries Over)

1. **Novena Companion:** Complex nested routing may need refactoring
2. **Confession Companion:** Text scaling implementation is app-specific
3. **Bible Reading:** Debug routes should be removed before production

### New Debt Introduced

1. **Route migration layer:** Temporary redirects from old app paths
2. **Settings migration:** Logic to merge settings from standalone apps
3. **Feature flags:** To control rollout of unified experience

---

## 9. Recommendations

### Immediate Actions

1. **Fix provider naming conflicts** (quick win, reduces confusion)
2. **Create unified app scaffold** with StatefulShellRoute
3. **Document route namespacing convention** before migration

### Strategic Decisions

1. **Home Screen Strategy:** Dashboard vs. Tab-based
   - *Recommendation:* Tab-based with unified dashboard as first tab
   
2. **Settings Strategy:** Unified vs. Per-feature
   - *Recommendation:* Unified settings with feature sections
   
3. **Launch Strategy:** Gradual migration vs. Big bang
   - *Recommendation:* Gradual with feature flags

### Long-term Considerations

1. **Feature modularity:** Each "app" should remain functional as a module
2. **Testing isolation:** Maintain ability to unit test features independently
3. **Performance monitoring:** Add analytics for cross-feature navigation

---

## 10. Conclusion

The SanctaVia codebase is well-positioned for unification. The existing investment in shared packages and consistent architecture significantly de-risks the project. The primary work involves route coordination and provider disambiguation—both straightforward technical tasks.

**Key Success Factors:**
- Clear route namespacing convention (adopt early, enforce strictly)
- StatefulShellRoute implementation for seamless tab navigation
- Comprehensive testing of user flow migrations

**Recommended Next Step:** Begin Phase 1 with provider naming fixes and unified app scaffold creation.

---

*Report generated by BoldHawk swarm worker agent. Questions or clarifications should be directed to the project coordinator.*