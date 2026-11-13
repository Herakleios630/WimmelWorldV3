# V3 G1b — Schritt 1 und Schritt 2

Status: **G1b Schritt 1 und Schritt 2 bestanden (Review 2026-11-13); Schritt 3
offen; Commit folgt**  
Bezug: `docs/v3-g1-spec.md`, `docs/v3-g1-workpackages.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`,
`docs/g1a/v3-g1a-report.md`

## Inhalt

- `v3-g1b-step1-report.md` — Needs, Gesundheit, voller Feldzyklus.
- `v3-g1b-step2-report.md` — Lebenszyklus, Demografie, Haushaltsauflösung.

## Umfang Schritt 1

- Needs **Hygiene**, **Spaß** und der langsame Zustand **Gesundheit**.
- Inspector/HUD zeigen sechs Werte: Hunger, Energie, Sozial, Hygiene, Spaß,
  Gesundheit.
- Voller Feldzyklus
  `FALLOW → PLOWING → PLOWED → SOWING → SOWN → GROWING → RIPE → HARVESTING → FALLOW`
  mit fortschrittsbasierter Arbeit, Aussaat, Wachstum, Ernte, Kornspeicher und
  Jahresbilanz bei 30-Tage-Jahr.
- Save-Schema **2**; Schema-1-Saves werden sichtbar abgelehnt.

## Umfang Schritt 2

- Alterung: Kind 0–12, Jugend 13–17, Erwachsen 18–59, Alt 60+; Geburtstage,
  Rollen- und Schedule-/Jobwechsel.
- Alters- und healthabhängige Sterblichkeit; Tod setzt `alive=0`, Cold-Record
  bleibt, stale Scheduler-Wakes werden ignoriert.
- Deterministische Partnerschaft unter lebenden Erwachsenen; bestehende
  Partner bleiben.
- Schwangerschaft, Geburt, Geburtsrisiko und neuer Agent mit Eltern/Haushalt.
- Haushaltsauflösung: Minderjährige zu verwandtem Haushalt, sonst Archiv und
  expliziter Nicht-Haushalt (0); keine Dangling-Referenzen.
- 1.000-Agenten-Demografie-Kohorte (100 Jahre, 5 Seeds) mit denselben
  Lifecycle-/Fertilitätsfunktionen wie die Hauptsimulation.
- Save-Schema **3**; Schema 1 und 2 werden sichtbar abgelehnt.
- Visueller 1-Jahres-Lauf mit **Featured Seed 34** (mindestens eine Geburt und
  ein Tod, ≥ 50 % lebend).

## Nicht in Schritt 2

- Kein Familienbaum, Follow, Alerts, Story of the Day, Chronik-UI, Replay.
- Keine Krankheit/Gewalt/Kriege/Tiere/Fantasy/Wirtschaft/Politik.
- Keine A*-/Pfad-Cache-Abhängigkeit.

## Tests ausführen

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

# 1) Import
& $godot --headless --path C:\coding\WimmelWorld\V3 --import

# 2) Visuellen G1a-Benchmark zuerst (T-UI-04/T-BENCH-02 lesen sein JSON)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn

# 3) Visuellen G1b-Jahreslauf (9 min; T-BENCH-03 liest sein JSON)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1b/visual_year.tscn

# 4) G1a-Gate (29 Test-IDs)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn

# 5) G1b-Gate (Schritt 1 + Schritt 2; 15 Test-IDs)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/g1b_suite.tscn

# 6) Visueller Smoke-Screenshot
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn

# Optional: Seed-Suche (kein Gate)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/seed_search.tscn
```

## Erwartete Gates

```text
G1A_SUITE results=29 passed=29 failed=0 checks=254
G1A_SUITE_OK

G1B_SUITE results=15 passed=15 failed=0 checks=248
G1B_SUITE_OK
```

Zusätzlich bleibt der G0.5-Spike unverändert:

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/unit_checks.tscn
# SPIKE_UNIT_OK
```

## Mess-Kurzfassung

### Schritt 1 (Seed 1337)

- 10 Agenten @50x visuell: **p95 5,07 ms**, **224,9 FPS**, 666 Draw Calls Ø.
- Ein Sim-Jahr (30 Tage): **4 Ernten**; Grain
  **60 + 880 − 769 = 171**; 260 Mahlzeiten-Skips in der Anfangsknappheit.
- Save Schema 2: **12.856 Bytes**.

### Schritt 2 (Seed 1337 / Featured Seed 34)

- Ein Sim-Jahr (Seed 1337): Startgrain **120**, 4 Ernten, Grain
  **120 + 880 − 828 = 172** (Endbestand 171 nach Jahresabschluss),
  **140** Mahlzeiten-Skips, A1-Gesundheit **92,4**, 1 Geburt, 0 Tode,
  11 Lebende.
- Demografie: 5 Seeds × 1.000 Agenten × 100 Jahre =
  **46.082 Geburten**, **4.990 Tode**, Median **49,0**,
  29,2 % vor 40, 16,2 % erreichen 70, 6,8 % erreichen 80.
- Featured Seed 34: **2 Geburten, 2 Tode, 8/10 Startagenten leben**,
  10 Lebende insgesamt; erste Geburt und erster Tod an Lifecycle-Tag 20
  (Anzeige Tag 21 00:00); Grain 182,
  ID 8 Gustav (Spec-A5) Gesundheit 80,1.
- Visueller Jahreslauf @50x: 30,000 Sim-Tage in 540,0 s,
  **p95 5,106 ms**, **224,2 FPS**, 665,3 Draw Calls Ø, max. 285,9 ms
  (Screenshot-Hitch; ohne Capture max. 10,6 ms im G1a-Bench).
- G1a-Bench @50x: **p95 5,086 ms**, **225,1 FPS**, 666,0 Draw Calls Ø,
  max. 10,641 ms.
- Save Schema 3: **13.506 Bytes**, Save **1,01 ms**, Load **7,77 ms**
  (Seed 1337, Tag 1 12:05).
