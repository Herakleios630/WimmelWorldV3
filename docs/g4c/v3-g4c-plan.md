# V3 G4c — Visual- und Startup-Zwischenschritt vor G5

Status: Planungsentwurf, keine Implementierung  
Stand: 2026-11-15  
Bezug: `docs/g4/v3-g4a-report.md`, `docs/g4/v3-g4b-report.md`,
`docs/v3-fidelity.md`, D-65..D-68.

## 1. Befund: Warum `visual_b` „ewig“ startet

- `tests/g4/visual_b.gd` erzeugt in `_ready` eine 10k-G4b-Simulation,
  prewarnt Pfade und ruft `G4BTestUtil.advance_chunked(sim, day 55, 3600)`
  **synchron** auf.
- Erst danach werden `WorldView`, Kamera, HUD und Panels erzeugt; der erste
  Frame erscheint also erst nach der 55-Tage-Vorsimulation. Godot zeigt
  währenddessen den Startbildschirm, ohne Fortschritt.
- Danach läuft ein 16-Tage-Fenster bei 50x (ca. 288 s) und der Prozess
  beendet sich; `_elapsed > 900` ist nur ein Fallback.
- `visual_b` ist ein **Benchmark/Smoke**, keine spielbare Demo.
- Die drei PowerShell-Befehle sind **sequenziell**: `visual_b` blockiert,
  bis es beendet ist; die 42-Minuten-G4b-Suite und die G3-Demo starten erst
  danach. Die G3-Demo allein startet in ca. 15 s inkl. 10 s Laufzeit.
- Steady-State-Performance ist gut (G4b p95 12,5 ms, p99 ≤18 ms); das
  Problem ist **Startup/Pre-Sim/Prewarm und Benchmark-UX**, nicht die
  laufende Simulation.

## 2. G4c-Ziel

G4c ist ein formaler Zwischenschritt vor G5, **kein neues Simulationsgate**:

### G4c-A — Startup, Loading, Demo
- Erster sichtbarer Frame < **2 s**; interaktiv < **5 s** bei 10k.
- Keine synchrone 55-Tage-Vorsimulation im `_ready`.
- Loading-Screen/Fortschritt für Weltgenerierung, Prewarm und optionalen
  Vorlauf; Arbeit über Frames/Threads verteilt.
- Benchmarks starten aus einem Save-Snapshot (G4b-Load ~1,1 s) oder einem
  kleinen Vorlauf, nicht aus 55 Tagen.
- Neue **spielbare G4c-Demo** (`tests/g4c/demo.tscn`): 10k-G4b-Welt,
  Kamera, Inspector, Chronik, Wirtschaft/Politik-Panels, Follow; kein
  Benchmark.
- Benchmarks bleiben separat und zeigen Fortschritt/Status.

### G4c-B — Visual-Pass
- Kenney-CC0-Packs als primäre Asset-Basis; 16x16-Tiles bleiben.
- Welt: Terrain, Gebäude, Felder, Wege, Props aus einem konsistenten Set.
- Figuren: lesbare Sprites statt Rechteck-Figuren; Aktivität, Auswahl,
  Namen bei Hover/Zoom, Schatten.
- Tageszeit/Seasons weiter über Tint; später Temperatur/Niederschlag.
- UI: weniger Überlappung, pixelige Panels, klare Priorität (Welt > Inspector
  > Chronik/Alerts), Zoom-/LOD-Regeln.
- Performance: 10k@50x p95/p99 nicht schlechter; keine Per-Agent-Nodes für
  unsichtbare Agenten; MultiMesh/Chunk-Renderer.

### G4c-Abnahme
- Startup-Budget eingehalten; Demo sichtbar/interaktiv.
- 10k@50x p95 ≤ 16 ms, p99 ≤ 20 ms; 3 Läufe.
- Screenshots Tag/Nacht/Season; Figuren lesbar; UI nicht überlappend.
- Keine Simulation-/Balance-/Fidelity-Änderung; G1–G4b-Suiten grün.
- Tag `g4c`.

## 3. Asset-Recherche (Kenney, CC0)

| Pack | Inhalt | Größe/Status | G4c-Rolle |
|---|---|---|---|
| Roguelike/RPG Pack | 1700 Assets: Tiles, Town, Furniture, UI | **16×16**, CC0 | Primäre Welt/Props/UI |
| Roguelike Characters | 450 Charakter-Sprites | CC0; Größe prüfen (vermutlich 16×16) | Primäre Figuren |
| RPG Base | 230 Tiles/Basis | CC0; Größe prüfen | Outdoor-Basis/Ergänzung |
| Tiny Farm | 130 Farm-Assets | **16×16**, CC0 | Felder, Pflanzen, Farm-Props |
| Tiny Town | 130 Town-Assets | **16×16**, CC0 | Häuser, Town-Props |
| Tiny Dungeon | 130 Dungeon-Assets | **16×16**, CC0 | Keller/Innenräume später |
| Medieval RTS | 120 Buildings/Units | CC0; Größe prüfen (vermutlich größer) | Nur falls stilistisch/maßstäblich passend |
| Map Pack | Overworld-Karten | CC0; Größe prüfen | Regionale Karte, nicht lokal |

**Stilrisiko:** Mehrere Kenney-Packs haben unterschiedliche Paletten/Outlines.
G4c braucht ein **Primärset** plus klar begrenzte Ergänzungen, keinen
unkoordinierten Mix. `Tiny Farm/Town` sind niedlich und einfach;
`Roguelike/RPG Pack` + `Roguelike Characters` wirken klassischer/RPG-näher
und passen besser zu „V1-Figuren, aber besser lesbar“.

## 4. Figurenmaßstab

- Aktuell: 1,5 m/Tile, 16 px/Tile, Figuren ~19–20 px.
- **Option A:** 16×16-Charaktere bei 1,5 m/Tile = 1 Tile = 1,5 m; V1-nah
  (V1: 2×8 px bei 8 px/Tile), sehr lesbar, aber etwas kurz.
- **Option B:** 16×24- oder 20-px-Figuren = 1,5 Tiles = 2,25 m; menschlicher,
  braucht aber passende Sprites/Scale.
- **Option C:** 32-px-Tiles/größere Figuren; bricht den bisherigen Maßstab
  und die 10k-Renderkosten.
- **Option D:** aktuelle Vektor-Figuren verbessern, keine Sprites.

## 5. Entschieden (2026-11-15)

1. **Reihenfolge:** Startup/Demo zuerst; keine Tages-Vorsimulation. G4c räumt
   Startup, Loading und die Demo auf; der Visual-Pass folgt in G4c.
2. **Primärset:** Roguelike/RPG Pack + Roguelike Characters + RPG Base.
   Tiny Farm/Town nur als optionale Props; Medieval RTS vorerst nicht
   (größerer/anderer Maßstab).
3. **Figurenmaßstab:** 16×16 bei 1,5 m/Tile (1 Tile ≈ 1,5 m), V1-nahe
   Proportion.
4. **Animation:** statische Sprites + Bob/Walk-Bob, Schatten,
   Aktivitätsmarker, Auswahl; keine 4-Richtungs-Walks in G4c.
5. **Demo vs. Benchmark:** neue spielbare `tests/g4c/demo.tscn`; Benchmarks
   separat und mit Fortschritt; `visual_b` bleibt Benchmark.
6. **Startup-Budget:** erster Frame <2 s, interaktiv <5 s; kein Presim.
7. **UI:** Kenney-UI (RPG-Pack) + bestehende Panels; weniger Überlappung,
   klare Priorität.
8. **Lizenz:** CC0; `ASSETS.md` mit Quellen, Versionen und Lizenz anlegen.
9. **Demo-Start:** **Tag 1, Frühling**; kein vorbereiteter Save.
10. **Startweg:** **Nur Seed + Loading-Screen**; Welt/Prewarm inkrementell
    aufbauen, kein 55-Tage-Presim, kein Demo-Snapshot.
11. **Kein Godot-Startbildschirm:** Boot-Splash-Bild deaktivieren; eigener
    Platzhalter-Startbildschirm (Titel, Status, animierter Ladebalken) bis
    die Welt fertig ist, danach Demo.
12. **Asset-Umfang:** nur **RPG-Pack + Roguelike Characters + RPG Base**;
    Tiny Farm/Town/Dungeon und Medieval RTS werden in G4c nicht importiert.

### G4c-A/B-Schnitt

- **G4c-A:** Startbildschirm, Loading, inkrementelle 10k-Generierung, echte
  Demo mit aktueller Optik, Benchmark-Trennung, Startup-Messung.
- **G4c-B:** Kenney-Assets, Figuren/Tiles/UI, Render-LOD, Screenshots.
- `g4c` wird erst nach G4c-B getaggt; G4c-A ist ein Zwischenstand.

## 6. Umsetzungsplan G4c

### G4c-A — Startup/Demo
- [ ] Kein Presim, kein Demo-Snapshot: 10k-Welt aus Seed 1337, Start Tag 1.
- [ ] Godot-Boot-Splash-Bild aus; eigener Startbildschirm mit Titel,
      Status und animiertem Ladebalken.
- [ ] Loading-Screen/Fortschritt: erste Frame <2 s, interaktiv <5 s.
- [ ] Welt-/Population-/Prewarm-Aufbau inkrementell (Frames/Threads), nicht
      blockierend in `_ready`; Fortschritt pro Stage.
- [ ] `tests/g4c/demo.tscn`: 10k-Welt, Kamera, Inspector, Chronik,
      Wirtschaft/Politik-Panels, Follow; keine Benchmark-Logik.
- [ ] `visual_b` ohne 55-Tage-Presim; Start Tag 1, kurzer Warm-up, Status.
- [ ] Cold-/Warm-Start-Messung dokumentieren; bei >5 s Optimierung oder
      begründete Budgetanpassung.

### G4c-B — Visual-Pass
- [ ] `assets/kenney/` mit RPG-Pack, Characters, RPG Base; Lizenzen.
- [ ] Tile-/Building-/Prop-Mapping (16×16, 1 px Margin).
- [ ] Figuren-Sprites (16×16) + Schatten, Bob, Auswahl, Aktivitätsmarker,
      Namen bei Hover/Zoom.
- [ ] Chunk-/Visible-only-Rendering; kein Per-Agent-Node für unsichtbare
      Agenten; Far-Zoom-Marker.
- [ ] UI-Panels aus Kenney-UI; Layout bei 1920×1080 ohne Überlappung.
- [ ] Screenshots Tag/Nacht/Season; Figuren lesbar.

## 7. Tests/Abnahme

- T-G4c-01 Startup: kein Godot-Splash-Bild; eigener Startbildschirm
  sichtbar, erster Frame <2 s, interaktiv <5 s.
- T-G4c-02 Seed-Start 10k: Ladebalken/Progress, keine 55-Tage-Presim, kein
  Snapshot.
- T-G4c-03 Demo: 10k-Welt sichtbar, Kamera/Inspector/Chronik/Panels/Follow.
- T-G4c-04 Assets: Tiles/Buildings/Characters gemappt, keine fehlenden
  Texturen; Figuren lesbar.
- T-G4c-05 10k@50x: p95 ≤16 ms, p99 ≤20 ms, 3 Läufe.
- T-G4c-06 UI: kein Overlap bei 1920×1080; Panels bedienbar.
- T-G4c-07 Benchmark/Demo getrennt; `visual_b` startet aus Snapshot.
- T-G4c-08 Regression: G1a/G1b/G2/G3/G4a/G4b grün; keine Sim-/Balance-
  Änderung.
- T-G4c-09 Kein Leak; Save/Load unverändert.
- T-G4c-10 Review + Tag `g4c`.

## 8. Keine offenen Grundsatzfragen

Alle G4c-Grundsatzentscheidungen sind getroffen. Offen sind nur Messwerte und
die konkrete Asset-Zuordnung (welche RPG-Pack-Tiles für Gras/Dirt/Wege/Felder/
Häuser), die im G4c-Report dokumentiert wird.

## 9. Verifizierte Asset-Fakten

- Roguelike/RPG Pack: 16×16, 1 px Margin, 1700 Assets, CC0.
- Roguelike Characters: 16×16, 1 px Margin, 450 Assets, CC0.
- RPG Base: 16×16-Design, Einzel-PNGs 64×64 (4×), Sheet 1280×832, CC0.
- Tiny Farm/Town/Dungeon: 16×16, CC0 (nur optionale Props).
- Medieval RTS: CC0, Maßstab/Style noch nicht bestätigt; vorerst außen vor.
- Downloads über Kenney-Signed-Link verifiziert; Pakete lokal geprüft.
