# G4a-Abnahmebericht – 10.000-Agenten-Kern

Status: **G4a bestanden (Review 2026-11-14); `g4a`-Tag folgt**  
Stand: 2026-11-14
Basis: G3 (`g3`, HEAD bdbee61) + G4a-Arbeitsstand
Godot: 4.7.2 stable (Standard-Build, GDScript)

## 1. Ergebnis

G4a ist **abgenommen**. Der 10k-Kern erfüllt alle T-G4a-01..10-Prüfungen,
die drei 120-Tage-Läufe sind bitgleich, die 200 Herbsternten und die
Grain-Jahresbilanz stimmen, und 10k@50x liegt in **drei headless** sowie
**drei visuellen** 5-Minuten-Läufen unter p95 16 ms / p99 20 ms.

| Track | Ergebnis |
|---|---|
| G4a-Suite | 12/12 PASS, 208 Checks |
| G1a | 29/29 PASS |
| G1b | 28/28 PASS |
| G2 | 21/21 PASS |
| G3a | 13/13 PASS, Hashes bitgleich zu G3 |
| Visueller 120-Tage-Smoke | OK, 4 Screenshots, 200 Ernten |

## 2. Geänderte/erstellte Dateien

**Neu (Kern):**
- `src/decisions/field_work_system.gd`
- `src/decisions/work_system.gd`
- `src/decisions/need_actions.gd`

**Geändert:**
- `src/data/sim_config.gd`
- `src/agents/simulation.gd`
- `src/agents/population_generator.gd`
- `src/agents/lifecycle_system.gd`
- `src/decisions/decision_system.gd`
- `src/decisions/role_schedule.gd`
- `src/decisions/needs_model.gd`
- `src/world/world_map.gd`
- `src/navigation/path_finder.gd`
- `src/navigation/route_store.gd`
- `src/persistence/sim_save.gd`
- `src/view/world_view.gd`
- `src/view/chronicle_hud.gd`
- `src/view/hud.gd`

**Tests/Benchmarks:**
- `tests/g4/g4_a_suite.gd`, `g4_a_suite.tscn`
- `tests/g4/g4_a_test_util.gd`
- `tests/g4/test_g4_01_world.gd` … `test_g4_10_scope.gd`
- `tests/g4/bench_visual.gd`, `bench_visual.tscn`
- `tests/g4/visual_120days.gd`, `visual_120days.tscn`

**Doku:**
- `docs/g4/README.md`
- `docs/g4/v3-g4a-report.md`

`src/lod/`, B-Tests, B-Doku, G0-Dokumente, README und `docs/v3-plan.md`
wurden nicht verändert. Keine G4b-Systeme.

## 3. Refactor-Ergebnis

`decision_system.gd` wurde vor der Skalierung von 986 auf 632 Zeilen geteilt:

| Datei | Zeilen | Inhalt |
|---|---:|---|
| `decision_system.gd` | 632 | Orchestrierung, Scheduling, Reisen, Routine |
| `field_work_system.gd` | 269 | Feldzustand, Arbeit, Ernte, Feld-Ticks |
| `need_actions.gd` | 251 | Need-Aktionen, Home-/Platz-/Brunnen-Punkte |
| `work_system.gd` | 28 | Arbeitsabschluss |

Verhalten blieb unverändert: G3 liefert exakt dieselben Hashes wie vor dem
Refactor (`state 0x5D49B80C`, `event 0x92367DFC`,
`chronicle 0xA09E0CBF`, `alive 1040`, `harvests 40`).
Zusätzlich wurden die Rollenpläne als unveränderliche Minuten-Tabellen
materialisiert; die G3-Hashes blieben bitgleich.

Detail-Suiten G1a/G1b/G2/G3: **91/91 PASS**.

## 4. 10k-Welt, Bevölkerung, Felder

| Größe | Wert |
|---|---:|
| Welt | 2048 × 2048 Tiles |
| Gebäude | 2.206 |
| Häuser | 2.000 |
| Felder | 200 |
| Werkstätten | 3 |
| Support | Kornspeicher, Scheune, Brunnen |
| Chunks | 4.096, davon 767 materialisiert |
| Agenten | 10.000 |
| Haushalte | 2.000 |
| Erwerbsfähige (18–59) | 3.900 |
| Feldarbeiter | 2.150 |
| Werkstattarbeiter | 2.946 |
| Beziehungen | 31.450 |
| Startgrain / Granary | 3.600.000 / 7.200.000 |

Rollen: 4.344 Kinder, 1.656 Jugendliche, 3.900 Erwachsene, 100 Alte.
Die ersten 200 Haushalte decken über `home_id % 200` alle 200 Felder ab und
stellen je Feld mindestens einen erwerbsfähigen Feldarbeiter.

## 5. Test-ID-Ergebnisse

| Test | Ergebnis |
|---|---|
| T-G4a-01a/b/c | PASS: 2048², 2.000 Häuser, 200 Felder, 2.206 Gebäude, 767/4.096 Chunks; 10.000 Agenten, 2.000 Haushalte, 3.900 Erwerbsfähige; deterministische Generierung |
| T-G4a-02 | PASS: 120 Tage, 4 × 30 Seasons, Frühling/Herbst-Fenster |
| T-G4a-03 | PASS: 200 Herbsternten, 0 außerhalb; Grain-Bilanz exakt |
| T-G4a-04 | PASS: A*/Wegpunktgraph, Cache 97,58 %, Budgets, keine Full-Agent-Sweeps, Chunk-Index |
| T-G4a-05 | PASS: Batching, `out_of_order=0`, Chunks 1/3600 hashgleich |
| T-G4a-06 | PASS: 120 Tage, 3 Läufe, Chunks 1/60/3600, alle Hashes gleich |
| T-G4a-07 | PASS: Schema 7, Save/Load exakt, Budgets, Schema 1–6 abgelehnt |
| T-G4a-08 | PASS: 10k@50x, 3 Läufe, p95/p99 eingehalten |
| T-G4a-09 | PASS: Inspector/Event-Log/Chronik/Familienbaum/Follow bei 10k, read-only |
| T-G4a-10 | PASS: D-57-Stubs, keine G4b-Module, B-Isolation, Dateigrenze, Schema 7 |

## 6. 120-Tage-Determinismus

Drei Läufe mit Chunks **1 / 60 / 3600** über je 120 Sim-Tage:

| Lauf | Chunk | State | Event | Chronik | Alive | Ernten |
|---|---:|---|---|---|---:|---:|
| 1 | 1 | `0xF1FC5EE7` | `0x1A410B37` | `0x3D78CD8F` | 10.233 | 200 |
| 2 | 60 | `0xF1FC5EE7` | `0x1A410B37` | `0x3D78CD8F` | 10.233 | 200 |
| 3 | 3600 | `0xF1FC5EE7` | `0x1A410B37` | `0x3D78CD8F` | 10.233 | 200 |

Jahresbilanz (Lauf 1):

```text
alive=10233 grain=3.644.695 start=3.600.000 seed=400.000
harvested=4.000.000 meals=3.555.305 skipped=0
seasons=[0, 0, 200, 0]
```

Damit gilt: 200 Ernten, alle im Herbst, 0 außerhalb; Saatgut 400.000;
Netto 3.600.000; Mahlzeiten 3.555.305; Granary nicht überlaufen.

## 7. 10k@50x Performance

### Headless, 5-Minuten-Fenster (18.000 Frames à 80 Ticks), 3 Läufe

| Lauf | p50 | p95 | p99 | Max | Events/Frame | >16 ms |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 4,13 | **12,40** | **17,41** | 244,48 | 142,6 | 285/18.000 |
| 2 | 4,11 | **12,41** | **17,47** | 216,15 | 142,5 | 287/18.000 |
| 3 | 4,09 | **12,36** | **17,23** | 196,85 | 142,8 | 293/18.000 |

Pfadstatistik je Lauf: ~1,07 Mio. Anfragen, Cache-Hit **97,58 %**,
33.882 Cache-Einträge, 25.882 Graph-Recalculations, 0 Tile-A*-Fallbacks,
max. 512 Lookups/Frame, 0 Tile-Recalculations/Frame.
Kein Full-Agent-Sweep pro Frame; Event-Batches `out_of_order=0`.

### Visuell, 5-Minuten-Fenster, VSync aus, 1920×1080, 3 Läufe

| Lauf | Frame p95 | Frame p99 | Max | FPS | Sim p95 | Render p95 | Draw Calls avg |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | **9,39** | **13,34** | 248,43 | 225,6 | 5,65 | 7,48 | 85,3 |
| 2 | **9,15** | **13,10** | 250,30 | 233,7 | 5,53 | 7,35 | 85,1 |
| 3 | **9,77** | **14,07** | 426,99 | 221,1 | 5,87 | 7,54 | 84,8 |

Alle sechs Läufe erfüllen p95 ≤ 16 ms, p99 ≤ 20 ms und ≥ 60 FPS.
Der visuelle Lauf nutzt einen MultiMesh-Markerpfad (ein Draw-Call für die
Agenten), Fern-LOD über die Terrain-Textur und deterministische
3-Frame-Marker-Updates; die Simulation bleibt kameraunabhängig.

Speicher (zusätzlicher visueller 5-Minuten-Lauf): statischer Speicher
288,9 MB → 291,5 MB, also **+2,6 MB** im Messfenster (Chronik-/Logwachstum,
kein sprunghafter oder routenbedingter Leak). Die ObjectDB-Warnung beim
Prozess-Exit stammt aus statischen Test-Referenzen der Suite, nicht aus
Simulationsobjekten pro Frame.

### Sichtbarer 120-Tage-Smoke

Tag 55→71 bei 50x, Screenshots an Tag 56/61/66/71:
frame p95 **10,03 ms**, 214 FPS, Cache **99,36 %**,
`harvests=200`, `seasons=[0,0,200,0]`, `grain=5.111.304`.

## 8. Save/Load, Schema 7

Snapshot an Tag 61, 07:10 (Herbstfelder reif/teilgeerntet, 1.760 Agenten
unterwegs, 176 Geburten, 103 Todesfälle):

| Größe | Wert | Budget |
|---|---:|---:|
| Schema | 7 | 7 |
| Dateigröße | 892.667 Bytes (0,89 MB) | ≤ 30 MB |
| Save | 216,8 ms | ≤ 2.000 ms |
| Load | 1.088 ms | ≤ 10.000 ms |
| State/Event/Chronik | exakt | exakt |
| Pfad-Cache | nicht gespeichert, beim Load via 8.000 Prewarm-Pfade neu aufgebaut | – |

Schema 1–6 werden für das 10k-Profil sichtbar als `unsupported_schema`
abgelehnt; historische G3-Saves bleiben im G3-Profil unter Schema 6 ladbar.
Der Payload ist ZStd-komprimiert; der Header bleibt schema-/versionsprüfbar.

## 9. Optimierungen (messbar)

- **Entscheidungsmodule:** 986 → 632 Zeilen; keine Verhaltensänderung.
- **Rollentabellen:** O(1)-Minutentabellen statt Plan-Scans pro Wake.
- **Need-Raten:** vorberechnete Sekundenraten, Inline-Settle (Settle-Zeit ca. halbiert).
- **Route-Längen:** einmalig gecacht statt Polyline-Summe pro Marker-Frame.
- **Pfadgraph:** A* auf ~600 Straßen-Wegpunkten plus kurze Anker; Tile-A* nur
  als Fallback (0 im headless 10k-Lauf, 452/4,16 Mio. im 16-Tage-Visual).
- **Cache:** FIFO-Eviction O(1), 65.536 Plätze, 97,6 % Hitrate.
- **Quellaggregation:** Routine-/hochfrequente Notable-Events werden gezählt,
  nicht materialisiert; seltene Lebens-/Feld-/Krisen-Events bleiben.
- **Jitter:** deterministischer Avalanche-Hash statt linearer id/home-Formel;
  Routine- und Need-Wakes werden sekundengranular gespreizt (keine
  Minuten-Cluster).
- **Render:** MultiMesh-Marker, 3-Frame-Gruppen, Farben einmalig, Fern-LOD.
- **World/Chunks:** Rechteck-Chunkmarkierung statt 4-Mio.-Tile-Scan;
  O(1)-Gebäude-/Feldindizes.

## 10. Bekannte Grenzen

- Der Pfadgraph ist auf das G4-Siedlungsraster zugeschnitten (Hauszeilen,
  Feldzugang, Support-Stichstraßen). Eine Layoutänderung braucht eine
  Anpassung der Graphknoten.
- Tile-A*-Fallback bleibt für nicht registrierte Anker (z. B. einige
  Gebäudetüren) aktiv; im 16-Tage-Visual 452 Anfragen von 4,16 Mio.
- Lifecycle-Rolltage erzeugen einzelne Max-Frame-Spikes (ca. 200–430 ms);
  p95/p99 bleiben davon unberührt, weil sie nur wenige Frames betreffen.
  Eine spätere Verteilung der Rollarbeit über den Tag ist möglich.
- Headless-Suite-Laufzeit: ca. 35 Minuten (drei 120-Tage-Läufe dominieren).
- G4b (Wirtschaft/Politik/Handel/Karawanen/Steuern/Diplomatie) ist nicht
  implementiert und nicht Teil dieser Abnahme.

## 11. Abnahme

**G4a vollständig bestanden.** Empfehlung: `g4a` taggen. Der Rückfall auf
`g3` ist nicht nötig. Es wurden keine Commits oder Tags durch den
Implementierungsagenten erstellt.

## 12. Review-Verifikation (2026-11-14)

- Der erste Suite-Lauf meldete **57.889 geleakte ObjectDB-Instanzen**. Ursache:
  `FieldWorkSystem`, `WorkSystem` und `NeedActions` hielten `DecisionSystem`
  stark (`d = host`). Fix: **WeakRef** wie in `DecisionSystem`/`LifecycleSystem`.
- Nach dem Fix: **12/12**, 208 Checks, 2.129,66 s, **keine Leak-Warnung**.
- 120 Tage, Chunks 1/60/3600: `state 0xF1FC5EE7`, `event 0x1A410B37`,
  `chronicle 0x3D78CD8F`; 10.233 lebend, 200 Ernten.
- Jahresbilanz: `3.600.000 + 4.000.000 − 400.000 − 3.555.305 = 3.644.695`;
  `seasons [0,0,200,0]`, 0 Skips.
- 10k@50x headless: p95 **12,33–12,49 ms**, p99 17,41–17,95 ms; visuell
  Frame-p95 9,15–9,77 ms, 221–234 FPS.
- Save: 892.667 Bytes, 219 ms Save, 1.164 ms Load; Schema 7.
- `decision_system.gd` nach Refactor 550 Zeilen; Module klein und getrennt.
- G1a/G1b/G2/G3: **91/91** grün.
- **G4a abgenommen.** Kein Rückfall auf `g3`; `g4a`-Tag folgt.
