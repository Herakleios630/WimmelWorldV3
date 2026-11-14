# G4b-Abnahmebericht – 10k + Wirtschaft/Politik

Status: **G4b bestanden (Review 2026-11-14); `g4b`-Tag folgt**  
Stand: 2026-11-14  
Basis: G4a (`g4a`, HEAD 54cf9eb) + D-68 (`cbacee7`)  
Godot: 4.7.2 stable (Standard-Build, GDScript)

## 1. Ergebnis

G4b ist auf dem bestandenen 10k-Kern implementiert und **abnahmefähig**.
Das G4a-Profil (`SimConfig.scale`, Schema 7) bleibt bitgleich; G4b nutzt ein
eigenes Profil (`SimConfig.civic`, Schema 8) mit aktivierter Wirtschaft und
Politik. Alle zwölf G4b-Tests sowie G1a/G1b/G2/G3/G4a bestanden. Die
10k@50x-Abnahme (p95/p99), der 120-Tage-Determinismus, Save/Load und die
sichtbaren 5-Minuten-Läufe sind eingehalten. Es wurden **keine Commits,
Pushes oder Tags** erstellt; die Abnahme/Tagging liegt beim Reviewer.

## 2. Geänderte/erstellte Dateien

**Neu (Wirtschaft):**
- `src/economy/goods.gd`
- `src/economy/market.gd`
- `src/economy/external_node.gd`
- `src/economy/caravan.gd`
- `src/economy/caravan_system.gd`
- `src/economy/economy_system.gd`

**Neu (Politik/UI):**
- `src/politics/diplomacy_state.gd`
- `src/politics/nation.gd`
- `src/politics/politics_system.gd`
- `src/view/economy_hud.gd`

**Geändert:**
- `src/data/sim_config.gd` (G4b-Profil `civic()`, Schema 8, Balance)
- `src/agents/simulation.gd` (optionaler Tagesbatch-Hook, State-Hash)
- `src/agents/population_generator.gd` (CIVIC nutzt den 10k-Generator)
- `src/world/world_map.gd` (CIVIC nutzt das 10k-Layout)
- `src/navigation/path_finder.gd` (CIVIC nutzt den Skalierungs-Pfadgraphen)
- `src/persistence/sim_save.gd` (Schema 8, G4a-Schema 7 bleibt ladbar)
- `src/kernel/sim_event.gd` (G4b-Eventtypen)
- `src/chronicle/chronicle_curator.gd` (Wirtschafts-/Politik-/Krisen-Taxonomie)
- `src/chronicle/chronicle_store.gd` (Kausalitätsanker für Karawanen/Preise)
- `src/view/view_state.gd` (Panel-Sichtbarkeit)
- `src/view/world_view.gd` (Karawanenmarker)

**Tests/Benchmarks:**
- `tests/g4/g4_b_suite.gd`, `g4_b_suite.tscn`
- `tests/g4/g4_b_test_util.gd`
- `tests/g4/test_g4b_01_households.gd` … `test_g4b_12_regression.gd`
- `tests/g4/bench_b.gd`, `bench_b.tscn`
- `tests/g4/visual_b.gd`, `visual_b.tscn`

**Scope-Tests (D-68, nur überholte Abwesenheits-/Token-Checks):**
- `tests/g1b/test_review.gd`: Entfernt die Verbote von `src/economy`/`src/politics`.
- `tests/g2/test_g2_stubs.gd`: Entfernt die Modul-Verbote für `economy/politics/trade/caravan` und die G4b-Token `caravan/karawane/nation_id/market_id/tax_rate`; `bookmark/timeline` bleiben verboten.
- `tests/g3/test_g3_10_scope.gd`: `forbidden_dirs` nur noch `army`; G4b-Token-Verbote in `sim_config.gd` entfernt.
- `tests/g4/test_g4_10_scope.gd`: `FORBIDDEN_DIRS` nur noch `army`; `karawane/steuer`-Token-Verbote in den Kernmodulen entfernt; D-57- und Schema-Checks unverändert.
- Alle Verhaltensprüfungen T01–T09, D-57-Stubs, Schema-/Determinismus-/Performance-Checks bleiben unverändert.

### Scope-Test-Diff im Detail

| Datei | Entfernt/relaxiert | Unverändert |
|---|---|---|
| `tests/g1b/test_review.gd` | `not DirAccess.dir_exists_absolute(res://src/economy)` und `.../politics` (2 Checks) | Doku-/Dateigrenzen, Netzwerk-Token, Schema 5, PathFinder/D-57-Präsenz, Suite-Inhalt |
| `tests/g2/test_g2_stubs.gd` | Modul-Loop für `economy/politics/trade/caravan`; `g3_terms` von `["bookmark","timeline","caravan","karawane","nation_id","market_id","tax_rate"]` auf `["bookmark","timeline"]` | D-57-Stubs/Events, Zielagenten/Weltgröße, Dateigrenze, G2-Testdateien, Report/README |
| `tests/g3/test_g3_10_scope.gd` | `forbidden_dirs` von `["economy","politics","trade","caravan","army"]` auf `["army"]`; die drei `sim_config`-Token-Checks `g4/politik/karawane` | D-57-Stubs, B-Isolation, Dateigrenze, Schema 6/5, G3-Suite/B-Test-Präsenz |
| `tests/g4/test_g4_10_scope.gd` | `FORBIDDEN_DIRS` von `["economy","politics","trade","caravan","army"]` auf `["army"]`; `karawane`/`steuer`-Checks in den fünf Kernmodulen | D-57-Stub-Checks, `d57`-Token-Check, B-Isolation, Dateigrenze, Schema 7/6/5, `scale().save_schema_version()==7`, G1–G3-Suite-Präsenz |

Alle Zeilenänderungen sind auf die genannten Abwesenheits-/Token-Prüfungen
begrenzt; es wurden keine Verhaltens-, Determinismus-, Performance- oder
Schema-Assertions abgeschwächt.

## 3. Wirtschafts-/Politikmodell und Balance

- **Nahrung:** G4a-Kornspeicher bleibt unverändert; der Markt handelt nur einen
  kleinen separaten Grain-Anteil und kann die Mahlzeiten nicht brechen.
- **Haushalte:** 2.000 Haushalte, Startbudget 200, Tagesbatch: Löhne
  (`Feld 2`, `Werkstatt 3`, leichte Arbeit 1), Steuern, Holz täglich,
  Werkzeug/Grain rotierend. Savings-Cap 3.000 pro Haushalt verhindert
  unbegrenzte Geldvermehrung; Überschuss wird als Konsum-Sink gebucht.
- **Markt:** Grain/Holz/Werkzeug mit Bestand, Tagessaldo, gedämpfter
  Preisfunktion (`price += (desired - price)/4`, ganzzahlig). Basispreise
  1/2/5 Geld; Preise bleiben auf 1/3…3× Basis begrenzt.
- **Karawanen:** drei abstrakte Knoten (Nordhaven, Ostfurt, Südweide) und
  höchstens drei physische Karawanen; Ladung, Hin-/Rückreise, Ankunft,
  Preisdifferenz, Zoll/Abkommen. Keine lokalen 10k-Agenten.
- **Nation:** eine Region „Wimmelmark“, Schatzkammer, Steuersatz 50–250‰,
  Budget Korn/Wege/Wachen/Notreserve, Spezialisierung Grain (Platzhalter).
- **Diplomatie:** zwei abstrakte Nachbarn, Relation −100…100, Geschenke,
  Handelsabkommen (Zoll 10 % → 5 %); kein Krieg.
- **Krisen:** Knappheit, Preisspitze, Überschuldung, Unruhe als
  major/notable Chronik-Events mit 10-Tage-Cooldown; kein Game Over.

## 4. Test-ID-Ergebnisse

| Test | Ergebnis |
|---|---|
| T-G4b-01 | PASS: 2.000 Haushalte, Löhne/Steuern/Marktverkäufe im Tagesbatch; Haushaltsgeld-Bilanz und Savings-Cap |
| T-G4b-02 | PASS: Preise steigen bei Knappheit, fallen bei Überangebot, reagieren auf Nachfrage/Angebot; gedämpft; deterministisch |
| T-G4b-03 | PASS: 3 externe Knoten, 8 abgeschlossene Karawanen im 120-Tage-Lauf, Ladung/Route/Marker |
| T-G4b-04 | PASS: Schatzkammer-Bilanz exakt (`treasury == start − Löhne + Steuern + Markt + Karawanen-Cash − Budget − Geschenke − Reserve`); Steuersatz/Budget/Schema |
| T-G4b-05 | PASS: 2 Nachbarn, 2 Handelsabkommen, 7 Geschenke, Relationen; kein Kriegs-Feature |
| T-G4b-06 | PASS: alle vier Krisen ausgelöst, Chronik-Events vorhanden, Cooldown, kein Game Over |
| T-G4b-07 | PASS: 120 Tage, 3 Läufe, Chunks 1/60/3600 bitgleich (siehe §5) |
| T-G4b-08 | PASS: Schema 8, 899.624 Bytes, Save 241,7 ms, Load 1.168 ms, exakt; Schema 1–7 abgelehnt; G4a-Schema 7 ladbar |
| T-G4b-09 | PASS: 10k@50x, 3 Läufe, p95 ≤ 16 ms, p99 ≤ 20 ms (siehe §6) |
| T-G4b-10 | PASS: 4 Panels (Markt/Schatzkammer/Diplomatie/Karawanen), Karawanenmarker, read-only |
| T-G4b-11 | PASS: kein Krieg/Armee, D-57 inert, eine Nation/10k, keine B-Referenz, Dateigrenze, Schema 8 |
| T-G4b-12 | PASS: G1/G2/G3/G4a-Kurzläufe bitgleich zu den eingefrorenen Hashes (siehe §9) |

Kurzlauf-Suite (ein 120-Tage-Lauf + alle nicht-performance Tests):
**10/10 PASS, 225 Checks**.

## 5. 120-Tage-Determinismus

Drei vollständige 120-Tage-Läufe (Seed 1337, `SimConfig.civic`), Chunks
1/60/3600. Der Save-Snapshot für T-G4b-08 liegt in Lauf 1 an Tag 61, 07:10.

| Lauf | Chunk | State | Event | Chronik | Alive | Karawanen | Verträge | Krisen | Haushaltsgeld | Schatz | Marktindex |
|---:|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | `0xB39248E0` | `0x209FEB40` | `0x216EABF7` | 10.233 | 8 | 2 | 0 | 663.037 | 678.859 | 1161 |
| 2 | 60 | `0xB39248E0` | `0x209FEB40` | `0x216EABF7` | 10.233 | 8 | 2 | 0 | 663.037 | 678.859 | 1161 |
| 3 | 3600 | `0xB39248E0` | `0x209FEB40` | `0x216EABF7` | 10.233 | 8 | 2 | 0 | 663.037 | 678.859 | 1161 |

Alle drei Läufe sind bitgleich. Lauf 1 speichert an Tag 61 und setzt danach
identisch fort; der Snapshot beeinflusst den Zustand nicht.

## 6. 10k@50x Performance

Headless, 3 Läufe, je 1.800 Warmup-Frames + 18.000 Mess-Frames (80 Ticks/Frame,
5-Minuten-Fenster bei 50x). `SimConfig.civic(1337+run)`.

| Lauf | p50 | p95 | p99 | max | Events/Frame | Cache-Hit | Economy-Batch avg/max |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 4,31 ms | **13,25 ms** | **19,06 ms** | 236,56 ms | 142,6 | 97,58 % | 5,92 / 6,68 ms |
| 2 | 4,25 ms | **12,98 ms** | **18,47 ms** | 222,00 ms | 142,5 | 97,58 % | 5,99 / 6,99 ms |
| 3 | 4,29 ms | **13,02 ms** | **18,64 ms** | 213,43 ms | 142,8 | 97,58 % | 6,05 / 7,46 ms |

- p95 ≤ 16 ms und p99 ≤ 20 ms in allen drei Läufen eingehalten.
- 18 Wirtschafts-/Politik-Tagesbatches pro 5-Minuten-Fenster; der Batch kostet
  im Mittel ~6 ms und läuft einmal pro Sim-Tag, nicht pro Frame. Die
  Frame-p95/p99 sind daher von G4a nicht messbar getrennt.
- Die Max-Werte sind einzelne Prewarm-/GC-Spikes; p95/p99 sind die
  Abnahmekriterien.

Visuell (1920×1080, VSync aus, 10k@50x, 5-Minuten-Fenster, 3 Läufe):

| Lauf | Frame p50 | Frame p95 | Frame p99 | FPS avg | Sim p95 | Render p95 | Draw Calls avg | Mem-Δ |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3,38 ms | **9,68 ms** | **13,69 ms** | 221,7 | 5,82 ms | 7,61 ms | 101,0 | +3,93 MB |
| 2 | 3,25 ms | **9,53 ms** | **13,44 ms** | 229,3 | 5,81 ms | 7,58 ms | 100,9 | +3,93 MB |
| 3 | 3,18 ms | **9,44 ms** | **13,23 ms** | 234,2 | 5,75 ms | 7,46 ms | 100,8 | +3,93 MB |

- 3/3 `G4B_VISUAL_OK`; p95 < 16,7 ms (60 FPS) und p99 < 20 ms.
- Der Speicherzuwachs ist über die drei Läufe konstant (kein fortlaufendes
  Wachstum); der Prozess beendet sich ohne ObjectDB-Leakwarnung.

## 7. Save/Load Schema 8

Snapshot in Lauf 1 an Tag 61, 07:10 (mitten in Markt, Karawanen und Politik):

- Schema: **8**
- Größe: **899.624 Bytes** (0,86 MB; Limit 40 MB)
- Save: **241,7 ms** (Limit 3 s)
- Load: **1.168 ms** (Limit 12 s)
- State/Event/Chronik/Wirtschaft/Politik nach Load **exakt gleich**
- Fortsetzung 3 Tage: State/Event/Chronik exakt, chunkunabhängig (3600 vs. 240)
- Schema 1–7 im G4b-Profil sichtbar abgelehnt (`unsupported_schema`)
- G4a-Schema 7 im G4a-Profil weiterhin ladbar
- Kein Leak: Der vollständige G4b-Suite- und die visuellen Prozesse beenden
  sich ohne ObjectDB-Leakwarnung; der Speicherzuwachs der drei visuellen
  Läufe ist konstant (+3,93 MB, kein fortlaufendes Wachstum).

## 8. UI und sichtbarer Smoke

- T-G4b-10 PASS: `EconomyHud` mit vier Panels
  (Markt/Schatzkammer/Diplomatie/Karawanen), Marktpreisen/Beständen,
  Steuersatz/Budget, zwei Nachbarn, Karawanenliste und drei Knoten.
- Karawanenmarker liegen innerhalb der 2048er-Welt und werden aus derselben
  read-only Route abgeleitet wie die Simulation; UI-Refresh ändert den
  State-Hash nicht.
- Sichtbarer 10k@50x-Lauf (5-Minuten-Fenster, 1920×1080, VSync aus):
  3/3 `G4B_VISUAL_OK`, 18,33 Sim-Tage pro Lauf, Frame-p95 9,44–9,68 ms,
  p99 13,23–13,69 ms, 221,7–234,2 FPS, Economy-Batch 5,86–5,97 ms avg.
- Sichtbarer 120-Tage-Smoke (Start Tag 55, Ende Tag 72): 200 Herbsternten,
  2 abgeschlossene Karawanen, Preise [1148, 2580, 5874], Schatz 810.422,
  Haushaltsgeld 555.754, 219,9 FPS, Frame-p95 10,03 ms.
  Screenshots: `bench/results/g4b_120days_day56.png`,
  `day61.png`, `day66.png`, `day71.png`; `G4B_120DAYS_OK`.

## 9. Regression G1–G4a

Kurze Referenzläufe (vor der G4b-Implementierung eingefroren, nach der
Implementierung bitgleich):

| Lauf | Tage | State | Event | Chronik | Alive |
|---|---:|---|---|---|---:|
| G1 | 10 | `0xED89E8C5` | `0x81EB3DE4` | `0x2DD7F835` | 10 |
| G2 | 30 | `0x465B30E9` | `0x7E05F14A` | `0x3E8117B7` | 104 |
| G3 | 30 | `0x81FAADA0` | `0x56070A4E` | `0xA8C576AC` | 991 |
| G4a | 20 | `0xD55A9EA9` | `0xE1775912` | `0xBD28E5A2` | 9.976 |

Die vollständigen Alt-Suiten wurden nach der G4b-Implementierung extern
ausgeführt; alle bestanden:

| Suite | Ergebnis | Checks | Log |
|---|---:|---:|---|
| G1a | 29/29 PASS | 265 | `bench/results/g4b_regression_g1a.log` |
| G1b | 28/28 PASS | 790 | `bench/results/g4b_regression_g1b.log` |
| G2 | 21/21 PASS | 229 | `bench/results/g4b_regression_g2.log` |
| G3a | 13/13 PASS | 232 | `bench/results/g4b_regression_g3.log` |
| G4a | 12/12 PASS | 198 | `bench/results/g4b_regression_g4a.log` |
| G4b | 12/12 PASS | 257 | `bench/results/g4b_suite.log` |

Zusätzlich sind die 120-Tage-G4a-Läufe der G4a-Suite bitgleich:

`state=0xF1FC5EE7 event=0x1A410B37 chronicle=0x3D78CD8F alive=10233
harvests=200` für Chunks 1/60/3600.

Die G1a/G1b/G2/G3/G4a-Verhaltensprüfungen, D-57-Stubs, Schema- und
Performance-Checks sind damit unverändert grün.

## 10. Bekannte Grenzen

- Der Markt ist bewusst klein: kein Kredit, keine Börse, keine
  Preisspekulation, keine individuellen Konten pro Tick.
- Karawanen sind wenige sichtbare Vehikel, keine vollständige
  Transportwirtschaft; die Route ist eine deterministische drei-Punkt-Linie.
- Grain bleibt öffentlich; Markt-Grain ist ein separater Marktanteil.
- Die Notreserve ist ein Fonds; es gibt noch keine automatische
  Krisenausschüttung aus der Reserve.
- `CaravanSystem.profit_total` ist der realisierte Cash-Erlös
  abgeschlossener Reisen. Bei noch laufenden Rückreisen kann er negativ sein,
  obwohl die Schatzkammer-Bilanz über `cash_in_total − cash_out_total` exakt
  ist; importierte Güter werden erst über spätere Haushaltskäufe zu
  Markterlösen.
- Im 120-Tage-Basisszenario traten keine natürlichen Krisen auf
  (Marktindex 1161, Schatz positiv). T-G4b-06 erzwingt alle vier
  Krisenbedingungen und prüft Chronik/Cooldown/kein Game Over.
- Die Diplomatie kennt zwei abstrakte Nachbarn und ein Handelsabkommen; keine
  Bündnisse, Grenzstreitigkeiten oder Kriege.
- G4b bleibt bei einer Nation und 10.000 Agenten; G5 (100k/3 Nationen) ist
  nicht Teil dieser Abnahme.

## 11. Abnahme

**G4b: abnahmefähig** (kein `g4b`-Tag durch die Implementierung gesetzt).

| Kriterium | Ergebnis |
|---|---|
| 10k@50x p95 ≤ 16 ms / p99 ≤ 20 ms / 60 FPS, 3 Läufe | PASS: headless p95 12,98–13,25 ms, p99 18,47–19,06 ms; visuell 3/3 p95 9,44–9,68 ms, 221,7–234,2 FPS |
| 120-Tage-Determinismus, 3 Läufe, Chunks 1/60/3600 | PASS: bitgleich (`0xB39248E0` / `0x209FEB40` / `0x216EABF7`) |
| Wirtschaftsbilanz nachvollziehbar; keine unendliche Geldvermehrung | PASS: Schatzkammer-Identität exakt; Geldmenge 1.347.896 < Start 1.400.000; Savings-Cap |
| Preise/Karawanen/Steuern/Budget/Diplomatie/Krisen | PASS: T-G4b-02..06; 2 Abkommen, 8 abgeschlossene Karawanen, 4 Krisen im Forced-Test |
| Save/Load Schema 8; ≤ 40 MB / ≤ 3 s / ≤ 12 s; kein Leak | PASS: 0,86 MB, 241,7 ms / 1.168 ms, exakt, kein Leak |
| Keine Kriege/D-57/G5/B | PASS: T-G4b-11, `src/lod/` unverändert, D-57 inert |
| G1a/G1b/G2/G3/G4a-Regression | PASS: 29/29, 28/28, 21/21, 13/13, 12/12; Kurz-Hashes bitgleich |

**Rückfall:** nicht erforderlich. `g4a` bleibt der letzte getaggte Stand,
bis der Reviewer `g4b` setzt.

## 12. Review-Verifikation (2026-11-14)

- G4b-Suite unabhängig: **12/12**, 257 Checks, 2.383,13 s, `G4B_SUITE_OK`;
  keine Leak-/ERROR-Warnung.
- 120 Tage, Chunks 1/60/3600: `state 0xB39248E0`, `event 0x209FEB40`,
  `chronicle 0x216EABF7`; 10.233 lebend, 8 Karawanen, 2 Abkommen.
- 10k@50x headless: p95 **12,46–12,55 ms**, p99 17,65–18,00 ms; visuell
  Frame-p95 9,44–9,68 ms, 221–234 FPS.
- Economy-Batch: ~5,7–5,8 ms avg, max 6,6 ms; p99 bleibt unter 20 ms.
- Save: 899.624 Bytes, 216 ms Save, 1.133 ms Load; Schema 8; G4a-Schema 7
  im G4a-Profil ladbar.
- D-68-Scope-Diff geprüft: nur Abwesenheits-/Token-Checks in G1b/G2/G3/G4a
  entfernt; alle Verhaltens-, D-57-, Schema- und Performance-Checks intakt.
- G1a/G1b/G2/G3/G4a-Regression: 29/29, 28/28, 21/21, 13/13, 12/12;
  Hashes bitgleich.
- **G4b abgenommen; G4 abgeschlossen.** `g4b`-Tag folgt. Für G5: Economy-
  Batch/ p99 und Save-Load bei 100k erneut budgetieren.
