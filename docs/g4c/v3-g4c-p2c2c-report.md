# G4c-P2.1c2c — 4-Bit-Edge-/Corner-Tiles

Status: **Teilstand/Checkpoint**, keine G4c-Abnahme  
Stand: 2026-11-15  
Bezug: `docs/g4c/v3-g4c-p2.md` (P2.1c2c)

## 1. Änderung

- Neues `tests/g4c_p2/edge_tiles.gd`: erzeugt pro Textur **16 Varianten**
  (4-Bit N/E/S/W) mit transparentem Außenbereich und gerundeten Ecken; keine
  47er-Blob-Library.
- Kanten-Sets für **Wege (Dirt)**, **Platz (Pflaster)**, **Sand** und
  **Wasser**; Wasser liegt auf einer Sandbasis.
- `_draw_roads`, `_draw_plaza` und `_draw_pond` zeichnen jetzt diese
  Kanten-Tiles statt der Soft-Linien/Kreise; `_soften_shape` wird für diese
  Flächen nicht mehr aufgerufen.
- 24 Häuser/8 Cluster/6 Felder/2 Civic bleiben; 100 View-Agenten.

## 2. Ergebnis

`G4C_P2_LAYOUT seed=421337 houses=24 rows=8 farms=3 fields=6 roads=615
trees=162 civic=2`; 5 Screenshots `bench/results/g4c_p2c2c_*.png`, `err=0`.

## 3. Bewertung

- **Besser:** Platz-, Weg-, Sand- und WasserKanten sind crisp und gerundet;
  keine weichen Graswolken mehr an diesen Flächen.
- **Noch offen:** Der **Pfadverlauf** ist weiter tile-treppig, weil die
  Mittellinie in Tile-Schritten läuft; 4-Bit-Kanten glätten nur den Rand.
  Felder nutzen noch die alten weichen Grasränder; Hauszeilen sind weiter
  horizontal/uniform; leere Grasflächen zwischen Clustern.
- **Nächster Schritt:** Pfadverlauf glätten (Spline/Polyline oder
  Corner-Varianten) und/oder Feldkanten auf Edge-Tiles umstellen. Danach
  Hauszeilen/Props.
