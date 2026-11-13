# V3 G1b — Schritt 2: Lebenszyklus, Demografie und Haushaltsauflösung

Status: **G1b Schritt 2 bestanden (Review 2026-11-13); Commit folgt**  
Stand: 2026-11-14  
Godot: **4.7.2-stable (official, ed1daf0bf)**, Standard-Build (GDScript)  
Zielplattform: Windows, 1920 × 1080, Ryzen 5 5600 / RTX 5060  
Featured Seed (visuelles Jahr): **34**  
Standard-Seed der bisherigen Abnahme: **1337**

Bezug: `docs/v3-g1-spec.md`, `docs/v3-g1-workpackages.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`,
`docs/g1a/v3-g1a-report.md`, `docs/g1b/v3-g1b-step1-report.md`

---

## 1. Ergebnis

G1b-Schritt 2 ist implementiert. Die Hauptsimulation hat jetzt Alterung,
alters- und gesundheitsabhängige Sterblichkeit, deterministische
Partnerschaftsbildung, Schwangerschaft/Geburt, Todesrecords und
Haushaltsauflösung. Die 1.000-Agenten-Demografie-Kohorte nutzt exakt dieselben
Regel- und Konfigurationsfunktionen wie die Hauptsimulation.

- **G1a:** 29/29 Test-IDs, **254 Checks**, `G1A_SUITE_OK`
- **G1b Schritt 1:** 7/7 Test-IDs, **81 Checks**, `G1B_SUITE_OK` (unverändert)
- **G1b Schritt 2:** T-LIFE-01..06 und T-BENCH-03/04;
  **`G1B_SUITE results=15 passed=15 failed=0 checks=248`**
- **Demografie (5 Seeds, 100 Jahre):** **46.082 Geburten**, **4.990 Tode**,
  Median **49,0**, 29,2 % sterben vor 40, 16,2 % erreichen 70, 6,8 %
  erreichen 80
- **Featured-Jahr (Seed 34):** 2 Geburten, 2 Tode, 8 der 10 Startagenten
  und 10 Agenten insgesamt lebend, Grain 182, ID 8 Gustav (Spec-A5)
  Gesundheit 80,1; erste Geburt und erster Tod an Lifecycle-Tag 20 (Anzeige Tag 21 00:00)
- **Save:** Schema **3**; 13.506 Bytes, Save 1,01 ms, Load 7,77 ms
  (Seed 1337, Tag 1 12:05); Schema 1 und 2 werden sichtbar mit
  `unsupported_schema` abgelehnt; Save/Load vor/nach Schwangerschaft, Geburt,
  Tod, Partnerschaft und Haushaltsauflösung ist exakt
- **Kalibrierung:** Startgrain 60 → 120; Mahlzeiten-Skips im Seed-1337-Jahr
  260 → **140**; A1-Gesundheit am Jahresende 100 → **92,4**; keine stille
  Auffüllung, keine Massenauslöschung in Woche 1
- **Visuell 10 Agenten @50x:** p95 **5,106 ms**, **224,2 FPS**,
  665,3 Draw Calls Ø; 30,000 Sim-Tage in 540,0 s; sichtbare Geburt/Tod
  an Lifecycle-Tag 20 (Anzeige Tag 21 00:00)
- **Dateigrenze:** neue Module bleiben unter 1.000 Zeilen;
  `decision_system.gd` wurde für den Lebenszyklus **nicht** weiter aufgebläht

## 2. Umfang und Nicht-Ziele

### Enthalten (Schritt 2)

- Alterung mit Geburtstagen und exakten Rollenwechseln:
  Kind 0–12, Jugend 13–17, Erwachsen 18–59, Alt 60+.
- Rollen-/Schedule-Wechsel inklusive deterministischer Jobzuweisung:
  Kind ohne Job, Jugend Lehrling/Werkstatt, Erwachsener Feldarbeit,
  Alt leichte Aufgaben/Werkstatt.
- Altersabhängige Sterblichkeit mit Health-Multiplikator und kritischer
  Gesundheit; keine Krankheit, keine Gewalt.
- Tod setzt `alive=0`, erhält den Cold-Record und macht alte Scheduler-Wakes
  über die Wake-Generation stale/ignoriert.
- Einfache, deterministische Partnerschaft unter lebenden, unverpartnerten
  Erwachsenen 18–59; lebende Partner bleiben, Blutsverwandte werden nicht
  verpaart.
- Geburt nur mit lebendem Partner, fruchtbarem Alter, deterministischer
  Monatswahrscheinlichkeit, Schwangerschaftsdauer und Geburtsrisiko.
- Neues Agentenobjekt mit stabiler ID, Elternbeziehungen, Haushalt, Home,
  Startwerten und Cold-Record.
- Haushaltsauflösung: Stirbt der letzte Erwachsene, werden Minderjährige einem
  lebenden verwandten Haushalt zugeordnet; ohne Verwandte wird der Haushalt
  als historischer Record archiviert und der Minderjährige explizit als
  „kein Haushalt“ (ID 0) geführt. Keine Dangling-Referenzen.
- Save-Schema 3 mit Schwangerschaft, Fertilität (Alter/Sex), Tod,
  Haushaltszuordnung/Archiv und Lifecycle-Zählern.
- 1.000-Agenten-Demografie-Kohorte als Test-/Kalibrierungswerkzeug.
- Sichtbarer 1-Jahres-Lauf mit Featured Seed 34.

### Nicht enthalten (bewusst Schritt 3 / G2)

- Kein Familienbaum, Follow-Modus, Alerts, Story of the Day, Chronik-UI,
  Chronik-Kuratierung oder Replay.
- Keine Krankheiten, Gewalt, Kriege, Tiere, Fantasy, Wirtschaft oder Politik.
- Keine Änderung an G0-Dokumenten, `README.md` oder `docs/v3-plan.md`.
- Keine Git-Commits/Pushes durch den Implementierer.

## 3. Geänderte und erstellte Dateien

### Produktionscode

| Datei | Änderung |
|---|---|
| `src/agents/lifecycle_rules.gd` | **neu:** reine Regel-/Fertilitäts-/Mortalitätsfunktionen |
| `src/agents/lifecycle_system.gd` | **neu:** Alterung, Monatsrollen, Partnerschaft, Geburt, Tod, Haushaltsauflösung |
| `src/data/sim_config.gd` | Schema 3; Startgrain 120; Health-Kalibrierung; Mortalitäts-/Fertilitätsparameter |
| `src/agents/agent_store.gd` | SoA-Felder `sex`, `birth_day`, `pregnant`, `pregnancy_due`, `pregnancy_father_id`, `death_day`, `death_cause`; erweiterte Spawn-Signatur |
| `src/agents/agent_record.gd` | Cold-Record-Felder `birth_day`, `death_day`, `death_cause` |
| `src/agents/household_record.gd` | `dissolved`, `dissolved_day`, `dissolved_reason`, `archived_member_ids` |
| `src/agents/simulation.gd` | Lifecycle-Instanz, Tages-Tick-Dispatch, Lifecycle-Zähler, State-Hash |
| `src/persistence/sim_save.gd` | Schema 3; neue Config-/Store-/Record-/Household-/Zählerfelder |
| `src/kernel/sim_event.gd` | Age-up-, Rollen-, Partner-, Schwangerschafts-, Geburts-, Todes- und Haushaltsereignisse |

Nicht geändert: `src/decisions/decision_system.gd`, `needs_model.gd`,
`role_schedule.gd` (nur über bestehende Schnittstellen genutzt),
`src/view/*`, G0-Dokumente, `README.md`, `docs/v3-plan.md`.

### Tests und Werkzeuge

| Datei | Zweck |
|---|---|
| `tests/g1b/test_lifecycle.gd` | T-LIFE-01..06 |
| `tests/g1b/test_demography.gd` | T-BENCH-03/04 |
| `tests/g1b/demography.gd` | 1.000-Agenten-Kohorte, 100 Jahre, 5 Seeds |
| `tests/g1b/featured_seed.gd` | Featured Seed 34 |
| `tests/g1b/seed_search.gd` + `.tscn` | dokumentierte Seed-Suche |
| `tests/g1b/visual_year.gd` + `.tscn` | sichtbarer 1-Jahres-Lauf @50x |
| `tests/g1a/test_save.gd` | Schema 3 und Ablehnung von Schema 1/2 |
| `tests/g1a/test_food.gd` | Startgrain aus `SimConfig` statt Literal 60 |
| `tests/g1b/g1b_suite.gd` | Schritt-1- und Schritt-2-Tests |

### Doku / Artefakte

- `docs/g1b/README.md` (aktualisiert)
- `docs/g1b/v3-g1b-step2-report.md` (diese Datei)
- `bench/results/g1b_year_result.json`, `g1b_year_birth.png`,
  `g1b_year_death.png`
- aktualisierte `bench/results/g1a_visual_result.json`, `g1a_demo*.png`

## 4. Lebenszyklus-, Fertilitäts- und Mortalitätsregeln

### 4.1 Zeit- und Rollenmodell

- Ein Sim-Jahr = 30 Tage. Alter wird aus `birth_day` und dem aktuellen Tag
  berechnet; ein Geburtstag wird an jedem Tages-Tick geprüft.
- Rollen: 0–12 Kind, 13–17 Jugend, 18–59 Erwachsen, 60+ Alt.
- Beim Rollenwechsel wird der Job deterministisch gesetzt und ein Wake
  angefordert, damit der neue `RoleSchedule` greift.
- Es gibt keinen Full-Agent-Sweep pro Frame. Alterung läuft einmal pro
  Sim-Tag, Sterblichkeit/Partnerschaft/Fertilität auf festen Roll-Tagen.

### 4.2 Kalibrierte Sterblichkeit pro Sim-Jahr

Die provisorische G1-Spec-Tabelle wurde gegen die Zielverteilung kalibriert.
Die 30–49-Jahre-Zeile wurde dafür in 30–39 und 40–49 getrennt.

| Alter | G1-Spec (provisorisch) | Schritt 2 (kalibriert) |
|---|---:|---:|
| 0–4 | 3,0 % | **1,0 %** |
| 5–14 | 0,5 % | **0,2 %** |
| 15–29 | 1,0 % | **0,5 %** |
| 30–39 | 2,0 % (30–49) | **1,5 %** |
| 40–49 | 2,0 % (30–49) | **3,5 %** |
| 50–64 | 4,0 % | **4,4 %** |
| 65–79 | 8,0 % | **8,0 %** |
| 80+ | 15,0 % | **15,0 %** |

- Monatsrisiko: `1 − (1 − Jahresrisiko × Health-Multiplikator)^(1/6)`.
  Ein G1b-Monat ist ein Roll-Intervall von 5 Sim-Tagen; es gibt 6 Rollen pro
  Jahr.
- **Health-Multiplikator:** `1 + 4 × ((100 − Health)/100)²`.
  Health 100 → 1,0; 80 → 1,16; 50 → 2,0; 0 → 5,0.
- **Kritische Gesundheit:** ab Health ≤ 10 gilt mindestens 15 % Todesrisiko
  pro Monatsrolle (schwere Gesundheitsfolge, keine Krankheit).
- Todesursachen: `Alter`, `schwere Gesundheit`, `Geburt`.
- Die erste Lifecycle-Rolle liegt an **Tag 10**, danach alle 5 Tage
  (10, 15, 20, 25, 30, …). Dadurch bleiben die exakten G1a-Abnahmen der Tage
  0–6 unverändert; im ersten Jahr entfällt genau eine der sechs Jahresrollen.
  In Woche 1 gibt es damit keine Mortalitätsrolle und keine Massenauslöschung.

### 4.3 Gesundheit und Knappheit

| Parameter | Schritt 1 | Schritt 2 |
|---|---:|---:|
| Startgrain | 60 | **120** |
| Health schlecht | −12/Tag | **−15/Tag** |
| Health-Erholung | +4/Tag | **+2,5/Tag** |
| Altersrückgang | −6/Jahr ab 60 | **−8/Jahr ab 60** |
| Kritische Schwelle | — | **≤ 10** |

- Keine stille Auffüllung: Grain entsteht weiterhin nur durch Ernte.
- Seed 1337, ein Sim-Jahr: Mahlzeiten-Skips **140** statt 260;
  A1-Gesundheit am Jahresende **92,4** statt 100.
- Die Featured-Siedlung (Seed 34) überlebt das Jahr mit 10 Lebenden; die
  Gesundheit von ID 8 Gustav (Spec-A5) fällt auf 80,1 und erhöht sein
  Sterberisiko, ohne eine Massenauslöschung zu erzeugen.

### 4.4 Partnerschaft und Fertilität

- Paarung nur unter lebenden, unverpartnerten Erwachsenen 18–59, gegengeschlechtlich,
  ohne direkte Eltern-/Kind-/Großelternbeziehung. Bestehende lebende Partner
  bleiben; historische Partnerbeziehungen zu Toten blockieren eine neue
  Partnerschaft nicht.
- Determinismus: Kandidaten werden nach Agent-ID sortiert; der erste gültige
  Partner nach ID gewinnt.
- Fruchtbarkeit: Frauen 18–40, Männer 18–55.
- Monatswahrscheinlichkeit: **20 %** pro Roll-Intervall.
- Schwangerschaftsdauer: **2 Roll-Intervalle = 10 Sim-Tage**; die Geburt wird
  am fälligen Roll-Tag geprüft.
- Geburtsrisiko: **0,5 %** Muttersterben pro Geburt. Das Kind bleibt mit
  beiden Elternbeziehungen bestehen.
- Neugeborene erhalten eine neue, nie wiederverwendete ID, `birth_day`,
  Geschlecht, Namen, Mutter-/Vaterbeziehungen, Haushalt/Home und Startwerte.

### 4.5 Tod, Records und Scheduler

- Tod: `alive=0`, `death_day`, `death_cause`, Cold-Record bleibt, Haushalt
  wird aktualisiert, Wake-Generation wird erhöht.
- Alte Agent-Wakes bleiben im Scheduler, werden aber über die Generation und
  `alive` ignoriert. Es gibt keinen Full-Agent-Sweep und keine Auferstehung.
- Tote Agenten bleiben bis zu einer späteren Kompaktierung (nicht Schritt 2)
  als Record erhalten.

### 4.6 Haushaltsauflösung

- Auslöser: Tod des letzten lebenden Erwachsenen (Alter ≥ 18) eines Haushalts.
- Zuerst werden lebende Minderjährige einem lebenden Verwandtenhaushalt
  zugeordnet: Eltern vor Großeltern, dann niedrigste Haushalts-ID, dann
  niedrigste Verwandten-ID.
- Ohne lebenden Verwandten wird der Minderjährige explizit mit
  `household_id = 0` („kein Haushalt“) geführt; `home_id` bleibt ein gültiges
  Gebäude.
- Der alte Haushalt wird mit `dissolved=1`, `dissolved_day`,
  `archived_member_ids` und leerem `member_ids` archiviert.
- `LifecycleSystem.validate_households()` prüft aktive Mitglieder, tote/
  unbekannte Referenzen, aufgelöste Haushalte und Home-Gebäude.

## 5. Test-ID-Ergebnisse

### 5.1 G1a — 29/29

Alle bisherigen G1a-IDs bleiben grün. Die einzige testseitige Anpassung ist
`T-FOOD-01`: Der erwartete Startbestand kommt jetzt aus
`sim.config.start_grain` statt aus dem Literal 60; die Prüfungen selbst sind
nicht abgeschwächt. `T-SAVE-01/03` prüfen Schema 3 und die sichtbare
Ablehnung von Schema 1 und 2.

| Bereich | Ergebnis |
|---|---|
| T-KERN-01..04 | bestanden |
| T-STORE-01..03 | bestanden |
| T-NEED-01..04 | bestanden |
| T-WORLD-01..03 | bestanden |
| T-MOVE-01..03 | bestanden |
| T-FOOD-01..03 | bestanden |
| T-SAVE-01..03 | bestanden (Schema 3; 1 und 2 abgelehnt) |
| T-UI-01..04 | bestanden |
| T-BENCH-01..02 | bestanden |

### 5.2 G1b Schritt 1 — 7/7

T-NEED-05..07 und T-FARM-01..04 bleiben unverändert grün (81 Checks).

### 5.3 G1b Schritt 2 — T-LIFE-01..06

| ID | Ergebnis | Kernprüfung |
|---|---|---|
| T-LIFE-01 | bestanden | Geburtstage, Alter 18/13/71/39, Rollen- und Jobwechsel, Schedule 13:00, 3-Lauf-Determinismus |
| T-LIFE-02 | bestanden | Alters-/Health-Mortalität, kritische Gesundheit, 1.000er-Kohorte 100 Jahre/5 Seeds, Zielverteilung |
| T-LIFE-03 | bestanden | gültige Paare, Minderjährige/blutsverwandte/unpassende nicht, bestehende Partner bleiben, 3-Lauf-Determinismus, Save/Load |
| T-LIFE-04 | bestanden | Schwangerschaft, Geburt, Elternbeziehungen, Haushalt, Save/Load vor/nach Geburt, Geburtsrisiko |
| T-LIFE-05 | bestanden | Tod/Record, stale Wake, Haushalt, natürlicher Alterstod, Save/Load |
| T-LIFE-06 | bestanden | Verwandtenzuordnung, Ward ohne Verwandte, Archiv, keine Dangling-Referenzen, Save/Load, Determinismus |

### 5.4 T-BENCH-03/04

| ID | Ergebnis | Kernprüfung |
|---|---|---|
| T-BENCH-03 | bestanden | Featured Seed 34: 1 Sim-Jahr, ≥ 1 Geburt, ≥ 1 Tod, ≥ 50 % lebend, chunk-unabhängig, visuelles JSON |
| T-BENCH-04 | bestanden | 5 Seeds, 1.000 Agenten, 100 Jahre, Mindestgeburten/-tode, Median und Zielverteilung |

## 6. Demografie-Verteilung

Protokoll: 1.000 Startagenten pro Seed (500 weiblich, 500 männlich, Alter 0),
100 Sim-Jahre, 6 Monatsrollen/Jahr, dieselben `LifecycleRules` und
`SimConfig`-Parameter wie die Hauptsimulation. Geburten werden mit derselben
Fertilitäts-/Schwangerschaftsregel erzeugt und gezählt; die Neugeborenen
werden in dieser reinen Kohorten-Lebenstafel nicht als neue
Kohortenmitglieder weiterverfolgt. Die Sterbealtersverteilung bezieht sich
daher auf die 1.000 Startagenten; dadurch gibt es keine Zensierung durch
später geborene Jahrgänge.

| Seed | Geburten | Tode | Geburtstode | Median | < 40 | 70+ | 80+ | zensiert |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1337 | 9.310 | 1.000 | 53 | 49,0 | 28,9 % | 15,4 % | 7,9 % | 0 |
| 1338 | 9.012 | 998 | 43 | 49,0 | 29,6 % | 16,1 % | 6,4 % | 2 |
| 1339 | 9.411 | 1.000 | 53 | 51,0 | 26,6 % | 17,4 % | 6,9 % | 0 |
| 1340 | 9.250 | 997 | 49 | 49,0 | 30,2 % | 16,3 % | 6,4 % | 3 |
| 1341 | 9.099 | 995 | 46 | 48,0 | 30,5 % | 16,0 % | 6,5 % | 5 |
| **Summe** | **46.082** | **4.990** | **244** | **49,0** | **29,2 %** | **16,2 %** | **6,8 %** | — |

Zielbereiche (aggregiert):

| Kennzahl | Ziel | Ergebnis | Status |
|---|---:|---:|---|
| Geburten | ≥ 500 | 46.082 | erfüllt |
| Tode | ≥ 500 | 4.990 | erfüllt |
| Median-Sterbealter | 48–52 | 49,0 | erfüllt |
| Tod vor 40 | 25–35 % | 29,2 % | erfüllt |
| 70 erreicht | 15–25 % | 16,2 % | erfüllt |
| 80 erreicht | 5–10 % | 6,8 % | erfüllt |

Jeder einzelne Seed liegt innerhalb der Zielbereiche. Die 244 Geburtstode
sind Teil der Sterblichkeit und verschieben die Verteilung leicht nach unten;
sie sind kein separater Balance-Satz.

## 7. Featured-Jahr und Messwerte

### 7.1 Featured Seed 34 (10 Agenten, 1 Sim-Jahr)

| Messwert | Ergebnis |
|---|---:|
| Startagenten | 10 |
| Lebend am Jahresende | 10 (inkl. 2 Geburten, 2 Tode) |
| Startagenten lebend | 8 von 10 |
| Geburten | 2 (ID 11 L-Tag 20 / Tag 21, ID 12 L-Tag 25 / Tag 26) |
| Tode | 2 (ID 2 Alma, 35, L-Tag 20 / Tag 21; ID 8 Gustav/Spec-A5, 70, L-Tag 20 / Tag 21) |
| Erste Geburt | L-Tag 20 = Anzeige Tag 21 00:00 (ID 11 „Katharina“) |
| Erster Tod | L-Tag 20 = Anzeige Tag 21 00:00 (ID 2 „Alma“, Ursache Alter) |
| Grain am Jahresende | 182 |
| ID 8 Gustav (Spec-A5) Gesundheit | 80,1 |
| Haushalte | 3 (keine Auflösung im Featured-Jahr) |

Der Tod von ID 2 (Alma) mit 35 ist kein Skript-Tod: Er entsteht aus demselben
alters-/healthabhängigen Monatsroll wie alle anderen Tode. Am Lifecycle-Tag 20
hatte Alma Health **84,1** (Hygiene 45); der Health-Multiplikator erhöhte ihr
Altersrisiko um ca. 10 %. ID 8 Gustav (Spec-A5, 70) hatte Health **79,7**
(Multiplikator ca. 1,16) und starb im selben Monatsroll aus Altersrisiko.
Damit wirkt Health vor dem Tod, ohne die Siedlung auszulöschen.

Seed 1337 (bisheriger Abnahmeseed) hat im ersten Jahr **1 Geburt, 0 Tode,
11 Lebende**; Grain **171**, 140 Skips, A1-Gesundheit **92,4**. Der Featured
Seed 34 wurde separat für den sichtbaren Geburts-/Todesnachweis gewählt.

### 7.2 Visueller 1-Jahres-Lauf

Protokoll: 1920 × 1080, VSync aus, 50x, Seed 34, 30 Sim-Tage
(540,0 s real, 9 min).

| Messwert | Ergebnis |
|---|---:|
| Frames | 119.931 |
| FPS (Durchschnitt) | **224,2** |
| Frame p50 | **4,361 ms** |
| Frame p95 | **5,106 ms** (Budget ≤ 16 ms) |
| Frame p99 | **5,996 ms** |
| Frame max | 285,861 ms (Screenshot-Hitch der Capture-Funktion) |
| Draw Calls Ø / max | **665,3 / 668** |
| Sim-Tage | 30,000 |
| Events | 5.850 |
| Sichtbare Geburt/Tod | 2 Geburten, 2 Tode; erste beide an L-Tag 20 (Tag 21) |
| Screenshots | `g1b_year_birth.png`, `g1b_year_death.png` |

Der Maximalframe entsteht durch `get_viewport().get_texture().get_image()` und
`save_png()` der beiden Beweis-Screenshots, nicht durch die Simulation oder das
normale Rendering. Ohne Capture liegt der G1a-Vergleichslauf bei max. 10,6 ms.
Der Schritt-2-Akzeptanzwert p95 ≤ 16 ms ist deutlich erfüllt.

Beide Screenshot-Dateien zeigen denselben Event-Log-Frame, weil Geburt ID 11
und die Tode von ID 2 (Alma) und ID 8 (Gustav) im selben Lifecycle-Tick
(L-Tag 20, Anzeige Tag 21 00:00) liegen. Der sichtbare Log enthält gemeinsam
„Katharina Geburt“, „Alma Tod“ und „Gustav Tod“; die zweite Geburt ID 12 folgt
an L-Tag 25 (Anzeige Tag 26).

### 7.3 G1a-Visual (10 Agenten @50x, 60 s)

Protokoll: 1920 × 1080, VSync aus, 6 s Warm-up, 60 s Messfenster,
Kamerafahrt Pan/Zoom, Seed 1337.

| Messwert | Ergebnis |
|---|---:|
| Frames | 13.505 |
| FPS (Durchschnitt) | **225,1** |
| Frame p50 | **4,334 ms** |
| Frame p95 | **5,086 ms** (Budget ≤ 16 ms) |
| Frame p99 | **6,255 ms** |
| Frame max | **10,641 ms** |
| Sim-Zeit im Messfenster | 3,67 Sim-Tage |
| Events im Messfenster | 757 |
| Draw Calls Ø / max | **666,0 / 668** |

### 7.4 Headless-Simkosten

Die bestehenden G1a-Headless-Messungen bleiben dokumentiert. Der Lebenszyklus
fügt nur einen Tages-Sweep über die aktiven Agenten und seltene Monatsrollen
hinzu; es gibt keinen Full-Agent-Sweep pro Frame.

## 8. Save-Schema 3

Gespeichert werden zusätzlich zu Schema 2:

- **Config:** Health-Kritisch-Parameter, Multiplikator-Kurve,
  Lifecycle-Rolltage, kalibrierte Mortalitätstabelle, Paarungs-/Fertigkeits-
  alter, Monatskonzeption, Schwangerschaftsdauer, Geburtsrisiko.
- **Agenten-SoA:** `sex`, `birth_day`, `pregnant`, `pregnancy_due`,
  `pregnancy_father_id`, `death_day`, `death_cause`.
- **Cold-Records:** `birth_day`, `death_day`, `death_cause`.
- **Haushalte:** `dissolved`, `dissolved_day`, `dissolved_reason`,
  `archived_member_ids`.
- **Simulationszähler:** `births`, `deaths`, `partnerships_formed`,
  `households_dissolved`, `lifecycle_ticks`.

Schema 1 und 2 werden vor dem Payload-Decode sichtbar abgelehnt; es gibt
keine stille Migration. Save/Load ist in den Tests vor/nach Schwangerschaft,
Geburt, Tod, Partnerschaftswechsel und Haushaltsauflösung exakt (State- und
Event-Hash).

Messwerte (Seed 1337, Tag 1 12:05, finaler Lauf):

| Messwert | Ergebnis |
|---|---:|
| Schema | 3 |
| Größe | **13.506 Bytes** |
| Save-Zeit | **1,01 ms** |
| Load-Zeit (inkl. Welt-/Log-Rekonstruktion) | **7,77 ms** |
| Schema 1 | sichtbar `unsupported_schema` |
| Schema 2 | sichtbar `unsupported_schema` |
| Schema 999 / Magic / Config-Hash | sichtbar abgelehnt |

## 9. Vorher/Nachher

| Beobachtung | Schritt 1 | Schritt 2 |
|---|---:|---:|
| Alterung | statisch | Geburtstage + Rollenwechsel |
| Tod | nicht vorhanden | alters-/healthabhängig, Record, stale Wakes |
| Partnerschaft | nur Startbeziehungen | deterministische Neu-/Weiterbildung |
| Geburt | nicht vorhanden | Schwangerschaft, Geburtsrisiko, neuer Agent |
| Haushaltsauflösung | nicht vorhanden | Verwandtenzuordnung/Archiv/Ward |
| Startgrain | 60 | 120 |
| Mahlzeiten-Skips (Seed 1337/Jahr) | 260 | 140 |
| A1-Health Jahresende | 100 | 92,4 |
| Save-Schema | 2 | 3 |
| G1a-Test-IDs | 29/29 | 29/29 (254 Checks) |
| G1b-Test-IDs | 7/7 | 15/15 (248 Checks, inkl. Schritt 2) |
| Visuell p95 | 5,07 ms | 5,106 ms (Jahreslauf) / 5,086 ms (G1a-Bench) |
| Draw Calls Ø | 666,1 | 665,3 (Jahreslauf) / 666,0 (G1a-Bench) |

## 10. Bekannte Grenzen und bewusste Vereinfachungen

1. **Kohorten-Geburten werden nicht weiterverfolgt.** Die Demografie-Kohorte
   ist eine Lebenstafel der 1.000 Startagenten; Geburten werden mit denselben
   Regeln erzeugt und gezählt, aber Neugeborene nicht als neue
   Kohortenmitglieder simuliert. Das vermeidet unbegrenztes Bevölkerungswachstum
   und Zensierung, ohne einen separaten Balance-Satz einzuführen.
2. **Monatsraster.** Fertilität, Sterblichkeit und Geburt liegen auf festen
   5-Tage-Rollen. Die erste Rolle ist Tag 10, um die exakten G1a-Tage 0–6
   nicht zu verändern; im ersten Jahr entfällt eine von sechs Jahresrollen.
3. **Schwangerschaftsdauer** ist 2 Roll-Intervalle (10 Sim-Tage), nicht
   realistisch 9 Monate. Das ist eine G1-Kalibrierung für das 30-Tage-Jahr.
4. **Partnerschaften führen keine Haushalte zusammen.** Partner können in
   verschiedenen Haushalten leben; das Kind folgt der Mutter.
5. **Wards ohne Verwandte** erhalten `household_id = 0`; sie bleiben am Leben
   und behalten ein gültiges Home-Gebäude. Eine Siedlungsvormundschaft ist
   nicht Teil von Schritt 2.
6. **Keine Dead-Record-Kompaktierung.** Tote bleiben als Cold-Record erhalten;
   die im Datenmodell vorgesehene DeadAgentRecord-Kompaktierung ist später.
7. **Keine Krankheit/Gewalt.** Tode entstehen nur durch Alter, schwere
   Gesundheit oder Geburtsrisiko.
8. **Kein Replay, keine Chronik-Kuratierung, keine Schritt-3-UI.** Familienbaum,
   Follow, Alerts, Story of the Day und Chronik-Panel bleiben Schritt 3.
9. **Visueller Lauf ist 9 Minuten.** Der Jahresnachweis ist zusätzlich
   headless (T-BENCH-03) und über die Demografie (T-BENCH-04) abgesichert.
10. **Test-Fixtures** für T-LIFE-03/04/05/06 setzen gezielt Partner, Alter,
    Mortalitätsraten oder Tod, um Einzelpfade deterministisch zu prüfen; die
    Produktionsbalance wird dadurch nicht verändert.
11. **Alterung ist ein Tages-Sweep** über die aktiven Agenten, kein
    Per-Frame-Sweep. Für G2 mit vielen Agenten ist eine
    Birthday-Event-Queue statt des Tages-Sweeps vorgesehen.
12. **Partner-/Haushaltssuche ist auf die 10-Agenten-Siedlung ausgelegt**
    (lineare Beziehungssuche pro Monatsrolle). Bei tausenden Agenten wären
    Indexstrukturen nötig; die Demografie-Kohorte nutzt dafür eine separate
    optimierte, aber regelgleiche Schleife.

## 11. Reproduktion

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

# 1) Import
& $godot --headless --path C:\coding\WimmelWorld\V3 --import

# 2) Sichtbarer G1a-Benchmark (T-UI-04/T-BENCH-02)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn

# 3) Sichtbarer G1b-Jahreslauf (T-BENCH-03; 9 min)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1b/visual_year.tscn

# 4) Headless-Gates
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/g1b_suite.tscn

# 5) Screenshot-Smoke
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn

# Optional: Seed-Suche (kein Gate)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/seed_search.tscn
```

## 12. Abnahmebeurteilung Schritt 2

**Review-Ergebnis: Schritt 2 bestanden mit Notizen.**

- 29/29 G1a-Test-IDs (254 Checks), 7/7 Schritt-1-Test-IDs (81 Checks) und
  15/15 G1b-Test-IDs inkl. Schritt 2 (248 Checks) sind grün.
- Alterung, Rollen-/Schedule-Wechsel und Jobwechsel sind implementiert und
  getestet.
- Mortalität ist alters- und healthabhängig; die 1.000er-Kohorte erfüllt
  Mindestgeburten/-tode, Median und alle Zielverteilungen über 5 Seeds.
- Partnerschaft, Geburt, Tod und Haushaltsauflösung sind deterministisch,
  save-fähig und ohne Dangling-Referenzen.
- Das Featured-Jahr zeigt 2 Geburten und 2 Tode; 8 von 10 Startagenten und
  10 Agenten insgesamt leben am Jahresende.
- Der Featured Seed wurde dokumentiert gesucht (300 Seeds, **223 mit
  Geburten**, **47 mit Toden**, **37 Kandidaten** mit beidem und ≥ 50 %
  lebend); Seed 34 wurde wegen 2 Geburten, 2 Toden, erster Geburt/Tod an
  Lifecycle-Tag 20 (Anzeige Tag 21) und 8 überlebenden Startagenten gewählt.
- Save-Schema 3 ist exakt; Schema 1 und 2 werden sichtbar abgelehnt.
- 10 Agenten @50x: p95 5,45 ms ≤ 16 ms (Review-Lauf); kein Full-Agent-Sweep.
- Es wurden keine Schritt-3-Features implementiert.

## 13. Review-Verifikation (2026-11-13)

- G1a: **29/29**, 254 Checks; G1b: **15/15**, 248 Checks.
- Visuell: p95 **5,45 ms**, **215,4 FPS**, 666 Draw Calls.
- **Leak gefunden und behoben:** Der erste Benchmark meldete
  `1320 ObjectDB instances leaked`; Ursache war ein starker RefCounted-Zyklus
  `Simulation ↔ LifecycleSystem`. `LifecycleSystem` nutzt jetzt einen WeakRef
  wie `DecisionSystem`; der erneute Benchmark läuft ohne Leak-Warnung.
- Demografie: 46.082 Geburten / 4.990 Tode; Median 49; <40 29,2 %;
  70+ 16,2 %; 80+ 6,8 % — alle Zielbereiche erfüllt.
- 10-Agenten-Jahr (Seed 1337): 1 Geburt, 0 Tode, 11 lebend, Grain 171,
  140 Skips, A1-Health 92,4. Featured Seed 34: 2 Geburten/2 Tode, 10 lebend.
- Scope geprüft: keine Familienbaum-/Follow-/Alerts-/Chronik-/Replay-Systeme.

**Notizen für Schritt 3/G2:** Die 140 Mahlzeiten-Skips im Standardjahr sind
eine bewusste Anfangsknappheit, aber weiterhin ein Balance-Kandidat. Die
Demografie-Kohorte ist eine Lebenstafel der 1.000 Startagenten; Geburten werden
mit denselben Regeln gezählt, aber nicht als neue Kohortenmitglieder
weiterverfolgt. Das ist für die G1b-Kalibrierung ausreichend, ersetzt aber
keine G2-Bevölkerungsprojektion.
