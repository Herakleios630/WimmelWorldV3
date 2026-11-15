# G4c-P2.1c2b — Cluster-Layout

Status: **Teilstand/Checkpoint**, keine G4c-Abnahme  
Stand: 2026-11-15  
Bezug: `docs/g4c/v3-g4c-p2.md` (P2.1c2b)

## 1. Änderung

- Oval-Ring, Kreuzstraßen und lange Gassen entfernt.
- **8 Hauscluster** (je 3 Häuser = 24) unregelmäßig um den Platz verteilt:
  N, NE, E, SE, S, SW, W, NW.
- **Radiale, gewellte Wege** vom Platz zu jedem Cluster (1–2 Tiles), statt
  durchgehendem Ring.
- Civic (Werkstatt/Kornspeicher) vor den Wegen platziert, damit sie nicht
  überschrieben werden.
- Plaza 14×10 bleibt; Felder/Farmsteads/Teich/Obstgärten unverändert.
- 100 View-Agenten; keine Sim-/Balance-/Save-Änderung.

## 2. Ergebnis

`G4C_P2_LAYOUT seed=421337 houses=24 rows=8 farms=3 fields=6 roads=615
trees=162 civic=2`.

Screenshots: `bench/results/g4c_p2c2b_overview|plaza|roads|pond|fields.png`,
alle `err=0`.

## 3. Bewertung

- **Besser:** Kein geometrischer Oval-Ring; Dorf liest sich als Cluster-
  Siedlung um einen Platz; radiale Wege und Lücken wirken organischer.
- **Noch offen:** Hauszeilen sind weiter horizontal und gleichförmig; die
  radialen Wege sind im Nahzoom tile-treppig; leere Grasflächen zwischen den
  Clustern; Felder/Farmsteads am Rand bleiben schematisch.
- **Nächster Schritt:** P2.1c2c — kuratiertes 4-Bit-Edge-/Corner-Set
  (16 Varianten) für Gras↔Dirt/Weg/Pflaster/Wasser, keine 47er-Blob-Library.
- Danach ggf. Hauszeilen rotieren/verkürzen und Props in die Lücken.
