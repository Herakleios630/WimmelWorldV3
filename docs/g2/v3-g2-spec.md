# V3 G2 — Spezifikation: 100-Agenten-Bauerschaft

Status: G2-Spezifikation, Entwurf  
Stand: 2026-11-14  
Bezug: `docs/v3-plan.md`, `docs/v3-architecture.md`, `docs/v3-data-model.md`, `docs/v3-benchmark.md`.

## 1. Ziel

G2 skaliert den bestandenen G1-Kern von 10 auf **100 Agenten** und beweist:

- deterministische 100-Agenten-Simulation über **30 Sim-Tage**,
- lokale Pfadfindung mit A* und Cache,
- Event-Batching ohne Full-Agent-Sweep pro Frame,
- Save/Load und Replay bei 100 Agenten,
- **100 Agenten @50x, 60 FPS, p95 ≤ 16 ms** auf Zielhardware.

G2 ist **kein** 1k-/100k-Gate. D-57-Systeme bleiben Stubs ohne Simulationseffekt.

## 2. Welt

- Karte: **384 × 384 Tiles** bei 1,5 m/Tile = **576 × 576 m**.
- Deterministische prozedurale Bauerschaft aus Seed.
- 20–25 Wohnhäuser, 4 Felder, 1 Kornspeicher, 1 Brunnen, 1 Werkstatt,
  1 Scheune, Wege zwischen allen Gebäuden.
- Statische Occupancy: Gebäude blockieren, Türen begehbar; keine dynamische
  Agenten-Kollision in G2.
- Kein zweites Settlement, keine Nation, keine Wirtschaftsketten.

## 3. Bevölkerung

- **100 Agenten** in 20–25 Haushalten.
- Deterministischer Generator: Haushalte, Alter, Geschlecht, Rollen, Jobs,
  Startbeziehungen, Namen.
- Altersverteilung: Kinder, Jugend, Erwachsene, Alte; mindestens 20
  Erwerbsfähige.
- Jobs: Feldarbeit, Werkstatt, Haushalt/Kochen, leichte Aufgaben; kapazitäts-
  und haushaltsbasiert.
- Bestehende G1b-Lifecycle-/Fertilitäts-/Mortalitätsregeln gelten weiter.
- Keine G2-Politik/Wirtschaft; Grain, Mahlzeiten und Felder bleiben G1-Umfang.

## 4. Pfadfindung und Bewegung

- Lokaler **A*** auf der Tile-Karte; deterministische Nachbar-/Tie-Break-
  Ordnung.
- Pfad-Cache: Schlüssel `(start_tile, goal, map_version)`, LRU/DRU,
  Cache-Hit-Rate > 90 % für wiederkehrende Ziele.
- Pfadaufrufe pro Frame budgetiert: höchstens **2 Neuberechnungen** und
  **50 Cache-Lookups**; Überschuss wird deterministisch vertagt.
- `position_at(time)` bleibt zeitbasiert; Ankunft exakt zum Termin.
- Kein Full-Agent-Sweep pro Frame; Pfad-Cache ist abgeleitet und wird nicht
  gespeichert.

## 5. Event-Batching

- Fällige Events werden pro Sim-Zeit/Siedlung gebündelt und in stabiler
  `(time, seq)`-Ordnung verarbeitet.
- Batch-Größen und p95 werden gemessen; keine Batch darf die Framezeit
  sprengen.
- Tägliche Lifecycle-/Geburtstagsprüfung ist erlaubt (100 Agenten/Tag), aber
  kein Per-Frame-Sweep.

## 6. D-57-Stubs

Nur Daten-/UI-Platzhalter ohne Simulationseffekt:

- Wetter, Feste, Religion, Kultur, Krankheit, Recht, Bildung.
- Keine Events, keine Zustandsänderung, keine Verbraucher, keine Produktion.
- Stub-Definition aus `docs/v3-architecture.md` §2.2.
- Keine D-57-Simulation in G2.

## 7. UI

- Bestehende G1-UI skaliert auf 100 Agenten: Inspector, Event-Log, Chronik,
  Familienbaum, Follow, Alerts, Story of the Day.
- Keine Lesezeichen/Sammlungen/Zeitleiste (G3/G5).
- Performance: UI bleibt unter Frame-Budget; Chronik-Filter dürfen die
  Simulation nicht ausbremsen.

## 8. Save/Replay

- Save-Schema **5** (100-Agenten-Welt, Haushalte, Jobs, Beziehungen,
  Chronik/Retention, Replay-Metadaten); Schema 1–4 sichtbar ablehnen.
- Pfad-Cache ist abgeleitet und nicht im Save.
- Save/Load mitten in Bewegung, Arbeit, Geburt/Tod und Chronik exakt.
- Replay = Re-Simulation aus Seed + Konfiguration + Save-Snapshot; Log-Kürzung
  ändert den Verlauf nicht.

## 9. Tests

- T-G2-01: Welt-/Bevölkerungsgeneration, 100 Agenten, 20–25 Haushalte.
- T-G2-02: A*, Pfad-Cache, Occupancy, deterministische Pfade.
- T-G2-03: Event-Batching, stabile Ordnung, Batch-Größen.
- T-G2-04: 30 Sim-Tage deterministisch, 3 Läufe.
- T-G2-05: Save/Load exakt, Schema 5, alte Schemas abgelehnt.
- T-G2-06: 100@50x Performance, p95 ≤ 16 ms, 3 Läufe.
- T-G2-07: UI/Inspector/Chronik bei 100 Agenten.
- T-G2-08: D-57 nur Stubs, keine G3-Features.
- Alle G1a-/G1b-Test-IDs bleiben grün.

## 10. Abnahme

- **Funktional:** 100 Agenten, 30 Sim-Tage headless/full-speed, 3 Läufe,
  identische State-/Event-Hashes. Ein sichtbarer 30-Tage-Lauf bei 50x (9 min)
  dient der UI-/Chronik-Abnahme.
- **Performance:** 5-Minuten-Fenster bei 50x, 3 Läufe; p95 ≤ 16 ms,
  p99 ≤ 20 ms, 60 FPS; Sim p95 ≤ 6 ms, Render p95 ≤ 6 ms.
- Pfad-Cache-Hit > 90 %; Pfadaufrufe/Frame im Budget.
- Save/Load exakt; Schema 5.
- Kein Leak-Warnhinweis.
- Keine Datei > ~1.000 Zeilen.
- D-57 nur Stubs; keine G3-Features.

## 11. Nicht-Ziele

- Keine 1.000 Agenten (G3), keine 10k/100k.
- Keine Wirtschaft/Politik/Handel/Karawanen (G4b/G5b).
- Keine D-57-Simulation, keine Tiere/Fantasy/Krieg.
- Keine Lesezeichen/Sammlungen/Zeitleiste/Nationen-Chronik.
- Keine Änderung an G0-/G1-Entscheidungen.
