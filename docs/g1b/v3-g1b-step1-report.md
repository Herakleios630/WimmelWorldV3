# V3 G1b — Schritt 1: Needs, Gesundheit und voller Feldzyklus

Status: **G1b Schritt 1 bestanden (Review 2026-11-13); Commit folgt**  
Stand: 2026-11-13  
Seed für alle Abnahmeläufe: **1337**  
Godot: **4.7.2-stable (official, ed1daf0bf)**, Standard-Build (GDScript)  
Zielplattform: Windows, 1920 × 1080, Ryzen 5 5600 / RTX 5060

Bezug: `docs/v3-g1-spec.md`, `docs/v3-g1-workpackages.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`, `docs/g1a/v3-g1a-report.md`

---

## 1. Ergebnis

G1b-Schritt 1 ist implementiert. Die drei zusätzlichen Werte **Hygiene**,
**Spaß** und **Gesundheit** sind aktiv, der Inspector zeigt sechs Werte, und
die tägliche Grain-Erzeugung ist durch den vollen Feldzyklus ersetzt.

- **G1a:** 29/29 Test-IDs, **252 Checks**, `G1A_SUITE_OK`
- **G1b Schritt 1:** 7/7 Test-IDs, **81 Checks**, `G1B_SUITE_OK`
- **Visuell 10 Agenten @50x:** Frame **p95 5,07 ms**, **224,9 FPS**,
  **666,1 Draw Calls Ø**
- **Ein Sim-Jahr (30 Tage):** 4 vollständige Ernten,
  Grain **60 + 880 − 769 = 171**, 260 Mahlzeiten-Skips in der
  Anfangsknappheit, keine stille Auffüllung
- **Save:** Schema **2**, 12.856 Bytes, Schema-1-Saves werden sichtbar mit
  `unsupported_schema` abgelehnt
- **Determinismus:** Feldzyklus über 3 Läufe identisch; Jahreslauf mit
  unterschiedlicher Chunk-Aufteilung identisch; Save/Load mitten im
  Feldzyklus (offener `FIELD_TICK`) exakt
- **G0.5-Regression:** `tests/spike/unit_checks.tscn` bleibt `SPIKE_UNIT_OK`
- **Hauptszene-Smoke:** `--headless --quit-after 120` Exit 0

## 2. Umfang und Nicht-Ziele

### Enthalten (Schritt 1)

- Needs **Hygiene**, **Spaß**; Gesundheit als langsamer Zustand 0–100.
- Waschen am Brunnen, Freizeit/Spiel am Platz, Soziales trägt zu Spaß bei.
- Gesundheit reagiert auf Hunger/Energie/Hygiene und Alter, erholt sich bei
  guten Needs. Keine Krankheit, keine Gewalt, kein Tod.
- Inspector/HUD: sechs Werte inkl. Gesundheit; HUD zeigt Feldstufe, Ernten
  und Jahr.
- Voller Feldzyklus
  `FALLOW → PLOWING → PLOWED → SOWING → SOWN → GROWING → RIPE → HARVESTING → FALLOW`.
- Arbeit ist Fortschritt; Aussaat, kalenderzeitbasiertes Wachstum, Ernte,
  Kornspeicher, Jahresbilanz.
- 30-Tage-Jahr, vier Jahreszeiten (Darstellung), ein Feld.
- Save-Schema 2 mit neuen Need-/Health-Feldern und Feldzustand.

### Nicht enthalten (bewusst Schritt 2/3)

- Keine Partnerschaft, Geburt, Tod, Alterung, Fertilität,
  Haushaltsauflösung, Mortalität.
- Kein Familienbaum, Follow, Alerts, Story of the Day, Chronik-UI,
  Chronik-Kuratierung, Replay.
- Kein A*/Pfad-Cache, keine Wirtschaft/Politik/Tiere/Fantasy.
- Keine Spielereingriffe, kein Rewind.

## 3. Geänderte und erstellte Dateien

### Produktionscode

| Datei | Änderung |
|---|---|
| `src/data/sim_config.gd` | Schema 2; Need-/Health-Parameter; Feld-/Jahresparameter |
| `src/decisions/needs_model.gd` | Hygiene/Spaß/Health-Raten, Schwellen, Settle, Anzeige |
| `src/decisions/decision_system.gd` | Waschen/Freizeit als Need-Aktionen; Feldarbeit, Stufen, Ernte, Feld-Tick |
| `src/agents/agent_store.gd` | SoA-Felder `hygiene`, `fun`, `health`; `ACT_HYGIENE` |
| `src/agents/simulation.gd` | Feld-/Jahreszähler, Jahresabschluss, Feld-Tick-Dispatch, State-Hash |
| `src/world/building.gd` | Feldzustand und Stufenkonstanten |
| `src/persistence/sim_save.gd` | Schema 2, neue Config-/Store-/Feld-/Jahresfelder |
| `src/kernel/sim_kinds.gd` | `EVENT_FIELD_TICK` |
| `src/kernel/sim_event.gd` | Feld-/Jahres-/Aktivitätsende-Events |
| `src/view/inspector_model.gd` | Sechs Werte inkl. Gesundheit |
| `src/view/hud.gd` | Sechs Need-Balken; Feldstufe/Ernte/Jahr in der Top-Leiste |

Nicht geändert: `src/decisions/role_schedule.gd` (nicht nötig),
`src/world/world_map.gd` (nur bestehende Helfer genutzt),
`src/view/world_view.gd`, `src/view/demo_main.gd`, `project.godot`,
`src/spike/`, G0-Dokumente, `README.md`, `docs/v3-plan.md`.

**Minimale Erweiterung außerhalb der genannten Dateiliste:** `sim_kinds.gd`
erhielt genau einen neuen Termin (`EVENT_FIELD_TICK`), `sim_event.gd` die
zugehörigen Event-Typen (Feldstufen, Aussaat, Reife, Ernte, Jahresabschluss,
Aktivitätsende). Ohne diese Enum-Erweiterungen müsste der einzelne
Wachstums-Termin ein Agenten-Wake missbrauchen oder Tests mit magischen Zahlen
arbeiten. Es entsteht keine neue Simulationslogik außerhalb des Feldzyklus.

### Tests

| Datei | Änderung |
|---|---|
| `tests/g1a/test_util.gd` | `set_need` für Hygiene/Spaß/Gesundheit |
| `tests/g1a/test_food.gd` | T-FOOD-01/03 an W6b angepasst (stärker, nicht abgeschwächt) |
| `tests/g1a/test_save.gd` | Schema 2, Schema-1-Ablehnung, Save-Metrik |
| `tests/g1a/test_ui.gd` | Sechs Inspector-Werte/Snapshot |
| `tests/g1a/test_store.gd` | Neue SoA-Arraytypen |
| `tests/g1a/test_context.gd` | Gate-Name `G1A`/`G1B` |
| `tests/g1b/g1b_suite.gd` + `.tscn` | Neues G1b-Gate |
| `tests/g1b/test_needs_g1b.gd` | T-NEED-05..07 |
| `tests/g1b/test_farm.gd` | T-FARM-01..04 |

### Doku und erzeugte Artefakte

- `docs/g1b/README.md`, `docs/g1b/v3-g1b-step1-report.md`
- `bench/results/g1a_suite_g1bstep1.log`
- `bench/results/g1b_suite_step1.log`
- `bench/results/g1a_visual_result.json` (aktualisiert)
- `bench/results/g1a_demo.png`, `bench/results/g1a_demo_night.png` (aktualisiert)
- `tests/g1a/capture_demo.gd.uid` sowie die `.uid`-Dateien der neuen
  `tests/g1b/`-Skripte (von Godot beim Import erzeugt)

**Hinweis:** `README.md` und `docs/v3-plan.md` waren im Arbeitsbaum bereits vor
dieser Implementierung modifiziert. Diese Arbeit hat beide Dateien nicht
angefasst.

## 4. Need- und Health-Parameter

Alle Werte liegen autoritativ in `SimConfig` und sind Teil des Config-Hashs
und des Saves.

| Wert | Start | Rate | Schwelle | Erfüllung |
|---|---:|---|---:|---|
| Hunger | 80 | +100/Tag | 60 | Mahlzeit: −50 |
| Energie | 80 | −60/16 h wach; +80/8 h Schlaf | 20 | Schlaf |
| Sozial | 70 | −50/Tag; ×1,5 wenn Spaß ≤ 40 | 40 | Sozialisieren: +30 |
| Hygiene | 80 | −60/Tag | 50 | Waschen: +50 |
| Spaß | 70 | −40/Tag (0 im Schlaf) | 40 | Freizeit/Spiel: +30; Soziales: +10 |
| Gesundheit | 100 | schlecht: −12/Tag; gut: +4/Tag; 60+: −6/Jahr | — | gute Needs |

**Gesundheit:**

- `bad`: Hunger ≥ 60 **oder** Energie ≤ 20 **oder** Hygiene ≤ 50.
- `good`: Hunger < 36, Energie > 30, Hygiene > 50, Sozial > 40, Spaß > 40.
- Der Health-Beitrag wird pro Settle-Intervall stückweise konstant aus dem
  Zustand vor dem Intervall berechnet. Das ist deterministisch und benötigt
  keine zusätzlichen Polling-Events.
- Gesundheit wird bei 0 geklemmt; es gibt keine Krankheit, keine Gewalt und
  keinen Tod in Schritt 1.
- Altersbedingter Rückgang gilt für Agenten ab 60 (A5 ist 70) und ist mit
  −6 pro 30-Tage-Jahr bewusst langsam.

**Need-Priorität:** Hunger → Energie → Hygiene → Spaß → Sozial. Reisen,
Essen, Schlafen, Sozialisieren und Waschen sind Commitments; Arbeit, Lernen
und Spielen können durch Needs unterbrochen werden. Spaß wird nicht doppelt
vergeben: Ein unterbrochenes Spiel gewährt keinen vollen Abschluss-Bonus.

**Spaß/Soziales-Kopplung:** Sozialisieren erhöht Spaß um 10. Niedriger Spaß
(≤ 40) erhöht den Sozialverlust um 50 %. Ein separates Stimmungssystem gibt es
in Schritt 1 nicht.

## 5. Voller Feldzyklus

### Zustände und Übergänge

```text
FALLOW → PLOWING → PLOWED → SOWING → SOWN → GROWING → RIPE → HARVESTING → FALLOW
```

- **FALLOW → PLOWING** beim Arbeitsbeginn eines Feldarbeiters.
- **PLOWING → PLOWED** nach 20 Feldarbeitsstunden.
- **PLOWED → SOWING** beim nächsten Arbeitsbeginn; **SOWING → SOWN** nach
  8 Feldarbeitsstunden.
- **SOWN → GROWING** unmittelbar nach der Aussaat; Wachstum ist Kalenderzeit.
- **GROWING → RIPE** nach 4 Sim-Tagen über genau ein `EVENT_FIELD_TICK`.
- **RIPE → HARVESTING** beim nächsten Arbeitsbeginn; **HARVESTING → FALLOW**
  nach 16 Feldarbeitsstunden und +220 Grain in den Speicher.

### Arbeit als Fortschritt

- Feldarbeit wird in Sekunden gesammelt und bei jedem Arbeitsende
  (Routinenwechsel oder Need-Unterbrechung) in den Feldzustand gebucht.
- Sobald eine Stufe abgeschlossen ist, wird der Rest derselben Arbeitssitzung
  (auch späterer Feldarbeiter am selben Termin) **nicht** in die Folgestufe
  übertragen. Jede Stufe braucht eigene Arbeit; es gibt keinen
  Instant-Kettenlauf. Das ist eine bewusste Vereinfachung, die im Jahreslauf
  mit 4 Ernten robust bleibt.
- Während `GROWING`, `RIPE` oder `FALLOW` loggen Feldarbeiter weiter Arbeit,
  erzeugen aber keinen Stufenfortschritt. Das ist in Schritt 1 bewusst
  vereinfacht (keine separate Instandhaltungsaufgabe).
- Kein Full-Agent-Sweep, kein Tick pro Frame. Der einzige neue periodische
  Termin ist der Feld-Tick pro Aussaat.

### Jahresbilanz und Grain

- 30-Tage-Jahr, vier Jahreszeiten nur als Darstellung
  (`(tag % 30) * 4 / 30`).
- Kein separater Saatgut-Abzug: Der Ernteertrag ist netto. Damit bleibt die
  einfache, prüfbare Grain-Identität erhalten:
  `grain = start + grain_produced − meals_served`.
- Jahresabschluss bei Tag 30 00:00: `last_year_*` wird gesetzt,
  `year_*` zurückgesetzt, ein `year_summary`-Event geloggt.
- Keine stille Auffüllung: Grain steigt ausschließlich durch
  `T_FIELD_HARVEST`; Mahlzeiten verbrauchen 1 Grain.

## 6. Test-IDs und Ergebnisse

### G1a — 29/29

| ID | Ergebnis | Kernprüfung |
|---|---|---|
| T-KERN-01 | bestanden | Scheduler-Ordnung `(time, seq)`, 3 Läufe |
| T-KERN-02 | bestanden | RNG-Streams getrennt/reproduzierbar |
| T-KERN-03 | bestanden | Debug/Chronik getrennt |
| T-KERN-04 | bestanden | Snapshot/Restore exakt |
| T-STORE-01 | bestanden | 10 Agenten, stabile IDs, SoA |
| T-STORE-02 | bestanden | ID-Lebenszyklus, toter Agent referenzierbar |
| T-STORE-03 | bestanden | keine Per-Agent-Dictionaries im Hot-Loop |
| T-NEED-01 | bestanden | Hunger unterbricht Arbeit, Rückkehr |
| T-NEED-02 | bestanden | Schlaffenster/Erholung |
| T-NEED-03 | bestanden | Sozial genau einmal, kein Dauerloop |
| T-NEED-04 | bestanden | Need-Events 3 Läufe identisch |
| T-WORLD-01 | bestanden | Erreichbarkeit |
| T-WORLD-02 | bestanden | Occupancy |
| T-WORLD-03 | bestanden | Weltgrenzen |
| T-MOVE-01 | bestanden | `position_at` exakt |
| T-MOVE-02 | bestanden | Ankunft exakt |
| T-MOVE-03 | bestanden | Waypoint, kein A* |
| T-FOOD-01 | bestanden | **angepasst:** Arbeit ist Fortschritt, Ernte erzeugt Grain, exakte Bilanz |
| T-FOOD-02 | bestanden | Mahlzeit: −1 Grain, Hunger-Reset |
| T-FOOD-03 | bestanden | **angepasst:** Knappheit ohne Auffüllung, Hunger **und Health** reagieren, Ernte rettet |
| T-SAVE-01 | bestanden | Save/Load vor Entscheidung exakt |
| T-SAVE-02 | bestanden | Save/Load nach Arbeit exakt |
| T-SAVE-03 | bestanden | Schema 2; 999 und **Schema 1** abgelehnt |
| T-UI-01 | bestanden | Inspector inkl. Hygiene/Spaß/Gesundheit und 6er-Snapshot |
| T-UI-02 | bestanden | Event-Log, keine Sim-Mutation |
| T-UI-03 | bestanden | Kamera/Zoom/Sichtbarkeit ohne Sim-Effekt |
| T-UI-04 | bestanden | 10@50x p95 ≤ 16 ms |
| T-BENCH-01 | bestanden | 3 Läufe identisch |
| T-BENCH-02 | bestanden | Headless + visuell dokumentiert |

**T-FOOD-01/03 sind bewusst angepasst, nicht abgeschwächt.** W6b ersetzt die
tägliche Grain-Erzeugung; die Tests prüfen jetzt zusätzlich
Stufenfortschritt, Ernte, Health-Reaktion und die exakte Grain-Identität.
Damit ist die G1a-Akzeptanzzeile „kein voller Feldzyklus“ durch den
G1b-Schritt-1-Auftrag abgelöst; alle G1a-Test-IDs bleiben grün. Das ist eine
versionierte Gate-Entscheidung (W6a → W6b), keine stille Änderung.

### G1b Schritt 1 — 7/7

| ID | Ergebnis | Evidenz |
|---|---|---|
| T-NEED-05 | bestanden | Waschen genau einmal, +50, Hygiene > 50; schlechte Hygiene senkt Health langsam, gute erholt sie |
| T-NEED-06 | bestanden | Freizeit genau einmal, Spaß > 40, kein Dauerloop; Soziales +Spaß; niedriger Spaß beschleunigt Sozialverlust |
| T-NEED-07 | bestanden | schlechte Needs −3/6 h, gute Needs +0,17/h, Alter −0,2/Tag, Clamp 0, `alive` bleibt 1 |
| T-FARM-01 | bestanden | Stufenfolge vollständig; 3 Läufe identisch (`state 0xFD815445`, `event 0xDFC28328`); Save/Load mitten im Zyklus exakt |
| T-FARM-02 | bestanden | 4 Ernten; Jahresbilanz `60 + 880 − 769 = 171`; Ernte-/Aussaat-/Jahres-Events; keine stille Auffüllung |
| T-FARM-03 | bestanden | erzwungener Ernteausfall: kein Grain, Hunger/Health, Shortage in Chronik; Ernte rettet Mahlzeiten |
| T-FARM-04 | bestanden | 30 Tage, vier Jahreszeiten, ≥1 vollständiger Zyklus, Chunked-vs-Sprung identisch |

## 7. Messwerte

### 7.1 Visuell (10 Agenten @50x)

Protokoll: 1920 × 1080, VSync aus, 6 s Warm-up, 60 s Messfenster,
Kamerafahrt Pan/Zoom, 50x, Seed 1337.

| Messwert | Ergebnis |
|---|---:|
| Frames | 13.497 |
| FPS (Durchschnitt) | 224,9 |
| Frame p50 | 4,35 ms |
| Frame p95 | **5,07 ms** (Budget ≤ 16 ms) |
| Frame p99 | 6,31 ms |
| Frame max | 10,08 ms |
| Sim-Zeit im Messfenster | 3,67 Sim-Tage |
| Events im Messfenster | 896 |
| Draw Calls Ø / max | 666,1 / 668 |

Die +6 Draw Calls gegenüber G1a (660) entstehen durch die drei zusätzlichen
HUD-Need-Balken. Das Budget bleibt deutlich eingehalten.

### 7.2 Headless (Sim-Kosten)

Protokoll: 10 Agenten, Seed 1337, Warm-up 1.800 Sim-Sekunden, dann ein
Sim-Tag in 1.080 `advance_to`-Aufrufen à 80 Sim-Sekunden.

| Messwert | Ergebnis |
|---|---:|
| Events im Messfenster | 167 |
| Events/Frame | 0,1546 |
| µs/Event (inkl. Advance-Overhead) | 50,6–53,4 |
| Sim p50 | 0,0010 ms |
| Sim p95 | 0,0010 ms |
| Sim p99 | 0,257 ms |
| Sim max | 0,810 ms |

p50/p95 sind ~1 µs, weil die meisten `advance_to`-Aufrufe eventlos sind. Ein
Full-Agent-Sweep pro Frame existiert nicht.

### 7.3 Ein Sim-Jahr / Feldzyklus (Seed 1337)

| Messwert | Ergebnis |
|---|---:|
| Sim-Jahr | 30 Tage |
| Ernten | **4** |
| Erntezeiten | Tag 7 12:00; Tag 13 17:00; Tag 20 12:00; Tag 26 17:00 |
| Grain Start | 60 |
| Grain geerntet | 880 |
| Mahlzeiten serviert | 769 |
| Mahlzeiten übersprungen | 260 (Anfangsknappheit, inkl. Retries) |
| Grain Ende | **171** |
| Grain-Identität | 60 + 880 − 769 = 171 |
| Gesundheit A1 am Jahresende | 100,0 |
| Vollständige Feldzyklen | 4 (5. Zyklus beginnt am Jahresende) |

Stufenfolge im Jahr (Event-Daten):
`[1,2,3,4,5,6,7,0]` viermal, danach `[1,2,3,4,5]` für den begonnenen fünften
Zyklus. Die erste Ernte ist Tag 7, weil Startgrain nur zwei Tage deckt und die
Arbeit Stufenfortschritt statt Tagesgrain erzeugt. Die Knappheit ist sichtbar,
wird aber nicht still aufgefüllt; ab der ersten Ernte bleibt die Bilanz positiv.

### 7.4 Determinismus

| Lauf | Ergebnis |
|---|---|
| G1a, ein Sim-Tag, 3 Chunks | `state 0xA7F758DD`, `event 0xF8442B0E`, `chronicle 0x75776244` |
| Feldzyklus, 7 Tage, 3 Chunks | `state 0xFD815445`, `event 0xDFC28328`, Stufenfolge identisch |
| 1 Sim-Jahr, 3600er-Chunks vs. ein Sprung | `state_hash` und `event_hash` identisch |
| Save/Load Tag 2 (GROWING, offener Feld-Tick) | Snapshot exakt; Verlauf bis Tag 7 inkl. Ernte exakt |

### 7.5 Save

| Messwert | Ergebnis |
|---|---:|
| Schema | 2 |
| Größe (12:05 Tag 1, Seed 1337) | 12.856 Bytes |
| Save-Zeit | 0,94–1,01 ms |
| Load-Zeit (inkl. Welt-/Log-Rekonstruktion) | 6,9–8,0 ms |
| Schema 1 | sichtbar `unsupported_schema` |
| Schema 999 / Magic / Config-Hash | sichtbar abgelehnt |

## 8. UI- und Save-Änderungen

### Inspector/HUD

- Inspector zeigt sechs Werte: Hunger, Energie, Sozial, Hygiene, Spaß,
  Gesundheit.
- Inspector-Höhe wurde für sechs Balken vergrößert.
- Top-Leiste zeigt `Grain`, geerntete Menge, Feldstufe und Jahr.
- Der Tages-/Nacht- und Jahreszeiten-Tint bleibt reine Darstellung.
- Keine neue Chronik-UI, keine Alerts, kein Follow, kein Familienbaum.

Screenshot `bench/results/g1a_demo.png` (Tag 1, 10:00, A1 ausgewählt) zeigt
Hunger 47, Energie 65, Sozial 62, Hygiene 70, Spaß 63, Gesundheit 99 und
`Feld: PLOWING`.

### Save-Schema 2

Gespeichert werden zusätzlich:

- Config: Start-/Raten-/Schwellenwerte für Hygiene, Spaß, Gesundheit;
  Feldarbeitszeiten, Wachstumsdauer, Ernteertrag.
- Agenten-SoA: `hygiene`, `fun`, `health`.
- Feldzustand: `field_stage`, `field_work_s`, `field_growth_end`,
  `field_growth_gen`.
- Zähler: `grain_harvested`, `harvests_completed`, `field_cycles_completed`.
- Jahresbilanz: `year_index`, `year_*`, `last_year_*`.

Schema-1-Saves werden vor dem Payload-Decode abgelehnt. Es gibt keine stille
Migration.

## 9. Vorher/Nachher

| Beobachtung | G1a (vorher) | G1b Schritt 1 (nachher) |
|---|---:|---:|
| Aktive Werte | 3 Needs | 6 Werte inkl. Gesundheit |
| Grain-Erzeugung | 1 Grain pro Feldarbeitsstunde | Ernte nach vollem Feldzyklus |
| Feldzustand | keiner | 8 Stufen + Arbeit + Wachstum |
| Erste Ernte | täglich | Tag 7 (Seed 1337) |
| Grain Tag 1 | 58 | 30 (keine Ernte, keine Auffüllung) |
| Grain Jahr 1 | nicht definiert | 171 (60 + 880 − 769) |
| Save-Schema | 1 | 2 |
| G1a-Tests | 29/29, 224 Checks | 29/29, 252 Checks |
| G1b-Tests | — | 7/7, 81 Checks |
| Visuell p95 | 5,11 ms | 5,07 ms |
| Draw Calls Ø | 660,0 | 666,1 |

Der niedrigere Grain-Bestand an Tag 1 ist kein Regressionsfehler: Die tägliche
Auffüllung ist entfernt. Die Knappheit ist sichtbar, und die erste Ernte
stabilisiert die Bilanz.

## 10. Bekannte Grenzen und bewusste Vereinfachungen

1. **Gesundheit ist in Schritt 1 nur Zustand.** Sie beeinflusst noch keine
   Arbeit, Entscheidungen, Mortalität oder Chronik; es gibt keine Krankheit
   und keine Gewalt.
2. **Keine Alterung.** `age_years` bleibt statisch. Der altersbedingte
   Health-Rückgang gilt für Agenten ab 60, verändert das Alter aber nicht.
3. **Jahreszeiten sind Darstellung.** Es gibt keine Wetter-, Ertrags- oder
   Arbeitszeitmodifikation pro Jahreszeit.
4. **Ein Feld, fester Ertrag.** Kein Saatgut-Abzug, keine Fruchtfolge, keine
   Sorten, kein Ertragszufall. Der Ertrag ist netto 220 Grain.
5. **Arbeitsfortschritt wird am Arbeitssitzungsende gebucht.** Es gibt kein
   Per-Frame-Progress-Update und keinen zusätzlichen Polling-Sweep. Während
   `GROWING`/`RIPE`/`FALLOW` loggen Feldarbeiter Arbeit ohne Stufenfortschritt.
6. **SOWN ist ein Übergang.** Persistiert wird nach der Aussaat `GROWING`;
   `SOWN` und `GROWING` werden als aufeinanderfolgende Events geloggt.
7. **T-FARM-03 erzwingt den Ernteausfall** durch einen Testzustand
   (`GROWING` mit weit entferntem Wachstumsende). Es gibt noch keine
   zufälligen Ernteausfälle.
8. **G1a-T-FOOD-01/03 sind semantisch angepasst.** Die G1a-Reportdetails zur
   täglichen Grain-Erzeugung sind historisch und werden durch diesen Bericht
   für W6b ersetzt.
9. **Save-Migration fehlt.** Schema 2 lädt nur Schema 2; Schema 1 wird
   sichtbar abgelehnt. Saves aus abweichenden Kalibrierungen werden über den
   Config-Hash abgelehnt.
10. **Visueller Lauf deckt 3,67 Sim-Tage ab**, nicht das ganze Jahr. Der
    Jahresnachweis ist headless (T-FARM-02/T-FARM-04).
11. **Draw Calls** steigen durch drei zusätzliche HUD-Balken von 660 auf 666;
    weiterhin weit unter dem G1a-Budget.
12. **Kein Replay, kein A*/Pfad-Cache, keine Chronik-Kuratierung.** Diese
    bleiben Schritt 2/3 bzw. G2.
13. **Demo-/Projektlabels bleiben teils „G1a“.** `project.godot`,
    `src/view/demo_main.gd` und der Fenstertitel wurden nicht angefasst, weil
    sie nicht in der erlaubten Dateiliste lagen. Die Simulation, der Inspector
    und die HUD-Werte sind G1b-Schritt 1.

## 11. Abnahmebeurteilung Schritt 1

**Review-Ergebnis: Schritt 1 bestanden mit Kalibrierungsauflage.**

- 29/29 G1a-Test-IDs und 7/7 neue G1b-Test-IDs bestehen.
- Ein Sim-Jahr zeigt vier vollständige Feldzyklen; mindestens ein Zyklus ist
  im Jahreslauf nachweisbar.
- Grain-Bilanz ist positiv und nachvollziehbar (`60 + 880 − 769 = 171`);
  Knappheit ist sichtbar, ohne stille Auffüllung.
- Inspector/HUD zeigen sechs Werte inkl. Gesundheit.
- Save/Load mit Schema 2 ist exakt, auch mitten im Feldzyklus; Schema 1 wird
  sichtbar abgelehnt.
- 10 Agenten @50x: p95 5,07 ms ≤ 16 ms; kein Full-Agent-Sweep.
- Keine G1b-Schritt-2/3-Features (keine Geburt, kein Tod, keine Partnerschaft,
  kein Familienbaum/Follow/Alerts/Chronik-UI, kein Replay).

**Review-Verifikation (2026-11-13):**

- G1a: **29/29**, 252 Checks; G1b: **7/7**, 81 Checks.
- Visuell: p95 **5,23 ms**, **221,9 FPS**, 666 Draw Calls.
- Jahreslauf: 4 Ernten, Grain 171, **260 Mahlzeiten-Skips** in der
  Anfangsknappheit; A1-Gesundheit 100 am Jahresende.
- Screenshot geprüft: sechs Needs + Gesundheit, Feldstufe `PLOWING`.
- Scope geprüft: keine Schritt-2/3-Systeme in der Produktion.

**Auflage für Schritt 2:** Die initiale Knappheit (260 Skips) und die
Health-Folgen kalibrieren, bevor Mortalität dazukommt; sonst ist Gesundheit
folgenlos. Dateigrößen (`decision_system.gd` 672, `sim_save.gd` 538) vor
Schritt 3 beobachten und bei Bedarf aufteilen.

Es wurden **keine Git-Commits** und kein Push durch den Implementierer
ausgeführt; der Review-Commit folgt separat.

## 12. Reproduktion

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path C:\coding\WimmelWorld\V3 --import
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1b/g1b_suite.tscn
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/spike/unit_checks.tscn
```

Die Logs der finalen Läufe liegen unter
`bench/results/g1a_suite_g1bstep1.log` und
`bench/results/g1b_suite_step1.log`.
