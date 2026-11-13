# V3-Projektstruktur und Toolchain

Status: G0-Artefakt; G0.5-Umsetzung angelegt  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, D-20, D-22, D-24, D-30.  
G0.5-Stand: `project.godot`, `src/spike/`, `tests/spike/`, `bench/native/`
und `docs/g0.5/` existieren. Kein Gameplay, kein Git-Repo initialisiert.

## 1. Repository

- Frisches `V3/` mit eigenem Godot-Projekt und eigenem Git-Repo.
- Keine V1-/V2-Dateien importieren; keine Altlasten.
- Branch `main`; Gate-Tags `g0`, `g0.5`, `g1a`, `g1b`, `g2`, `g3`, `g4a`,
  `g4b`, `g5a`, `g5b`.
- Jeder Gate-Abschluss bekommt einen kurzen Bericht in `docs/gates/`.

## 2. Ordnerstruktur

```text
V3/
  project.godot
  docs/
    g0/
    gates/
    adr/
  src/
    kernel/
    world/
    agents/
    decisions/
    navigation/
    economy/
    politics/
    persistence/
    view/
    data/
  tests/
    unit/
    integration/
    determinism/
    golden/
  bench/
    scenarios/
    runners/
  data/
    species/
    jobs/
    buildings/
    items/
    recipes/
    cultures/
    names/
  assets/
    placeholder/
```

## 3. Godot und Sprache

- Godot 4.7.2 stable, Standard-Build (GDScript).
- GDScript zuerst; G0.5 misst GDScript plus einen **verpflichtenden,
  wegwerfbaren Native-Hotloop** (C#/GDExtension) außerhalb des V3-Projekts.
- Portentscheid am G0.5-Exit bindend für G1a; G2 bestätigt.
- Keine C#-Abhängigkeit im V3-Projekt vor dem Portentscheid.
- Keine Third-Party-ECS-/Test-Frameworks ohne dokumentierte Entscheidung.

## 4. Test-Runner

- Minimaler eigener Godot-Test-Runner; Szenen unter `tests/`.
- Headless: `godot --headless --path V3 --quit-after ... res://tests/...`.
- Externes PowerShell/Python-Harness für 3-Lauf-Messungen, Seeds, Warm-up,
  JSON/CSV-Output.
- Jeder Test endet mit eindeutigem OK-String und Exitcode 0.
- Keine Ad-hoc-Szenen als Abnahme.

## 5. Benchmark-Harness

- `bench/scenarios/` enthält Szenariodefinitionen (Seed, Last, Dauer, Kamera).
- `bench/runners/` startet 3 Läufe, sammelt Metriken, schreibt JSON/CSV.
- Rohdaten bleiben erhalten; keine geschätzten Werte.
- Zielhardware: Ryzen 5 5600, RTX 5060, Windows, 1920×1080.

## 6. Dokumentation

- `docs/g0/` enthält **nur Verweise/Checklisten, keine Kopien**; der Master
  bleibt `docs/v3-plan.md`.
- ADRs für: Zeitmodell, Agentenspeicher, Raummodell, Fidelity A/B,
  Sprache/Port, Persistenz, Chronik-Retention.
- Masterplan ist `docs/v3-plan.md` im V3-Root.
- V1-/V2-Dokumente sind Referenz, nicht V3-Wahrheit.

## 7. Namens- und Dateiregeln

- Dateien: `snake_case.gd`, Szenen `snake_case.tscn`.
- Klassen: `PascalCase`.
- Keine Datei über ~1.000 Zeilen; darüber nach Verantwortlichkeit teilen.
- Ein Zustandsbesitzer pro Fakt; keine stillen Kopien.
- Keine zyklischen Abhängigkeiten.
- Öffentliche APIs dokumentieren.

## 8. Git-Regeln

- Kleine Commits pro Arbeitspaket.
- Keine generierten Bench-/Save-Dateien committen.
- Keine Secrets/Assets ohne Lizenz.
- Gate-Tag erst nach vollständiger Abnahme.
- Kein Force-Push, keine History-Umschreibung.

## 9. Lokale Befehle (geplant)

```text
godot --headless --path V3 --quit-after 120 res://tests/unit/kernel.tscn
godot --headless --path V3 --quit-after 300 res://tests/integration/g1a.tscn
godot --headless --path V3 --quit-after 600 res://tests/determinism/g1a_runs.tscn
powershell -File bench/runners/run_g1a.ps1
```

## 10. Nicht-Ziele

- Kein CI-Cloud-Setup in G0.
- Keine Asset-Pipeline vor G1.
- Keine Netzwerk-/Serverstruktur vor G6.
- Keine V1-/V2-Imports.
