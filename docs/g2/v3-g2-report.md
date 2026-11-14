# V3 G2 — Implementierungsbericht: 100-Agenten-Bauerschaft

Status: **G2 bestanden (Review 2026-11-14); G3 bereit**  
Seed: **1337**  
Godot: **4.7.2-stable (official, ed1daf0bf)**, Standard-Build (GDScript)  
Zielplattform: Windows, 1920 × 1080, Ryzen 5 5600 / RTX 5060

---

## 1. Ergebnis

G2 implementiert die 100-Agenten-Bauerschaft auf dem unveränderten G1b-Kern:
384 × 384 Tiles, 24 Häuser, 4 Felder, Kornspeicher, Brunnen, Werkstatt,
Scheune, Wege, lokaler A* mit Pfad-Cache, Event-Batching, Save-Schema 5,
Replay und skalierte G1-UI. D-57-Systeme sind reine Daten-/UI-Stubs.

Alle T-G2-01..08 sind bestanden; die G1a-/G1b-Suiten bleiben grün. Die
Messwerte stehen in §8, die Abnahmebeurteilung in §10.

## 2. Welt- und Bevölkerungsgeneration

- `WorldMap` bleibt für G1 unverändert (128 × 128, 7 Gebäude). G2 nutzt
  `SimConfig.g2()` und `WorldMap` mit `PROFILE_G2`.
- G2-Karte: 384 × 384 Tiles, 1,5 m/Tile = 576 × 576 m.
- 24 Häuser in 6 × 4-Reihen, 4 Felder, Kornspeicher, Brunnen, Werkstatt,
  Scheune; alle Türen liegen auf dem Tile-Wegnetz.
- Statische Occupancy: Gebäude blockieren, Türen und Felder sind begehbar;
  keine dynamische Agenten-Kollision.
- `PopulationGenerator` erzeugt deterministisch 100 Agenten in 24 Haushalten:
  40 Erwerbsfähige (18–59), 40 Kinder/Jugendliche, 20 Alte; Partner-,
  Eltern-Kind-, Großeltern- und Freundschaftsbeziehungen; Jobs nach
  Kapazität/Haushalt.
- G1b-Lifecycle (Alterung, Sterblichkeit, Partnerschaft, Fertilität,
  Haushaltsauflösung) läuft unverändert weiter.

## 3. A*, Pfad-Cache, Occupancy

- `src/navigation/path_finder.gd` nutzt `AStarGrid2D` auf der Tile-Karte.
  Gebäude sind solid; Straßen erhalten eine niedrigere Gewichtung.
  Der Pfad ist bei gleichem Grid/Start/Ziel deterministisch.
- Cache-Schlüssel: `(start_tile, goal_tile, map_version)`, LRU über
  `PackedInt64Array`; Kapazität 2.048. Cache ist abgeleitet und nicht im Save.
- Frame-Budget pro festem Sim-Frame (`path_frame_ticks = 80` Ticks, entspricht
  1/60 s bei 50x): max. **2 Neuberechnungen** und **50 Pfadanfragen/Lookups**.
  Überschuss wird auf den nächsten festen Frame vertagt; die Vertagung hängt
  nicht von der `advance_to`-Chunk-Größe ab.
- Deterministisches Prewarming füllt den Cache beim Start und nach einem Load
  aus demselben autoritativen Zustand. Dadurch ist der Cache eine reine
  Beschleunigung; Save/Load bleibt exakt.
- Gemessene Cache-Hit-Rate (konsultierte Anfragen) über 30 Sim-Tage:
  **99,94 %**; anfragebezogen inklusive der 2.616 Budget-Vertagungen sind es
  87,7 %. Vertagungen sind keine Cache-Misses; sie werden im nächsten festen
  Frame bedient. 12 Laufzeit-Neuberechnungen, 0–2 Recalcs/Frame,
  max. 50 Lookups/Frame.

## 4. Event-Batching

- `EventBatcher` bündelt alle fälligen Scheduler-Events derselben Sim-Zeit.
  Dispatch bleibt strikt `(time, seq)`; keine Dictionary- oder Heap-Reihenfolge.
- Kein Full-Agent-Sweep pro Frame. Die tägliche Lifecycle-/Geburtstagsprüfung
  läuft als Tages-Tick.
- 30-Tage-Lauf: 59.522 Scheduler-Events in 18.035 Batches; max. Batch 102,
  p95-Batch 4; `out_of_order = 0`.

## 5. D-57-Stubs

`src/data/d57_stubs.gd` enthält Wetter, Feste, Religion, Kultur, Krankheit,
Recht und Bildung als reine Daten-/UI-Platzhalter:

- keine Events, keine Zustandsänderung, keine Verbraucher, keine Produktion,
- keine Referenz aus `Simulation`, `DecisionSystem` oder `LifecycleSystem`,
- HUD zeigt die Stub-Zeile nur im G2-Profil.

## 6. Save/Load/Replay und Schema 5

- `SimConfig.SCHEMA_VERSION = 5`, `SimSave.SCHEMA_VERSION = 5`.
- Schema 1–4 und 999 werden sichtbar mit `unsupported_schema` abgelehnt;
  falsche Magic → `bad_magic`, Config-Hash → `config_hash_mismatch`.
- Gespeichert werden Clock, Scheduler, RNG, 100 Agenten-SoA, Records,
  Haushalte, Beziehungen, 4 Feldzustände, Routen, Logs/Chronik und
  Replay-Metadaten. Der Pfad-Cache wird **nicht** gespeichert und nach dem
  Load deterministisch neu aufgebaut.
- Save/Load mitten in Bewegung/Arbeit/Lifecycle ist exakt; Fortsetzung mit
  unterschiedlichen Chunks ergibt identische State-/Event-/Chronik-Hashes.
- Replay = Re-Simulation aus Seed + Konfiguration + Save-Snapshot; das Kürzen
  von Debug-/Chronik-Logs ändert den Verlauf nicht.

## 7. Test-IDs

| ID | Ergebnis | Kernprüfung |
|---|---|---|
| T-G2-01 | **bestanden** | 384er-Welt, 24 Häuser, 4 Felder, 100 Agenten, 24 Haushalte, 40 Erwerbsfähige, deterministisch |
| T-G2-02 | **bestanden** | A* deterministisch, Occupancy, Cache-Hit > 90 %, 2 Recalcs/50 Lookups pro Frame |
| T-G2-03 | **bestanden** | Batching, stabile Ordnung, keine Per-Frame-Sweeps |
| T-G2-04 | **bestanden** | 30 Sim-Tage, 3 Läufe, identische Hashes |
| T-G2-05 | **bestanden** | Save/Load exakt, Schema 5, 1–4 abgelehnt, Replay |
| T-G2-06 | **bestanden** | 100@50x, Sim p95 ≤ 6 ms, Gesamtframe p95 ≤ 16 ms |
| T-G2-07 | **bestanden** | Inspector/Chronik/Familienbaum/Follow bei 100 Agenten |
| T-G2-08 | **bestanden** | D-57 nur Stubs, keine G3-Features, Dateigrenzen |

G1a: **29/29** (265 Checks), G1b: **28/28** (792 Checks), nach den
G2-Anpassungen der Schema-/Scope-Prüfungen. Die G1a-/G1b-Verhaltens- und
Determinismusprüfungen bleiben aktiv. G1a-visuell: Frame-p95 3,95 ms,
FPS 484; G1b-Jahreslauf: Frame-p95 3,75 ms, FPS 482, 30,0 Sim-Tage,
Geburt und Tod sichtbar.

## 8. Messwerte

### 8.1 30-Sim-Tage-Determinismus (Seed 1337)

| Lauf | Chunk | State | Event | Chronik | Alive |
|---|---|---:|---|---|---:|
| 1 | 80 s | 0x3A4C63E5 | 0xE22AF525 | 0x0DF2BE26 | 104 |
| 2 | 3600 s | 0x3A4C63E5 | 0xE22AF525 | 0x0DF2BE26 | 104 |
| 3 | 86400 s | 0x3A4C63E5 | 0xE22AF525 | 0x0DF2BE26 | 104 |

### 8.2 Headless 100@50x (5-Minuten-Fenster, 18.000 Frames, 3 Läufe)

| Lauf | Sim p50 | Sim p95 | Sim p99 | Events/Frame |
|---|---:|---:|---:|---:|
| 1 | 0,001 ms | 0,791 ms | 8,270 ms | 1,82 |
| 2 | 0,001 ms | 0,798 ms | 8,094 ms | 1,82 |
| 3 | 0,001 ms | 0,797 ms | 8,217 ms | 1,82 |

Sim-p95 ≤ 6 ms in allen drei Läufen; Cache-Hit 100 %, max. 0 Recalcs/Frame,
max. 50 Lookups/Frame, 1.624 Vertagungen.

### 8.3 Visuell 100@50x (5 Minuten, 3 Läufe)

| Lauf | Frame p50 | Frame p95 | Frame p99 | Render p95* | FPS | Draw Calls Ø |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 1,519 ms | **3,655 ms** | 9,418 ms | 3,614 ms | 503,4 | 239,8 |
| 2 | 1,496 ms | **3,431 ms** | 8,179 ms | 3,385 ms | 522,4 | 240,1 |
| 3 | 1,489 ms | **3,474 ms** | 8,188 ms | 3,417 ms | 520,2 | 239,3 |

\* Render-p95 ist die konservative Obergrenze `Frame - gemessene Sim-Zeit`
(enthält Render, UI, Engine und Idle). Sim-p95 lag in allen Läufen bei
0,007–0,008 ms; die 5-Minuten-Fenster decken 16,7 Sim-Tage ab (18,3 inkl.
30 s Warm-up).

### 8.4 Sichtbarer 30-Tage-Lauf

- 30,0 Sim-Tage bei 50x, 59.522 Events, 104 lebende Agenten, 106 Records,
  Frame-p95 4,68 ms, 440 FPS Ø.
- Screenshots: `bench/results/g2_30days_day01.png`,
  `g2_30days_day15.png`, `g2_30days_day30.png`; sichtbar sind Inspector,
  Event-Log, Story of the Day, Alerts und die kuratierte Chronik.

### 8.5 Save/Load

| Messwert | Wert |
|---|---:|
| Schema | 5 |
| Save-Größe (Tag 12, 17:00) | ca. 1,92 MB (davon Debug-Log-Ringpuffer) |
| Save-Zeit | ca. 100 ms |
| Load-Zeit inkl. Welt-/Cache-Aufbau | ca. 448 ms |
| Load exakt | State/Chronik/Fortsetzung identisch |
| Pfad-Cache im Save | nein |

## 9. Geänderte/erstellte Dateien

**Produktion**

- `src/data/sim_config.gd` — G2-Profil, Schema 5, Pfad-/Frame-Parameter
- `src/world/world_map.gd` — G2-Siedlung, Gebäude-IDs, Felder, Wege
- `src/world/building.gd` — Scheune (`KIND_BARN`)
- `src/agents/population_generator.gd` — 100 Agenten / 24 Haushalte
- `src/agents/simulation.gd` — Profil-Setup, Batching, Prewarming, 4 Felder
- `src/agents/agent_store.gd` — `defer_until` für deterministische Pfadvertagung
- `src/agents/lifecycle_system.gd` — unverändert, weiter aktiv
- `src/decisions/decision_system.gd` — A*/Cache-Dispatch, mehrere Felder
- `src/navigation/path_finder.gd` — AStarGrid2D, LRU-Cache, Budgets
- `src/navigation/route_store.gd` — Routen-Kompaktierung
- `src/kernel/event_batcher.gd` — Batch-Messung/Ordnung
- `src/data/d57_stubs.gd` — D-57-Platzhalter
- `src/persistence/sim_save.gd` — Schema 5, vier Felder, Profilfelder
- `src/view/world_view.gd` — 384er-Terrain, 4 Felder, Sicht-Culling
- `src/view/game_camera.gd`, `src/view/demo_main.gd`, `src/view/hud.gd`,
  `src/view/chronicle_hud.gd`, `src/view/family_tree_view.gd` — UI-Skalierung

**Tests/Doku**

- `tests/g2/` — G2-Suite, T-G2-01..08, visueller 5-Minuten-Benchmark,
  sichtbarer 30-Tage-Lauf, Demo
- `tests/g1a/test_move.gd`, `tests/g1a/test_save.gd` — G1-Schema-/Scope-
  Erweiterung (keine Abschwächung)
- `tests/g1b/test_review.gd` — Schema 5, G3-Abgrenzung
- `docs/g2/README.md`, `docs/g2/v3-g2-report.md`
- `bench/results/g2_visual_run1..3.json`, `g2_30days_result.json`,
  `g2_30days_day01/15/30.png`

Hinweis: `README.md` und `docs/v3-plan.md` waren bereits vor G2 lokal geändert
(G2-Statusvermerk); G2 hat diese Dateien nicht angefasst. Es wurden keine
Commits/Pushes erstellt.

## 10. Bekannte Grenzen

1. G2 ist kein 1k-/100k-Gate; es gibt keine Wirtschaft/Politik/Handel.
2. D-57-Systeme sind ohne Simulationseffekt; es gibt keine Wetter-/Krankheits-
   oder Rechtsmechanik.
3. Es gibt keine dynamische Agenten-Kollision; nur statische Tile-Occupancy.
4. A* ist lokal auf der Tile-Karte; Fernreisen/regionaler Graph sind nicht Teil
   von G2. Das Rendering zeichnet nur den sichtbaren Kartenausschnitt
   (Offscreen-Culling); die Simulation selbst wird nicht gefiltert.
5. Pfad-Prewarming kostet beim Start/Load ca. 0,4 s; der Cache bleibt abgeleitet.
6. Der Debug-Log-Ringpuffer (20.000 Events) dominiert die Save-Größe; die
   kuratierte Chronik ist deutlich kleiner.
7. Die 5-Minuten-Performance gilt bei 50x und 1920 × 1080; andere Fenster/
   Zoomstufen sind nicht Teil der Abnahme.
8. Der sichtbare 30-Tage-Lauf dient der UI-/Chronik-Beobachtung; die harte
   Determinismus-Abnahme läuft headless.

## 11. Abnahmebeurteilung

**Review-Ergebnis: G2 bestanden mit G3-Auflagen.** Alle T-G2-01..08 sind grün,
die G1a-/G1b-Suiten bleiben grün, 30 Sim-Tage sind über drei unterschiedliche
Frame-Aufteilungen bitgleich, Save/Load ist exakt mit Schema 5, der Pfad-Cache
liegt über 90 %, und D-57 bleibt ein wirkungsloser Stub.

## 12. Review-Verifikation (2026-11-14)

Unabhängig vom Implementierungslauf ausgeführt:

- G1a: **29/29**, 265 Checks; G1b: **28/28**, 792 Checks; G2: **21/21**,
  233 Checks.
- 30 Sim-Tage, 3 Läufe: State `0x3A4C63E5`, Event `0xE22AF525`, Chronik
  `0x0DF2BE26`; 104 lebend, 59.522 Events.
- Performance 100@50x: Frame-p95 **3,43–3,65 ms**, Sim-p95 **0,82–0,92 ms**,
  Sim-p99 8,5–9,8 ms, 503–522 FPS, 240 Draw Calls.
- Pfad-Cache: 100 % Laufzeit-Hits, 87,7 % Request-Hit inkl. Vertagungen;
  0 Laufzeit-Recalcs, max. 2 Recalcs/50 Lookups pro Frame.
- Batching: 18.035 Batches, max. 102, p95 4, out_of_order 0.
- Save: 1.916.165 Bytes, Save 109 ms, Load 508 ms.
- Screenshots Tag 1/15/30 geprüft: 24 Häuser, 4 Felder, 100+ Agenten,
  Chronik/Story/Alerts; UI dicht, aber funktional.
- Keine Leak-/Fehler-Warnhinweise in den geprüften Logs.

**G3-Auflagen:**

1. **Save-Größe:** Der nicht-autoritative Debug-Log (20.000 Events) dominiert
   das 1,9-MB-Save. Vor G3 den Debug-Log vom Save entkoppeln oder hart
   begrenzen; G1b-Save/Load-Tests auf `state_hash`/`chronicle_hash` umstellen
   und ein Save-Größenbudget setzen.
2. **P99/Batch-Spikes:** Sim-p99 liegt bei 8,5–9,8 ms; bei 1k die Batch- und
   Pfadspitzen erneut messen und budgetieren.
3. **UI-Polish:** Panels überlappen die Karte; für 1k einen ruhigeren
   Beobachtungsmodus prüfen.
4. **Dynamik:** Dynamische Kollision und regionaler Graph bleiben spätere
   Gates; G2 nutzt statische Occupancy und lokale A*.
