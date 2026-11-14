# G3 — B-Spike (deterministisches Tiering, 100k@150x/200x)

Status: **B-Spike messbar bestanden** (2026-11-14). Kein finales B, keine UI,
keine Kunst, keine Wirtschaft/Politik. A/Cursed Beyond und G1/G2 bleiben
unverändert.

## Zweck

Mess Spike für den Standalone-Zeitraffer-Modus **B**:

- 100.000 persistente Agentenrecords (SoA + kalte Felder), 200 Siedlungen,
  2.800 Kohorten.
- Deterministisches Detailtier **1.000/5.000** Agenten, Auswahl über stabile
  Hash-Rotation plus Ereignisnähe, Alter/Beziehungen, Reisen; **nicht** über
  Kamera/Sichtbarkeit.
- Hintergrund-Coarse pro Siedlung/Kohorte (täglich; Ehen/Jobwechsel wöchentlich).
- Individuelle Key-Events: Geburt, Tod, Ehe, Jobwechsel.
- Promotion/Demotion mit deterministischem Catch-up, kein Teleport.
- 150x (1 Sim-Tag in 6 s) und 200x (4,5 s).

## Schnellstart

```powershell
$GODOT = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

# B-Suite (18 Tests, ca. 2–3 Minuten)
& $GODOT --headless --path V3 "res://tests/g3/g3_suite.tscn"

# Vollbenchmark (4 Szenarien x 3 Läufe, ca. 2 Minuten)
& $GODOT --headless --path V3 "res://tests/g3/bench_b.tscn"
```

Der Benchmark schreibt `bench/results/g3_b_spike_results.json` (lokal,
gitignored). Fehlt die Datei, fährt die Suite eine kompakte Live-Messung als
Fallback.

## Ergebnis (Headless, Ryzen 5 5600, Godot 4.7.2)

| Szenario | Events/Frame | Frame p95 | Frame p99 | Sim-Budget p95 |
|---|---:|---:|---:|---:|
| 1k @150x | 41,3 | 3,25 ms | 4,15 ms | 19,5 % |
| 5k @150x | 195,3 | 6,95 ms | 8,17 ms | 41,7 % |
| 1k @200x | 55,0 | 3,63 ms | 4,88 ms | 21,8 % |
| 5k @200x | 260,4 | 8,99 ms | 10,73 ms | 53,9 % |

- 100k laufen bei 150x und 200x innerhalb des 16,67-ms-Sim-Frames.
- Save/Load: ca. 14,0–14,2 MB, 24–26 ms Save, 35–38 ms Load, exakt.
- Determinismus: 3 Läufe je Szenario identisch; Chunks 1/60/3600 identisch.
- Key-Events (4 Sim-Tage): 157 Geburten, 345 Tode, 285 Ehen, 246 Jobwechsel,
  keine verlorenen Identitäten.
- Kein Leak: wiederholter Aufbau/Abbau, Speicher-Delta 0 Bytes.
- G1a 29/29, G1b 28/28, G2 21/21, G3 18/18.

Details, Grenzen und Empfehlung: `v3-g3-b-spike-report.md`.

## Dateien

- Produktion: `src/lod/b_hash.gd`, `b_config.gd`, `b_kinds.gd`,
  `b_records.gd`, `b_key_log.gd`, `b_tier_selector.gd`, `b_detail.gd`,
  `b_background.gd`, `b_metrics.gd`, `b_sim.gd`, `b_save.gd`.
- Tests: `tests/g3/` (Suite, Einzeltests, Benchmark, Utility).
- Doku: dieser README und `v3-g3-b-spike-report.md`.

## Nicht-Ziele

Kein finales B, keine UI/A Kunst, keine Wirtschaft/Politik, keine Änderung an
A/Cursed Beyond, G0-Dokumenten, `README.md` oder `docs/v3-plan.md`, keine
Git-Commits/Pushes.
