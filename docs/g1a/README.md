# G1a — Test- und Demoanleitung

Status: G1a und G1a.1 bestanden (2026-11-13); Commit folgt  
Siehe auch: `v3-g1a-report.md`

## Voraussetzungen

- Godot **4.7.2 stable**, Standard-Build (kein .NET).
- Projekt: `C:\coding\WimmelWorld\V3`.
- Empfohlene Auflösung: 1920 × 1080.

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
```

## 1. Projekt importieren

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 --import
```

## 2. Visuellen 10@50x-Benchmark ausführen (zuerst!)

Der Benchmark schreibt `res://bench/results/g1a_visual_result.json`. Die
Headless-Suite liest diese Datei für **T-UI-04** und **T-BENCH-02**.

```powershell
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn
```

Erwartung:

- `G1A_VISUAL_OK`, Exitcode 0
- 60-s-Messfenster nach 6 s Warm-up, VSync aus
- Gesamtframe **p95 ≤ 16 ms**, FPS ≥ 55

## 3. Headless-Gate ausführen

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn
```

Erwartung:

- 29/29 Test-IDs `PASS`, 224 Checks
- `G1A_SUITE results=29 passed=29 failed=0`
- `G1A_SUITE_OK`, Exitcode 0

Enthalten: T-KERN-01..04, T-STORE-01..03, T-NEED-01..04,
T-WORLD-01..03, T-MOVE-01..03, T-FOOD-01..03, T-SAVE-01..03,
T-UI-01..04, T-BENCH-01..02.

## 4. Sichtbare Demo

```powershell
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/demo.tscn
```

Oder ohne Szenenargument (Hauptszene):

```powershell
& $godot --path C:\coding\WimmelWorld\V3
```

Steuerung:

| Taste | Funktion |
|---|---|
| Linksklick | Agent auswählen/fokussieren |
| WASD / Pfeile | Kamera pan |
| Mausrad | Zoom |
| Mittlere Maustaste | Kamera ziehen |
| Leertaste | Pause |
| 1 / 2 / 3 | 1x / 10x / 50x |
| F5 | Speichern (`user://g1a_save.bin`) |
| F9 | Laden |

1x = 15 reale Minuten pro Sim-Tag; 50x = 18 reale Sekunden pro Sim-Tag.

## 5. Visueller Smoke-Screenshot

```powershell
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn
```

Schreibt `bench/results/g1a_demo.png` (Tag 1, 10:00, A1 ausgewählt) und
`bench/results/g1a_demo_night.png` (Tag 1, 22:00, Tag/Nacht-Smoke).

## 6. G0.5-Regression (Referenz unverändert)

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/unit_checks.tscn
```

Erwartung: `SPIKE_UNIT_OK`.

## 7. Rohdaten

`bench/results/` ist per `.gitignore` von Commits ausgenommen. Relevante lokale
Dateien nach einem Lauf:

- `g1a_visual_result.json` — Frame-/Draw-Call-/Sim-Tages-Messung
- `g1a_visual_calibrated.log`
- `g1a_suite_calibrated.log`
- `g1a_demo.png` — visueller Smoke (Tag)
- `g1a_demo_night.png` — Tag/Nacht-Smoke

## 8. Hinweise

- Die Suite darf nicht ohne vorherigen visuellen Benchmark als bestanden
  gelten: T-UI-04/T-BENCH-02 würden dann sichtbar fehlschlagen.
- Headless-Frame-Zeiten sind keine gültige FPS-Messung (Dummy-Renderer); die
  visuelle Messung ist separat.
- G1a.1-Kalibrierung: `energy_per_16h_awake` ist 60 statt 100. Im
  Seed-1337-Tag gibt es dadurch kein Routine-Nickerchen und 30/30 Mahlzeiten;
  die Grain-Bilanz endet bei 58. Die Spec-Tabelle bleibt unverändert, die Rate
  ist ein Kalibrierungsparameter (G1-Spec §5/§14).
- Saves aus der 100/16 h-Kalibrierung werden über den Config-Hash abgelehnt.
- Feldlabels zeigen kurze Namen plus ID (`Ar1`, `Cl3`, …); der selektierte
  Agent zeigt seinen vollen Namen. Nicht-selektierte Agenten werden nicht auf
  einen einzelnen Aktivitätsbuchstaben wie `A` gekürzt.
- G1a enthält bewusst keine G1b-/G2-Features. Details und Kalibriergrenzen
  stehen im Bericht.
