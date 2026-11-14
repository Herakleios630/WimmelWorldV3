# V3 G3 — Spezifikation: 1.000-Agenten-Kleinstadt

Status: G3-Spezifikation, Entwurf  
Stand: 2026-11-14  
Bezug: `docs/v3-plan.md`, `docs/v3-fidelity.md`, `docs/v3-architecture.md`,
`docs/v3-data-model.md`, `docs/v3-benchmark.md`, `docs/g2/v3-g2-report.md`.

## 1. Ziel

G3 skaliert A (Vollsimulation, 1x autoritativ) von 100 auf **1.000 Agenten**
und beweist:

- deterministische 1.000-Agenten-Simulation über **120 Sim-Tage** (ein Jahr),
- **saisonale Felder** im neuen **120-Tage-Jahr mit 30-Tage-Seasons**,
- lokale Pfadfindung/Cache/Chunking unter 1k-Last,
- Save/Load, Chronik und UI bei 1k,
- **1.000 Agenten @50x, 60 FPS, p95 ≤ 16 ms**,
- D-57 bleibt Stubs ohne Simulationseffekt.

G3 ist **kein** 10k-/100k-Gate. B (150x-Zeitraffer) bleibt separat und wird
nicht in A integriert.

## 2. Kalender und Jahreszeiten

- **1 Sim-Jahr = 120 Tage**, 4 Seasons à **30 Tage**:
  - Frühling: Tag 1–30
  - Sommer: Tag 31–60
  - Herbst: Tag 61–90
  - Winter: Tag 91–120
- 1 Tag = **15 reale Minuten bei 1x**.
- 1 Jahr = 30 h bei 1x, 3 h bei 10x, 36 min bei 50x, 12 min bei 150x (B).
- 50-Jahre-Leben bei 50x = 30 h; bei 150x = 10 h.
- A nutzt 1x/10x/50x; B (separat) 150x/200x.
- **Saisonale Übergänge** (Temperatur/Niederschlag/Visuals) bleiben D-57-
  Stubs in G3; nur der Kalender und die Feldlogik sind aktiv.

## 3. Saisonale Felder

- **Ein Feld = eine Ernte pro Jahr**, kein Dauerzyklus.
- Phasen:
  - Frühling: Pflügen (20 h) und Säen (8 h).
  - Sommer: Wachstum (30 Tage).
  - Herbst: Ernte (16 h) und Einlagerung.
  - Winter: Brache.
- 40 Felder für 1.000 Agenten (4 für 100 Agenten), abgeleitet aus:
  `fields = ceil(population * 3 Mahlzeiten * 120 Tage / net_yield_per_field)`.
- Platzhalter-Balance:
  - Bruttoertrag **10.000 Grain/Feld**,
  - Saatgut **1.000/Feld**,
  - Netto **9.000/Feld**,
  - 40 Felder = 360.000 Netto-Grain/Jahr; 1.000 Agenten × 3 Mahlzeiten ×
    120 Tage = 360.000 Mahlzeiten.
  - Startgrain 90.000; Kornspeicher-Kapazität 720.000 (2 Jahre).
- Keine Ernte außerhalb des Herbstfensters; keine stille Auffüllung.
- Genaue Werte sind G3-Kalibrierung, keine finale Wirtschaft.

## 4. Welt und Bevölkerung

- Karte: **768 × 768 Tiles** (1,5 m/Tile = 1.152 × 1.152 m).
- 200–250 Wohnhäuser, 40 Felder, 3 Werkstätten, Kornspeicher, Brunnen,
  Scheune, Wege.
- **1.000 Agenten** in 200–250 Haushalten; 40 % erwerbsfähig.
- Deterministischer Generator: Haushalte, Alter, Geschlecht, Rollen, Jobs,
  Beziehungen, Namen; G1b-Lifecycle/Fertilität/Mortalität aktiv.
- Jobs: Feld, Werkstatt, Haushalt, leichte Aufgaben; kapazitätsbasiert.
- Keine Wirtschaft/Politik/Handel; Grain/Mahlzeiten bleiben G1-Umfang.

## 5. Pfadfindung, Chunks, Batching

- Lokaler A* auf Tiles, deterministische Tie-Breaks; Pfad-Cache mit
  Map-Version.
- Pfadbudget: max. 2 Neuberechnungen + 50 Lookups/Frame; Cache-Hit > 90 %.
- Chunked Terrain/Occupancy; nur aktive Chunks materialisiert.
- Event-Batching pro Sim-Zeit/Siedlung, stabile `(time, seq)`-Ordnung.
- Kein Full-Agent-Sweep pro Frame; tägliche Lifecycle-Prüfung erlaubt.

## 6. D-57-Stubs

Wetter, Feste, Religion, Kultur, Krankheit, Recht, Bildung bleiben reine
Daten-/UI-Platzhalter ohne Events/Zustand/Verbraucher/Produktion. Keine
Saison-Simulation außer Kalender/Feldlogik.

## 7. UI/Chronik

- Bestehende G1/G2-UI auf 1.000 Agenten skalieren: Inspector, Event-Log,
  Chronik-Filter, Familienbaum, Follow, Alerts, Story of the Day.
- Keine Lesezeichen/Sammlungen/Zeitleiste/Nationen-Chronik (G4/G5).
- Performance: UI p95 im Frame-Budget; keine Simulationszugriffe.

## 8. Save/Replay

- Save-Schema **6** (120-Tage-Kalender, saisonale Felder, 40 Felder,
  1k-Welt, Chronik/Retention); Schemas 1–5 sichtbar ablehnen.
- Pfad-Cache abgeleitet, nicht gespeichert.
- Save/Load mitten in Feldphase, Bewegung, Arbeit, Geburt/Tod exakt.
- Replay = Re-Simulation aus Seed + Config + Snapshot; Log-Kürzung ändert
  den Verlauf nicht.

## 9. Tests

- T-G3-01: Welt/Bevölkerung, 1.000 Agenten, 200–250 Haushalte, 40 Felder.
- T-G3-02: 120-Tage-Kalender, 4×30-Seasons.
- T-G3-03: Saisonale Felder, genau eine Ernte/Feld/Jahr, keine Winterernte.
- T-G3-04: A*/Cache/Chunking bei 1k, Pfadbudget.
- T-G3-05: Event-Batching, stabile Ordnung.
- T-G3-06: 120 Sim-Tage deterministisch, 3 Läufe.
- T-G3-07: Save/Load exakt, Schema 6, alte Schemas abgelehnt.
- T-G3-08: 1k@50x Performance, p95 ≤ 16 ms, 3 Läufe.
- T-G3-09: UI/Chronik bei 1k.
- T-G3-10: D-57 nur Stubs, keine G4-Features.
- G1a/G1b/G2-Test-IDs bleiben grün.

## 10. Abnahme

- 1.000 Agenten, 120 Sim-Tage, 3 Läufe, identische State-/Event-Hashes.
- Saisonale Felder: 40 Ernten im Herbst, 0 außerhalb; Grain-Bilanz
  nachvollziehbar.
- 1k@50x: p95 ≤ 16 ms, p99 ≤ 20 ms, 60 FPS; Sim p95 ≤ 6 ms.
- Pfad-Cache > 90 %; kein Full-Agent-Sweep.
- Save/Load exakt; Schema 6.
- Kein Leak; keine Datei > ~1.000 Zeilen.
- D-57 nur Stubs; keine G4-Features.
- G3 wird als Git-Tag `g3` gesichert.

## 11. Nicht-Ziele

- Keine 10.000 Agenten (G4), keine 100k (G5).
- Keine Wirtschaft/Politik/Handel/Karawanen (G4b/G5b).
- Keine D-57-Simulation, keine Tiere/Fantasy/Krieg.
- Keine B-Integration in A; B bleibt separater 150x-Modus.
- Keine Lesezeichen/Sammlungen/Zeitleiste/Nationen-Chronik.
