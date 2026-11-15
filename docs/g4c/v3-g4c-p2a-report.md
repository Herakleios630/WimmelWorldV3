# V3 G4c-P2.1a — Modularer Dorf-Designpass (100 Agenten)

Stand: 2026-11-15 · Timebox: 30 Minuten · Seed 421337 · 384×384, 1,5 m/Tile

## Umfang

P2.1a liefert den port-basierten Segment-Generator, das organische Dorf-Layout,
eigene Häuser aus Kenney-RPG-Base/RPG-Pack und vier Screenshots. Es wurden
**keine** Simulations-, Balance-, Save- oder G1–G4b-Dateien geändert. Kein
10k-/Suite-/Perf-Lauf.

## Segment-/Generator-Ansatz

- `tests/g4c_p2/segments.json`: 17 Segmenttypen mit Footprint, Road-Ports,
  Tags, Gewicht und Bedingungen (`square_well`, `road_straight/corner/t/cross`,
  `house_row`, `house_single`, `farmstead`, `workshop`, `granary`, `barn`,
  `field_cluster`, `pond`, `orchard`, `garden`, `trees`, `props`) sowie
  9 Hausvarianten (6×6 bis 8×7/8×8).
- `tests/g4c_p2/settlement_gen.gd`: deterministischer `RandomNumberGenerator`
  pro Siedlung. Baut Platz/Brunnen, eine gewundene Nord-Süd-Avenue, sechs
  gewundene Ost-West-Gassen, 24 Häuser mit Gärten/Zäunen, sechs 10×8-Felder,
  Werkstatt/Scheune/Kornspeicher, Teich mit Ufer, Obstgarten, 335 Bäume,
  Marktstände/Bänke/Fässer/Karren. Occupancy-Check verhindert Überlappung;
  Wall/Gate/Tower liegen nur als `wall_plan` vor (keine Mauer gebaut).
- Die Prefabs werden in `world_view_p2.gd` aus RPG-Base-Tiles komponiert
  (Wände/Dächer/Tür/Fenster/Schornstein), nicht als fertige Asset-Häuser.
  Das ist die P2.1a-Basis; `house_row`/`farmstead` sind als Port-Segmente
  deklariert, werden im ersten Layout aber als Einzelhäuser platziert.

## Layout / Häuser / Felder

- Zentraler Platz (18×14) mit Brunnen, Marktständen, Bänken; Wege 1–2 Tiles
  breit, kurvig und an den Platz angebunden.
- 24 Häuser, überwiegend nördlich der Gassen, mit 1-Tile-Tür, zwei/drei
  Fenstern, Schornstein und 3 warmen Dachfarben; 6–8 Tiles breit, 6–8 hoch.
  Gärten mit Zaun, Beeten und Blumen; einzelne Häuser als Nachbarschaft
  südlich des Platzes.
- 6 Feldparzellen (10×8) an den Rändern, wechselnde Phasen (Furche/Saat/
  Wachstum/Reife/Ernte), Hecken bzw. Zäune; Feldfarben derzeit noch
  schematisch.
- Teich mit Sandufer, Schilf; Obstgarten mit Zäunen; Werkstatt, Scheune,
  Kornspeicher am Platzrand; 335 Bäume als Lückenfüller.
- 100 Figuren (Demo-Viewer) laufen deterministisch auf dem Weg-Graphen,
  1,2× Figurengröße, Y-sortiert mit Häusern/Bäumen/Props. Tag-/Nacht- und
  Season-Tint über `day`/`season_index`; keine Sim-Kopplung.

## Screenshots

- `bench/results/g4c_p2_closeup.png` — Häuserzeile, Türen, Figuren, Gärten.
- `bench/results/g4c_p2_overview.png` — Dorfübersicht (Platz, Gassen, Felder,
  Teich, Werkstatt/Scheune/Kornspeicher).
- `bench/results/g4c_p2_fields.png` — Feldparzelle mit Hecke/Furchen.
- `bench/results/g4c_p2_night.png` — Nacht-Tint, Platz/Brunnen, beleuchtete
  Fenster (dezent).

Reproduktion (Godot 4.7.2, nach einmaligem `--import`):

```
Godot_v4.7.2-stable_win64_console.exe --path V3 res://tests/g4c_p2/screenshots.tscn
```

## Funktioniert / nicht

- Funktioniert: deterministisches Layout, 24 Häuser, 6 Felder, 100 Agenten,
  Platz/Brunnen, gewundene Wege, Teich/Ufer, Y-Sort, Tag/Nacht, keine
  fehlenden Texturen (Lauf ohne Asset-Fehler), 1-Tile-Türen, 1,2×-Figuren.
- Eingeschränkt: Dorf wirkt in der Übersicht noch locker/bandförmig; Gras
  ist flächig und wenig strukturiert; Feldfrüchte sind schematische Streifen;
  `house_row`/`farmstead`/`orchard` sind noch keine echten 16×16-Prefabs;
  Mauer nur Planung; 100 Agenten sind reine View-Läufer (kein Sim-
  Verhalten), bewusst zur Isolation des Designpasses.
- Nicht geprüft: G1–G4b-Suiten, 10k, Performance/Baseline (per Timebox
  ausgeschlossen). Keine Git-Commits.

## P2.1b

1. Echte 16×16-Prefabs für `house_row_a/b`, `farmstead`, `orchard`, `props`
   und Andocken über Ports statt Einzelplatzierung.
2. Häuserfronten/Dachschrägen, Türen mit Vordach, mehr Fensterdetails;
   Gassen mit Zäunen/Hecken und Bäumen dichter fassen.
3. Feldphasen als echte Kacheln/Saisonfarben, Bewässerung/Wege; 6. Feld in
   der Übersicht sicher einrahmen.
4. Gras-Varianten und Uferkanten verfeinern; Dorfkomposition verdichten.
5. Kurzer 100-Agenten-Smoke + finale P2-Screenshots; danach G4c-Regression.
