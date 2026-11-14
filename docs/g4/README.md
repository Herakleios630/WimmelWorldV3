# G4a – 10.000-Agenten-Kern

Dieser Ordner enthält Spezifikation und Abnahmebericht des G4a-Gates.
G4b (Wirtschaft, Politik, Handel, Karawanen, Steuern, Diplomatie) ist **nicht**
Teil von G4a; `src/lod/` und die B-Spike-Tests bleiben unverändert.

## Gegenstand

- 10.000 Agenten in 2.000 Haushalten auf 2.048 × 2.048 Tiles (1,5 m/Tile).
- 2.000 Häuser, 200 Felder, drei Werkstätten, Kornspeicher, Brunnen, Scheune.
- 120-Tage-Jahr als 4 × 30 Seasons; eine Ernte pro Feld und Jahr, nur im Herbst.
- A*/Wegpunktgraph, Pfad-Cache, Chunk-Index, Event-Batching.
- Save-Schema 7 mit komprimiertem Payload; Schema 1–6 wird für das 10k-Profil
  abgelehnt.
- D-57 bleibt bei Stubs.

## Tests

```text
godot --headless --path V3 res://tests/g4/g4_a_suite.tscn
```

Die Suite führt T-G4a-01..10 aus und schreibt Messwerte nach
`bench/results/`. Die 120-Tage-Determinismusläufe (Chunks 1/60/3600) und die
drei 10k@50x-Läufe dominieren die Laufzeit.

Visuelle Messung (Fenster, kein `--headless`):

```text
godot --path V3 res://tests/g4/bench_visual.tscn -- --run=1
godot --path V3 res://tests/g4/visual_120days.tscn
```

## Dokumente

- `v3-g4-spec.md` – Gate-Spezifikation.
- `v3-g4a-report.md` – Abnahmebericht mit Messwerten und Grenzen.
