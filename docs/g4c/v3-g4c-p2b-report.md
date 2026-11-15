# V3 G4c-P2.1b — Kompaktes Ringdorf, House-Rows und Farmsteads

Stand: 2026-11-15 · Timebox: 30 Minuten · Seed 421337 · 176×176, 1,5 m/Tile

## Ergebnis

P2.1b verdichtet das Dorf zu einem kompakten Oval-/Ring-Kern um Platz und
Brunnen. Es gibt **8 echte 16×16-House-Rows mit je 3 Häusern (24 Häuser)**,
**3 Farmsteads mit je 2 Feldparzellen (6 Felder)**, geclusterte Vegetation und
neue Screenshots. Keine Simulation, kein Save, keine Balance, keine
G1–G4b-Dateien geändert. Kein Git-Commit.

## Geänderte Dateien

- `tests/g4c_p2/settlement_gen.gd` — neues kompaktes Layout (176²), Ringstraße,
  Gassen, House-Row-Slots, Farmsteads, Feldzufahrten, Obstgärten, Baumcluster.
- `tests/g4c_p2/world_view_p2.gd` — 16×16-Row-/Farmstead-Prefabs, ovale
  Platzfläche, Palette, Grasbüschel, Hof-/Felddetails, Y-Sort für Prefabs.
- `tests/g4c_p2/segments.json` — 12 Hausvarianten (5×6/5×7, Farmhaus 6×7),
  drei Wand-/Dachfamilien.
- `tests/g4c_p2/demo_main.gd` — Kamera/Startwerte, HUD-Titel und P2.1b-Log.
- `tests/g4c_p2/screenshot_runner.gd` — vier P2.1b-Screenshots.
- `bench/results/g4c_p2b_*.png` — neue Screenshots.
- `docs/g4c/v3-g4c-p2b-report.md` — dieser Report.

## Layout / Generator

- Welt 176×176 statt 384; Dorfkern ca. 108×92 Tiles, Gesamtfootprint inkl.
  Felder/Höfe ca. 126×140 Tiles.
- Zentraler Platz als **Ellipse** (16×12) mit Brunnen, Marktständen, Bänken;
  keine rechteckige Slab-Fläche mehr.
- Gewundene Ringstraße (Ellipse mit Wobble), zwei Kreuzstraßen, drei
  Ost-West-Gassen; alle Wege sind angebunden.
- **8 House-Row-Slots** (16×16) in zwei Bändern nördlich/südlich des Platzes,
  je 3 Häuser à 5 Tiles Breite, 6–7 Tiles hoch, 1-Tile-Türen, gemeinsamer
  Vorgarten mit Zaun und Torlücken. 2–3 Dachfarben je Zeile, drei
  Wandfamilien über das Dorf verteilt.
- **3 Farmsteads** (16×16, Nord/Ost/Süd) mit Farmhaus, Scheune, gepflastertem
  Hof, Karren/Fass/Holzstapel und eigener Zufahrt; je 2 Felder direkt am Hof.
- **6 Feldparzellen** (10×8) an den Dorfrändern, Hecken oder Zäune,
  Erdraine und Zufahrten; alle sechs im Übersichtsbild.
- Werkstatt und Kornspeicher flankieren den Platz; Teich mit Sandufer und
  Stichweg im Westen; Wall/Gate/Tower bleiben reine Planung.

Reproduktion:

```
Godot_v4.7.2-stable_win64_console.exe --path V3 res://tests/g4c_p2/screenshots.tscn
```

## Vegetation / Felder / House-Rows

- **158 Bäume**, verteilt auf 3 Obstgärten (mit Zäunen und Fruchtpunkten) und
  6 Baumcluster/Wäldchen; zusätzlich Einzelbäume an Gassen und Platzrändern.
  Keine gleichmäßige Streuung mehr.
- Feldfarben entsättigt, Furchen/Crop-Reihen mit Erd-/Feuchtflecken; Hecken
  als runde Kante, Zäune an Alternativparzellen.
- House-Rows werden in der View als **ein 16×16-Bild** aus den drei
  Haus-Texturen komponiert; Farmsteads ebenso aus Farmhaus + Scheune.
  Beide werden als Prefab y-sortiert.
- Gras: entsättigte Grundtextur plus deterministische Grasbüschel/Moosflecken.
- Wege dunkler/wärmer, Wasser mit Sandufer, Schilf und Uferkante.

## Screenshots / visuelle Bewertung

- `bench/results/g4c_p2b_overview.png` — kompaktes Oval, alle 6 Felder, 3 Höfe,
  Ringstraße, geclusterte Bäume; keine bandförmige Übersicht.
- `bench/results/g4c_p2b_plaza.png` — Platz mit Brunnen/Markt, flankierende
  Werkstatt/Kornspeicher, House-Rows mit Türen, Fenstern, Gärten, Figuren.
- `bench/results/g4c_p2b_fields.png` — Nordhof mit Farmhaus, Scheune, Hof,
  zwei Feldern, Hecken/Zäunen und Zufahrten.
- `bench/results/g4c_p2b_night.png` — Nacht-Tint, Y-Sort, Fensterlichter,
  Platz und House-Rows lesbar.

Bewertung: Das Dorf ist deutlich kompakter und nicht mehr bandförmig; alle
Felder sind im Bild. Der Platz ist kleiner, wirkt durch die Tile-Rasterung
aber noch leicht treppig. Hof- und Feldflächen sind funktional, aber noch
schematisch (Stroh/Furchen statt echter Detailkacheln). Die House-Rows lesen
sich als Wohnzeilen; die 5-Tile-Häuser sind bewusst kompakt für 3 Häuser je
16×16-Prefab.

## Tests / Timebox

- Nur P2-Demo/Screenshot-Szenen; **keine G1–G4b-/G3-/G4a-Suiten, kein 10k,
  kein Perf-/Baseline-Lauf**. Kein `--import` nötig.
- Lauf: `houses=24 rows=8 farms=3 fields=6 roads=1904 trees=158 civic=2`;
  vier Screenshots mit `err=0`, keine fehlenden Texturen.
- 100 Agenten laufen als View-Figuren weiter auf dem Weg-Graphen; Tag/Nacht,
  Season-Tint und Y-Sort funktionieren.
- Jeder Befehl unter 120 s; Timebox eingehalten.

## Offen / nächster Schritt

1. Platzrand als Autotile/weiche Kante statt Tile-Treppe; evtl. Platz noch
   etwas kleiner und mit Beeten/Ständen weiter füllen.
2. Feldphasen und Jahreszeiten pro Parzelle koppeln (aktuell nur Stage-Farben
   der View); echte Pflug-/Saat-/Ernte-Kacheln.
3. Farmstead-Höfe detaillieren (Heu, Zaunsegmente, Scheuneninhalt), evtl.
   zwei Farmstead-Varianten.
4. House-Rows mit 6-Tile-Häusern oder versetzten Fronten variieren.
5. Finaler P2-Abschluss mit kurzem 100-Agenten-Smoke; danach G4c-Regression
   (nicht Teil dieser Timebox).
