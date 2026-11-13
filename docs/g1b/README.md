# V3 G1b — Schritt 1

Status: **G1b Schritt 1 bestanden (Review 2026-11-13); Commit folgt**  
Bezug: `docs/v3-g1-spec.md`, `docs/v3-g1-workpackages.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`, `docs/g1a/v3-g1a-report.md`

## Inhalt

- `v3-g1b-step1-report.md` — Implementierungs-, Test- und Messbericht.

## Umfang Schritt 1

- Needs **Hygiene**, **Spaß** und der langsame Zustand **Gesundheit**.
- Inspector/HUD zeigen sechs Werte: Hunger, Energie, Sozial, Hygiene, Spaß,
  Gesundheit.
- Voller Feldzyklus
  `FALLOW → PLOWING → PLOWED → SOWING → SOWN → GROWING → RIPE → HARVESTING → FALLOW`
  mit fortschrittsbasierter Arbeit, Aussaat, Wachstum, Ernte, Kornspeicher und
  Jahresbilanz bei 30-Tage-Jahr.
- Save-Schema **2**; Schema-1-Saves werden sichtbar abgelehnt.

## Nicht in Schritt 1

- Keine Partnerschaft, Geburt, Tod, Alterung, Fertilität oder
  Haushaltsauflösung.
- Kein Familienbaum, Follow, Alerts, Story of the Day, Chronik-UI, Replay.
- Keine Wirtschaft/Politik/Tiere/Fantasy, kein A*/Pfad-Cache.

## Tests ausführen

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

# 1) Import
& $godot --headless --path C:\coding\WimmelWorld\V3 --import

# 2) Visuellen Benchmark zuerst (T-UI-04/T-BENCH-02 lesen sein JSON)
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn

# 3) G1a-Gate (29 Test-IDs)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn

# 4) G1b-Schritt-1-Gate (7 Test-IDs)
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/g1b_suite.tscn

# 5) Visueller Smoke-Screenshot
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn
```

## Erwartete Gates

```text
G1A_SUITE results=29 passed=29 failed=0 checks=252
G1A_SUITE_OK

G1B_SUITE results=7 passed=7 failed=0 checks=81
G1B_SUITE_OK
```

Zusätzlich bleibt der G0.5-Spike unverändert:

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/unit_checks.tscn
# SPIKE_UNIT_OK
```

## Mess-Kurzfassung (Seed 1337)

- 10 Agenten @50x visuell: **p95 5,07 ms**, **224,9 FPS**, 666 Draw Calls Ø.
- Ein Sim-Jahr (30 Tage): **4 Ernten**; Grain
  **60 + 880 − 769 = 171**; 260 Mahlzeiten-Skips in der Anfangsknappheit.
- Save Schema 2: **12.856 Bytes**, Save 0,94–1,01 ms, Load 6,9–8,0 ms
  (12:05 Tag 1).
- Feldzyklus über 3 Läufe identisch: `state 0xFD815445`,
  `event 0xDFC28328`.
