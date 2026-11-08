# Catholic Devotionals App — Research & Scoping Dossier

*Compiled November 9, 2026 from four parallel deep-dive research threads: (1) daily prayer practices, (2) weekly/monthly/annual & liturgical cycles, (3) novenas/Marian/saint devotions & consecrations, (4) app landscape, data sources, licensing & Flutter feasibility. Purpose: define the complete possible scope for a Flutter app (iOS/Android) that supports practicing Catholic devotionals with reminders, guided prayer sessions, and progress tracking.*

---

## PART 1 — THE COMPLETE INVENTORY OF CATHOLIC DEVOTIONS

### 1.1 Daily practices

| Practice | Structure | Schedule | Scheduling class |
|---|---|---|---|
| **Liturgy of the Hours / Divine Office** — Ordinary Form | Invitatory (Ps 95/100/67/24) · Office of Readings (3 psalms, 2 readings, responsories, Te Deum) · Lauds (psalm + canticle + psalm, Benedictus, intercessions) · Daytime Terce/Sext/None (3 short psalms) · Vespers (2 psalms + NT canticle, Magnificat, petitions) · Compline (Ps 4+133 or 91, Nunc Dimittis, *Visita quaesumus*, Marian antiphon) | Up to 5 sessions/day; Office of Readings any time; Daytime ~9/12/3 | Time-of-day anchors + liturgical-calendar-driven content |
| — Seasonal Marian antiphons | Alma Redemptoris (Advent→Feb 2), Ave Regina Caelorum (Feb 2→Holy Week), Regina Caeli (Easter→Pentecost), Salve Regina (rest of year) | After Compline (and optionally Lauds/Vespers) | Season-dependent text |
| **Liturgy of the Hours — 1962 Extraordinary Form** | 8 hours incl. suppressed Prime; Matins w/ nocturns; full public-domain data (Divinum Officium, MIT) | 7–8 hrs/day | Same, different corpus |
| — Eastern (Byzantine) Hours | Midnight Office → Matins → First/Third/Sixth/Ninth Hours → Vespers → Compline; troparia by tone | Daily | Future/optional scope |
| **Daily Mass readings** | Sunday: 3-year cycle A/B/C (reset at Advent 1, not Jan 1); weekday: Year I/II odd/even in OT, fixed sets in Advent/Lent/Easter | Daily | Calendar-driven data |
| **Order of Mass** | Introductory Rites → Liturgy of the Word → Liturgy of the Eucharist → Concluding Rites | At Mass | Reference content |
| **Spiritual Communion** | St. Alphonsus prayer; Anima Christi; at-home Sunday service w/ readings | When unable to attend | User-initiated + Sunday variant |
| **Angelus / Regina Caeli** | 3 versicles + 3 Hail Marys + collect; Regina Caeli during Easter (no HMs, standing) | 6am / noon / 6pm | Time-of-day + season swap |
| **Rosary** | Creed, OF, 3 HMs, 5 decades (announce → scriptural option → OF/10HM/GB/[Fatima]), Hail Holy Queen + collect | Daily; mysteries: Mon/Sat Joyful, Tue/Fri Sorrowful, Wed/Sun Glorious, Thu Luminous; **Sunday exception: Joyful in Advent/Christmas, Sorrowful in Lent** | Day-of-week + season override |
| **Divine Mercy Chaplet + Hour of Mercy** | OF/HM/Creed, Eternal Father ×5, "For the sake…" ×50, Holy God ×3, optional Diary 950 closing | 3:00 PM daily (also anytime) | Time-of-day anchor |
| **Morning Offering** | Offers the day; includes "intentions of the Holy Father this month" → monthly papal-intention data feed | On waking | Time-of-day + monthly data |
| **Daily Examen** | Ignatian 5 steps: thanksgiving → light → review → pardon → resolve (modern variants) | Evening (trad. noon + evening) | Guided timed session |
| **Examination of Conscience** | Commandment/sin/state-of-life based question lists; before Act of Contrition | Nightly | Guided session |
| **Lectio Divina** | Lectio → Meditatio → Oratio → Contemplatio (+Actio), usually on the day's Gospel | Daily, 10–20 min | Guided session + readings data |
| **Fixed daily prayers** | Morning/night sets: Sign of Cross, OF, LM, St. Michael, Guardian Angel (day/night wordings), Memorare, Act of Contrition, Acts of Faith/Hope/Love, St. Gertrude prayer, Eternal Rest, Grace before/after meals, Creeds, Come Holy Spirit, Jesus Prayer, aspirations/ejaculations | Morning/night/any | Composable prayer library |
| **Daily consecration renewal** | "I am all yours and all I have is yours, O dear Jesus, through Mary" (de Montfort TD §233) | Daily or monthly | Anchor of consecration programs |
| **Stations of the Cross** | 14 stations (St. Alphonsus form; Scriptural Stations JPII 1991); acclamation + prayers per station; optional 15th | Any; esp. Fridays, daily in Lent | Guided walk + weekly/seasonal |

### 1.2 Weekly rhythms

| Practice | Structure | Schedule |
|---|---|---|
| **Sunday Mass obligation** | Canon 1246; Vigil Mass valid Sat ≥4pm; holy-day vigils analogous | Weekly (Sat PM–Sun) |
| **Nine First Fridays** | Communion + reparation intention (± confession); 12 promises of Sacred Heart | 1st Friday × 9 consecutive months |
| **Five First Saturdays** | Confession (within ±8 days), Communion, 5 decades, 15-min meditation, reparation intention | 1st Saturday × 5 consecutive months |
| **Six First Thursdays** | Communion + 1-hr adoration on the wounds (Blessed Alexandrina); also St. Cajetan historic indulgence | 1st Thursday × 6 consecutive months |
| **Nine First Wednesdays** | St. Joseph for a happy death (Pious Union) | 1st Wednesday × 9 consecutive |
| **Holy Hour / Adoration** | One hour (Sheen's 3×20 pattern; benediction texts) | Weekly (trad. Thursday) |
| **Friday abstinence & penance** | Canon 1251/1253; country variants (US: Lent Fridays; England/Wales: year-round) | Every Friday; skip if solemnity |
| **Saturday confession** | Traditional prep-for-Sunday custom | Weekly |
| **Perpetual novenas (weekday)** | Mon: Miraculous Medal · Tue: Perpetual Help / 13 Tuesdays of St. Anthony / Sacred Heart (Padre Pio) · Wed: St. Jude / St. Joseph · Thu: Blessed Sacrament | Weekly loops |
| **15 Thursdays of St. Rita** | 15 consecutive Thursdays ending near her feast (May 22) | Weekly series ×15 |
| **Weekly Stations** | Parish Friday Stations, esp. Lent | Weekly in Lent |

### 1.3 Monthly dedications

| Month | Standard dedication | Variant |
|---|---|---|
| January | Holy Name of Jesus | Childhood of Jesus |
| February | Holy Family | — |
| March | St. Joseph | — |
| April | Blessed Sacrament | + Holy Spirit |
| May | Blessed Virgin Mary (May crowning) | — |
| June | Sacred Heart | — |
| July | Precious Blood | — |
| August | Immaculate Heart of Mary | — |
| September | Seven Sorrows of Mary | — |
| October | Holy Rosary | + Holy Angels |
| November | Holy Souls in Purgatory | — |
| December | Immaculate Conception | Divine Infancy |

Month-scale habits: monthly confession, monthly day of recollection, November Eternal Rest/De Profundis daily, Living Rosary (1 decade/day).

### 1.4 Annual / seasonal windows

| Window | Practices | Anchoring |
|---|---|---|
| **Advent** | Advent wreath (weekly candle blessings), Advent calendar (daily), **O Antiphons Dec 17–23**, Rorate Masses, **St. Andrew Christmas Novena Nov 30–Dec 24 prayed 15×/day**, **Christmas Novena Dec 16–24**, Simbang Gabi / Las Posadas (Dec 16–24), Immaculate Conception (Dec 8), Guadalupe (Dec 12) | Fixed dates + week-of-Advent counters |
| **Christmas→Candlemas** | Chalking the door (Epiphany: Jan 6 or Sun Jan 2–8; "20+C+M+B+YY"), house blessing, **Candlemas Feb 2**, St. Blaise blessing of throats (Feb 3) | Fixed dates |
| **Pre-Lent/Feasts** | Feast of the Holy Face (Shrove Tuesday; novena starts 10 days prior), Memento Mori novena (Feb 1–10) | Easter-relative + fixed |
| **Lent** | Ash Wednesday (fast+abstinence; 18–59/14+ rules by conference), **Stations (esp. every Friday)**, Seven Penitential Psalms (Ps 6;32;38;51;102;130;143), Lenten calendar, almsgiving/fasting plans, Laetare Sunday, Friday of Sorrows | Easter−46 … |
| **Holy Week / Triduum** | Palm Sunday (palms→ashes!), Tenebrae (Spy Wednesday), Holy Thursday (Seven Churches visitation tracker), **Good Friday**: Tre Ore / Seven Last Words (12–3pm) + **Divine Mercy Novena begins**, Easter-food blessing, Easter Vigil | Easter−7…−1 |
| **Eastertide** | Regina Caeli replaces Angelus, **Divine Mercy Novena (9 days: E−2…E+6, with 9 daily soul-group intentions)**, Divine Mercy Sunday (E+7; indulgence w/ conditions), Ascension (E+39 Thu or E+43 Sun in US), **Pentecost Novena (Ascension→Pentecost; 7 gifts)**, Trinity Sunday (+56), **Corpus Christi (+60 Thu / +63 Sun; procession)**, Sacred Heart (+68; novena beforehand), Immaculate Heart (+69; impeded some years) | Easter-relative |
| **Year-end** | Christ the King (last OT Sunday) | Liturgical calc |
| **Fixed annual windows** | **Portiuncula indulgence (Aug 1 noon–Aug 2 midnight)**, St. Michael's Lent (Aug 15–Sep 29, 40 days), Sep 15 Seven Sorrows feast, blessing of animals (Oct 4), **All Saints/All Souls: cemetery-visit plenary indulgences Nov 1–8**, Forty Hours ( parish schedule, data feed) | Fixed |

### 1.5 Novenas (categorization matters; catalog may be ~250 items — Intercede publishes the full calendar)

| Class | Examples | Engine behavior |
|---|---|---|
| Feast-anchored (day 9 = feast) | St. Jude (Oct 19–28), Assumption (Aug 6–15), All Saints, St. Therese Rose (Sep 22–Oct 1; also 24 Glory Bes daily), St. Monica (Aug 18–27), Padre Pio (Sep 14–23), St. Michael (Sep 20–29), Guardian Angel, St. Benedict, Anne/Joachim, Kolbe, Faustina, Infant of Prague, Novena of Grace (Mar 4–12) | Countdown + 9-day counter |
| Liturgical-season anchored | Divine Mercy (Good Friday→Mercy Sunday), Holy Spirit/Pentecost (Ascension→Pentecost), Sacred Heart (Pentecost+10), Holy Face (Shrove Tuesday) | Easter-computed windows |
| Fixed-date range | St. Andrew (Nov 30–Dec 24), Christmas (Dec 16–24), Novena for the Dead (Oct 24–Nov 2), Miraculous Medal 1830 (Nov 18–27) | Fixed windows |
| Perpetual/weekday loops | Mon Miraculous Medal, Tue Perpetual Help, Wed St. Jude | Infinite weekly loop + streak |
| Any-start, specialty | Undoer of Knots, Surrender Novena, St. Jude, novenas for intentions (jobs, lapsed, fertility), Triduums (3-day) | Start-any-day + 9-day counter |
| Multi-phase marathons | **54-Day Rosary Novena**: days 1–27 petition / 28–54 thanksgiving; mysteries cycle J-S-G ×3 per phase; missed-day policy configurable | Phase model, 6 sub-novenas |
| Per-day repetition | St. Andrew 15×/day; St. Therese 24 Glory Bes; Angelic Warfare 15 HMs | Repetition counter widget |

### 1.6 Consecrations & structured programs

- **Total Consecration to Jesus through Mary (St. Louis de Montfort, 33 days)** — fully public domain. Structure: Days 1–12 renouncing spirit of world; 13–19 self; 20–26 Mary; 27–33 Jesus; Day 34 = consecration **which must land on a Marian feast** → start = feast − 33 (calendar table incl. leap-year cases). Daily readings + prayers (Veni Creator, Ave Maris Stella, litanies, Rosary). Annual renewal support.
- **Consecration to St. Joseph (Fr. Calloway, 33 days)**, **33 Days to Morning Glory (Fr. Gaitley)**, **Marian Consecration for Children (Gress)** — copyrighted books → "companion mode": schedule calculator + link-outs, not reproduced texts.
- Consecration to the Holy Spirit (33-day, 7-gifts), Sacred Heart enthronement of the home (ceremony checklist + annual renewal), family consecrations (Immaculate Heart, Holy Family).

### 1.7 Chaplets, litanies, rosary variants (bead-script library)

Chaplets: St. Michael (9 angelic choirs + 4 OFs), Divine Mercy, Seven Sorrows/Servite Rosary, Franciscan Crown (7 joys + 2 HMs + Lent substitution), Brigittine (6 decades), Holy Wounds, Holy Face (39 beads, Golden Arrow), Sacred Heart, Precious Blood (33 OFs), St. Anne (3×[1 OF+5 HM]), St. Anthony (13×3), St. Rita, St. Benedict, St. Jude, St. Dymphna/other moderns (no official text — pick a source), + cords: St. Philomena, Angelic Warfare Confraternity (15 HMs/day).
Litanies (versicle-cycle player): Saints, Loreto, St. Joseph, Sacred Heart, Precious Blood, Holy Name, Humility (PD), Trust (© modern). Most are public domain.

### 1.8 Sacramentals & personal-cycle tracking

- **Brown Scapular**: enrollment date + Sabbatine Privilege tracker (daily Rosary + chastity compliance).
- **Green Scapular**: daily prayer counts, "pray for [person]" proxy mode.
- Miraculous Medal, St. Michael scapular, Fivefold, etc. — catalog with rules panels.
- **Personal anniversaries**: name day (saint lookup incl. movable feasts), baptismal anniversary (renewal-promises rite), birthday, wedding anniversary (Book of Blessings rite), parish/patronal feasts.

### 1.9 Family & home

Family Rosary (group mode), Enthronement of the Sacred Heart (ceremony checklist), May crowning, Epiphany chalking (auto-year text), home/house blessings, Book of Blessings rites (anniversary blessing, not "vow renewal"), Holy Heroes-style kids' content gap (best kids product is email/print, not an app).

### 1.10 Indulgences (a cross-cutting system, not a devotion)

Plenary = work + confession + communion + prayer for Pope + detachment; **1 per day cap**; confession reusable for days. Day-anchored opportunities: Nov 1–8 cemetery, Portiuncula, Divine Mercy Sunday, Stations (Lent Fridays), prayer before a crucifix (En ego), Holy Hour, First Thursdays. → "Indulgence companion" with condition checklists and per-day cap logic.

---

## PART 2 — SYSTEMS WE NEED TO BUILD (capability scope)

### 2.1 Liturgical calendar engine (core primitive, not a feature)
- Gregorian computus + all movable dates: Ash Wed E−46, Palm E−7, Triduum, Divine Mercy E+7, Ascension E+39/+43 cfg, Pentecost E+49, Corpus E+60/+63 cfg, Sacred Heart E+68, Immaculate Heart E+69 (impediments!), Christ the King, Advent-1 (Sunday Nov 27–Dec 3), Holy Family, Baptism of the Lord (Monday edge cases).
- Day model: `{date, season, rank (solemnity|feast|mem|optional), color, transferOf?, precedenceRules}`; Evening Prayer I for solemnities; Lent weekday memorial demotion; Saturday BVM optional memorial.
- **Region profiles**: US (6 HDOs, Jan 1/Aug 15/Nov 1 obligation suppressed on Sat/Mon, Ascension→Sun, Epiphany→Sun), Ireland (+St Patrick), Poland, Philippines, Germany/Hungary, etc. + Ember/rogation toggle for EF/Ordinariate forms.
- Lectionary mapping: Sun 3-year (reset at Advent 1), weekday I/II, fixed seasonal sets.
- Data sources to validate against: romcal (MIT, TS), Divinum Officium (MIT, 1962), Liturgical Calendar API (JohnRDOrazio), calapi.inadiutorium.cz; test oracle = USCCB published calendars.

### 2.2 Scheduling engine — six pattern classes
1. Fixed date / date-range (O Antiphons, Nov 1–8, Portiuncula)
2. Easter-anchored offsets (Divine Mercy novena, Holy Face novena)
3. nth-weekday-of-month (First Fri/Sat/Thu/Wed, 3rd Sunday)
4. N-consecutive calendar-position commitments (9 First Fridays, 54-day, 33-day consecrations) — **consecutive positions, not dates**
5. Weekly/day-of-week perpetual loops (weekday novenas, Friday penance)
6. Time-of-day anchors (Angelus 6/12/6, 3pm mercy hour, Lauds/Vespers/Compline)
Plus: per-day repetition counters (St. Andrew 15×), one-shot ceremonies (enthronement), season-dependent content selection (mystery overrides, Regina Caeli/Angelus, Marian antiphon), and grace windows (First-Saturday confession ±8 days; vigil Mass from 4pm).

### 2.3 Tracking / progress model
Per-commitment counters with consecutiveness validation; strict-vs-permissive missed-day policies (both rules exist in practice); phases (54-day; consecration weeks); repetition progress; projected completion dates ("3 First Saturdays left: Jun 6, Jul 4, Aug 1"); grace-window satisfaction; completion badges with dated history; streaks + heatmaps; lifetime counts; intentions list (with souls list, proxy prayers); plenary-indulgence daily cap + condition checklists.

### 2.4 Prayer session engine
A "script" format covering: bead maps (decades, chaplet layouts, 39/33/13-bead oddities), versicle/response cycles (litanies), step-based guided sessions (Examen, Lectio, Stations, consecration days), toggles (Fatima prayer, 15th station, Latin/English, short/full forms), pause/resume, timers, optional audio ("prayed along"), multiple approved text variants per prayer.

### 2.5 Content pipeline & licensing gates
- **Public-domain core (launchable day 1, zero license risk)**: Douay-Rheims/Challoner bible, 1962 Roman Breviary/Missal (Divinum Officium, MIT), all classic prayers/Litany of Humility-class litanies/old chaplets, St. Alphonsus novenas, de Montfort consecration, traditional Miraculous Medal novena, 54-day rosary petitions, Stations (Liguori), Enchiridion-era indulgence texts.
- **Copyrighted gates**:
  - Ordinary-Form LoH: ICEL + Grail/Abbey Psalms. **Second Edition timeline: confirmed Oct 2025; first use Ash Wed Feb 10, 2027; current edition valid until Advent Dec 3, 2028 (mandatory); digital licensing opens mid-2027 via USCCB selection process.** Build a text-pipeline abstraction now; use 1962 (free) as the bundled Office meanwhile.
  - USCCB daily readings (NAB ©): permissable-path = USCCB RSS feed; alternatives = DR/CPDV readings + link-out.
  - Divine Mercy Diary translations: © Marians (license; USCCB reproduces chaplet core — positive sign).
  - Modern consecration books, Franciscan Media saint bios, Universalis/AELF output: do not copy; link-out or write original.
  - Martyrology/saints: 2004 Italian official posting free; older English martyrologies PD.

### 2.6 Reminders & app tech (Flutter, verified packages)
- `flutter_local_notifications` + `timezone` (+`flutter_timezone`): daily/weekly/yearly triggers, TZ-correct.
- Precompute the entire liturgical year at launch → reminders never depend on network; `workmanager`/`background_fetch` only for opportunistic refresh (iOS limits documented).
- Offline-first local DB: **drift** (Flutter Favorite; avoid Isar/Hive for new projects).
- Audio: `just_audio` + `audio_session` (looping decades, speed control).
- Widgets/Live Activities: `home_widget` + small native SwiftUI/WidgetKit + ActivityKit targets.
- No-account, fully-offline pattern is precedent-set (PrayForge) and cheap given MIT data.

### 2.7 Competitive positioning (what exists / the open lane)
Text engines (Universalis, iBremviary, Divine Office, Laudate: strong texts, weak tracking/UX); audio platforms (Hallow $70/yr, Amen, Ascension, Magnificat: rich content, subscriptions, online-dependent, no liturgical engine); habit/trackers (Echo, Exodus 90, novena apps: tracking only, no texts).
**No app combines: licensed liturgical texts + genuine habit/progress tracking + fully offline + modern reminders/widgets.** Structured progress is the weakest column in every competitor. Family/kids devotional app space is nearly empty. Timing note: entering the USCCB 2nd-edition licensing process early (opens mid-2027) is a strategic advantage; the Dec 2028 mandatory switch will force all Office apps to re-license.

---

## PART 3 — OPEN DECISIONS FOR THE DESIGN PHASE

1. **Personal use vs published app** — reshapes licensing, accounts, region profiles, revenue.
2. Which rites/forms: Ordinary Form only? + 1962 Extraordinary Form? + Eastern hours?
3. LoH text strategy v1 (1962 PD now / apply ICEL / link-out to approved apps).
4. Bible translation (DR PD vs licensed RSV-CE/NABRE; RSS readings path).
5. Library scope v1 vs roadmap (core daily set + top novenas vs full ~250 catalog).
6. Audio (none / TTS / recorded), language(s) beyond English, Latin.
7. Region profile(s) needed (US only?).
8. Cloud/accounts/sync family sharing or strictly local.
9. Widgets/live activity scope.
10. Monetization (none / one-time / subscription).
