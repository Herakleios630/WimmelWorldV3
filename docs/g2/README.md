# V3 G2 — 100-Agenten-Bauerschaft

Status: G2 bestanden (Review 2026-11-14); G3 bereit  
Bezug: `docs/g2/v3-g2-spec.md`, `docs/v3-architecture.md`,
`docs/v3-data-model.md`, `docs/v3-benchmark.md`.

## Umfang

G2 skaliert den bestandenen G1b-Kern auf **100 Agenten in 24 Haushalten** in
einer deterministischen **384 × 384-Tile-Bauerschaft** (576 × 576 m). Enthalten
sind:

- deterministischer Welt-/Bevölkerungsgenerator,
- lokaler A* auf Tiles mit LRU-Pfad-Cache, Map-Version und Frame-Budget,
- Event-Batching mit stabiler `(time, seq)`-Ordnung,
- 30-Sim-Tage-Determinismus (3 Läufe),
- Save-Schema **5**, exaktes Save/Load, Replay aus Seed + Config + Snapshot,
- skalierte G1-UI (Inspector, Event-Log, Chronik, Familienbaum, Follow,
  Alerts, Story of the Day),
- D-57 nur als Platzhalter ohne Events/Zustand/Verbraucher/Produktion.

Nicht enthalten: G3 (1.000 Agenten), Wirtschaft/Politik/Handel, D-57-Simulation,
Lesezeichen/Sammlungen/Zeitleiste/Nationen-Chronik.

## Startbefehle

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path C:\coding\WimmelWorld\V3 --import
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g2/demo.tscn
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g2/g2_suite.tscn
```

Visuelle Abnahme:

```powershell
# 5-Minuten-Performancefenster, dreimal:
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g2/bench_visual.tscn -- --run=1
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g2/bench_visual.tscn -- --run=2
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g2/bench_visual.tscn -- --run=3

# Sichtbarer 30-Sim-Tage-Lauf bei 50x (ca. 9 Minuten):
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g2/visual_30days.tscn
```

Ergebnisse: `bench/results/g2_visual_run1..3.json`,
`bench/results/g2_30days_result.json`,
`bench/results/g2_30days_day01.png`, `..._day15.png`, `..._day30.png`.

## Test-IDs

T-G2-01 Welt-/Bevölkerungsgeneration, T-G2-02 A*/Pfad-Cache/Occupancy,
T-G2-03 Event-Batching/Ordnung, T-G2-04 30-Tage-Determinismus,
T-G2-05 Save/Load Schema 5, T-G2-06 Performance 100@50x,
T-G2-07 UI/Inspector/Chronik, T-G2-08 D-57-Stubs/keine G3-Features.
Die G1a-/G1b-IDs bleiben grün.

## Dokumente

- `docs/g2/v3-g2-spec.md` — Spezifikation
- `docs/g2/v3-g2-report.md` — Implementierungs- und Messbericht
