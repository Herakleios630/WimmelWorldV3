# V3 G4 — Spezifikation: 10.000-Agenten-Stadt und Systeme

Status: G4-Spezifikation, Entwurf (nach G3 zu verfeinern)  
Stand: 2026-11-14  
Bezug: `docs/v3-plan.md`, `docs/v3-fidelity.md`, `docs/g3/v3-g3-spec.md`,
`docs/g3/v3-g3-b-spike-report.md`.

## 1. Ziel

G4 skaliert A von 1.000 auf **10.000 Agenten** und führt die erste
Wirtschaft/Politik-Stufe ein. G4 ist in zwei formale Gates geteilt:

- **G4a — 10k-Kern:** 10k-Agenten-Stadt + Hinterland, 120-Tage-Jahr,
  saisonale Felder, Pfad-/Chunk-/Save-Stress, D-57 nur Stubs.
- **G4b — 10k + Systeme:** Haushalte, lokale Märkte, physische Karawanen,
  Steuern/Budget, leichte Diplomatie, Krisen als Chronik.

G4 ist **kein** 100k-Gate; B bleibt separater 150x-Modus.

## 2. G4a — 10k-Kern

### Welt/Population
- 10.000 Agenten in ~2.000 Haushalten.
- Stadt + Hinterland, 2.048×2.048 Tiles (1,5 m/Tile ≈ 3,07 km × 3,07 km).
- ~2.000 Häuser, ~200 Felder, Werkstätten, Märkte als Stubs, Kornspeicher,
  Brunnen, Scheune, Wege.
- Deterministischer Generator, G1b-Lifecycle aktiv.

### Kalender/Felder
- 120-Tage-Jahr, 4×30 Seasons; saisonale Felder wie G3.
- Ein Feld = eine Ernte/Jahr; Feldanzahl skaliert mit Population
  (Platzhalter: 200 Felder für 10k).
- Keine Ernte außerhalb des Herbstfensters.

### Pfad/Chunks/Save
- A*/Cache/Chunking unter 10k; Pfadbudget; Cache-Hit > 90 %.
- Kein Full-Agent-Sweep pro Frame; Event-Batching.
- Save-Schema **7**; Schema 1–6 ablehnen; Pfad-Cache nicht speichern.
- 120-Tage-Determinismus, 3 Läufe; Save/Load mitten in Feldphase/Bewegung/
  Geburt/Tod.

### Abnahme G4a
- 10k@50x: p95 ≤ 16 ms, p99 ≤ 20 ms, 60 FPS; 5-Minuten-Fenster, 3 Läufe.
- 120-Tage-headless: 3 Läufe identisch; 200 Ernten im Herbst, 0 außerhalb.
- Save/Load exakt; kein Leak.
- D-57 nur Stubs; keine G4b-Systeme.
- Tag `g4a`.

## 3. G4b — 10k + Wirtschaft/Politik

### Wirtschaft (D-44..D-49)
- Haushalte mit Budget, lokale Märkte, Preise, physische Karawanen zwischen
  Siedlungen, nationale Schatzkammer, Steuern, öffentliches Budget.
- Krisen: Knappheit, Preisspitzen, Hunger, Verschuldung, Unruhe als
  Chronik-Ereignisse; kein Game Over.
- Individuelle Löhne/Münzen für sichtbare Agenten; Haushaltsbudget;
  Siedlungs-/Nationsledger; keine Transaktion pro Agent/Tick.
- Physische Karawanen mit Ladung; lokale Preise; Handelsabkommen.
- Drei Nationen? G4b bleibt bei einer Region/einem Nationsnetz; drei Nationen
  und 100k sind G5.

### Politik
- Nation/Region mit Schatzkammer, Steuersatz, öffentlichem Budget,
  Diplomatie/Verträgen; kein Krieg.
- Deterministische Utility-KI; keine LLM-Entscheidungen.
- 3 Ressourcen-Spezialisierungen als Platzhalter.

### Abnahme G4b
- Wirtschaftsbilanz nachvollziehbar; Preise/Karawanen/Steuern/Budget
  funktionieren; Krisen erzeugen Chronik.
- 10k@50x p95 ≤ 16 ms; 3 Läufe; 120-Tage-Determinismus.
- Save-Schema **8**; Schema 1–7 ablehnen.
- Keine Kriege/Tiere/Fantasy; keine D-57-Simulation.
- Tag `g4b`.

## 4. Tests

- G4a: T-G4a-01..10 (Welt/Population, Kalender/Felder, A*/Chunk, Batching,
  120-Tage-Determinismus, Save/Load Schema 7, 10k@50x, UI/Chronik, Leaks,
  keine G4b-Systeme).
- G4b: T-G4b-01..12 (Haushalte/Budget, Markt/Preise, Karawanen, Steuern/
  Budget, Diplomatie/Verträge, Krisen, Chronik, Determinismus, Save/Load
  Schema 8, 10k@50x, keine Kriege, Regression).
- G1/G2/G3-Suiten bleiben grün.

## 5. Nicht-Ziele

- Keine 100k (G5), keine drei Nationen (G5), keine Kriege/Tiere/Fantasy.
- Keine D-57-Simulation; Stubs bleiben.
- Keine B-Integration in A.
- Keine Lesezeichen/Sammlungen/Zeitleiste/Nationen-Chronik.
- Keine stillen Balance-/Fidelityänderungen.

## 6. Risiken

- 10k-Pfad/Chunk/Save-Kosten; G3-Checkpoint als Rückfall.
- Wirtschaft/Politik können 10k-Performance brechen; getrennte G4a/G4b-Gates.
- Save-Größe; G3/G4-Save-Budget definieren.
- Revert über Git-Tags `g3`, `g4a`, `g4b`.
