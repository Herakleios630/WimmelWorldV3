# G0.5 — Run-Kommandos (WimmelWorld V3)

Wegwerfbarer Technikspike. Kein Gameplay, keine UI, kein finales Save-Format.
Alle Pfade relativ zu `C:\coding\WimmelWorld\V3`.

## Voraussetzungen

- Godot 4.7.2 stable **Standard-Build** (GDScript, kein .NET-Build):
  `C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`
- .NET SDK 8.0 (nur für `bench/native`, **keine** Godot-.NET-Integration).
- Windows, Zielhardware Ryzen 5 5600 / RTX 5060.

Im Folgenden steht `$GODOT` für den Godot-Pfad oben.

## 1. Projekt einmalig importieren (Klassen-Cache)

```powershell
$GODOT --headless --path C:\coding\WimmelWorld\V3 --import
```

Exitcode 0. Nötig nach neuen `class_name`-Dateien; erzeugt `.godot/`.

## 2. Unit-/Smoke-Checks

```powershell
$GODOT --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/unit_checks.tscn
```

Erwartet: `SPIKE_UNIT_OK`, Exitcode 0.

## 3. Paritäts-Referenz (GDScript-Hashes)

```powershell
$GODOT --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/parity_ref.tscn
```

Erwartet: `PARITY_REF_OK`, Exitcode 0. Schreibt `bench/results/parity_ref.json`.

## 4. Native-Vergleich (C#-Konsolen-App)

```powershell
dotnet run -c Release --project C:\coding\WimmelWorld\V3\bench\native
```

Erwartet: `NATIVE_SPIKE_OK`, Exitcode 0. Schreibt
`bench/results/native_csharp.json`.

Wichtig: reine .NET-Konsole außerhalb Godots. Kein Godot-.NET-Build, keine
Interop-, GC- oder Engine-Kopplung gemessen.

## 5. Render-Spike

Headless (nur CPU-Instanzaufbau, **keine** GPU-Aussage):

```powershell
$GODOT --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/render_spike.tscn
```

Fenster 1920×1080, VSync aus, echte GPU (RTX 5060):

```powershell
$GODOT --path C:\coding\WimmelWorld\V3 --resolution 1920x1080 res://tests/spike/render_spike.tscn
```

Erwartet: `RENDER_SPIKE_OK`, Exitcode 0. Schreibt `render_cpu.json` bzw.
`render_window.json`. Headless nutzt den Dummy-Renderer: Frame-Zeiten und
Draw Calls dort sind **ungültig** für GPU-Abnahmen.

## 6. Gesamtlauf

```powershell
$GODOT --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/spike_all.tscn
```

Erwartet: `SPIKE_RUN_DONE ... checks_ok=true`, Exitcode 0 (2 = Check
fehlgeschlagen). Laufzeit ca. 25 s.

Einzelne Szenarien:

```powershell
$GODOT --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/spike_all.tscn -- --only=scheduler,soa
```

Erlaubte Namen: `scheduler`, `soa`, `needs`, `path`, `batch`, `save`, `repeat`,
`render`, `native`.

Reihenfolge: Schritte 2–5 vor Schritt 6, damit `spike_all` Render-, Native- und
Paritätsdaten zusammenführen kann.

## Ausgaben

`bench/results/` (nicht committen):

| Datei | Inhalt |
|---|---|
| `spike_results.json` | alle Kern-Szenarien, Meta, Checks |
| `scheduler.csv`, `soa.csv`, `path.csv`, `batch.csv`, `save.csv` | Tabellen des Gesamtlaufs |
| `render_cpu.json` | Instanzaufbau headless (keine GPU-Werte) |
| `render_window.json` | Fenster-Frames, Draw Calls, Primitive |
| `native_csharp.json` | C#-Scheduler/SoA, Paritäts-Hashes |
| `parity_ref.json` | GDScript-Referenz-Hashes |
| `spike_save_10000.bin`, `spike_save_100000.bin` | Wegwerf-Save des Durchsatz-Tests |

## Exitcodes

- `0`: Szenario/Check bestanden.
- `1`: Unit-Check fehlgeschlagen.
- `2`: `spike_all`-Check fehlgeschlagen (Details in `spike_results.json` → `checks`).

## Hinweise

- Kein `--quit-after` verwenden: die Szenen beenden sich selbst mit Code.
- Die Godot-Skripte schreiben absolute Pfade über
  `ProjectSettings.globalize_path("res://bench/results")`.
- Fensterläufe kurz halten; VSync ist im Render-Spike deaktiviert, FPS sind
  ungedrosselte Main-Loop-Werte, keine GPU-Budgetaussage.
