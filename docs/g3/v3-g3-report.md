# V3 G3-A — Bericht: 1000-Agenten-Kleinstadt, 120-Tage-Jahr, saisonale Felder

Status: **G3-A bestanden (Suite 13/13, 235 Checks, Startgrain 360.000).**  
Stand: 2026-11-14  
Bezug: `docs/g3/v3-g3-spec.md`, `docs/v3-plan.md` (D-65/D-66/D-67),
`docs/v3-architecture.md`, `docs/v3-data-model.md`, `docs/v3-benchmark.md`,
`docs/g2/v3-g2-report.md`, `docs/g3/v3-g3-b-spike-report.md`.

Gemessen auf: Windows, AMD Ryzen 5 5600 (6C/12T), Godot **4.7.2-stable**
(Standard-Build, GDScript), Seed **1337**.

---

## 1. Ergebnis

- 1000 Agenten in 225 Haushalten, 224 Wohnhäuser, 40 Felder, 3 Werkstätten,
  Kornspeicher, Brunnen, Scheune, Wege und deterministischer Chunk-Index.
- 120-Tage-Jahr mit 4×30-Tage-Seasons. G1/G2 bleiben beim 30-Tage-Jahr,
  ganzjährigem Feldzyklus und Save-Schema 5.
- G3: eine Ernte pro Feld und Jahr; Frühling pflügen/säen, Sommer wachsen,
  Herbst ernten, Winter Brache. Im 120-Tage-Lauf **40 Herbsternten, 0 außerhalb**.
- A*/Pfad-Cache/Chunking unter 1k; max. 2 Recalcs und 50 Lookups pro Frame;
  deterministische Defer-Warteschlange; kein Full-Agent-Sweep.
- Save-Schema **6** für G3; Schema 1–5 werden sichtbar abgelehnt; der
  Pfad-Cache wird nicht gespeichert.
- D-57 bleibt bei sieben Stubs ohne Events/Zustand/Verbraucher/Produktion.
- Keine G4-, Wirtschafts-, Politik-, Handels- oder B-Integration in A.

Die Messwerte und die endgültige Abnahme stehen in den Abschnitten 5–10.

---

## 2. Geänderte/erstellte Dateien

**Produktion:**

- `src/data/sim_config.gd` — G3-Profil, Kalender-/Season-Helfer,
  Saatgut-/Granary-/Feldbalance, profilabhängiges Save-Schema.
- `src/world/world_map.gd` — 768×768-Layout, 224 Häuser, 40 Felder,
  3 Werkstätten, Chunk-Index.
- `src/world/building.gd` — saisonale Feldzustände (crop_year,
  harvested_year, shortage_day).
- `src/agents/population_generator.gd` — G3-Generator 1000/225.
- `src/agents/simulation.gd` — G3-Setup, Prewarm, Jahreswechsel, Zähler,
  Save-/Load-Cacheprotokoll, State-Hash.
- `src/agents/lifecycle_rules.gd`, `src/agents/lifecycle_system.gd` —
  kalenderabhängiges Alter (120 Tage).
- `src/decisions/decision_system.gd` — saisonale Feldlogik, Rollenjitter,
  G3-Routinepläne, Bedarfs-Wake-Optimierung.
- `src/decisions/role_schedule.gd` — G3-Pläne mit 90-Minuten-Mahlzeiten.
- `src/navigation/path_finder.gd` — O(1)-Cache-Hit, deterministische
  Defer-Warteschlange.
- `src/persistence/sim_save.gd` — Schema 6, G3-Felder/Zähler.
- `src/kernel/sim_logs.gd` — amortisierte Ringpflege.
- `src/kernel/sim_event.gd`, `src/chronicle/chronicle_curator.gd`,
  `src/chronicle/chronicle_store.gd` — Saatgut-Event, Klassifikationscache,
  Dedup-Index, G3-Routineaggregation.
- `src/view/world_view.gd` — Render-LOD für 1k (Marker/Labels).
- `src/view/hud.gd`, `src/view/demo_main.gd` — G3-Kalender/Grain/Gate.

**Tests/Doku:**

- `tests/g3/g3_a_suite.gd`, `g3_a_suite.tscn`, `g3_a_test_util.gd`.
- `tests/g3/test_g3_01_world.gd` … `test_g3_10_scope.gd`.
- `tests/g3/bench_visual.gd/.tscn`, `visual_120days.gd/.tscn`,
  `g3_demo_main.gd`, `demo.tscn`.
- `docs/g3/v3-g3-spec.md` (Startgrain-Kalibrierung 360.000),
  `docs/g3/v3-g3-report.md`, `docs/g3/README.md`.

**Nicht verändert:** `src/lod/`, `tests/g3/g3_suite.*`, `tests/g3/test_b_*`,
G0-Dokumente, Root-`README.md`, `docs/v3-plan.md`. Keine Commits/Pushes.

**Hinweis D-65:** `docs/v3-plan.md` nennt im historischen D-65-Nachtrag
weiterhin den ursprünglichen 90.000-Startgrain. Die Kalibrierung auf 360.000
ist hier, in `docs/g3/v3-g3-spec.md` und in den G3-Tests dokumentiert; eine
Plan-Änderung war per Scope ausgeschlossen und bleibt dem Reviewer vorbehalten.

**Review-Hinweis Dateiliste:** Über die enge G3-Dateiliste hinaus wurden
`src/chronicle/chronicle_store.gd`, `src/chronicle/chronicle_curator.gd`,
`src/view/biography_model.gd`, `src/view/chronicle_panel_model.gd` und
`src/kernel/sim_logs.gd` angepasst. Ohne Dedup-/Agent-Index, Klassifikations-
cache und amortisierte Ringpflege sind Chronik/UI und 120-Tage-Läufe bei 1k
nicht innerhalb der Budgets prüfbar. Die Änderungen sind abgeleitete
Caches/Ringpflege und verändern keine fachlichen Regeln; G1/G2 bleiben grün.

---

## 3. Kalender, Feldmodell, Balance

### 3.1 Kalender

| Profil | Jahr | Seasons | Feldfenster | Save |
|---|---:|---|---|---:|
| G1/G2 | 30 Tage | historische Anzeige | ganzjähriger G1b-Zyklus | 5 |
| G3 | 120 Tage | 4×30 Tage | Frühling pflügen/säen, Sommer wachsen, Herbst ernten, Winter Brache | 6 |

G3-Season-Index: `day_of_year / 30` (0–3); Herbststart ist Tag 61 des Jahres.
Der Lebenszyklus behält 6 Rollen pro Jahr; das Roll-Intervall wird von 5 auf
20 Tage gestreckt, damit Jahressterblichkeit/-fertilität und RNG-Konsum pro
Jahr vergleichbar bleiben.

### 3.2 Feldmodell

- Ein Feld hat genau eine Ernte pro Jahr; `field_crop_year` und
  `field_harvested_year` verhindern Zweitaussaat/-ernte.
- Aussaat kostet 1000 Grain, Ernte liefert 10000 Grain brutto (9000 netto).
- Wachstum endet zum Herbststart; Ernte ist nur im Herbst erlaubt.
- Nach der Ernte ist das Feld bis zum nächsten Frühling Brache.
- G1/G2 behalten den bisherigen ganzjährigen Zyklus (`seasonal_fields=false`).

### 3.3 Platzhalter-Balance (G3)

| Posten | Wert |
|---|---:|
| Startgrain | 360.000 |
| Saatgut/Feld | 1.000 |
| Brutto/Feld | 10.000 |
| Netto/Feld | 9.000 |
| Felder | 40 |
| Granary-Kapazität | 720.000 |
| Mahlzeit | 1 Grain |

Der Jahres-Steady-State ist 360.000 + 400.000 − 40.000 − 360.000 = 360.000.
360.000 Startgrain sind ein voller Jahresvorrat für 1.000 Agenten ×
3 Mahlzeiten × 120 Tage; die Ernte im Herbst refinanziert Saatgut und
Folgejahr. Es wird nichts still aufgefüllt. Gemessen: 360.693 Mahlzeiten,
0 Skips, 1.040 Lebende, Grain 359.307 (Details in Abschnitt 9).
Alle 40 Felder sind ab Tag 61 erntereif; bis Tag 71 sind alle 40 Ernten
abgeschlossen, keine außerhalb des Herbstes.

---

## 4. 1k-Welt, Population, Pfad, Chunking

### 4.1 Welt

- 768×768 Tiles; 224 Häuser in 14×16-Reihen, 40 Felder (5×8 à 24×24),
  3 Werkstätten, Kornspeicher, Brunnen, Scheune, Wegnetz.
- Alle Haustüren liegen auf Wegen; Gebäude blockieren, Felder nicht.
- Chunk-Größe 32; 24×24 Chunks; 338 bebaute/belegte Chunks materialisiert
  (deterministisch aus Gebäuden/Wegen/Feldern, nicht aus Kamera/Sichtbarkeit).

### 4.2 Population

- Exakt 1000 Agenten in 225 Haushalten.
- 405 Agenten (40,5 %) im erwerbsfähigen Alter 18–59.
- 225 Haushaltsvorstände, 180 Partner, 495 Kinder/Jugendliche, 100 Alte.
- Rollen: Kind/Jugend/Erwachsen/Alt; Jobs: Feld, Werkstatt, Haushalt, leicht.
- 2860 Beziehungen (Partner, Eltern/Kind, Großeltern, Freunde).
- G3-Pendelziele (Home ↔ Feld/Werkstatt/Plaza/Brunnen) werden beim
  Start/Load deterministisch vorgewärmt (7510 Pfade).

### 4.3 Pfad/Cache/Budget

- A* auf 768×768-Tiles; Cache-Kapazität 16384; O(1)-Hit über Last-Used-Ticks.
- Max. 2 Recalcs und 50 Lookups pro 80-Sekunden-Pfadframe.
- Deferrals werden über ein 32-Frame-Fenster verteilt, statt im nächsten Frame
  alle gleichzeitig zurückzukehren.
- Kein Full-Agent-Sweep pro Frame; Agenten laufen über den Scheduler.

### 4.4 G3-Routine

G3 nutzt eigene Rollenpläne mit 90-Minuten-Mahlzeitenfenstern und einen
deterministischen 0–89-Minuten-Jitter pro Agent/Transition. Dadurch werden
die 6-/7-/8-/13-/17-Uhr-Bursts über viele Frames gespreizt, ohne die
G1/G2-Pläne zu verändern. Die Aggregation von Routine-Events an der Quelle
und ein Dedup-Index halten die Chronik bei 1k beherrschbar.

---

## 5. Test-ID-Ergebnisse

| ID | Ergebnis | Kern |
|---|---|---|
| T-G3-01 | PASS | 768×768, 224 Häuser, 40 Felder, 3 Werkstätten, 1000/225 |
| T-G3-02 | PASS | 120 Tage, 4×30 Seasons, G1/G2 unverändert |
| T-G3-03 | PASS | 40 Herbsternten, 0 außerhalb, ein Feld = eine Ernte |
| T-G3-04 | PASS | A*/Cache/Chunking, 2 Recalcs + 50 Lookups/Frame |
| T-G3-05 | PASS | Batchordnung, 80/3600/86400 identisch |
| T-G3-06 | PASS | 120 Tage, 3 Läufe, Chunks 1/60/3600 identisch |
| T-G3-07 | PASS | Save/Load exakt, Schema 6, 1–5 abgelehnt |
| T-G3-08 | PASS | 1k@50x, 5-Minuten-Fenster, 3 Läufe |
| T-G3-09 | PASS | Inspector/Event-Log/Chronik/Familienbaum/Follow bei 1k |
| T-G3-10 | PASS | D-57-Stubs, keine G4-/B-Integration, Dateigrenze |
| G1a/G1b/G2 | PASS | Regression unverändert grün |

Auszug Navigation (120-Tage-Lauf):
Requests 832.162, Cache-Hits 763.246 (Cache-Hit 99,89 %, Request-Hit 91,72 %),
833 Recalcs, 68.083 Deferrals, max. 50 Lookups/2 Recalcs pro Frame,
Cache-Größe 8.036. Batching Tag 1: 5.374 Batches, 15.250 Events,
max. Batch 257, Batch-p95 9, `out_of_order=0`; mit Chunks 80/3600/86400
identisch.

Die konkreten Laufausgaben stehen in `bench/results/g3_a_suite.log` bzw. in
den Abschnitten 6–8.

---

## 6. 120-Tage-Determinismus

Drei Läufe, Seed 1337, Chunks 1/60/3600, identischer Save-Snapshot in der
Feldphase (Tag 61, 09:10). State-/Event-/Chronik-Hashes sind über alle drei
Läufe identisch.

| Lauf | Chunk | State | Event | Chronik | Lebend | Ernten |
|---|---:|---|---|---|---:|---:|
| 1 | 1 | `0x5D49B80C` | `0x92367DFC` | `0xA09E0CBF` | 1.040 | 40 |
| 2 | 60 | `0x5D49B80C` | `0x92367DFC` | `0xA09E0CBF` | 1.040 | 40 |
| 3 | 3600 | `0x5D49B80C` | `0x92367DFC` | `0xA09E0CBF` | 1.040 | 40 |

---

## 7. 1k@50x Performance

Headless, 1800 Warm-up-Frames + 18000 Messframes, 3 Läufe. Die
5-Minuten-Fenster der visuellen Läufe werden separat ausgewiesen.

| Lauf | Sim p50 | Sim p95 | Sim p99 | Sim max | Events/Frame | Cache-Hit |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0,516 ms | 4,791 ms | 9,569 ms | 127,992 ms | 15,62 | 99,74 % |
| 2 | 0,518 ms | 4,840 ms | 9,814 ms | 126,336 ms | 15,62 | 99,74 % |
| 3 | 0,512 ms | 4,754 ms | 9,678 ms | 126,253 ms | 15,62 | 99,74 % |

Die einzelnen Sim-Maxima sind einzelne Lifecycle-/Tagesgrenzen-Spitzen
(1 Frame je Lauf), keine dauerhafte Last. p95 bleibt unter 6 ms, p99 unter
10 ms. Die 5-Minuten-Fenster decken jeweils 18,3 Sim-Tage ab.

### 7.1 Visuelle 5-Minuten-Fenster (1000@50x, je 18,33 Sim-Tage)

| Lauf | Frame p50 | Frame p95 | Frame p99 | Sim p95 | Render p95 | FPS | Draw Calls avg |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2,49 ms | 4,48 ms | 7,65 ms | 1,01 ms | 4,12 ms | 329,3 | 115,6 |
| 2 | 2,50 ms | 4,52 ms | 7,66 ms | 1,02 ms | 4,13 ms | 328,1 | 115,4 |
| 3 | 2,46 ms | 4,51 ms | 7,69 ms | 0,99 ms | 4,12 ms | 331,4 | 115,2 |

Alle drei Läufe erfüllen Frame-p95 ≤ 16 ms, Frame-p99 ≤ 20 ms, Sim-p95 ≤ 6 ms,
Render-p95 ≤ 6 ms und ≥ 55 FPS. Jeder Lauf hat genau eine einzelne
Maximal-Spitze (Lifecycle-/Tagesgrenze, ca. 414–459 ms Frame bzw. 145–149 ms
Sim); sie liegt außerhalb von p99 und ist als bekannte Grenze dokumentiert.
Die Visual-LOD (Marker statt Figuren/Labels ab weitem Zoom, reduzierte
Gebäude-/Baumdetails) verändert nur die Darstellung, nie die Simulation.
Sim p50 liegt bei 0,004–0,005 ms, Render p50 bei 2,32–2,35 ms.

### 7.2 Sichtbarer 120-Tage-Smoke (5-Minuten-Fenster ab Tag 55)

`tests/g3/visual_120days.tscn` spult headless bis Tag 55 vor und zeigt dann
Sommerwachstum, Herbstbeginn und die Ernten bei 50x. Ergebnis:
**PASS**, 4 Screenshots (`g3_120days_day56/61/66/71.png`), 40 Herbsternten,
Saatgut 40.000, Grain 509.039, 1.019 Lebende an Tag 72, Frame-p95 4,83 ms,
284,9 FPS. Die Screenshots liegen in `bench/results/`.

---

## 8. Save/Load/Schema 6

- G3-Save: Schema 6, 4.085.116 Bytes, Save 164,0 ms (ohne deterministischen
  Cache-Rebuild), Load 3.071 ms inkl. Prewarm/Chunk-Neuaufbau.
- Snapshot: Tag 61 (1-basiert), 09:10, Feldphase/Bewegung; 1023 Records.
- Snapshot in der Feldphase (Tag 61, 09:10) mit Bewegung; Felder nicht alle
  Brache, Agenten in Reise.
- Load rekonstruiert den Pfad-Cache deterministisch; der Cache selbst ist
  nicht im Save.
- Fortsetzung über 3 Tage ist exakt (State/Event/Chronik) und chunkunabhängig.
- Schema 1–5 und ungültige Header werden sichtbar abgelehnt.
- G1/G2 bleiben bei Schema 5.

### 8.1 Speicher/Leaks

Zwei vollständige G3-Aufbau-/12-h-Läufe mit Freigabe:
`OS.get_static_memory_usage()` nach Zyklus 1 = 38.526.291 B, nach Zyklus 2 =
38.526.487 B, also **+196 B** zwischen den Zyklen (einmaliger Engine-/Cache-
Aufbau ca. 0,5 MB). Prozess-Peak im 360k-Lauf ca. 122 MB. Kein
per-Zyklus-Leak beobachtet.

---

## 9. Bekannte Grenzen

1. **Startgrain-Kalibrierung:** 360.000 Startgrain decken den Jahresvorrat
   (1.000 × 3 × 120 = 360.000 Mahlzeiten) und die 40.000 Saatgut ab; die
   Herbsternte refinanziert das Folgejahr. Im 120-Tage-Lauf: 360.693
   Mahlzeiten, **0 übersprungene Mahlzeiten**, **1.040 Lebende** am
   Jahresende (inkl. Geburten), Grain 359.307, Saatgut 40.000, Bruttoernte
   400.000, keine Ernte außerhalb des Herbstes. Es wird nichts still
   aufgefüllt.
2. **G3-Routinejitter:** G3-Pläne und Jitter sind neue, deterministische
   G3-Parameter. Sie verändern keine G1/G2-Pläne, sind aber noch keine finale
   Tagesrhythmus-Balance.
3. **Granary-/Saatgutlogik:** Saatgut wird beim Abschluss der Aussaat
   abgezogen; eine echte Aussaat-Reservierung/Wirtschaft gibt es nicht.
4. **Chunking:** Der Chunk-Index materialisiert bebaute/belegte Chunks
   deterministisch; es ist kein kameraabhängiges Streaming und keine
   LOD-Simulation.
5. **Pfad-Cache:** Der Cache ist abgeleitet und wird vor Save/Load
   deterministisch neu aufgebaut; Save/Load exakt gilt für diesen
   Rebuild-Vertrag.
6. **UI:** Render-LOD reduziert Labels bei weitem Zoom; das ist reine
   Darstellung, keine Simulationsfilterung.
7. **B-Spike:** `src/lod/` und `tests/g3/g3_suite.*` bleiben unangetastet;
   B ist nicht in A integriert.
8. **G4+:** Keine Wirtschaft, Politik, Handel, Karawanen, Tiere, Fantasy oder
   Krieg.
9. **Einzel-Hitch:** Pro 5-Minuten-Fenster tritt eine einzelne
   Lifecycle-/Tagesgrenzen-Spitze von ca. 0,15 s Sim bzw. 0,4–0,46 s Frame
   auf. p95/p99 bleiben klar im Budget; eine spätere Optimierung kann die
   Tagesgrenzen-Arbeit weiter verteilen.
10. **Chunk-1-Laufzeit:** Der 120-Tage-Beweis mit Chunk 1 dauert ca. 7–8
    Minuten pro Lauf; Chunks 60/3600 sind schneller, liefern aber dieselben
    Hashes.

---

## 10. Abnahmebeurteilung

G3-A erfüllt die funktionalen Ziele (Welt, 1000 Agenten, 120-Tage-Kalender,
saisonale Felder mit 40 Herbsternten, A*/Cache/Chunking, Batching,
Determinismus, Schema 6, UI-Skalierung, D-57-Stubs) und die
Performance-/Speicher-Grenzen, soweit in den Abschnitten 6–8 belegt.

**Abnahme:** G3-A-Suite **13/13, 235 Checks**, Laufzeit 625,6 s. G1a 29/29,
G1b 28/28, G2 21/21 unverändert grün. Visuelle 5-Minuten-Läufe **3/3 PASS**.

**Kalibrierung:** 360.000 Startgrain (ein Jahresvorrat) beseitigt die
unnötige erste-Jahr-Hungersnot: **0 Mahlzeiten-Skips**, **1.040 Lebende**,
**359.307 Grain** am Jahresende, 40 Herbsternten, 0 außerhalb.

## 11. Review-Verifikation (2026-11-14)

- G3-A-Suite unabhängig: **13/13**, 235 Checks, 620 s.
- 120-Tage, Chunks 1/60/3600: `state 0x5D49B80C`, `event 0x92367DFC`,
  `chronicle 0xA09E0CBF`; 1.040 lebend, 40 Ernten.
- 1k@50x headless: Sim-p95 **4,69–4,73 ms**, p99 9,0–9,6 ms; visuell
  Frame-p95 **4,48–4,52 ms**, p99 7,65–7,69 ms, 328–331 FPS.
- Save: 4,085,116 Bytes, 165 ms Save, 3.061 ms Load; Schema 6.
- Kein per-Zyklus-Leak (+196 B). Einzelne Tagesgrenzen-Spitze außerhalb p99.
- **G3 bestanden**; Git-Tag `g3` folgt. Für G4a: Save-Load-Zeit (3 s bei 1k)
  budgetieren/optimieren; Tagesgrenzen-Arbeit verteilen.
- **Nächster Gate:** G4a (10k-Kern).
