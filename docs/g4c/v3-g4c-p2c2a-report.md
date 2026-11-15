# G4c-P2.1c2a — Organischer Layout-Teilstand

Status: **Teilstand/Checkpoint**, keine G4c-Abnahme  
Stand: 2026-11-15  
Bezug: `docs/g4c/v3-g4c-p2.md` (P2.1c2a)

## 1. Was gemacht wurde

- Der P2.1c2a-Subagent kam leer zurück; der Layout-Tweak wurde deshalb direkt
  und klein umgesetzt.
- **8 Hauszeilen** leicht versetzt (x/y ±1–3), weiterhin 3 Häuser pro Zeile
  = **24 Häuser**.
- **Drei Ringlücken** im Oval (ca. 31–49°, 140–158°, −146…−129°), damit der
  Ring nicht perfekt durchläuft.
- **Plaza** von 16×12 auf **14×10** Tiles verkleinert.
- Screenshot-Ausgabe auf `g4c_p2c2a_*.png` umgestellt; HUD-Label aktualisiert.

## 2. Ergebnis

- `G4C_P2_LAYOUT seed=421337 houses=24 rows=8 farms=3 fields=6 roads=1769
  trees=158 civic=2`.
- 5 Screenshots: `bench/results/g4c_p2c2a_overview|plaza|roads|pond|fields.png`,
  alle `err=0`.
- Keine Sim-/Balance-/Save-Änderung; 100 View-Agenten.

## 3. Grenzen

- Hauszeilen bleiben lange, uniforme Blöcke; die Ringlücken wirken noch grob.
- Große leere Grasflächen zwischen Ring/Häusern/Plaza.
- Kein echter Cluster-/Gassen-Umbau, keine neuen Props in den Lücken.
- Die „richtigen“ 4-Bit-Edge-/Corner-Tiles fehlen noch (P2.1c2b).
- Der Oval-Ring ist nur unterbrochen, nicht durch eine organische Struktur
  ersetzt.

## 4. Nächster Schritt

1. **P2.1c2b:** Oval-Ring aufgeben; 5–7 Hauscluster um den Platz, variable
   Orientierungen, kurze Zeilen, Gassen/Gärten/Props in den Lücken.
2. **P2.1c2c:** kuratiertes 4-Bit-Edge-/Corner-Set (16 Varianten) für
   Gras↔Dirt/Weg/Pflaster/Wasser, keine 47er-Blob-Bibliothek.
3. Danach erneut Screenshots und visuelle Abstimmung.
