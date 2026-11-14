# V3 G1b — Schritt 3: Kuratierte Chronik, Beobachtungs-UI und Replay

Status: **bestanden (Review 2026-11-14), Commit folgt**  
Stand: 2026-11-14  
Godot: **4.7.2-stable (official, ed1daf0bf)**, Standard-Build (GDScript)  
Featured Seed (visuelles Jahr): **34**  
Standard-Seed: **1337**

Bezug: `docs/v3-g1-spec.md`, `docs/v3-chronicle.md`,
`docs/v3-g1-workpackages.md`, `docs/v3-architecture.md`,
`docs/v3-data-model.md`, `docs/g1a/v3-g1a-report.md`,
`docs/g1b/v3-g1b-step1-report.md`, `docs/g1b/v3-g1b-step2-report.md`

---

## 1. Ergebnis

G1b-Schritt 3 implementiert die kuratierte Chronik, die Beobachtungs-UI und
Replay als Re-Simulation. Die Chronik ist kein roher Event-Log: Sie besitzt
Event-Taxonomie, Importance, Dedup/Aggregation, Tagesdigest, Story of the Day
und Kausalitätslinks. Routine-Events werden an der Quelle aggregiert.

- **Chronik:** `src/chronicle/` mit Event-Record, Store, Kurator, Story of the
  Day und Replay.
- **UI:** Familienbaum, Follow, Alerts, Story of the Day, Chronik-Panel mit
  Filtern, Basis-Biografie im Inspector.
- **Replay:** Re-Simulation aus Seed + Konfiguration + Save-Snapshot; der
  Chronik-/Debug-Log ist nicht Replay-Quelle.
- **Save:** Schema **4** mit Chronik, Retention-Metadaten und Replay-Metadaten;
  Schema 1–3 werden sichtbar abgelehnt.
- **Tests:** G1a 29 IDs, G1b Schritt 1/2 15 IDs und Schritt 3
  T-CHRON-01..05, T-UI-05..08, T-REPLAY-01..03, T-REVIEW-01.

## 2. Event-Taxonomie und Importance

Die Taxonomie liegt in `ChronicleCurator.classify()`. Jeder Event-Typ erhält
eine Kategorie und eine Importance:

| Kategorie | Beispiel-Typen | Importance |
|---|---|---|
| leben | Geburt, Tod, Schwangerschaft, Alterung | notable/major/routine |
| sozial | Partnerschaft, Haushalt | notable/major |
| arbeit | Rollenwechsel, Arbeit, Need-Unterbrechung | routine/notable |
| wirtschaft | Feldstufen, Aussaat, Reife, Ernte, Jahresbilanz | notable/major/historic |
| krise | Knappheit, übersprungene Mahlzeit | notable/major |
| reise | Aufbruch, Ankunft | routine |
| system | Sim-Start, Tagesbeginn, Save/Load | routine/notable |

Importance-Stufen: `routine`, `notable`, `major`, `historic`. Routine-Events
werden nicht einzeln gespeichert; `historic` bleibt dauerhaft und budgetiert.

## 3. Dedup, Aggregation und Digest

- Routine-Events werden in Tages-Buckets aggregiert und im Tagesdigest als
  „N Alltagsaktivitäten“ zusammengefasst.
- Wiederholte Meal-Skips/Knappheiten/Need-Unterbrechungen derselben Person am
  selben Tag werden über einen Dedup-Key zu einem Record mit `count` und
  `last_time` zusammengeführt.
- Mehrere Tode am selben Tag werden **nicht** zu einer erfundenen Seuche
  aggregiert. Jeder Tod bleibt ein eigener Record; die Texte nennen nur die
  simulierte Todesursache.
- Tagesdigest: 1–7 Zeilen, bei aktiven Tagen 3–7; keine Event-Flut, keine
  erfundenen Fakten.
- Dedup-Ratio: `1 − (gespeicherte Chronik-Events / ingestierte Quell-Events)`.
  Routine-Aggregation und Tages-Dedup machen die Ratio typischerweise deutlich
  größer als 80 %.

## 4. Kausalität

Kausalitätslinks entstehen ausschließlich aus bereits simulierten Events:

- Geburt → letzte Schwangerschaft der Mutter.
- Tod durch Geburt → Schwangerschaft; Tod durch schwere Gesundheit → letzte
  Knappheit/übersprungene Mahlzeit.
- Knappheit → übersprungene Mahlzeit; übersprungene Mahlzeit → letzte Knappheit.
- Reife → Aussaat; Ernte → Reife/Aussaat.
- Haushaltsauflösung → letzter Tod im Haushalt; Zuordnung/Ward → Auflösung.

Verdrängte Kausalitäts-Anker bleiben kompakt bis zu einem Sim-Jahr erhalten,
damit ein „Warum?“-Link nicht auf einen fehlenden Record zeigt.

## 5. Retention

Provisorische Budgets aus `docs/v3-chronicle.md`, konfigurierbar in
`SimConfig`:

- **Recent:** letzte 7 Sim-Tage, nur notable+, max. 250k Events.
- **Summaries:** Tagesdigests für 1 Sim-Jahr, max. 50k.
- **Historic:** dauerhafte Jahres-/Meilenstein-Events, max. 10k.
- **Routine:** an der Quelle aggregiert, nie einzeln gespeichert.
- **Anker:** verdrängte Kausalitäts-Records, max. 5.000, bis 1 Sim-Jahr.
- `ChronicleStore.budget_info()` weist Counts und Byte-Schätzungen aus; das Save
  enthält die Budgets und Replay-Metadaten.

## 6. Story of the Day und Fokusunabhängigkeit

- `StoryOfDay.for_day()` wählt major/historic plus höchstens eine persönliche
  notable-Geschichte, max. 7 Einträge.
- Sortierung: Importance, Fokusrelevanz, Zeit, Event-ID. Bei festem Fokuspfad
  ist die Auswahl deterministisch.
- Der Fokus (Agent/Haushalt/Kamera) ist reiner View-Input. Er verändert keine
  Chronik-Events; T-CHRON-05 vergleicht unterschiedliche Fokuspfade über
  State-, Event- und Chronik-Hash.

## 7. UI

- **Familienbaum:** `FamilyTreeModel`/`FamilyTreeView`; Eltern-Kind-Kanten,
  Partner-Kanten, mindestens 3 Generationen (A5→A6→A7), tote Agenten als
  historische Knoten mit Todesdatum.
- **Follow:** `FollowModel` + `GameCamera`; Kamera folgt dem gewählten Agenten,
  manuelles Pan beendet Follow. 60 s @60 Hz stabil getestet; keine
  Sim-Mutation.
- **Alerts:** nur major/historic, max. 20/Tag, keine Routine-Flut.
- **Story of the Day:** max. 7/Tag, deterministisch bei festem Fokus.
- **Chronik-Panel:** Filter nach Agent, Haushalt/Familie, Siedlung,
  Importance und Zeitraum; liest nur den kuratierten Store.
- **Inspector:** bleibt erhalten und zeigt eine Basis-Biografie aus der Chronik;
  tote Agenten bleiben lesbar.

## 8. Replay-Semantik und Log-Unabhängigkeit

- Replay = Re-Simulation aus Seed + Konfiguration + Save-Snapshot
  (`Replay.run_from_snapshot`).
- T-REPLAY-01 vergleicht Re-Simulation und direkten Save-Load-Verlauf.
- T-REPLAY-02 lädt denselben Snapshot zweimal, löscht im zweiten Lauf Chronik-
  und Debug-Log und vergleicht State sowie alle neu emittierten Events.
- T-REPLAY-03 wiederholt den Lauf dreimal mit unterschiedlichen Chunk-Größen und
  vergleicht State-, Event- und Chronik-Hash.
- Der Chronik-Hash ist bewusst **nicht** Teil des `state_hash`; Log-Kürzung kann
  den Simulationszustand daher nicht verändern.

## 9. Save-Schema 4

Zusätzlich zu Schema 3:

- Config: Chronik-Retention, Alert-/Story-Limits.
- Chronik: Recent-Events, Summaries, Historic, Anker, Routine-Buckets,
  Dedup-/Ingest-Zähler und `latest`-Kausalitätsindex.
- Replay-Metadaten: Version, Seed, Config-Hash, Snapshot-Zeit,
  Quelle `seed_config_snapshot`.
- Schema 1, 2 und 3 werden vor dem Payload-Decode sichtbar mit
  `unsupported_schema` abgelehnt.

## 10. Test-IDs

| ID | Ergebnis |
|---|---|
| T-CHRON-01 | Event-Taxonomie: Kategorien/Importance für alle G1-Typen |
| T-CHRON-02 | Dedup-Ratio > 80 %, keine Routine-Flut, keine erfundene Todesursache |
| T-CHRON-03 | Retention-Budgets, Summaries, exakter Chronik-Save/Load |
| T-CHRON-04 | Kausalitätslinks für Geburt, Ernte, Knappheit, auflösbar |
| T-CHRON-05 | Fokusunabhängigkeit von State, Events und Chronik |
| T-UI-05 | Familienbaum >= 3 Generationen, tote Knoten, korrekte Kanten |
| T-UI-06 | Follow 60 s stabil, keine Sim-Mutation |
| T-UI-07 | Alerts <= 20/Tag, nur major/historic |
| T-UI-08 | Story <= 7/Tag, deterministisch bei festem Fokus |
| T-REPLAY-01 | Re-Simulation aus Snapshot exakt |
| T-REPLAY-02 | Log-Kürzung ändert Replay nicht |
| T-REPLAY-03 | 3 Replay-Läufe identisch |
| T-REVIEW-01 | Doku, Dateigrenzen, Schema 4, keine G2-Features |

G1a (29 IDs), G1b Schritt 1 (7 IDs) und Schritt 2 (8 IDs inkl.
T-BENCH-03/04) bleiben Bestandteil der finalen Suite.

## 11. Messwerte

### G1a-Gate

```text
G1A_SUITE results=29 passed=29 failed=0 checks=260
G1A_SUITE_OK
```

### G1b-Gate (Schritt 1 + 2 + 3)

```text
G1B_SUITE results=28 passed=28 failed=0 checks=792
G1B_SUITE_OK
```

Enthalten: 7 IDs aus Schritt 1, 8 IDs aus Schritt 2 (inkl. T-BENCH-03/04)
und 13 neue Schritt-3-IDs.

### 1 Sim-Jahr, Featured Seed 34, 10 Agenten @50x

- 30,0 Sim-Tage in **540,0 s**; 5.850 Events; 117.414 Frames.
- **2 Geburten, 2 Tode, 10 Lebende** (8/10 Startagenten); erste Geburt und
  erster Tod an Lifecycle-Tag 20 (Anzeige Tag 21 00:00).
- Frame **p50 4,424 ms**, **p95 5,319 ms**, **p99 7,208 ms**,
  **219,5 FPS**, 694,2 Draw Calls Ø, maximal 359,8 ms
  (Screenshot-Hitch bei Geburt/Tod-Capture).
- Chronik: **88 gespeicherte Events**, **30 Tages-Summaries**,
  **1 historisches Event**, **72 Kausalitäts-Anker**,
  **Dedup-Ratio 99,1 %**, kuratierter Hash **0x89F6C4C8**.
- **Alerts max. 10/Tag** (Limit 20); **Story of the Day max. 7/Tag**
  (Limit 7).
- Kein Leak-/Fehler-Warnhinweis in den Lauf-Logs.
- Chronik/Tools sichtbar: `bench/results/g1b_chronicle_ui.png`,
  `bench/results/g1b_family_tree.png`, `g1b_year_birth.png`,
  `g1b_year_death.png`.

### 10 Agenten @50x, G1a-Bench

- **p50 4,332 ms**, **p95 5,107 ms**, **p99 6,241 ms**,
  **225,0 FPS**, 665,9 Draw Calls Ø, max. 10,429 ms
  (ohne Screenshot-Capture), 13.501 Frames.

### Headless-Simulation

- G1a-Sim-Slice: p95 **0,001 ms**, p99 0,338 ms, max. 0,943 ms,
  63,8 µs/Event.

### Dedup/Retention

- Tag 3, Seed 1337: 919 ingestierte Quell-Events, **37 gespeicherte**,
  875 Routine-Events, **Dedup-Ratio 0,960**.
- Jahreslauf: **Dedup-Ratio 0,991**; 30 Summaries; 1 Historic;
  72 Anker; Recent-Events im 7-Tage-Fenster.

### Save-Schema 4

- Seed 1337, Tag 1 12:05: **16.835 Bytes**, Save **1,25 ms**,
  Load **7,66 ms**.
- Enthält Chronik, Retention-Budgets, Replay-Metadaten; Schema 1–3 werden
  abgelehnt.

### Demografie (unverändert)

- 5 Seeds × 1.000 Agenten × 100 Jahre: **46.082 Geburten**,
  **4.990 Tode**, Median **49,0**, 29,2 % vor 40, 16,2 % erreichen 70,
  6,8 % erreichen 80.

### UI-/Replay-Tests

- T-UI-06: Follow 3.600 Frames (60 s @60 Hz) ohne Zielverlust und ohne
  State-/Event-Änderung.
- T-REPLAY-02: gekürztes Chronik-/Debug-Log, identischer State und identische
  neue Events.
- T-REPLAY-03: drei Läufe mit Chunks 1/60/3600, identische State-, Event- und
  Chronik-Hashes.

## 12. Bekannte Grenzen

1. Die Chronik ist auf die G1-Ebenen Individuum, Familie und Siedlung begrenzt.
   Nationen-Chronik bleibt G5.
2. Es gibt keine Lesezeichen, Sammlungen, Zeitleiste oder Pfad-/A*-Features.
3. Der Tagesdigest ist eine deterministische Auswahl, keine generative
   Erzählung; es gibt keine LLM-/Netzwerkabhängigkeit.
4. Kausalitäts-Anker sind kompakt und budgetiert; sie ersetzen keine
   vollständige historische Rohdatenhaltung.
5. Die 7-Tage-Retention und 1-Jahres-Summaries sind provisorische Budgets und
   werden in G2 kalibriert.
6. Follow ist eine Kamera-/View-Funktion; es gibt keinen Spielereingriff.
7. Replay ist Re-Simulation, kein Rewind/Scrubbing für den Spieler.
8. Die UI-Modelle sind headless getestet; der visuelle Smoke prüft die
   Darstellung, nicht jede Interaktion.
9. Der 1-Jahres-Lauf ist 9 Minuten real; die Headless-Suite prüft dieselben
   Semantiken zusätzlich deterministisch.
10. Neue Chronik-Daten erhöhen das Save, bleiben aber im G1-Budget.

## 13. Abnahmebeurteilung

**G1b Schritt 3 ist bestanden.**

Begründung:

1. Die Chronik ist mehr als ein Event-Log: Taxonomie, vier Importance-Stufen,
   Dedup/Aggregation, Tagesdigest, Story of the Day und auflösbare
   Kausalitätslinks sind implementiert und getestet.
2. Familienbaum (>= 3 Generationen, tote Knoten), Follow (60 s stabil ohne
   Sim-Mutation), Alerts (<= 20/Tag, nur major/historic), Story (<= 7/Tag,
   deterministisch bei festem Fokus) und das Chronik-Panel mit Filtern sind
   sichtbar und headless geprüft.
3. Fokusunabhängigkeit ist über unterschiedliche Agenten-Fokuspfade belegt:
   State-, Event- und Chronik-Hash bleiben identisch.
4. Replay ist Re-Simulation aus Seed + Konfiguration + Save-Snapshot.
   Log-Kürzung verändert weder State noch neu emittierte Events.
5. Save-Schema 4 ist exakt, Schema 1–3 werden sichtbar abgelehnt.
6. Der Featured-Seed-34-Jahreslauf zeigt Geburten und Tode, >= 50 % lebend,
   p95 5,346 ms und sichtbare Chronik/Tools; kein Leak-Warnhinweis.
7. Die 10-Agenten@50x-Messung bleibt mit p95 5,091 ms deutlich unter 16 ms.
8. Keine G2-Features, keine A*-/Pfad-Cache-Abhängigkeit, keine
   Wirtschaft/Politik, keine Änderung an G0-Dokumenten, Root-README oder
   `docs/v3-plan.md` durch diese Implementierung.
9. Keine Datei überschreitet die weiche 1.000-Zeilen-Grenze
   (`chronicle_store.gd` 673, `sim_save.gd` 730 Zeilen).

Offene Punkte für spätere Gates: Kalibrierung der Retention-Budgets in G2,
Siedlungs-/Nationen-Chronik erst G5, Lesezeichen/Sammlungen/Zeitleiste und
Spieler-Rewind bleiben ausdrücklich außerhalb von G1b Schritt 3.

## 13.1 Review-Verifikation (2026-11-14)

Unabhängig vom Implementierungslauf ausgeführt:

- G1a: **29/29**, 260 Checks; G1b: **28/28**, 792 Checks.
- Kurzer visueller Benchmark: p95 **5,31 ms**, 218,3 FPS, 666 Draw Calls;
  keine Leak-Warnung.
- **Vollständiger 1-Jahres-Lauf erneut ausgeführt:** 30 Sim-Tage in 540,005 s;
  2 Geburten, 2 Tode, 10 lebend, Grain 182; p95 **5,562 ms**, 215,0 FPS,
  694 Draw Calls; Alerts max. 10/Tag, Story max. 7/Tag, Dedup 99,1 %;
  Chronik 88 Events / 30 Summaries / 1 Historic / 72 Anker; keine
  Leak-Warnung.
- Screenshots geprüft: Chronik-Panel, Alerts, Story of the Day, Familienbaum
  (3 Generationen, tote Knoten), Geburts-/Todes-Tag. Die UI ist für einen
  Debug-Slice funktional, aber dicht/überlappend; G2/G3-Polish.
- Scope geprüft: keine G2-Systeme, keine Nationen-Chronik, keine
  Lesezeichen/Sammlungen/Zeitleiste, kein A*/Pfad-Cache.
- Dateigrenzen: alle Produktionsdateien unter 1.000 Zeilen; `sim_save.gd` und
  `chronicle_store.gd` wachsen, bleiben aber im Budget.

**G1 ist damit abgeschlossen:** G0.5, G1a, G1a.1 und G1b Schritte 1–3 sind
bestanden. Nächster Gate: **G2 (100 Agenten)**.
