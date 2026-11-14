# V3 G3 B-Spike — Bericht: 100k@150x/200x Zeitraffer

Status: **B-Spike bestanden (Review 2026-11-14); B ist für 100k@150x auf
Simulationsebene tragfähig. Kein finales B.**  
Stand: 2026-11-14  
Bezug: `docs/g3/v3-g3-b-spike.md`, `docs/v3-fidelity.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`, `docs/g2/v3-g2-report.md`.

Gemessen auf: Windows, AMD Ryzen 5 5600 (6C/12T), Godot **4.7.2-stable**
(Standard-Build, GDScript), headless. Warm-up 1 Sim-Tag, Messfenster 3
Sim-Tage, 60-Hz-Frame-Raster, 3 Läufe je Szenario. Seed **1337**.

---

## 1. Ergebnis in einem Satz

100.000 persistente B-Records, ein deterministisches Detailtier mit 1.000 oder
5.000 Agenten, tägliche Siedlungs-/Kohorten-Coarse-Updates und individuelle
Key-Events laufen bei **150x** und **200x** innerhalb des 16,67-ms-Frames
(headless, ohne Render/UI). Detail 1k bleibt deutlich unter dem Budget; Detail
5k ist ebenfalls tragfähig, lässt aber weniger Render-/UI-Reserve.

| Szenario | Events/Frame | Frame p95 | Frame p99 | Frame max | Sim-Budget bei p95 | Ziel |
|---|---:|---:|---:|---:|---:|---:|
| 100k, Detail 1k, 150x | 41,3 | **3,25 ms** | 4,15 ms | 6,73 ms | 19,5 % | 150x |
| 100k, Detail 5k, 150x | 195,3 | **6,95 ms** | 8,17 ms | 11,00 ms | 41,7 % | 150x |
| 100k, Detail 1k, 200x | 55,0 | **3,63 ms** | 4,88 ms | 7,53 ms | 21,8 % | 200x |
| 100k, Detail 5k, 200x | 260,4 | **8,99 ms** | 10,73 ms | 12,71 ms | 53,9 % | 200x |

Frame = reine Sim-Advance-Zeit im Headless-Modus. Render/UI/A Kunst sind
bewusst **nicht** Teil dieses Spikes; die Spalte „Sim-Budget“ ist der Anteil
des 16,67-ms-60-Hz-Frames, den die Simulation bei p95 belegt.

---

## 2. Geänderte/erstellte Dateien

**Neu (Produktion, B-only):**

- `src/lod/b_hash.gd` — stateless deterministische Hashes.
- `src/lod/b_config.gd` — B-Konfiguration, Speed-/Cadence-/Rate-Parameter.
- `src/lod/b_kinds.gd` — B-Eventarten.
- `src/lod/b_records.gd` — 100k-SoA-Records, Siedlungen/Kohorten, Indexaufbau.
- `src/lod/b_key_log.gd` — individuelle Key-Event-Log-/Identitätsprüfung.
- `src/lod/b_tier_selector.gd` — Detailtier-Auswahl, stabiles Top-K, Diff.
- `src/lod/b_detail.gd` — Detail-Wakes, Needs, Reisen, Promotion/Demotion.
- `src/lod/b_background.gd` — Tages-/Wochen-Coarse, Geburt/Tod/Ehe/Jobwechsel.
- `src/lod/b_metrics.gd` — Messung (Frame/Batch/Detail/Hintergrund/Auswahl).
- `src/lod/b_sim.gd` — B-Orchestrierung, Scheduler, Batching, Hashes.
- `src/lod/b_save.gd` — B-Save-Schema 1 (Spike-Format, kein finales Format).

**Neu (Tests/Doku/Benchmark):**

- `tests/g3/g3_test_util.gd`
- `tests/g3/test_b_generation.gd`
- `tests/g3/test_b_tier.gd`
- `tests/g3/test_b_background.gd`
- `tests/g3/test_b_determinism.gd`
- `tests/g3/test_b_save.gd`
- `tests/g3/test_b_performance.gd`
- `tests/g3/bench_b.gd`, `tests/g3/bench_b.tscn`
- `tests/g3/g3_suite.gd`, `tests/g3/g3_suite.tscn`
- `docs/g3/v3-g3-b-spike-report.md`, `docs/g3/README.md`
- `bench/results/g3_b_spike_results.json` (lokal; durch
  `bench/results/*` in `.gitignore` ausgeschlossen)

**Nicht verändert:** G1a/G1b/G2-Produktion, A, Cursed Beyond, G0-Dokumente,
`README.md`, `docs/v3-plan.md`, `.gitignore`. Keine Commits/Pushes.

---

## 3. B-Record-/Tier-/Hintergrundmodell

### 3.1 Records

- 100.000 persistente Agenten in SoA + kompakten kalten Feldern.
- 200 synthetische Siedlungen à 500 Agenten, je 14 Kohorten
  (7 Altersbänder × 2 Geschlechter), 2.800 Kohorten.
- Stabile IDs 1..100000; Geburten erhalten fortlaufende neue IDs, keine
  Wiederverwendung. Tote bleiben als Record mit `death_day` erhalten.
- Identität/Name (namensindexiert), Geschlecht, Geburtstag, Haushalt, Wohnung,
  Job, Partner, Eltern, Gesundheit, Needs, Position, Tier, Key-Event-Zähler.
- Kalte Beziehungen: Partner, Mutter, Vater; Key-Events referenzieren stabile
  IDs. Haushalte sind synthetisch, keine Wirtschaft/Politik.

### 3.2 Detailtier

- Zielgröße 1.000 oder 5.000, exakt gehalten (Todesfälle werden über einen
  deterministischen Dead-Buffer aufgefangen).
- Auswahl: stabiles Top-K über `(ID, Rotations-Epoche)`-Hash plus Bonus für
  - Key-Event-Nähe (letzte 3 Sim-Tage),
  - Alter (0–4, 75+; 15–29),
  - Partnerschaft, Job,
  - deterministische Ereignisnähe,
  - Reisen/Aktivität,
  - Siedlungs-Key-Event-Nähe.
- **Keine Kamera/Sichtbarkeit:** Follow/Inspector werden nur gespeichert und
  gehen nicht in Auswahl oder `state_hash()` ein.
- Auswahl läuft in 1.440 festen Sim-Sekunden-Slices pro Tag (70 Records/Slice)
  und wird um Mitternacht committet. Das hält den Tages-Commit klein.
- Stabile Rotation: Basis-Hash wechselt alle 5 Sim-Tage; Prioritäten dürfen
  täglich übersteuern. Dadurch bleibt die Tier-Größe konstant, ohne tägliche
  Voll-Neuverteilung.

### 3.3 Promotion/Demotion/Catch-up

- Promotion: Needs/Gesundheit werden aus dem letzten autoritativen B-Record
  materialisiert; Position bleibt unverändert; neuer Wake wird geplant.
- Demotion: Needs/Gesundheit werden materialisiert; Position wird
  eingefroren; laufende Reisen werden an der **interpolierten** Position
  angehalten (kein Teleport).
- Stale Wakes werden über `wake_gen` verworfen. Kein Zeitsprung, keine
  erfundenen Events.
- Gemessen: 3.198 Wechsel/5 Commits bei 1k, 8.670 bei 5k; Catch-up zusammen
  13,2 ms bzw. 38,4 ms über 5 Commits.

### 3.4 Hintergrund-Coarse und Key-Events

- Täglich pro Siedlung: Todesfälle/Geburten je Kohorte, Kohortenmittel für
  Needs/Gesundheit; Wochenbatch zusätzlich Ehen und Jobwechsel.
- 200 Siedlungsbatches/Tag; im Messfenster 800 Batches in 4 Tagen.
- Key-Events werden **individuell** erzeugt und geloggt:
  Geburt, Tod, Ehe, Jobwechsel. Jedes Event hat stabile Agent-IDs,
  `last_key_day`, `key_event_count`, `key_event_hash`.
- Key-Event-Zahlen sind pro Kohorte/Tag gedeckelt (Tod max. 4, Geburt max. 3,
  Ehe max. 3, Jobwechsel max. 8 pro Siedlung/Woche), um Batch-Spitzen zu
  begrenzen. Die Raten selbst sind Spike-Platzhalter.
- Background-Needs/Gesundheit sind aggregiert; per-Agent-Werte werden lazy bei
  Key-Event/Promotion materialisiert. Das ist B-Coarse, kein A-Äquivalent.

---

## 4. Messwerte

### 4.1 150x / 200x, Detail 1k/5k (3 Läufe, 3 Sim-Tage Messfenster)

| Szenario | p50 | p95 | p99 | max | Events/Frame | Batches | Max. Batch |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1k @150x | 2,06 ms | 3,25 ms | 4,15 ms | 6,73 ms | 41,3 | 39.576 | 5 |
| 5k @150x | 4,65 ms | 6,95 ms | 8,17 ms | 11,00 ms | 195,3 | 137.725 | 9 |
| 1k @200x | 2,67 ms | 3,63 ms | 4,88 ms | 7,53 ms | 55,0 | 39.576 | 5 |
| 5k @200x | 6,22 ms | 8,99 ms | 10,73 ms | 12,71 ms | 260,4 | 137.725 | 9 |

Bereiche über die 3 Läufe:

- 1k @150x: p95 2,93–3,37 ms; p99 4,00–4,15 ms; max 6,65–6,73 ms.
- 5k @150x: p95 6,95–7,42 ms; p99 7,94–9,08 ms; max 11,00–12,63 ms.
- 1k @200x: p95 3,63–3,93 ms; p99 4,88–5,56 ms; max 7,53–8,17 ms.
- 5k @200x: p95 8,90–9,13 ms; p99 10,70–10,73 ms; max 12,71–13,40 ms.

### 4.2 Ziel/Ist-Speed

- Ziel: 150x = 1 Sim-Tag in 6,0 s = 240 Sim-Sekunden/Frame bei 60 Hz;
  200x = 4,5 s/Tag = 320 Sim-Sekunden/Frame.
- Nachhaltige Speed bei p95 (Headless): **768x** (1k/150), **360x**
  (5k/150), **918x** (1k/200), **371x** (5k/200).
- Ungedrosselter Headless-Durchsatz: 1.118–1.184x (1k/150), 514–533x
  (5k/150), 1.174–1.212x (1k/200), 526–534x (5k/200).
- Bei 60-Hz-Pacing bleibt 150x/200x in allen vier Szenarien innerhalb des
  Budgets; 5k/200 belegt bei p95 ca. 54 % des Frames, 1k/150 nur ca. 20 %.

### 4.3 Batch-Kosten

| Szenario | Batch p50 | Batch p95 | Batch p99 | Batch max | Größe p95 | Größe max |
|---|---:|---:|---:|---:|---:|---:|
| 1k @150x | 0,019 ms | 0,355 ms | 0,437 ms | 6,249 ms | 2 | 5 |
| 5k @150x | 0,020 ms | 0,066 ms | 0,394 ms | 8,771 ms | 3 | 9 |
| 1k @200x | 0,019 ms | 0,350 ms | 0,380 ms | 6,050 ms | 2 | 5 |
| 5k @200x | 0,020 ms | 0,065 ms | 0,391 ms | 9,231 ms | 3 | 9 |

Die Batch-Maxima entstehen an Tagesgrenzen (Tier-Commit + Siedlungsbatches),
nicht durch Event-Stürme. `out_of_order = 0` in allen Determinismusläufen.

### 4.4 Detail-/Hintergrund-/Auswahlkosten

| Szenario | Detail µs/Agent/Tag | Detail-Events/Tag | Hintergrund µs/Siedlung/Batch | Auswahl µs/Record |
|---|---:|---:|---:|---:|
| 1k @150x | 151,0 | 12.935 | 86,0 | 5,27 |
| 5k @150x | 154,6 | 67.775 | 83,8 | 5,37 |
| 1k @200x | 140,7 | 12.935 | 80,4 | 5,03 |
| 5k @200x | 152,9 | 67.775 | 83,5 | 5,31 |

- Detailtier: ca. **13 Routineentscheidungen/Agent/Tag** (inkl. Reise/Arbeit),
  nicht pro Minute.
- Hintergrund: ca. **80–86 µs pro Siedlungsbatch**, ein Batch/Tag/Siedlung;
  Ehen/Jobwechsel zusätzlich im Wochenbatch.
- Auswahl: ca. **5,0–5,4 µs/Record**; 100k Records/Tag = ca. 0,5 s/Tag,
  verteilt auf 1.440 Slices. Das ist der größte Coarse-Kostenblock, liegt
  aber weit unter dem Frame-Budget.

### 4.5 Frame/Sim/Render/FPS

- Headless: Frame = Sim-Advance; **Render/UI nicht gemessen** (kein UI/A-Teil
  im Spike). FPS im ungedrosselten Headless-Lauf: 460 (1k/150), 210 (5k/150),
  363 (1k/200), 159 (5k/200).
- Die FPS-Zahlen sind Durchsatz, keine gerenderte Bildrate. Für die
  Abnahme zählt der 16,67-ms-Sim-Anteil; Render/UI muss in einem visuellen
  B-Folge-Spike separat gemessen werden.

---

## 5. Determinismus, Save/Load, Key-Events

### 5.1 Determinismus (3 Läufe)

Vollbenchmark, 3 Läufe je Szenario, identische State-/Event-/Tier-Hashes:

| Szenario | State | Event | Tier |
|---|---|---|---|
| 1k @150x | `0xF912C8CB` | `0xC1457792` | `0x95ACDAD0` |
| 5k @150x | `0x6E1C078F` | `0x0AC5BFF2` | `0x555B183A` |
| 1k @200x | `0x8C55B591` | `0xC1457792` | `0x95ACDAD0` |
| 5k @200x | `0x1D8B681D` | `0x0AC5BFF2` | `0x555B183A` |

Chunk-Unabhängigkeit (2 Sim-Tage, Detail 1k, Chunks 1/60/3600):

- State `0x63074CAD`, Event `0x03DEB3A8`, Tier `0x7976F245`, Alive 99.877,
  Detail 1.000 in allen drei Läufen.
- Detail 5k, Chunks 60/3600: State `0xDC979A24`, Event `0x5BD4B589`,
  Tier `0xBAC7D865`, Detail 5.000.

150x/200x teilen Event-/Tier-Hashes bei gleicher Detailgröße (gleiche
Sim-Ereignisse), unterscheiden sich aber im State-Hash durch Clock/Scheduler.
Das ist erwartet.

### 5.2 Save/Load (B-Schema 1, kein finales Format)

| Szenario | Größe | Save | Load | Exakt |
|---|---:|---:|---:|---|
| 1k | 14.047.304 B (13,4 MiB) | 25,5 ms | 35,7 ms | State/Event/Tier ja |
| 5k | 14.185.692 B (13,5 MiB) | 24,0 ms | 35,0 ms | State/Event/Tier ja |

- Save mitten in der Tier-Auswahl (aktive Epoche, Cursor, Heap) ist exakt;
  Fortsetzung mit Chunks 60 vs. 3600 ergibt identische Hashes.
- Schema/Magic/Config-Hash werden sichtbar abgelehnt; fehlgeschlagenes Laden
  mutiert die Sim nicht.
- Die Save-Größe wird von den 100k Records dominiert (ca. 15,0 MB
  Record-Schätzung), nicht vom Key-Log (ca. 42 KB bei 4 Tagen).

### 5.3 Key-Event-Erhalt

Messfenster 1 Warm-up + 3 Messtage (4 Sim-Tage):

- 1.033 Key-Events: **157 Geburten, 345 Tode, 285 Ehen, 246 Jobwechsel**.
- Lebend danach: 99.812 = 100.000 + 157 − 345.
- `verify_identities`: keine verlorenen Geburten/Tode/Ehen/Jobwechsel;
  Geburten haben gültige Mutter/Vater-Referenzen, Tote bleiben als Record,
  Ehen setzen Partner-IDs, Jobwechsel setzen `last_job_change_day`.
- Key-Event-Nähe: 541/541 geprüfte Agenten mit Key-Event aus Tag 1–2 waren
  im Detailtier (Detail 1k). Key-Agenten werden also deterministisch
  promoviert.
- Routine-Events werden gezählt, nicht als Key-Events gespeichert.

---

## 6. Speicher/Leaks

Pro Sim (Schätzung aus den Packed-Arrays):

| Posten | Bytes |
|---|---:|
| 100k Records | 15.024.193 |
| Kohorten-Row-Index | 400.628 |
| Key-Log (4 Tage) | 42.353 |
| Scheduler | 83.636–206.024 |
| **Summe** | **15,55–15,67 MB** |

- Engine-Static vor Sim: ca. 26,9–27,0 MB; nach Sim: ca. 48,6–50,4 MB
  (inkl. Engine-Caches, nicht nur B-Daten).
- Prozess-Peak im Gesamtbenchmark: ca. 48,95 MB (1k/150) bis 94,1 MB
  (5k-Läufe mit vorherigen Szenarien im selben Prozess).
- **Leak-Test:** 2× BSim aufbauen, 0,1 Sim-Tag laufen, freigeben:
  `OS.get_static_memory_usage()` vorher = nachher, **Delta 0 Bytes**.
  Kein Leak bei wiederholtem Aufbau/Abbau beobachtet.

---

## 7. Regression G1/G2

Unabhängig nach den B-Änderungen ausgeführt:

- G1a: **29/29**, 265 Checks, grün.
- G1b: **28/28**, 792 Checks, grün.
- G2: **21/21**, 233 Checks, grün.
- G3 B: **18/18**, 289 Checks, grün.

Es wurden keine G1-/G2-Produktionsdateien verändert. Die B-Dateien liegen
ausschließlich unter `src/lod/`; die Tests unter `tests/g3/`.

---

## 8. Empfehlung

### 8.1 Detailtier

- **1.000 Agenten** ist die sichere Standardgröße für 100k@150x:
  p95 3,25 ms, ca. 20 % des 60-Hz-Frames, 41 Events/Frame. Es bleiben ca.
  13,4 ms für Render/UI.
- **5.000 Agenten** ist auf Simulationsebene tragfähig: p95 6,95 ms bei 150x,
  8,99 ms bei 200x. Es bleiben bei 150x ca. 9,7 ms, bei 200x ca. 7,7 ms für
  Render/UI. 5k ist als Qualitätsmodus empfehlenswert, **wenn** ein visueller
  B-Spike den Render-/UI-Anteil unter ca. 7–9 ms hält.
- Empfehlung: **1k als Default, 5k als optionale Qualitätsstufe**; final erst
  nach einem visuellen B-Spike festlegen.

### 8.2 Cadence

- Hintergrund: **täglich** pro Siedlung/Kohorte für Tod/Geburt/Needs-Health;
  **wöchentlich** für Ehen/Jobwechsel. 200 Siedlungsbatches/Tag sind
  kostenseitig unkritisch (ca. 80–86 µs/Batch).
- Detail-Auswahl: **täglich**, aber mit **stabiler 5-Tage-Rotation** und
  1.440 Slices/Tag. Das hält Tier-Wechsel und Commit-Kosten klein.
- Auswahlkosten (ca. 0,5 s/Tag) sind der größte Coarse-Block; für das finale B
  lohnt eine Optimierung (z. B. vorberechnete Basis-Hashes pro Rotationsepoche
  oder Auswahl nur bei Kohorten-/Ereignisänderung).

### 8.3 150x/200x

- **150x** ist mit 1k und 5k auf Simulationsebene sicher.
- **200x** ist ebenfalls messbar: 5k p95 8,99 ms, p99 10,73 ms, max 12,71 ms;
  1k p95 3,63 ms. Kein Simulationsblocker.
- Empfehlung: **150x als Primärmodus**, 200x als Stretch-/Qualitätsmodus,
  abhängig vom visuellen Budget.

### 8.4 Reicht B für 100k@150x?

**Ja, auf Simulationsebene.** Der Spike belegt:

- 100k persistente Records und Identitäten,
- deterministisches Detailtier 1k/5k ohne Kameraabhängigkeit,
- tägliche/wöchentliche Coarse-Hintergrundupdates,
- individuelle Key-Events ohne Identitätsverlust,
- deterministische Tier-Wechsel mit Catch-up ohne Teleport,
- exaktes Save/Load innerhalb B,
- 150x und 200x innerhalb des 16,67-ms-Sim-Budgets.

**Noch nicht belegt** sind finales B, UI/A Kunst, Render-/UI-Budget,
Wirtschaft/Politik, finale Save-Migration und Langzeit-Demografie. Das ist
bewusst außerhalb dieses Spikes.

---

## 9. Offene Punkte

1. **Visueller B-Spike:** Render/UI/A Kunst fehlen; p95 oben ist reine
   Sim-Zeit. 5k@150x lässt nur ca. 9,7 ms Render-/UI-Reserve.
2. **Finales B-Save:** Schema 1 ist ein Spike-Format; 14 MB unkomprimiert,
   25 ms Save / 35 ms Load. Kompression, Migration und Dead-Archive sind offen.
3. **Auswahlkosten:** ca. 5,3 µs/Record, ca. 0,5 s/Tag. Für das finale B
   optimieren oder seltener auswählen.
4. **Demografie-Balance:** Key-Event-Raten sind Spike-Platzhalter; die
   Bevölkerung sinkt um ca. 47/Tag (ca. 0,047 %/Tag). Langfristige Geburts-/
   Sterbe-/Heiratsraten müssen kalibriert werden.
5. **Coarse-Needs/Gesundheit:** Kohortenmittel sind aggregiert; per-Agent-
   Werte werden lazy materialisiert. Das ist B-Coarse, kein A-Äquivalent.
6. **Reisen/Navigation:** B nutzt direkte siedlungsnahe Geometrie, keinen
   regionalen Graphen und kein A*. Pfadkosten sind nicht Teil dieses Spikes.
7. **Tier-Churn:** 3.198/8.670 Wechsel über 5 Commits. Catch-up ist billig,
   aber sichtbare Tier-Übergänge brauchen später UI-/Verhaltensglättung.
8. **Hardware:** Nur Ryzen 5 5600/Windows/Godot 4.7.2 gemessen; andere
   Plattformen/Engine-Builds brauchen eigene Messungen.
9. **A/B-Replay:** Keine A/B-Replay-Gleichheit getestet oder behauptet; B ist
   ein eigener Modus.
10. **UI-/Save-Kennzeichnung:** „Zeitraffer (150x, grob)“ und
    `fidelity_mode = B` sind noch nicht im finalen UI/Save implementiert.

## 10. Review-Verifikation (2026-11-14)

- B-Suite: **18/18**, 289 Checks; G1a **29/29**, G1b **28/28**, G2 **21/21**.
- p95: 1k@150x **3,25 ms**, 5k@150x **6,95 ms**, 1k@200x **3,63 ms**,
  5k@200x **8,99 ms**; Ziel/Ist-Speed 525–1.211x.
- Save: 14,0 MB, 25–27 ms Save / 35–41 ms Load; Deterministisch, keine
  Leaks.
- Key-Events und Identitäten erhalten; Kamera/Focus ändert Tier nicht.
- **Entscheidung:** 1k-Detail als Default für 100k@150x; 5k als
  Qualitätsmodus; 150x primär, 200x Stretch. B ist auf Simulationsebene
  tragfähig; finaler visueller B-Spike, Save-Format und Demografie-Balance
  bleiben offen.
- Der B-Spike ist ein **Forschungsartefakt**, kein finales B; G3 bleibt A.
