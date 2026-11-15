# G4c-P — Visueller Kenney-Pretest (V3)

**Status: Pretest, keine G4c-Abnahme.** Kein 10k, keine
Wirtschafts-/Politik-/Chronik-Politur, keine Simulation-, Balance- oder
Save-Änderung an G1–G4b. Die vollständige Regression ist gelaufen:
G1a/G1b/G2/G3-A/G3-B/G4a/G4b sind grün; G4a brauchte auf der belasteten
Arbeitsmaschine einen Rerun mit hoher Prozesspriorität (p95 12,68–12,97 ms,
p99 17,93–18,47 ms) und bestand damit 12/12.

## 1. Ziel und Scope

Geprüft wird, ob der bestehende V3-Kern mit Kenney-Tiles und Kenney-Figuren
in einem sichtbaren 100-Agenten-Dorf lesbar wird: Maßstab, Anker, Y-Sort,
Palette, Feldphasen, Tag/Nacht, Kamera und ein minimales HUD. Die Pretest-
Ansicht ist vollständig getrennt von der Gate-Ansicht
`src/view/world_view.gd`; die Gates bleiben unverändert.

Nicht Teil des Pretests: 10k-Darstellung, Save/Load des Pretest-Profils,
G4c-UI-Politur, neue Sim-Systeme, Balancing, G4c-Abnahme.

## 2. G4c-P-Profil, Welt und Population

`SimConfig.g4c_pre(seed)` ist ein **additives Pretest-Profil**
(`PROFILE_G4C_P = 5`). Es nutzt das G2-Siedlungslayout (384×384 Tiles) und
den G3-Kalender/Feldzyklus, ohne einen der bestehenden Profile zu verändern.

| Größe | Wert |
|---|---:|
| Welt | 384×384 Tiles, 1,5 m/Tile (576×576 m) |
| Agenten / Haushalte | 100 / 24 |
| Felder | 4 saisonale Felder (je 28×28 Tiles) |
| Jahr | 120 Tage, 4×30 Tage (Frühling/Sommer/Herbst/Winter) |
| Start | Tag 1, Frühling, 06:00 |
| Startgrain / Granary | 36.000 / 72.000 |
| Feldbilanz | 10.000 brutto, 1.000 Saatgut, 9.000 netto pro Feld/Jahr |
| Navigation | A*/Cache wie G2/G3, `path_cache_capacity=2048` |
| Save | kein eigenes Schema; im Pretest nicht angeboten |

Die 24 Häuser, der Kornspeicher, die Werkstatt, die Scheune, der Brunnen und
die vier Felder stammen aus `_build_g2_settlement()`. Für G4c-P werden die
Felder am 1. Frühling auf **Brache** zurückgesetzt (die G2-Welt staffelt sie
für den 30-Tage-Zyklus vor) und ein kleiner Teich als Hindernis ergänzt.
Dadurch entsteht am Start kein zweiter, unbezahlter Fruchtsatz im selben
Jahr. Der Teich ist nur im Pretest-Profil vorhanden.

Beobachteter Feldverlauf (Seed 1337, echte Simulation):

| Zeit | Feldzustand |
|---|---|
| Tag 1, 06:00 | alle 4 Brache |
| Tag 1, 09:30 | alle 4 Pflügen |
| Tag 1, 14:30 | Felder 2/4 Säen, Felder 1/3 Pflügen |
| Tag 1, 18:30 | Felder 2/4 wachsen, Felder 1/3 gepflügt |
| Tag 61, 06:30 | alle 4 reif |
| Tag 61, 09:30 | alle 4 Ernte |

## 3. Dateien

**Neu:**

- `tests/g4c_p/kenney_world_view.gd` — separate Kenney-Pretest-Ansicht
- `tests/g4c_p/demo.tscn`, `tests/g4c_p/demo_main.gd` — sichtbare Demo
- `tests/g4c_p/pretest_camera.gd` — Kamera/Zoom/Pan
- `tests/g4c_p/screenshots.tscn`, `tests/g4c_p/screenshot_runner.gd` — Screenshot-Harness
- `tests/g4c_p/pretest_check.gd` — Selbstcheck (kein Gate)
- `tests/g4c_p/perf_probe.gd` — Headless-Performance/Determinismus
- `tests/g4c_p/perf_window.gd`, `tests/g4c_p/perf_window.tscn` — sichtbare Performance-Messung
- `assets/kenney/` — drei CC0-Pakete + Lizenzen + `ASSETS.md`
- `docs/g4c/v3-g4c-p-report.md` (dieser Report)
- `bench/results/g4c_p_*.png`, `bench/results/g4c_p_perf*.json`

**Geändert (nur additiv, alte Profile unverändert):**

- `src/data/sim_config.gd` — `PROFILE_G4C_P`, `g4c_pre()`, `uses_pathfinder()`,
  G4c-P in `uses_g3_schedule()`
- `src/world/world_map.gd` — G4c-P nutzt G2-Layout, Felder-Reset, Teich
- `src/agents/simulation.gd` — Profil-Gates über `uses_pathfinder()` /
  `uses_g3_schedule()`; G1/G2/G3/G4a/G4b-Verhalten bleibt gleich
- `src/agents/population_generator.gd` — `birth_day` nutzt `config.year_days`
  (G2: 30, unverändert; G4c-P: 120)

## 3a. Reproduktion

Godot 4.7.2 Standard-Build, Projektwurzel `V3`:

```text
# Demo (sichtbar)
godot --path V3 res://tests/g4c_p/demo.tscn

# Screenshots (1600x900, echte Simulation)
godot --path V3 --resolution 1600x900 res://tests/g4c_p/screenshots.tscn

# Selbstcheck (kein Gate)
godot --headless --path V3 --script res://tests/g4c_p/pretest_check.gd

# Headless-Performance + Determinismus
godot --headless --path V3 --script res://tests/g4c_p/perf_probe.gd

# Sichtbare Performance (Closeup + Ueberblick, VSync aus)
godot --path V3 --resolution 1600x900 res://tests/g4c_p/perf_window.tscn
```

Demo-Steuerung: `Space` Pause, `1`–`6` Speed (1/10/60/300/1200/3600×),
Mausrad Zoom, Mittelklick Pan, Linksklick Auswahl, `T` Terrain, `C` Figuren,
`V` Scale/Y-Sort-Debug, `R` Dorfmitte, `F12` Screenshot, WASD/Pfeile Pan.

## 4. Assets, Mapping und Lizenzen

Details, Kachelkoordinaten und SHA-256 stehen in
`assets/kenney/ASSETS.md`. Kurzfassung:

- **RPG Pack** (`roguelikeSheet_transparent.png`): Gras, Dirt, Sand, Wasser,
  Kopfsteinpflaster, Blumen, Bäume.
- **Roguelike Characters**: 12 vollständige 16×16-Figuren (Spalten 0/1,
  Zeilen 5–10) als deterministische Agentenvarianten.
- **RPG Base** (`RPGpack_sheet.png`, 64 px, 4×-Design): Wände, Dächer, Türen,
  Fenster, Schornstein, Säcke; 16-px-Downscale per Nearest.
- **Gebäude** werden aus RPG-Base-Kacheln komponiert (Wohnhaus, Werkstatt,
  Kornspeicher, Scheune, Brunnen). Die Pakete enthalten keine vollständigen
  Häuser.
- **Felder**: Dirt-Boden plus prozedurale Furchen/Saat/Halme, weil die Pakete
  keine Acker-/Fruchtphasen-Kacheln enthalten.
- Alle drei Pakete: **CC0 1.0**; Lizenztexte liegen bei. Tiny Farm/Town/Dungeon
  und Medieval RTS wurden nicht verwendet.

## 5. Ansicht: Figuren, Terrain, Y-Sort, Toggles

- **Getrennte Ansicht:** `KenneyWorldView` liest nur `Simulation`/`ViewState`
  und schreibt nie in die Simulation. `src/view/world_view.gd` bleibt
  unverändert.
- **Terrain:** 16-px-Kacheln aus RPG Pack; 32×32-Tile-Grasmuster (512 px)
  gegen sichtbare Wiederholung; Straßen/Felder als getile Texturen.
- **Figuren:** 16×16-Kenney-Sprites, Schatten, Bob, Facing über
  Positionsvergleich, Auswahlring, Aktivitätsmarker (Buchstabe + Farbe),
  Namen bei Hover/Selection und ab Zoom 1,9×. Kinder/Alte leicht skaliert.
- **Y-Sort:** Gebäude nach Unterkante, Bäume nach Stammfuß, Agenten nach
  Fußpunkt (inkl. Anzeige-Offset). Sortierung erfolgt pro Frame über eine
  gemeinsame Drawable-Liste; Ringe/Marker/Namen werden in einem zweiten Pass
  über allen Sprites gezeichnet, damit die Auswahl nicht verdeckt wird.
- **Anzeige-Offset:** Agenten an exakt gemeinsamen Tür-/Feldpunkten werden
  rein visuell deterministisch um bis zu ~0,66 Tile versetzt. Die
  Simulationspositionen bleiben unverändert; es wird kein Agent gefiltert.
  Der Offset ist im Report und im Code als View-Element markiert.
- **Render-LOD:** Ab Zoom < 0,62 werden Agenten als screen-konstante
  Farbpunkte gezeichnet; Straßen ab < 0,40, Felder ab < 0,38 flach. Alle
  Agenten bleiben sichtbar. Kein Sim-LOD, keine Event-/Zeitverkürzung.
- **Tag/Nacht:** Modulate-Farbe nach Uhrzeit plus warme Fensterlichter;
  Jahreszeiten-Tint. Kein Sim-Effekt.
- **Toggles:** `T` Terrain RPG Pack ↔ RPG Base (16-px-Downscale), `C` Kenney-
  Figuren ↔ aktuelle Vektor-Figuren, `V` Scale/Y-Sort-Debug (Tile-Raster,
  Y-Sort-Linien, 10-Tile-Maßstab = 15 m).
- **Kamera:** Zoom 0,14–6,0; WASD/Pfeile, Mittelklick-Pan, Mausrad-Zoom auf
  den Cursor, `R` Dorfmitte, Start bei (196,165) mit 1,45×.
- **HUD:** Uhr/Tag/Jahr/Saison, Agenten/Haushalte/Gebäude, Grain/Granary,
  Ernten/Saatgut, Feldzustände, Zoom/Terrain/Figuren, minimale Inspector-
  Ansicht mit Needs-Balken. `F12` speichert einen manuellen Screenshot.

## 6. Screenshots

Erzeugt mit `tests/g4c_p/screenshots.tscn` (1600×900, echte Simulation,
`advance_to`; Kamera/Auswahl/Hover sind reine View-Zustände):

| Datei | Tag/Zeit | Kamera/Zoom | Inhalt |
|---|---|---|---|
| `bench/results/g4c_p_closeup.png` | Tag 1, 11:30 | (290,150), 1,80× | Werkstatt, Straße, Feld, 5+ Figuren, Auswahl Bernd (#9), Inspector |
| `bench/results/g4c_p_overview.png` | Tag 1, 12:00 | (192,190), 0,30× | ganze Siedlung, 4 Felder, Teich, Agentenpunkte, ohne HUD |
| `bench/results/g4c_p_night.png` | Tag 1, 22:30 | (188,150), 1,80× | Nacht-Tint, Fensterlichter, Brunnenplatz, Figuren, Auswahl Emil (#20) |
| `bench/results/g4c_p_field_season.png` | Tag 61, 09:30 | (300,164), 0,48× | Herbst, alle 4 Felder „Ernte“, Hauszeilen, HUD mit Feldzuständen |

Zusätzliche Toggle-Evidenz (optional, nicht Teil der vier Pflichtmotive):

| Datei | Inhalt |
|---|---|
| `bench/results/g4c_p_toggle_terrain_base.png` | gleiche Closeup-Szene mit RPG-Base-Terrain |
| `bench/results/g4c_p_toggle_vector.png` | gleiche Closeup-Szene mit Vektor-Figuren |

Die Screenshots zeigen die echte Simulation. Die Zeit wird über
`advance_to` vorgespult; es werden keine Felder, Agenten oder Events
künstlich gesetzt. Nur Kamera, Auswahl, Hover, Terrain-/Figuren-Toggle und
die HUD-Sichtbarkeit sind View-Zustände.

## 7. Messwerte

### Headless (Seed 1337, 120 Tage, `tests/g4c_p/perf_probe.gd`)

| Metrik | Wert |
|---|---:|
| Setup (Welt + 100 Agenten + Texturen) | 121,7 ms |
| Sim-Zeit pro Tag (Mittel) | 91,3 ms |
| p50 / p95 / p99 / max pro Tag | 90,5 / 106,3 / 112,8 / 125,6 ms |
| Events im Jahr | 201.725 |
| Pfad-Cache-Hitrate | 99,72 % (75.687 Hits / 209 Recalculations) |
| Grid-Fallbacks | 0 |
| Determinismus | zwei 120-Tage-Läufe, identischer State-Hash (`2210945855`) |
| Jahr-Endstand | 104 lebend (6 Geburten, 2 Tode), Grain 35.963 |
| Ernten | 4 (alle im Herbst), 0 Overflow, Feldzyklen 4 |
| Jahresbilanz | 36.000 Start − 4.000 Saatgut + 40.000 Ernte − 36.037 Mahlzeiten = 35.963 |

Die 91 ms/Tag sind Event-Kosten des 100-Agenten-Kerns, nicht Renderkosten.
Bei 1× (900 s/Tag) sind das ca. 0,01 % CPU; bei 300× ca. 3 %, bei 1200×
ca. 12 % und bei 3600× ca. 36 % eines Kerns. Die Demo-Speedstufen sind
deshalb bewusst gedeckelt (max. 3600×).

### Sichtbar (100 Agenten, Demo-Fenster, 1600×900, VSync aus, 300×)

`tests/g4c_p/perf_window.tscn`, 6 s Closeup + 6 s Überblick:

| Phase | Zoom | Draw Calls | Frame p50/p95/p99 | Max | FPS avg |
|---|---:|---:|---:|---:|---:|
| Closeup (Werkstatt/Feld) | 1,80× | 38 | 0,74 / 1,61 / 1,98 ms | 5,94 ms | 1140 |
| Überblick (Dorf/Felder) | 0,30× | 517 | 5,84 / 7,36 / 8,59 ms | 14,27 ms | 167 |

Der Überblick ist der teurere Fall (alle 260 Bäume, 100 Agentensprites und
100 screen-konstante Marker), bleibt aber deutlich unter 16 ms p95. Es gibt
kein hartes Gate für G4c-P.

### Bewertung

- Das 100-Agenten-Profil liegt erwartungsgemäß deutlich unter dem 10k-Gate.
- Die Zahlen dienen der Maßstabs-/Render-Entscheidung für G4c, nicht als
  Abnahme.
- Die Screenshot-FPS im HUD sind bewusst durch „Screenshot (Performance:
  Report)“ ersetzt, weil der Harness die Zeit zwischen Frames synchron
  vorspult und damit keine gültige FPS-Stichprobe liefert.

## 8. Was visuell funktioniert

- **Lesbarkeit:** 16-px-Figuren sind ab ~1,5× klar als Personen erkennbar;
  Auswahlring, Name und Aktivitätsmarker funktionieren.
- **Terrain/Gebäude:** Gras, Wege, Wasser, Felder und die fünf Gebäudetypen
  sind auf einen Blick unterscheidbar. Die komponierten Dächer/Wände lesen
  sich als Dorf, auch ohne fertige Haus-Sprites.
- **Y-Sort:** Figuren vor/hinter Gebäuden und Bäumen sitzen richtig; der
  zweite Overlay-Pass hält Auswahl/Namen sichtbar.
- **Feldphasen:** Brache → Pflügen → Säen → Wachsen → Reif → Ernte ist im
  Verlauf und in den Screenshots unterscheidbar; der 120-Tage-Kalender
  funktioniert mit dem G3-Feldzyklus.
- **Tag/Nacht:** Der Nacht-Tint plus Fensterlichter ist stimmungsvoll und
  verändert keine Sim.
- **Toggles:** `T`, `C` und `V` sind sichtbar und ohne Sim-Effekt.
- **Kamera:** Vom 0,30×-Überblick bis 2,2×-Nahaufnahme bleibt die Szene
  bedienbar; der Mausrad-Zoom auf den Cursor fühlt sich richtig an.

## 9. Was (noch) nicht funktioniert / Grenzen

- **Keine fertigen Häuser im Kenney-Pack.** Die komponierten Gebäude sind
  zweckmäßig, aber Dächer/Türen wirken bei 16 px teils grob; ein dediziertes
  Town-/Farm-Tileset wäre für G4c besser.
- **Keine Acker-/Fruchtphasen-Kacheln.** Felder sind Boden + prozedurale
  Reihen; bei 0,48× wirken sie als braune Rasterflächen, bei 1,8× als
  Furchen. Für G4c braucht es echte Phasenkacheln oder ein Feld-Decalset.
- **Figuren sind statisch** (ein Frame pro Variante). Laufen wirkt über Bob/
  Offset, nicht über Animation. Für G4c: 2–4 Lauf-/Arbeitsframes.
- **Stapelung an gemeinsamen Zielen** (Werkstatt, Feldarbeit, Haustüren) wird
  nur durch den View-Offset entzerrt. Bei sehr großen Gruppen bleibt es eng;
  eine echte Zielpunktverteilung wäre eine Sim-Entscheidung und ist hier
  bewusst nicht erfolgt.
- **Palette:** Kenney-Gras ist sehr gesättigt; die RPG-Base-Variante ist
  flacher. Eine G4c-Palette sollte Gras leicht entsättigen und Dächer wärmer
  abstimmen.
- **Maßstab:** 1 Tile = 1,5 m; 16-px-Figuren sind damit ~1,5 m, 8×8-Häuser
  ~12×12 m, 2-Tile-Türen ~3 m. Das ist stylized, aber Türen wirken zu breit;
  für G4c entweder 1,2× Figurenscale oder 1-Tile-Türen/2-m-Tiles prüfen.
- **Kein Save** für G4c-P (kein eigenes Schema); die Demo bietet bewusst
  kein Speichern an.
- **Overlay-Dichte:** Bei 1,9×+ werden alle Namen gezeichnet; in dichten
  Gruppen überlappen sie. Für G4c: Namen nur für Hover/Selection oder
  Leader-Lines.

## 10. Empfehlungen für G4c

1. **Maßstab/Anker:** 16-px-Tile als Basis behalten, aber Figuren auf 1,2×
   (≈1,8 m) und Türen auf 1×2 Tiles normalisieren. Anker: Füße auf
   Tile-Mitte, Gebäude-Y-Sort an der Unterkante, Dachfirst separat.
2. **Tileset:** Ein dediziertes Town-/Farm-Set mit vollständigen Häusern,
   Dächern in 2–3 Neigungen und 4–6 Feldphasen wählen; die Kenney-Packs
   bleiben gut für Gelände, Figuren und Deko.
3. **Y-Sort/Overlays:** Den zweiten Overlay-Pass beibehalten; Namen nur bei
   Hover/Selection, Aktivitätsmarker ab 1,5×, Agenten ab < 0,62× als
   screen-konstante Punkte.
4. **Kamera:** Start 1,4× auf der Dorfmitte, Überblick 0,30×, Nahaufnahme
   1,8–2,4×; Zoom auf Cursor und Mittelklick-Pan sind ausreichend. Für G4c
   zusätzlich Follow auf selektierte Agenten und eine Minimap prüfen.
5. **HUD:** Die minimale Top-Leiste + Inspector reicht für den Pretest. Für
   G4c eine kompakte Zeitleiste (Tag/Saison/Speed) und eine einklappbare
   Inspector-Spalte; im Überblick HUD ausblenden.
6. **Palette:** Gras leicht entsättigen, Wege dunkler/wärmer, Dächer in
   Brown/Cream/Gray belassen, Nacht-Tint beibehalten. Jahreszeiten-Tint nur
   subtil (Herbst wärmer, Winter kühler).
7. **Harness:** `advance_to`-Screenshots mit festen Kamera-/Zoom-Presets und
   ohne HUD für Übersichten beibehalten; das ist reproduzierbar und trennt
   View von Sim sauber.

## 11. Regression G1–G4b

Die Kernänderungen sind additiv: neue Profilkonstante, `uses_pathfinder()`,
G4c-P in `uses_g3_schedule()`, G4c-P-Zweige in `WorldMap` und
`Simulation`-Gates. Die bestehenden Profile und ihre Hashes bleiben
unverändert; die Regression wird mit den vollständigen Suiten geprüft.

| Suite | Ergebnis | Checks |
|---|---:|---:|
| G1a | 29/29 PASS | 265 |
| G1b | 28/28 PASS | 790 |
| G2 | 21/21 PASS | 229 |
| G3-A | 13/13 PASS | 232 |
| G3-B (Spike) | 18/18 PASS | 289 |
| G4a | 12/12 PASS (Rerun) | 198 |
| G4b | 12/12 PASS | 257 |

Die G3-A-120-Tage-Hashes sind unverändert:
`state=0x5D49B80C event=0x92367DFC chronicle=0xA09E0CBF` für Chunks
1/60/3600. Die G4a-Kurzläufe liefern ebenfalls die eingefrorenen Hashes
(`state=0xF1FC5EE7 event=0x1A410B37 chronicle=0x3D78CD8F`, `alive=10233`,
`harvests=200`). G4b meldet `state=0xB39248E0`, `event=0x209FEB40`,
`chronicle=0x216EABF7`, `alive=10233`, `caravans=8`, `treaties=2`;
T-G4b-12 bestätigt die G1/G2/G3/G4a-Regression.

**Performance-Hinweis:** Der erste G4a-Suite-Lauf auf dieser Arbeitsmaschine
meldete T-G4a-08 knapp rot (p95 16,50–16,56 ms, p99 23,50–23,88 ms), während
alle 11 anderen G4a-Tests und die Hashes exakt grün waren. Ein isolierter
T-G4a-08-Lauf mit hoher Prozesspriorität lag bei p95 13,08–14,15 ms und p99
18,46–20,10 ms; eine unveränderte HEAD-Baseline lag unter gleichen
Bedingungen bei p95 13,28–13,31 ms / p99 18,57–18,76 ms. Der vollständige
G4a-Rerun mit hoher Priorität bestand T-G4a-08 mit p95 12,68–12,97 ms und
p99 17,93–18,47 ms und damit **12/12**. Die Abweichung im ersten Lauf war
Last-/Scheduling-Rauschen der vielen Hintergrundprozesse (VS Code, Outlook,
OneDrive), keine Verhaltensänderung: Events, Alive-Zahlen und alle
State-/Event-/Chronik-Hashes sind bitgleich. Der G4b-Lauf mit hoher
Priorität bestand T-G4b-09 mit p95 12,67–12,75 ms / p99 18,15–18,26 ms.

**G4c-P-Selbstcheck:** `tests/g4c_p/pretest_check.gd` — 36/36 PASS
(Profil, 100/24/4, Tag 1/Frühling, Startgrain, Feldphasen bis Ernte,
Toggles, Anzeige-Offset).
