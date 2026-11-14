# G4 – 10.000-Agenten-Kern und G4b-Systeme

Dieser Ordner enthält Spezifikationen und Abnahmeberichte der G4-Gates.
G4a ist der bestandene 10k-Kern; G4b ergänzt die leichte Wirtschafts- und
Politikschicht auf demselben 10k-Kern. `src/lod/` und die B-Spike-Tests
bleiben unabhängig.

## G4a – 10k-Kern

- 10.000 Agenten in 2.000 Haushalten auf 2.048 × 2.048 Tiles (1,5 m/Tile).
- 2.000 Häuser, 200 Felder, drei Werkstätten, Kornspeicher, Brunnen, Scheune.
- 120-Tage-Jahr als 4 × 30 Seasons; eine Ernte pro Feld und Jahr, nur im Herbst.
- A*/Wegpunktgraph, Pfad-Cache, Chunk-Index, Event-Batching.
- Save-Schema 7 mit komprimiertem Payload; Schema 1–6 wird für das 10k-Profil
  abgelehnt.
- D-57 bleibt bei Stubs.

## G4b – 10k + Wirtschaft/Politik

- Eigenes Profil `SimConfig.civic()` mit `economy_enabled`/`politics_enabled`;
  G4a-Profil `SimConfig.scale()` und dessen Schema 7 bleiben unverändert.
- Haushaltsbudgets, Löhne, Steuern, lokaler Markt mit gedämpften Preisen.
- Drei abstrakte Handelsknoten, wenige physische Karawanen mit Ladung.
- Eine Nation mit Schatzkammer, Steuersatz, Budget und zwei abstrakten
  Nachbarn; Handelsabkommen, kein Krieg.
- Krisen (Knappheit, Preisspitze, Überschuldung, Unruhe) als Chronik.
- Save-Schema 8; G4a-Schema 7 bleibt im G4a-Profil ladbar.
- Kein Krieg, keine D-57-Simulation, keine G5-Nationen/100k.

## Tests

G4a:

```text
godot --headless --path V3 res://tests/g4/g4_a_suite.tscn
```

G4b:

```text
godot --headless --path V3 res://tests/g4/g4_b_suite.tscn
```

Die G4b-Suite führt T-G4b-01..12 aus und schreibt Messwerte nach
`bench/results/`. Die drei 120-Tage-Determinismusläufe (Chunks 1/60/3600) und
die drei 10k@50x-Läufe dominieren die Laufzeit. D-68 erlaubt die
Fortschreibung der historischen Scope-Assertions; die G1–G4a-Verhaltensprüfungen
bleiben unverändert.

Visuelle Messung (Fenster, kein `--headless`):

```text
godot --path V3 res://tests/g4/bench_visual.tscn -- --run=1
godot --path V3 res://tests/g4/visual_120days.tscn
godot --path V3 res://tests/g4/bench_b.tscn -- --run=1
godot --path V3 res://tests/g4/visual_b.tscn
```

## Dokumente

- `v3-g4-spec.md` – Gate-Spezifikation.
- `v3-g4a-report.md` – G4a-Abnahmebericht mit Messwerten und Grenzen.
- `v3-g4b-spec.md` – G4b-Spezifikation inklusive D-68.
- `v3-g4b-report.md` – G4b-Abnahmebericht (abnahmefähig).

