# V3 G4c-P — Visueller Pretest mit 100 Agenten

Status: Pretest-Planung, Umsetzung startet  
Stand: 2026-11-15  
Bezug: `docs/g4c/v3-g4c-plan.md`, `docs/g4/v3-g4a-report.md`,
`docs/g4/v3-g4b-report.md`, `docs/v3-fidelity.md`.

## 1. Ziel

Vor dem 10k-G4c-Umbau wird visuell geprüft, ob die Kenney-Tiles und Figuren
zum Maßstab, zur Kamera, zur Welt und zum geplanten Wimmelbild-Look passen.
**Kein 10k, kein neues Gameplay, keine Simulation-/Balance-Änderung.**

- 100 Agenten, 24 Haushalte, 4 saisonale Felder.
- 384×384-Tile-Welt (576×576 m), Tag 1/Frühling, 120-Tage-Jahr.
- Kenney: Roguelike/RPG Pack + Roguelike Characters + RPG Base.
- 16×16 bei 1,5 m/Tile; Figuren 16×16, statisch + Bob.
- Sichtbare Demo mit Kamera/Zoom, Inspector, minimalem HUD, Tag/Nacht.
- Screenshots: Nahaufnahme, Dorfübersicht, Nacht, Feld/Season.
- Danach Fein-Tuning; erst dann G4c (10k).

## 2. Engine-Fit (Analyse)

- **Simulation:** unabhängig von der Optik; Tiles/Positionen bleiben
  1,5 m/Tile, 16 px/Tile, ganzzahlige Tiles. Keine Sim-Änderung nötig.
- **View:** aktuell prozedurale Rechtecke/Vektoren, kein Tile-Atlas, keine
  Sprite-Figuren, keine Y-Sortierung, keine Animation. Für Kenney braucht es
  einen **separaten KenneyWorldView**.
- **Maßstab:** 16×16-Tiles passen; 16×16-Figuren = 1 Tile = 1,5 m (V1-nah,
  etwas kurz). RPG Base ist 16×16-Design in 64×64-Dateien (4×) und muss für
  16-px-Darstellung herunterskaliert werden.
- **Gebäude:** Footprints sind tile-basiert; Kenney-Gebäude sind mehrere
  Tiles groß. Mapping/Anker (Fußpunkt, Y-Sort) nötig.
- **Performance:** 100 Agenten unkritisch; 10k braucht Visible-only/
  Instancing/Marker. Der Pretest validiert den Look, nicht 10k.
- **UI:** bestehende Debug-Panels bleiben für den Pretest minimal; Kenney-UI
  kommt in G4c-B.

## 3. Pretest-Umfang

- Neues Profil `SimConfig.g4c_pre()`: 100 Agenten/24 Haushalte/4 Felder,
  120-Tage-Jahr, saisonale Felder, 384×384, Startgrain ~36.000,
  Granary ~72.000.
- Neuer `src/view/kenney_world_view.gd` (nur Pretest-Szene; G1–G4b-View
  bleibt unverändert).
- Neues `tests/g4c_p/demo.tscn` + `demo_main.gd`.
- Kenney-Assets unter `assets/kenney/` mit Lizenz-/Quellen-Datei.
- Tile-/Building-/Character-Mapping:
  - Terrain: Gras, Dirt, Wasser, Wege, Felder (Phasen).
  - Gebäude: Wohnhaus, Werkstatt, Kornspeicher, Brunnen, Scheune.
  - Figuren: 8–12 Varianten nach Rolle/Farbe; Schatten, Bob, Auswahl,
    Aktivitätsmarker, Namen bei Hover/Zoom.
- Vergleichs-Toggles:
  - `T`: Terrain RPG Pack ↔ RPG Base (16-px-Downscale).
  - `C`: Figuren Kenney ↔ aktuelle Vektor-Figuren.
  - `V`: Y-Sort/Scale-Debug optional.
- Kamera: WASD/Pfeile, Mausrad, Zoom; Tag/Nacht; Pause/Speed.
- Screenshots aus der Demo (Nah/Dorf/Nacht/Feld).

## 4. Nicht-Ziele

- Kein 10k, keine G4c-Abnahme, kein Loading-Screen-Umbau.
- Keine Wirtschaft/Politik-Panels, keine Chronik-/UI-Politur.
- Keine Simulation-/Balance-/Fidelity-Änderung.
- Keine Tiny-Farm/Town/Dungeon- oder Medieval-RTS-Assets.
- Keine Änderung an G0-Dokumenten/README/Master-Plan.
- Keine Git-Commits; Review/Commit/Tag `g4c-p` durch den Hauptagenten.

## 5. Abnahme

- Demo startet mit 100 Agenten, 4 saisonalen Feldern, Tag 1/Frühling.
- Terrain, Gebäude und Figuren sind klar erkennbar; Figuren lesbar.
- Nah- und Fernzoom funktionieren; Y-Sort/Überlappung plausibel.
- Tag/Nacht-Tint funktioniert; Felder zeigen Phasen.
- Keine fehlenden Texturen/Platzhalter im sichtbaren Bereich.
- G1–G4b-Suiten bleiben unverändert grün.
- Screenshots + kurzer Pretest-Report mit Design-Feedback-Punkten.
