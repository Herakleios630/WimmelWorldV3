# V3-Architektur

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, D-11, D-13, D-19, D-20, D-21.

## 1. Ziele und Grenzen

- Deterministische, kameraunabhängige Simulation.
- 10k@50x und 100k@10x als Pflicht; 100k@50x als Stretch.
- Kein Kamera-LOD, keine stillen Zeit-/Event-Sprünge.
- Eine autoritative Quelle pro Fakt; Caches sind abgeleitet.
- GDScript zuerst; Hot-Path-Port nach C#/GDExtension bei gemessenem Bedarf.
- Engine und Spielschale getrennt; V3 nutzt keine Spielereingriffe.

## 2. Schichten

### 2.1 Kernel

- `SimClock`: ganzzahlige Sim-Zeit, **1 Tick = 1 Sim-Sekunde** als Zeiteinheit,
  keine Wall-Clock.
- `EventScheduler`: Min-Heap, stabile Ordnung `(time, seq)`, keine
  Dictionary-Iteration.
- `RngStreams`: getrennte Streams für Welt, Agenten, Wirtschaft, Politik,
  Lifecycle, Kampf (später).
- `DebugLog` und `ChronicleLog` sind getrennt; **keiner ist Replay-Quelle**.
- `Snapshot`: Clock, Scheduler, RNG, Event-Sequenz, Konfiguration.

**Zeit-Semantik:** Events liegen auf logischen Terminen, nicht auf jedem Tick.
**1 Sim-Minute ist das Entscheidungsquantum/der Planungshorizont**, kein
Pflicht-Polling aller Agenten pro Minute. Es gibt keinen Sekunden- oder
Minuten-Loop über alle Agenten.

### 2.2 Welt

- Einheitliche Tile-Skala: 1,5 m/Tile, 16 px/Tile, 3/4-Topdown.
- Sparse Koordinatenraum; materialisiert werden aktive Siedlungen, Wege und
  Chunks.
- Terrain/Walkability prozedural aus Seed; Chunks sind abgeleitet.
- Gebäude, Footprints und Occupancy mit einem Besitzer.
- Straßen/Graphen: lokale Tiles plus regionaler Siedlungs-/Straßen-Graph.
- Bürger können lokale Wege bauen; Graph-/Tile-Versionen invalidieren Caches.

**Stub-Definition (G2/G3):** Ein Stub ist ein Daten-/UI-Platzhalter **ohne
Simulationseffekt**: keine Events, keine Zustandsänderung, keine Verbraucher,
keine Produktion. Abnahme: sichtbar/ladbar, aber wirkungslos.

### 2.3 Agenten

- Hot-Store als Structure of Arrays:
  `id`, `alive`, `age`, `position`, `activity`, `next_event`, `hunger`,
  `energy`, `social`, `hygiene`, `fun`, `health`, `home_id`, `job_id`.
- Kalte Records: Name, Beziehungen, Historie, Inventar, Traits.
- Stabile Integer-IDs, keine Wiederverwendung.
- Keine Per-Agent-Dictionaries in Hot-Loops.
- Höchstens der früheste Termin pro Agent im Scheduler; weitere Termine im
  Agentenzustand.

### 2.4 Entscheidungen

- Need-basierter Zustandsautomat plus Utility/Priorität.
- Aktivitäten: `IDLE`, `WORK`, `SEEK_FOOD`, `EAT`, `SLEEP`, `SOCIAL`,
  `HYGIENE`, `LEISURE`, `TRAVEL`, `DANGER` (später).
- Commitments und Fortsetzung statt ständigem Wechsel.
- Externe Wake-ups für Gefahr, Job, Gebäude, Weg, Bestand.
- Keine vollständige Neuplanung pro Frame.

### 2.5 Bewegung und Navigation

- Zeitbasierte Routengeometrie: Start, Ziel, Geschwindigkeit, Reisezeit.
- `position_at(time)` per Binärsuche; Ankunft exakt zum Termin.
- Lokaler A* auf Tiles; Pfad-Cache mit Map-/Building-/Road-Version.
- Fernreisen über regionalen Graphen, nicht über globales A*.
- Pfadaufrufe pro Frame budgetiert; Cache-Hit-Rate messen.

### 2.6 Wirtschaft und Politik

- Haushalte, Siedlungen und Nationen als Ledger-/Bestandsbesitzer.
- Produktion/Verbrauch/Löhne/Steuern in Tages-/Wochenbatches.
- Lokale Märkte, Preise, physische Karawanen, Handelsabkommen.
- Nationen: Schatzkammer, Steuersatz, Budget, Diplomatie, Verträge.
- Keine Transaktion pro Agent und Tick; keine doppelte Buchung.
- Wirtschaft/Politik aktualisieren pro Siedlung/Nation, nicht pro Frame.

### 2.7 Persistenz und Replay

- Versioniertes Binär-Save; Schema-Version im Header.
- Inhalt: Clock, Scheduler, RNG, Agenten-Arrays, kalte Records, Welt,
  Haushalte, Siedlungen, Nationen, Wirtschaft, Chronik-Summaries,
  DeadAgent-Archiv, Replay-Metadaten, Konfiguration.
- Deterministischer Restore; abgeleitete Indizes werden rekonstruiert.
- **Replay = Re-Simulation aus Seed + Konfiguration + Save-Snapshot**, nicht
  aus dem Chronik-/Debug-Log. Keine Spielereingriffe.
- Retention: jung notable+ im Ringpuffer, älter aggregiert, historisch
  budgetiert; Routine wird an der Quelle aggregiert.

### 2.8 View/UI

- Liest ausschließlich Snapshots/Views; schreibt nie Simulation.
- Chunk-Terrain, instanzierte Agenten/Tiere, 3/4-Topdown.
- Rendering-LOD erlaubt (Marker/Instanzen), Simulation-LOD nicht.
- Kamera/Zoom/Sichtbarkeit nur Darstellung.
- Inspector, Event-Log, Familienbaum, Follow, Alerts, Story of the Day.

## 3. Verträge

1. **Ein Zustandsbesitzer:** Jedes Feld hat genau eine autoritative Quelle.
2. **Determinismus:** Gleicher Zustand, Seed, Konfiguration und gleiche
   Eingaben ergeben bei gleicher Sim-Zeit denselben relevanten Zustand.
3. **Ereignisordnung:** `(time, seq)` bleibt die Grundordnung.
4. **Keine stillen Sprünge:** keine Teleports, kein LOD-gesteuertes Aussetzen,
   keine übersprungenen Events, keine künstlichen Zeitgewinne.
5. **Kameraunabhängigkeit:** Simulation liest niemals Kamera, Zoom oder
   Sichtbarkeit.
6. **Abrechnung vor Zugriff:** Fällige Buchungen werden vor konkurrierenden
   Zugriffen materialisiert.
7. **Messbarkeit:** Jede Performancebehauptung braucht Last, Seed, Warm-up,
   Szene, Dauer und Rohdaten.
8. **Keine versteckte Fidelity:** A/B-Entscheidungen laufen über den
   B-Vertrag (`v3-fidelity.md`).

## 4. Threading

- Simulation standardmäßig single-threaded und deterministisch.
- Erlaubte Worker: Terrain-/Chunk-Generierung, Pfad-Vorberechnung,
  Render-Vorbereitung; Ergebnisse werden deterministisch einsortiert.
- Keine Worker, die Event-Reihenfolge oder RNG-Verbrauch verändern.
- Bei Native-Port: gleiche Event-/RNG-Semantik, keine Nebenläufigkeit im
  autoritativen Zustand.

## 5. Modulgrenzen und Dateien

- `src/kernel/`, `src/world/`, `src/agents/`, `src/decisions/`,
  `src/navigation/`, `src/economy/`, `src/politics/`, `src/persistence/`,
  `src/view/`, `src/data/`.
- Weiche Dateigrenze: ~1.000 Zeilen; darüber nach Verantwortlichkeit teilen.
- Keine neue `settlement_runtime.gd`-Monolithdatei.
- Jedes Subsystem hat Tests und einen messbaren Benchmark.
- Öffentliche Schnittstellen dokumentieren; keine zyklischen Abhängigkeiten.

## 6. Engine-/Spielgrenze

- Engine: deterministischer Kernel, Welt, Agenten, Entscheidungen, Navigation,
  Wirtschaft/Politik, Persistenz, View-API.
- Spielschale: Kamera, UI, Chronik-Darstellung, Zeitsteuerung, Szenen.
- Für Cursed Beyond bleibt eine Command-/Event-API vorbereitet; V3 nutzt sie
  nicht für Spielereingriffe.
- Kein Netzwerk in V3.

## 7. Test- und Messstrategie

- Unit-Tests für Kernel, Store, Needs, Pfad, Save.
- Property-/Determinismustests für wiederholte Läufe.
- Golden Runs für G1a/G1b/G2–G5.
- Kamera-/Zoom-/Sichtbarkeitsvergleiche.
- Benchmarks pro Gate; 3 Läufe, p50/p95/p99/max, Events, Speicher, Save-Größe.
- Kein „PARTIAL“: Ein Gate ist nur bestanden, wenn alle Kriterien erfüllt sind.

## 8. Offene Architekturpunkte

- Genaue SoA-Feldliste und kalte Record-Struktur (G0-Datenmodell).
- Chunk-Größe, Cache-Eviction und Materialisierungsregeln (G0.5/G2).
- Pfad-Cache-Schlüssel und Invalidierung (G0.5/G2).
- Native-Port-Grenze und Interop (G0.5).
- Event-Log-Format und Retention (G0-Chronik).
- Save-Kompression und Migrationsschema (G0-Datenmodell).
