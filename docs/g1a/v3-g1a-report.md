# V3 G1a — Implementierungsbericht

Status: **G1a bestanden (Review 2026-11-13); Commit folgt**  
Stand: 2026-11-13  
Bezug: `docs/v3-g1-spec.md`, `docs/v3-g1-workpackages.md`,
`docs/v3-architecture.md`, `docs/v3-data-model.md`, `docs/v3-benchmark.md`,
`docs/g0.5/v3-g0.5-results.md`

Seed für alle Abnahmeläufe: **1337**  
Godot: **4.7.2-stable (official, ed1daf0bf)**, Standard-Build (GDScript)  
Zielplattform: Windows, 1920 × 1080, Ryzen 5 5600 / RTX 5060

---

## 1. Ergebnis

G1a ist als sichtbarer, deterministischer Kern-Loop mit 10 Agenten
implementiert. Alle **29 Test-IDs** aus `v3-g1-workpackages.md` bestehen:

- **Headless:** 29/29, 216 Checks, `G1A_SUITE_OK`
- **Visuell:** 10 Agenten @50x, Gesamtframe **p95 = 6,89 ms**, **165,1 FPS**
- **Save/Load:** exakt vor/nach Entscheidung und Arbeit, Version 1
- **Determinismus:** 3 Läufe mit unterschiedlicher Frame-Aufteilung
  (1 s, 300 s, ein Sprung) ergeben identische State-/Event-/Chronik-Hashes
- **Kamera/Zoom/Sichtbarkeit:** kein Sim-Zustandsunterschied
- **G0.5-Spike:** unverändert; `tests/spike/unit_checks.tscn` bleibt
  `SPIKE_UNIT_OK`

Die vollständigen Testprotokolle liegen lokal unter:

- `bench/results/g1a_suite_final.log`
- `bench/results/g1a_visual_result.json`
- `bench/results/g1a_visual_final.log`

---

## 2. Umfang

### Enthalten (G1a)

- 128 × 128 Tiles, 1,5 m/Tile, 16 px/Tile; 3 Häuser, 1 Feld, 1 Kornspeicher,
  1 Brunnen, 1 Scheune/Werkstatt, Wege zwischen allen Gebäuden.
- 10 Agenten in 3 Haushalten (A1–A7/C1–C3 gemäß Spec), Rollen Kind/Jugend/
  Erwachsen/Alt, kalte Records für Namen/Beziehungen.
- Needs: **Hunger, Energie, Sozial**; keine Hygiene/Spaß/Gesundheit.
- Wohnen, Routinen, Feldarbeit mit Fortschritt, einfacher Grain-Speicher,
  Mahlzeiten, Tag/Nacht, Jahreszeiten-Tint (nur Darstellung).
- Waypoint-/Gerade-Linien-Bewegung über einen kleinen Weg-Graphen;
  `position_at(time)` und exakte Ankunfts-Events.
- Inspector, Event-Log, Zeit/Pause/1x/10x/50x, Auswahl/Fokus, Tag/Nacht.
- Versioniertes Binär-Save (Schema 1) mit getrenntem Debug-/Chronik-Log.
- Headless-Testsuite, visueller Benchmark, sichtbare Demo.

### Nicht enthalten (bewusst G1b/G2)

- Keine Hygiene/Spaß/Gesundheit, keine Krankheit/Gewalt.
- Keine Partnerschaft/Geburt/Tod/Familienbaum/Follow/Alerts/Story of the Day/
  Chronik-Kuratierung.
- Kein A*/Pfad-Cache/Occupancy-Pathing, kein voller Feldzyklus.
- Keine Wirtschaft/Politik/Handel/Tiere/Fantasy/D-57-Systeme.
- Kein Replay, keine Spielereingriffe, kein Rewind.

---

## 3. Architektur und Dateien

### Produktionsmodule

| Bereich | Dateien |
|---|---|
| `src/data/` | `sim_config.gd` |
| `src/kernel/` | `hash_util.gd`, `rng_stream.gd`, `rng_streams.gd`, `sim_clock.gd`, `event_scheduler.gd`, `sim_event.gd`, `sim_logs.gd`, `sim_kinds.gd` |
| `src/agents/` | `agent_record.gd`, `household_record.gd`, `relationship_record.gd`, `agent_records.gd`, `agent_store.gd`, `simulation.gd` |
| `src/decisions/` | `needs_model.gd`, `role_schedule.gd`, `decision_system.gd` |
| `src/world/` | `building.gd`, `world_map.gd` |
| `src/navigation/` | `route_store.gd` |
| `src/persistence/` | `byte_writer.gd`, `byte_reader.gd`, `sim_save.gd` |
| `src/view/` | `view_state.gd`, `inspector_model.gd`, `event_log_model.gd`, `world_view.gd`, `game_camera.gd`, `hud.gd`, `demo_main.gd` |

### Tests / Szenen / Doku

- `tests/g1a/g1a_suite.gd|.tscn` — Headless-Gate
- `tests/g1a/test_kernel.gd`, `test_store.gd`, `test_needs.gd`,
  `test_world.gd`, `test_move.gd`, `test_food.gd`, `test_save.gd`,
  `test_ui.gd`, `test_bench.gd`, `test_context.gd`, `test_util.gd`
- `tests/g1a/demo.tscn` — sichtbare Demo
- `tests/g1a/bench_visual.gd|.tscn` — 10@50x-Frame-Benchmark
- `tests/g1a/capture_demo.gd|.tscn` — visueller Smoke-Screenshot
- `docs/g1a/v3-g1a-report.md`, `docs/g1a/README.md`

Geändert wurde außerdem `project.godot` (Main-Scene, Name, Fenster/Stretch,
Nearest-Filter). Alle Produktionsdateien bleiben unter ~500 Zeilen; keine Datei
über ~1.000 Zeilen. Der G0.5-Spike unter `src/spike/`, `tests/spike/`,
`bench/native/` wurde nicht verändert.

**Hinweis zu G0-Dokumenten:** `README.md` und `docs/v3-plan.md` waren im
Arbeitsbaum bereits vor dieser Implementierung mit Statuszeilen-Änderungen
(„G1a in Arbeit“) modifiziert. Diese G1a-Arbeit hat diese beiden Dateien nicht
angefasst; G0-Inhalte/Entscheidungen wurden nicht geändert.

### Kernentscheidungen

- **SoA-Hotstore** für Agenten; kalte Records für Identität/Beziehungen.
  Keine Per-Agent-Dictionaries in den Hot-Loop-Dateien (T-STORE-03 prüft den
  Quellcode).
- **Ein gültiges Scheduler-Event pro Agent.** Der Payload enthält
  `(wake_gen, row)`; stale Events nach externen Wakes werden deterministisch
  ignoriert. Ordnung strikt `(time, seq)`.
- **Lazy Needs:** Werte werden nur zu logischen Terminen materialisiert;
  Anzeige nutzt `value_at(now)` ohne Mutation.
- **Arbeit als Fortschritt:** volle Feldarbeitsstunden erzeugen Grain;
  Restsekunden werden über Unterbrechungen getragen.
- **Commitments:** Reisen, Essen, Schlafen und Sozialisieren werden nicht durch
  Needs unterbrochen; Arbeit/Lernen/Spielen/Idle schon.
- **Getrennte Logs:** Debug-Log (UI) und rohe G1a-Chronik sind getrennte
  Container und getrennte Save-Sektionen; keiner ist Replay-Quelle.
- **View liest nur:** `Simulation` kennt weder Kamera noch Zoom noch
  Sichtbarkeit. `ViewState` ist ausschließlich Darstellung.

---

## 4. Test-IDs und Ergebnisse

Alle Ergebnisse stammen aus dem finalen Lauf
`bench/results/g1a_suite_final.log` (Headless) und
`bench/results/g1a_visual_result.json` (visuell).

| ID | Ergebnis | Evidenz / Kernprüfung |
|---|---|---|
| T-KERN-01 | **bestanden** | 300 Events, Ordnung `(time, seq)`, 3 Läufe identisch |
| T-KERN-02 | **bestanden** | gleicher Seed → gleiche Streams; Streams unabhängig |
| T-KERN-03 | **bestanden** | Debug/Chronik getrennt; Log-Löschen ändert State nicht; Save-Sektionen getrennt |
| T-KERN-04 | **bestanden** | Clock/Scheduler/RNG/Snapshot exakt restauriert; Folgeverlauf exakt |
| T-STORE-01 | **bestanden** | 10 Agenten, stabile IDs, 3 Haushalte, kalte Records, keine Kopien |
| T-STORE-02 | **bestanden** | toter Agent bleibt per ID/Record referenzierbar; neue ID 11, keine Wiederverwendung |
| T-STORE-03 | **bestanden** | Quellcode-Scan der Hot-Loop-Dateien ohne `Dictionary`; Packed-Array-Typen |
| T-NEED-01 | **bestanden** | Hunger unterbricht Arbeit, Mahlzeit, Rückkehr zur Arbeit um 11:00 |
| T-NEED-02 | **bestanden** | Schlaffenster 21:00–06:00; +80/8h mit Clamp; 06:01 wach |
| T-NEED-03 | **bestanden** | Sozial-Need startet genau einmal, +30, kein Dauerloop |
| T-NEED-04 | **bestanden** | Need-Werte/-Events über 3 Läufe identisch |
| T-WORLD-01 | **bestanden** | alle 7 Gebäude im Weg-Graphen verbunden; Türen auf Wegen |
| T-WORLD-02 | **bestanden** | Footprints blockiert, Feld begehbar, Türen frei, keine Überlappung, Agenten auf begehbaren Tiles |
| T-WORLD-03 | **bestanden** | 145 Stichproben über einen Tag; keine Position/Ziel außerhalb; Clamp/Route in Grenzen |
| T-MOVE-01 | **bestanden** | `position_at` Start/Mitte/Ziel exakt, monoton; 1-s- vs. 1-Sprung-Lauf identisch |
| T-MOVE-02 | **bestanden** | Ankunft exakt zum Termin, ARRIVE-Event mit exakter Zeit |
| T-MOVE-03 | **bestanden** | Route mit ≥3 Wegpunkten; keine `AStar`/`astar`/`a_star`-Referenz in Navigation/Entscheidungen |
| T-FOOD-01 | **bestanden** | 12 Grain vormittags, 24 nach Nachmittag; 10/20 Mahlzeiten; Bilanz exakt |
| T-FOOD-02 | **bestanden** | 10 Mittagessen = −10 Grain; Hunger-Reset ≥45 |
| T-FOOD-03 | **bestanden** | 08:30: 0 Grain/0 erzeugt/0 Mahlzeiten, ≥10 Skips, Shortage-Event, Hunger >85; später nur erarbeiteter Grain |
| T-SAVE-01 | **bestanden** | Save 07:59:30; Verlauf bis 10:00 exakt (State/Events) |
| T-SAVE-02 | **bestanden** | Save 12:05 (nach Arbeit); Verlauf bis 18:00 exakt, unterschiedliche Chunks |
| T-SAVE-03 | **bestanden** | Schema 999 → `unsupported_schema`; Magic → `bad_magic`; Config-Hash → `config_hash_mismatch`; kein Teil-Load |
| T-UI-01 | **bestanden** | Inspector: Name, Alter, Rolle, Haushalt, Home, Job, Aktivität, Needs, Position, Next-Event |
| T-UI-02 | **bestanden** | Kernereignisse (`meal_end`, `work_end`, `arrive`) sichtbar; 5× Lesen ohne State-/Log-Mutation |
| T-UI-03 | **bestanden** | 17-s-Chunks mit wechselnder Kamera/Zoom/Sichtbarkeit/Auswahl vs. ein Sprung: identische Hashes |
| T-UI-04 | **bestanden** | visuell 10@50x: p95 6,89 ms, 165,1 FPS, 3,67 Sim-Tage |
| T-BENCH-01 | **bestanden** | 3 Läufe (Chunks 1 s / 300 s / 86400 s) identisch |
| T-BENCH-02 | **bestanden** | Headless- und visuelle Messung vorhanden und dokumentiert |

**3-Lauf-Hashes (Seed 1337, ein Sim-Tag):**

```text
state     0x13AC9730
event     0x2A36315F
chronicle 0xA105A4E3
```

---

## 5. Messwerte

### 5.1 Headless (Sim-Kosten)

Protokoll: 10 Agenten, Seed 1337, Warm-up 1.800 Sim-Sekunden, dann 1 Sim-Tag
in 1.080 `advance_to`-Aufrufen à 80 Sim-Sekunden (50x-Frame-Raster),
VSync nicht relevant, `Time.get_ticks_usec()`.

| Messwert | Ergebnis |
|---|---:|
| Events im Messfenster | 132 |
| Events/Frame | 0,122 |
| µs/Event (inkl. Advance-Overhead) | 48,5 |
| Sim p50 | 0,0010 ms |
| Sim p95 | 0,0010 ms |
| Sim p99 | 0,199 ms |
| Sim max | 0,603 ms |
| Sim-Slice-Budget p95 | ≤ 6 ms → **deutlich eingehalten** |

Der Headless-Aufruf ist meistens eventlos; deshalb ist p50/p95 ~1 µs. Die
Kosten pro tatsächlichem Event liegen je nach Lauf bei ~47–62 µs inklusive
Dispatch und Advance-Overhead. Ein Full-Agent-Sweep pro Frame existiert nicht.

### 5.2 Visuell (10 Agenten @50x)

Protokoll: 1920 × 1080, VSync **aus**, 6 s Warm-up, 60 s Messfenster,
Kamerafahrt Pan/Zoom, 50x, Seed 1337.

| Messwert | Ergebnis |
|---|---:|
| Frames | 9.908 |
| FPS (Durchschnitt) | 165,1 |
| Frame p50 | 5,94 ms |
| Frame p95 | **6,89 ms** (Budget ≤ 16 ms) |
| Frame p99 | 7,97 ms |
| Frame max | 13,05 ms |
| Sim-Zeit im Messfenster | 3,67 Sim-Tage |
| Events im Messfenster | 608 |
| Events/Frame | 0,061 |
| Draw Calls Ø / max | 830,5 / 832 |

Die 830 Draw Calls entstehen überwiegend durch die 180 Vektor-Bäume
(3–4 Primitives je Baum) plus Gebäude/Agenten/UI. Das ist für G1a unkritisch
(p95 6,89 ms), aber ein naheliegender Optimierungspunkt, falls die Szene
später wächst.

### 5.3 Sim-Tag / Bilanz (Seed 1337)

| Messwert | Ergebnis |
|---|---:|
| Debug-Events Tag 1 | 208 |
| Grain am Ende Tag 1 | 61 |
| Grain erzeugt | 24 |
| Mahlzeiten serviert | 23 |
| Mahlzeiten übersprungen | 0 |

Der Tag beginnt um 06:00. Vier Feldarbeiter erzeugen je 3 Grain am Vormittag
und 3 am Nachmittag (volle Arbeitsstunden; die Reisezeit 08:00→08:01 kostet
jeweils die volle vierte Stunde, der Rest wird als Restsekunden getragen).
23 statt 30 Mahlzeiten entstehen, weil ein Teil der Agenten während des
Energie-Nickerchens das 18:00-Abendessen verpasst. Das ist eine direkte Folge
der Spec-Raten (siehe Grenzen).

### 5.4 Save

| Messwert | Ergebnis |
|---|---:|
| Schema | 1 |
| Größe (12:05, Seed 1337) | 12.044 Bytes |
| Save-Zeit (Dev-Smoke) | 0,97 ms |
| Load-Zeit (inkl. Welt-/Log-Rekonstruktion) | 7,16 ms |
| Load exakt verifiziert | T-SAVE-01/02/03, T-KERN-04 |
| Version | inkompatible Versionen sichtbar abgelehnt |

Das Save enthält Clock, Scheduler-Heap inkl. `next_seq`, alle RNG-Streams,
Agenten-SoA, kalte Records, Haushalte, Beziehungen, Weltbestand, Routen,
Zähler sowie Debug- und Chronik-Log getrennt. Logs sind nicht autoritativ.

---

## 6. Sichtbare Demo und Startbefehle

### Demo

```powershell
$godot = "C:\Users\ajsch\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/demo.tscn
```

Alternativ ohne Szenenargument (Hauptszene ist die Demo):

```powershell
& $godot --path C:\coding\WimmelWorld\V3
```

Steuerung:

- Linksklick: Agent auswählen und fokussieren
- WASD/Pfeile: Kamera; Mausrad: Zoom; Mittlere Maustaste: Drag
- Leertaste: Pause; 1/2/3: 1x/10x/50x
- F5: Speichern (`user://g1a_save.bin`); F9: Laden

1x ist auf 15 reale Minuten pro Sim-Tag kalibriert (96 Sim-Sekunden pro realer
Sekunde). 50x entspricht 18 realen Sekunden pro Sim-Tag.

### Tests

```powershell
& $godot --headless --path C:\coding\WimmelWorld\V3 --import
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/bench_visual.tscn
& $godot --headless --path C:\coding\WimmelWorld\V3 res://tests/g1a/g1a_suite.tscn
```

Die Headless-Suite liest `res://bench/results/g1a_visual_result.json` für
T-UI-04 und T-BENCH-02. Deshalb **zuerst den visuellen Benchmark** ausführen;
danach die Suite. Details: `docs/g1a/README.md`.

Visueller Smoke-Screenshot:

```powershell
& $godot --path C:\coding\WimmelWorld\V3 res://tests/g1a/capture_demo.tscn
```

Er schreibt `bench/results/g1a_demo.png` (Tag 1, 10:00, Agent A1 ausgewählt)
und `bench/results/g1a_demo_night.png` (Tag 1, 22:00, Tag/Nacht-Smoke).

---

## 7. Bekannte Grenzen und bewusste G1a-Vereinfachungen

1. **Keine Gesundheit in G1a.** Knappheit führt zu ausfallenden Mahlzeiten,
   steigendem Hunger, `meal_skipped`-/`shortage`-Events und keiner stillen
   Auffüllung. Die Gesundheitsfolge ist G1b (T-NEED-07).
2. **Energie-Rate der Spec erzeugt einen Nachmittags-Nickerchen.**
   Start 80, −100/16 h wach, Schwelle 20 → ca. 15:36; Schlaf bis Energie 50
   (ca. 18:37). Dadurch verpassen einige Agenten das 17:00-Sozialisieren
   und/oder das 18:00-Abendessen. Das ist keine stille Anpassung, sondern eine
   beobachtete Folge der Spec-Startwerte/Raten; die Kalibrierung bleibt offen
   (G1-Spec §14).
3. **Grain-Modell ist bewusst einfach.** 1 Grain pro voller Feldarbeitsstunde,
   Mahlzeit = 1 Grain, Start 60. Reisezeit und Unterbrechungen tragen
   Restsekunden; es gibt keinen Crop-Zyklus, keine Aussaat/Ernte und keinen
   Feldzustand. Der zentrale Speicher ist ein gemeinsamer Kornspeicher; die
   Mahlzeit findet am Haus statt, verbraucht aber zentralen Grain.
4. **Need-Semantik:** Hunger ist ein Antrieb (0 = satt, 100 = sehr hungrig),
   Energie/Sozial sind Vorräte. Sozial fällt im Schlaf nicht; Hunger steigt
   auch im Schlaf. Diese Vereinfachung ist im Code dokumentiert.
5. **Routine-Vorrang:** Liegt ein Routinemahl/-schlaf/-sozialisieren innerhalb
   des Vorausschau-Fensters, wird der Need-Wake unterdrückt, um Doppelmahlzeiten
   zu vermeiden. Reisen/Essen/Schlafen/Sozialisieren sind Commitments; Arbeit,
   Lernen, Spielen und Idle können durch Needs unterbrochen werden.
6. **Kein Replay, kein A*/Pfad-Cache, kein Feldzyklus.** Bewegung ist ein
   kleiner Weg-Graph mit geraden Segmenten und `position_at(time)`.
7. **Keine Lebenszyklus-Simulation.** Beziehungen (Partner, Eltern, Großeltern,
   Freundschaft C1–C3) liegen als kalte Records vor und werden gespeichert,
   aber nicht verändert. T-STORE-02 nutzt einen testweisen Spawn, um
   ID-Lebenszyklus ohne G1b-Features zu prüfen.
8. **Save ist Schema 1, ohne Migration/Kompression.** Inkompatible Saves werden
   sichtbar abgelehnt. Die Logs werden mitgespeichert, sind aber nicht
   Replay-Quelle.
9. **Darstellung ist Programmer Art.** 16 px/Tile, 19–20 px Figuren,
   pseudo-3/4-Häuser, Vektor-Bäume. Keine Assets, kein LOD. Kamera/Zoom/
   Sichtbarkeit sind reine View-Werte.
10. **1x-Volltag:** Die Demo ist auf 15 reale Minuten pro Tag ausgelegt und
    damit direkt beobachtbar. Als Messläufe wurden ein voller Sim-Tag headless
    und 3,67 Sim-Tage visuell bei 50x erhoben; ein separater 15-minütiger
    1x-Videolauf ist nicht in den Rohdaten enthalten.
11. **Draw Calls:** 830,5 Ø durch Vektor-Deko. Innerhalb des G1a-Budgets, aber
    bei späterem Szenenwachstum zu optimieren.

---

## 7.1 Review-Verifikation (2026-11-13)

Unabhängig vom Implementierungslauf ausgeführt:

- `tests/g1a/g1a_suite.tscn`: **29/29**, 216 Checks, `G1A_SUITE_OK`.
- `tests/g1a/bench_visual.tscn`: p95 **7,43 ms**, **156,1 FPS**,
  830,5 Draw Calls, 3,67 Sim-Tage.
- Hauptszene `--quit-after 120`: Exit 0.
- G0.5-Regression `tests/spike/unit_checks.tscn`: `SPIKE_UNIT_OK`.
- Tag-/Nacht-Screenshots: Inspector, Event-Log, Agenten im Feld/Haus,
  Schlaf-Marker und Tag/Nacht-Tint sichtbar.

**Review-Notizen:**

- G1a-Scope ist korrekt; keine G1b-/G2-Systeme in der Produktion.
- Keine Kamera-/Zoom-/Sichtbarkeitsreferenzen in Simulation, Entscheidungen
  oder Scheduler.
- Energie-Nickerchen und 23/30 Mahlzeiten sind Kalibrierungsbeobachtungen,
  kein Blocker.
- 830 Draw Calls sind für G1a okay, aber ein G2-Optimierungspunkt.
- Nicht-selektierte Agentenlabels werden im Feld zu „A“ gekürzt; UI-Polish
  für G1b/G2.
- Die Headless-Suite liest `bench/results/g1a_visual_result.json`; ein frischer
  Clone muss zuerst den visuellen Benchmark ausführen.

## 8. Abnahmebeurteilung

**Review-Ergebnis: G1a bestanden mit Auflagen.** Alle 29 Test-IDs bestehen,
die sichtbare Demo läuft, Determinismus und Save/Load sind exakt, die
10@50x-Messung liegt mit p95 7,43 ms (Review-Lauf) unter 16 ms, und die
G0.5-Referenz bleibt grün.

**Auflagen für G1b/G2:**

- Energie-/Mahlzeiten-Kalibrierung vor G1b abschließen.
- Draw-Call- und Label-Polish in G1b/G2.
- Visuellen Benchmark vor der Headless-Suite dokumentiert ausführen.

Es wurden **keine Git-Commits** und kein Push durch den Implementierer
ausgeführt; der Review-Commit folgt separat.
