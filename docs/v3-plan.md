# WimmelWorld V3 — Planung

Status: G1b Schritte 1–2 bestanden; Schritt 3 (Chronik/Beobachtung) bereit  
Stand: 2026-11-13  
Arbeitsmodus: **Nur Analyse und Planung. Kein Code, keine Implementierung, keine Änderung an V1/V2.**

> **Externes Review 2026-11-13:** `reviews/v3-review-2026-11-13.md`.
> Die strukturellen Änderungen sind bestätigt: G0.5-Technikspike, G1a/G1b,
> G4a/G4b, G5a/G5b, D-57-Stubs, Chronik-Design und B-Fidelity-Vertrag.

## 0. Zweck und Prozess

Dieses Dokument ist die einzige lebende Planungsquelle für V3. Es wird nach
jeder Entscheidung im Chat aktualisiert. Entscheidungen bekommen IDs (`D-01`,
`D-02`, …) und werden im Entscheidungslog festgehalten. Es gibt keine stillen
Richtungswechsel.

Grundregel für die Planung: Erst das Ziel und die Abnahmekriterien, dann die
Architektur, dann der Code. Kein Feature und keine Optimierung ohne Bezug zu
einem beschlossenen Gate.

### Kurzfassung der bisherigen Richtung

- V3 ist ein kompletter Neustart ohne V1-/V2-Code.
- Ziel: spielbare, beobachtbare Wimmelbild-Lebenssimulation **und** Fundament
  für Cursed Beyond; 10k ist ein Zwischenschritt, ~100k die Designperspektive.
- Erste sichtbare Abnahme: **10 Akteure** mit Bedürfnissen, Arbeit, Wohnung,
  Nahrung, Tag/Nacht, Beziehungen und Lebenszyklus.
- Zeitbasis: **30 Tage/Jahr**, **15 reale Minuten/Tag bei 1x**, 4 Jahreszeiten,
  1 Sim-Minute als Entscheidungsquantum; typische Lebensspanne **~50 Jahre**
  mit hoher Variation (viele sterben mit ~30, einzelne werden ~70).
- Skalenleiter: **10 → 100 → 1.000 → 10.000 → 100.000** Individuen, mit
  Siedlungstypen als Meilensteinen.
- Welt: **3 Nationen** (Untote und Orks zunächst außen vor), **kompakt ~100k**,
  ~90–120 Siedlungen.
- Raum: **eine durchgehende Tile-Skala**, sparse materialisiert, Fernreisen
  über Siedlungs-/Straßen-Knoten; keine getrennte „reduzierte“ Umlandkarte.
- Maßstab: **1,5 m/Tile, 16 px/Tile, ~19–20 px Figuren**.
- Fidelity: **Vollsimulation als Start (A)**, deterministisches Tiering (B) als
  messungsgetriebener Fallback; **strikt kameraunabhängig**.
- Technik: wiederverwendbare deterministische Engine plus dünne Spielschale;
  Save/Replay ab Tag 1, noch kein Netzwerk.
- Sprache/Modell: **GDScript zuerst**, Hot-Path-Port nach C#/GDExtension bei
  Bedarf; **SoA + eventgetrieben**.
- Projekt: **frisches `V3/` mit eigenem Git-Repo**.
- G1: **landwirtschaftlicher Weiler** mit 10 Agenten.
- Messung: **Ryzen 5 5600 / RTX 5060** plus identische headless-Läufe.
- Gates: **G0, G0.5, G1a/G1b, G2, G3, G4a/G4b, G5a/G5b** mit sichtbarer Demo,
  Determinismus, Save/Load, Replay, Benchmark und Review; kein „PARTIAL“.
- G0.5: **Technikspike** vor G1 (Scheduler, SoA, Needs, Pfad, Render,
  GDScript-vs-Native); keine Gameplay-Implementierung.
- G1: **G1a** Kern-Loop mit drei Needs; **G1b** weitere Needs, Soziales,
  Lebenszyklus und alle Chronik-Tools. Beide formal abnehmen.
- G5: **G5a** Skalierung/Welt/Graph/Save; **G5b** Märkte, Karawanen, Steuern,
  Budget, Diplomatie, Krisen.
- D-57: Zusatzsysteme ab G2/G3 nur als **Daten-/UI-Stubs**; echte Simulation ab
  G4/G5.
- Fidelity: **B-Vertrag** jetzt definieren (preserved fields, Approximationen,
  Determinismus, Save/Replay, Freigabepflicht).
- Budgets: provisorisch pro Szenario/Event-Typ, in G0.5/G2 kalibrieren, harte
  Gates ab G3.
- Spielerrolle: **Beobachter/Chronist**, in V3 **keine Eingriffe**; Einfluss
  erst in einer späteren Version.
- Kern: **Geschichten/Chronik**, Sandbox ohne Game Over.
- G5-Systeme: **Leben + Wirtschaft + Handel + Politik**; Krieg/Tiere später.
- Wirtschaft/Politik: **Haushalte + lokale Märkte + physische Karawanen +
  Schatzkammern**; **3 Nationen mit Steuern/Budget/Diplomatie**, Utility-KI und
  Ressourcen-Spezialisierungen; Krisen als Chronik, kein Game Over.
- Scope: V3-Kern = **Leben + Soziales + Wirtschaft + Handel + Politik**;
  Krieg, Tiere, Untote/Orks/Drachen sind **Erweiterungen nach G5**.
- Setting: **Low-Fantasy-Mittelalter**, 3 menschliche Nationen; Untote/Orks als
  spätere JSON-Addon-Fraktionen, Drachen als seltene Events.
- Soziales: **Liebe/Familie/Freundschaft/Reputation**.
- Art/UI: **3/4-Topdown**, Inspector + Chronik + Familienbaum.
- Weitere Systeme: **Wetter, Feste, Religion, Kultur, Krankheit, Recht und
  Bildung** als leichte Systeme ab G2/G3; keine Tiefensimulation.
- Beobachtung: **Inspector + Chronik + Beziehungen**.
- Chronik: **kuratiert** (Event-Log, Wichtigkeit, Summaries/Templates),
  **deutsch**, Ebenen **Individuum + Familie + Siedlung**.
- G1-Werkzeuge: **Inspector + Event-Log + Familienbaum + Follow + Alerts +
  Story of the day**; **kein Rewind** in V3.
- Prozess: Hauptagent als PM/Reviewer, Subagenten für Implementierung, eine
  Quelle der Wahrheit, harte Gates, menschliche Freigabe pro Meilenstein.

## 1. Ausgangslage (belegt durch Dokumente und Code-Inspektion)

### 1.1 V1

- Umfang: ca. 11.500 Zeilen Addon-Code, ca. 1.400 Zeilen Demo, ca. 9.700
  Zeilen Tests; 433 Test-Checks laut Dokumentation grün.
- Inhalt: Bewohner, Bedürfnisse, Familien, Jobs, Wirtschaft, Tiere, Fraktionen,
  Politik, Krieg, Untote, Rendering, UI, Save/Load.
- Messung: 1.008 Bewohner, Speed 3, Nahzoom: Ø 58,55 ms, p95 137,57 ms.
  Der 5-Minuten-10k-Lauf erreichte 21.144/21.600 Ticks (97,89 %), 6,33 s
  Delta-Clamping, Spitzen bis 1,3 s. **M2 verfehlt, M3 nicht nachgewiesen.**
- Architektur: großer `Being`-Kern, viele Systeme in einer Laufzeit, lokale
  Optimierungen, Performance-Modus und Makro-Schnellvorlauf mit abweichendem
  Verhalten.

### 1.2 V2

- Umfang nach ca. drei Tagen: ca. 17.000 Zeilen `src`, ca. 24.800 Zeilen Tests.
- Erreicht: sauberer Kernel (Clock, `(time, seq)`-Scheduler, RNG-Streams,
  Event-Vertrag), Agenten-/Accounting-/Navigations-/Save-Grundlagen, visueller
  Welt-Slice, Jahres-Feldzustand, Nutztierherden, Kohortenprototyp.
- Offen: 10k-p95 ca. 154–166 ms bei ca. 471.000 Events pro 600 Ticks;
  Batch-Maxima 1.000/750/750; M2 nur „PARTIAL“, M3 fehlt.
- Reaktion auf Performance: Cache-Vergrößerung, Accounting-Stagger,
  Delivery-Chunking, Agenten-Phasenoffsets, Speed-Profile und Kohortenmodus.
  Keine dieser Änderungen löste das p95-Problem; einige senkten den Durchsatz
  oder veränderten das Verhalten.
- `settlement_runtime.gd` ist nach wenigen Tagen bereits 2.897 Zeilen groß.
- ADR 0009 führt einen Kohortenmodus ein, der ausdrücklich **nicht** identisch
  zum Detailmodus ist; der Rückweg Kohorte → Detail ist approximiert.

### 1.3 Gemeinsame Muster

Beide Versuche haben viel Funktionalität und viele Tests erzeugt, aber das
eigentliche Abnahmekriterium nie erreicht. Die wichtigsten Muster:

1. **Kein klares Gesamtziel für Optik und Engine.** Beide wurden nicht von
   Anfang an gemeinsam durchgeplant; Grafik-, Welt- und Performanceentscheidungen
   wurden unabhängig voneinander getroffen.
2. **Kein hartes Nordstern-Gate.** M2/M3 wurden nie als vollständige,
   wiederholbare Abnahme durchgeführt; „PARTIAL“, „technischer Slice“ und
   Kurzbenchmarks ersetzten den Nachweis.
3. **Fidelity-Escape-Hatches.** V1: Performance-/Makromodus. V2: Speed-Profile,
   Kohortenmodus, approximierter Rückweg. Damit wurde das Kernproblem
   (Kosten pro Tick) umgangen statt gelöst.
4. **Scope vor Kernel.** Featurebreite und V1-Parität wurden ausgebaut, bevor
   ein skalierendes Ausführungsmodell bewiesen war.
5. **Event-Modell ohne hartes Budget.** Zu viele Events pro Tick, zu große
   Batches, teure Einzelentscheidungen; optimiert wurde an den Rändern.
6. **Monolith- und Ownership-Drift.** V1 `Being`, V2 `SettlementRuntime`;
   mehrere Stores, Kataloge und parallele Zustandsbesitzer.
7. **Messung nicht entscheidungsfähig.** Kurze Fenster, kein sauberer
   CPU-/GPU-Split, keine drei vollständigen Läufe, keine feste Zielhardware.
8. **Dokumentations- und Prozessdrift.** Viele Roadmaps, TODOs und ADRs mit
   widersprüchlichem Status; schnelle KI-Implementierung ohne Review-Gate.
9. **Welt- und Skalierungsparameter nicht aus Performance/Fidelity abgeleitet.**
   Große Welten, lange Wege, 10k Bewohner in wenigen Siedlungen, 3-m-Tiles und
   8-px-Rendering wurden parallel festgelegt, ohne die Kosten zu belegen.

## 2. Failure-Hypothesen (durch Runde 1 bestätigt)

- **H1 — Abnahme:** Ohne ein einziges, hartes, messbares Nordstern-Gate
  zerfasert die Arbeit in Slices, die einzeln grün sind, aber zusammen kein
  Produkt ergeben.
- **H2 — Fidelity:** Jede Abkürzung bei Performance (Modus, Kohorte,
  Zeitraffung) zerstört die Glaubwürdigkeit des Deterministmusversprechens und
  verschiebt das Problem nur.
- **H3 — Reihenfolge:** Featurebreite vor Skalierungsnachweis erzeugt
  Architektur, die später nicht mehr bezahlbar ist.
- **H4 — Ausführungsmodell:** Das gewählte Event-/Tick-Modell erzeugt zu viel
  Arbeit pro simulierter Sekunde; lokale Optimierungen reichen nicht.
- **H5 — Struktur:** Zentrale Runtime-Dateien und mehrere Zustandsbesitzer
  machen Änderungen teuer und verstecken Kopplungen.
- **H6 — Messung:** Ohne belastbare Messmatrix ist nicht entscheidbar, ob eine
  Änderung hilft oder nur Rauschen verschiebt.
- **H7 — Prozess:** KI-Subagenten liefern schnell Code und Dokumente, aber
  ohne hartes Gate und Review entsteht Parallelwahrheit statt Fortschritt.
- **H8 — Parameter:** Weltgröße, Bevölkerungsdichte, Reisezeiten und
  Renderauflösung wurden nicht gemeinsam mit dem Performancemodell kalibriert.
- **H9 — Planung:** Optik und Engine wurden nicht von Anfang an als ein
  zusammenhängendes Ziel geplant.

## 3. Beschlossene Richtung

### 3.1 Produkt

V3 ist eine frische, spielbare und beobachtbare **Wimmelbild-Lebenssimulation**
und gleichzeitig das technische Fundament für die spätere gemeinsame Welt mit
**Cursed Beyond**. 10.000 Individuen sind ein Zwischenschritt, nicht das
Endziel; die Engine soll perspektivisch auch **~100.000 Individuen** tragen
können. **100k@10x ist Pflicht für G5a; 100k@50x ist Stretch.**

**Spielerrolle in V3:** Beobachter/Chronist. Der Spieler greift nicht in die
Simulation ein; er beobachtet, folgt einzelnen Sims, liest die Chronik und
studiert Beziehungen. Einflussnahme (Dekrete, Ressourcen, Bauaufträge) ist eine
bewusste spätere Version, nicht Teil von V3. Die Kernschleife ist
**Geschichten/Chronik**: emergente Biografien, Familien und Siedlungsgeschichte
sichtbar und lesbar machen.

### 3.2 Erste sichtbare Abnahme

Die erste sichtbare Scheibe wird mit **10 Akteuren** gebaut, um Optik,
Bedürfnisse, Bewegung, Tagesablauf und Lebenszyklus zu tunen. Das ist
ausdrücklich **kein Skalierungsnachweis**. Skalierung wird danach stufenweise
und separat gemessen.

### 3.3 Neustart

V3 ist **komplett frisch**. V1 und V2 werden nicht als Codebasis verwendet,
sondern nur als Referenz, Ideenquelle und Warnung. Keine V1-/V2-Datei wird
verändert.

### 3.4 Zeit- und Entscheidungsrichtung

- Ein Sim-Jahr hat **30 Tage**; vier Jahreszeiten à etwa 7,5 Tage.
- Ein Sim-Tag dauert bei 1x **15 reale Minuten**.
- Geschwindigkeiten **1x, 10x und 50x** sind die Richtung; 50x ist die obere
  Messlatte, nicht die erste Ausbaustufe.
- Ein Sim-Tag = 86.400 Sim-Sekunden. Bei 15 realen Minuten ist 1x bereits eine
  Zeitraffung um Faktor 96; 10x = Faktor 960; 50x = Faktor 4.800.
- Entscheidungsquantum: **1 Sim-Minute**. Das ist die Auflösung für
  Termine/Ereignisse, kein Pflicht-Polling aller Akteure pro Minute.
- Sims treffen **keine pausenlosen Entscheidungen**. Sie entscheiden
  need-/bedarfsbasiert, erfüllen das Bedürfnis kurz und kehren in Routine/Arbeit
  zurück.
- Die Simulation darf **nicht an einen festen 1-Sekunden-Tick gekoppelt** sein.
  Bewegung und Positionen sind zeitbasiert; Ereignisse werden zu ihren
  logischen Terminen verarbeitet.

### 3.5 Lebenszyklus

- Typische Lebensspanne: **~50 Jahre**, mit hoher Variation.
- Viele sterben bereits mit **~30**, einzelne werden **~70**.
- Das ist eine Verteilung, kein fester Wert. Die erste Scheibe braucht daher
  eine einfache Alterssterblichkeit mit Zufallsvariation, keine feste
  Lebensdauer pro Agent.
- Geburt, Alterung und Tod müssen deterministisch, sichtbar und speicherbar
  sein. Keine stille Bevölkerungsauffüllung.

### 3.6 Siedlungs- und Bevölkerungsprofil (Planungsrechnung)

Grundlage sind die vom Nutzer vorgegebenen Siedlungstypen. Für die erste
Rechnung wird pro Nation von folgendem mittleren Profil ausgegangen:

| Typ | Anzahl pro Nation | Einwohner je | Summe pro Nation |
|---|---:|---:|---:|
| Großstadt | 1 | 17.000 | 17.000 |
| Mittelstadt | 1 | 7.000 | 7.000 |
| Kleinstadt | 2 | 2.200 | 4.400 |
| Kirchdorf | 4 | 700 | 2.800 |
| Größeres Dorf | 4 | 350 | 1.400 |
| Bauerschaft | 10 | 110 | 1.100 |
| Einzelhof | 8 | 12 | 96 |
| **Summe** | **30** | | **33.796** |

Damit ergeben sich für **3 Nationen**:

- **~101.400 Einwohner**
- **~90 Siedlungen**
- 3 Großstädte, 3 Mittelstädte, 6 Kleinstädte, 12 Kirchdörfer,
  12 größere Dörfer, 30 Bauerschaften, 24 Einzelhöfe.

Die Spannweite der vom Nutzer genannten Größenordnungen ergibt:

| Profil | Einwohner pro Nation | 3 Nationen | Siedlungen (ca.) |
|---|---:|---:|---:|
| Niedrig | 17.240 | 51.720 | 84 |
| Mittel | 30.520 | 91.560 | 102 |
| Hoch | 44.040 | 132.120 | 120 |

**Fazit:** Die gewünschte 3-Nationen-Struktur liegt im Mittel bei ~92k und mit
leicht größeren Städten/Höfen bei ~100k. **100k ist damit eine realistische
Planungsgröße, kein Fantasieziel.** Die genaue Verteilung ist mit **D-15**
entschieden: Kompakt ~100k.

### 3.7 Maßstab: ein Raster, aber sparse

Der Nutzer will „alles aus einem Guss“, also eine durchgehende Tile-Skala statt
einer separaten reduzierten Umlandkarte. Das ist möglich, wenn die Welt nicht
als dichtes Array, sondern als **sparse Koordinatenraum** verstanden wird:

- Die 71 × 71 km sind ein Koordinatenraum; materialisiert werden nur aktive
  Siedlungen, Wege und Chunks.
- Terrain außerhalb aktiver Bereiche wird prozedural aus dem Seed erzeugt.
- Fernreisen laufen über einen Siedlungs-/Straßen-Graph, nicht über einen
  A* über das ganze Land.
- Lokale Wege und neue Bürgerwege verändern die lokale Tile-/Graphstruktur.

Damit ist ein einheitliches **1,5-m- oder 3-m-Raster** technisch denkbar. Die
Kosten liegen nicht in der Anzahl der Koordinaten, sondern in:

- der Anzahl gleichzeitig materialisierter Chunks,
- der Pfadfindung,
- der Anzahl individueller Agenten und Ereignisse,
- der Renderlast.

| Auflösung | Tiles über 71 km | Tiles gesamt | Bewertung |
|---|---:|---:|---|
| 1,5 m/Tile | 47.200 | ~2,23 Mrd. | sparse denkbar, viele Chunks |
| 3 m/Tile | 23.600 | ~557 Mio. | sparse gut handhabbar |
| 10 m/Tile | 7.070 | ~50 Mio. | lokal zu grob für Figuren |
| 50 m/Tile | 1.414 | ~2 Mio. | nur regional/abstrakt |

**Entschieden (D-13):** Single-scale sparse + Graph. Eine durchgehende
Tile-Skala, aktive Siedlungen/Wege/Chunks werden materialisiert, Fernreisen
laufen über Knoten/Straßen. Ein mehrstufiges Raummodell bleibt ein Fallback,
falls die single-scale-Variante bei 100k zu teuer wird.

### 3.8 Maßstabs-Kombination

Die Wahl „3 m/Tile“ oder „1,5 m/Tile“ ist mit der Pixelgröße gekoppelt. Eine
1,8-m-Figur ist bei 16 px/Tile und 1,2 m/Tile genau 24 px hoch. Bei 3 m/Tile
wäre sie nur 9,6 px hoch; für eine gut lesbare Figur braucht es dann 32 px/Tile.

| Kombination | m/Tile | px/Tile | Figur 1,8 m | Sichtbar bei 1920 px | Land 71 km | Bewertung |
|---|---:|---:|---:|---:|---:|---|
| A | 3,0 | 32 | 19,2 px | 60 Tiles = 180 m | 23.600 Tiles | effizient, grobe lokale Wege |
| B | 3,0 | 16 | 9,6 px | 120 Tiles = 360 m | 23.600 Tiles | kleine Figuren, sehr weiter Blick |
| C | 1,5 | 16 | 19,2 px | 120 Tiles = 180 m | 47.200 Tiles | guter Kompromiss |
| D | 1,2 | 16 | 24 px | 120 Tiles = 144 m | 58.900 Tiles | passt zur 24-px-Figur, größte Karte |

**Entschieden (D-14):** Kombination **C** — 1,5 m/Tile, 16 px/Tile, Figuren
~19–20 px. Das ist der Kompromiss aus Lesbarkeit, schlichter Grafik und
vertretbarer Kartengröße.

### 3.9 Vorläufiges Event-Budget

Annahme: ~8–10 Ereignisse pro Individuum und Tag (Needs, Arbeit, Ankunft,
Soziales, Lifecycle). Pflicht- und Stretch-Ziele werden getrennt:

| Szenario | Events/Tag | Events/s | Events/Frame @60 FPS | µs/Event für 8 ms Sim |
|---|---:|---:|---:|---:|
| 10k @ 50x | 80k–100k | 4,4k–5,6k | 74–93 | ~86–108 µs |
| 100k @ 10x | 800k–1M | 8,9k–11,1k | 148–185 | ~43–54 µs |
| 100k @ 50x (Stretch) | 800k–1M | 44k–56k | 740–926 | ~8,6–10,8 µs |

**Konsequenz:** 10k@50x und 100k@10x sind die Pflichtziele und deutlich
weniger extrem als 100k@50x. Das Stretch-Gate 100k@50x ist ohne Native-Spike
unwahrscheinlich. G0.5 muss die tatsächlichen Eventkosten messen, bevor G1
beginnt.

**60 FPS/Gesamtframe sind ab G1a hart; Per-Event-/Pfad-/Save-Budgets werden in
G0.5/G2 kalibriert und ab G3 hart.**

- Gesamtframe p95 ≤ 16,0 ms, p99 ≤ 20 ms; Sim p95 ≤ 6 ms, Render p95 ≤ 6 ms,
  UI/Godot/GC ≤ 4 ms.
- Kein einzelnes Event über 250 µs; Batch-p95 unter 2 ms.
- Pfad/Frame: max. 2 Neuberechnungen und 50 Cache-Lookups; p95 ≤ 2 ms/Frame;
  Cache-Hit-Rate > 90 % für lokale Ziele.
- Render: nah/fern/Pan getrennt; 100k nur mit Instancing/Markern, keine
  100k-Einzel-Draw-Calls.
- Save: Größe/Ladezeit/Peak-Speicher pro Gate messen; Zielwerte in G0.5
  festlegen.
- Event-Log/Chronik: 7 Sim-Tage notable+ im Ringpuffer, 1 Sim-Jahr Summaries,
  historische Events budgetiert; Routine wird an der Quelle aggregiert.
  Retention-Budget in G0.5/G2.
- Replay ist Re-Simulation aus Seed + Konfiguration + Save-Snapshot, nicht aus
  dem Chronik-/Debug-Log.

### 3.10 Fidelity-Modell und AI-LOD

Die Beobachtung ist richtig: Spiele mit 100k+ Einwohnern simulieren fast nie
alle Individuen gleichzeitig in voller Tiefe. Sie kombinieren:

1. **Persistente Datensätze** für alle (ID, Alter, Wohnung, Job, Bedürfnisse).
2. **Lazy Materialisierung**: Details (Weg, Animation, Position) entstehen erst,
   wenn sie gebraucht werden.
3. **Statistische Simulation**: Hintergrundbevölkerung wird in Aggregaten
   gerechnet.
4. **Relevanz-/Kamera-LOD**: nur Sichtbares wird detailliert simuliert.

| Stufe | Was passiert | Determinismus | Kameraunabhängig | Individuelle Biografie |
|---|---|---|---|---|
| Persistenter Datensatz | Alle 100k haben ID, Alter, Wohnung, Job, Bedürfnisse | ja | ja | ja, aber ggf. grob |
| Lazy Materialisierung | Weg/Animation/Position werden bei Bedarf berechnet | ja | ja | ja |
| Statistische Simulation | Hintergrund in Siedlungs-/Berufsgruppen | ja, wenn geseedet | ja | nein, nur aggregiert |
| Kamera-/Relevanz-LOD | Detail nur bei Sichtbarkeit | nein | nein | nein, Beobachtung verändert Leben |

**Entschieden (D-18):** **A starten, B als Fallback.** V3 beginnt mit
Vollsimulation: alle Agenten haben individuelle Zustände und Ereignisse; keine
statistischen Hintergrundkohorten. Deterministisches Tiering (B) wird nur
ergänzt, wenn die Messung 10k@50x oder 100k@10x verfehlt. Kamera-LOD (C) ist
keine Option, solange D-19 gilt.

**Entschieden (D-19):** **Strikt kameraunabhängig.** Simulation liest niemals
Kamera, Zoom oder Sichtbarkeit; nur das Rendering darf LOD nutzen. Damit bleiben
Determinismus, Replay und die spätere serverautoritative Cursed-Beyond-Welt
konsistent.

### 3.11 Leitplanken

1. Ein Nordstern, aber gestufte Gates: erst 10 Akteure sichtbar/korrekt, dann
   Skalierung.
2. **Fidelity-Modell explizit.** Keine versteckte Hintertür:
   Kamera-/Sichtbarkeitsabhängigkeit der Simulation ist verboten.
3. **Lazy Materialisierung ist kein Schummeln**, solange sie deterministisch
   aus autoritativem Zustand abgeleitet wird. Statistik/Tiering ist eine
   dokumentierte, messungsgetriebene Entscheidung.
4. Hartes Budget pro Sim-Zeit und pro Frame: Ereignisse, Batches, Speicher,
   Renderkosten.
5. Ein Zustandsbesitzer pro Fakt; keine parallelen Kataloge/Caches.
6. Messung ab Tag 1: Zielhardware, Seed, Warm-up, Laufzeit, p50/p95/p99,
   Ereignisse, Speicher, Save-Größe, CPU/GPU getrennt.
7. Jede Scheibe endet mit einem sichtbaren oder messbaren Ergebnis; keine
   „PARTIAL“-Halbzustände.
8. Optik und Engine werden von Anfang an gemeinsam geplant, nicht nacheinander.

### 3.12 Architektur-Skizze (Vorschlag, sprachunabhängig)

**Schichten und Verantwortlichkeiten:**

1. **Kernel:** ganzzahlige Sim-Zeit, `(time, seq)`-Scheduler, getrennte
   RNG-Streams, Event-Log, Snapshot/Restore. Keine Nodes, keine UI, keine
   Kamera.
2. **World:** Terrain (1,5 m/Tile, sparse Chunks), Gebäude/Occupancy, Straßen/
   Graph, Siedlungen, Ressourcen. Jeder Store hat genau einen Besitzer und eine
   Version.
3. **Agents:** Hot-Store als Structure of Arrays (Position, Alter, Needs,
   Aktivität, nächster Termin, Home/Job, Flags) plus kalte Records (Identität,
   Beziehungen, Historie). Keine Per-Agent-Dictionaries in Hot-Loops.
4. **Decisions:** need-basierter Zustandsautomat plus Utility/Priorität;
   Commitments und Fortsetzung; externe Wake-ups für Gefahr, Job, Gebäude, Weg.
   Keine vollständige Neuplanung pro Frame.
5. **Movement/Navigation:** zeitbasierte Routengeometrie; lokale A* auf dem
   Tile-Grid; regionaler Siedlungs-/Straßen-Graph; Pfad-Cache; Bürger können
   lokale Wege bauen und den Graphen ändern.
6. **Economy:** Produktion/Verbrauch/Ledger pro Siedlung; individuelle
   Arbeitsintervalle; Batch-Accounting; keine doppelten Buchungen.
7. **Persistence:** versioniertes Binär-Save; Agenten-Arrays, Scheduler, RNG,
   Welt-Stores, Event-Log, Konfiguration; deterministischer Restore; Replay.
8. **View/UI:** liest ausschließlich Snapshots/Views; Chunk-Terrain, instanzierte
   Agenten/Tiere; Kamera/Zoom/Sichtbarkeit nur Darstellung.

**Prinzipien:**

- Kein Pflicht-Loop über alle Agenten pro Tick.
- Keine Per-Agent-Dictionaries in Hot-Loops.
- Keine kameraabhängige Simulation.
- Keine versteckten Fidelity-Modi.
- Ein autoritativer Zustand pro Fakt.
- Weiche Dateigrenze: ~1.000 Zeilen pro Datei; darüber nach Verantwortlichkeit
  aufteilen. Keine neue `settlement_runtime.gd`-Monolithdatei.
- Jedes Subsystem hat Tests und einen messbaren Benchmark.

### 3.13 Meilensteinkette (Vorschlag)

Jeder Meilenstein hat Ziel, Umfang, Nicht-Ziele, Abnahmekriterien, Benchmark,
sichtbare Demo und Review. „PARTIAL“ ist kein Abschluss.

| Gate | Ziel | Kernumfang | Harte Abnahme |
|---|---|---|---|
| **G0** | Planung und Fundament | Master-Plan, G1-Spec, Architektur, Datenmodell, Benchmark, Chronik-Design, Risiko-Register | Review-Checkliste; kein Code |
| **G0.5** | Technikspike | Scheduler, SoA, Needs, Pfad, Render, GDScript-vs-Native | Messwerte; Sprach-/Portentscheidung; Budgets |
| **G1a** | 10-Akteure-Kern | Weiler, 10 Agenten, Hunger/Energie/Sozial, Wohnen, Arbeit, Tag/Nacht, Inspector, Event-Log, Save/Load | Sichtbarer Tag; Determinismus; Save/Load |
| **G1b** | Soziales/Lebenszyklus/Chronik | Hygiene/Spaß/Gesundheit, Partnerschaft, Geburt, Tod, Familienbaum, Follow, Alerts, Story of the Day | Sichtbares Jahr bei 50x; Chronik; Determinismus |
| **G2** | 100-Akteure-Slice | Bauerschaft, Haushalte, Jobs, Felder, lokale Wege, Event-Batching; D-57 nur Stubs | 100@50x 60 FPS; 3 Läufe; Save/Load |
| **G3** | 1.000-Akteure-Slice | Kirchdorf/Kleinstadt, mehrere Arbeitsplätze, Pfadfindung, Eventbudget; Wetter/Feste/Kultur leicht | 1k@50x 60 FPS; Pfad-Checkpoint; 3 Läufe |
| **G4a** | 10.000-Akteure-Kern | Stadt + Hinterland; Vollsimulation A | 10k@50x 60 FPS; 3 Läufe |
| **G4b** | 10.000 + Wirtschaft/Politik | Haushalte, Märkte, Karawanen, Steuern, Diplomatie | Systembilanz + Performance |
| **G5a** | 100.000 Skalierung | Land, ~90–120 Siedlungen, Graph, Reisen, Save/Load | 100k@10x Pflicht; 100k@50x Stretch; 3 Läufe |
| **G5b** | 100.000 Systeme | Märkte, Karawanen, Steuern, Budget, Diplomatie, Krisen | Systembilanz + Chronik |
| **G6** | Erweiterungen | Krieg, Wildtiere, Fantasy-Addons, Cursed Beyond | Separate Planung |

**Stand 2026-11-13:** G0 bestanden; G0.5 bestanden; G1a/G1a.1 bestanden;
G1b Schritte 1–2 bestanden, Schritt 3 offen.

**Wichtig:** G1a/G1b sind formale Gates; G1a ist kein halbes G1. G0.5 ist der
Machbarkeitsnachweis vor dem ersten Gameplay-Code. G4a/G5a sind
Skalierungsgates; G4b/G5b sind Systemgates. G6 bleibt Erweiterung.

### 3.14 G1a/G1b — 10-Akteure-Slice: Definition

**Gemeinsames Setting:** Ein kleiner Weiler/Einzelhof-Verbund mit 10 Agenten,
3 Häusern, 1 Feld, 1 Kornspeicher, 1 Brunnen, 1 Scheune/Werkstatt und Wegen.
Keine Stadt, keine Fraktionen, keine Wirtschaftsketten.

**Gemeinsame Zeit/Optik:** 30-Tage-Jahr, 15 min/Tag bei 1x, 1x/10x/50x;
1,5 m/Tile, 16 px/Tile, ~19–20 px Figuren; 3/4-Topdown; Tag/Nacht.

#### G1a — Kern-Loop

**Umfang:**

- 3 Haushalte, gemischte Altersstufen.
- Needs: **Hunger, Energie, Sozial**.
- Wohnung, Arbeit, **einfacher Nahrungsspeicher**, Tag/Nacht.
- **Waypoint-Bewegung**, kein voller Feldzyklus, keine A*-/Pfad-Cache-
  Abhängigkeit.
- Inspector, Event-Log, Save/Load. **Kein Replay.**
- Einfache Beziehungen (Partner/Eltern/Kind) als Daten, noch ohne
  Familienbaum-UI.

**Abnahme:**

- Ein voller Sim-Tag bei 1x ist beobachtbar und verständlich.
- Gleicher Seed + gleiche Eingaben → identische Snapshots/Events (3 Läufe).
- Save/Load vor/nach Entscheidung und Arbeit ergibt exakt denselben Verlauf.
- Kamera/Zoom/Sichtbarkeit verändern keinen Simulationszustand.
- Headless-Tests und Main-Smoke grün.
- Performance: 10 Agenten bei 50x stabil 60 FPS; Ereignis-/Tick-Kosten
  gemessen und dokumentiert.
- Keine Datei über ~1.000 Zeilen; klare Modulgrenzen.

#### G1b — Soziales, Lebenszyklus, Chronik

**Umfang:**

- Zusätzliche Needs: **Hygiene, Spaß, Gesundheit**; Gesundheit als langsamer
  Zustand, in G1b ohne Krankheiten/Gewalt.
- Partnerschaft, Geburt, Alterung, Tod; einfache Beziehungen sichtbar.
- **Voller Feldzyklus**, Aussaat/Ernte, Jahresbilanz.
- **Replay als Re-Simulation** aus Seed + Konfiguration + Snapshot.
- Familienbaum, Follow-Modus, Alerts, Story of the Day.
- Strukturiertes Event-Log plus kuratierte Chronik (Wichtigkeit, Templates).
- Chronik-Ebenen: Individuum, Familie, Siedlung.

**Abnahme:**

- **Demografie:** 1.000-Agenten-Kohorte, 100 Sim-Jahre, 5 Seeds;
  Mindestgeburten/-tode, Median-Sterbealter 48–52, Zielverteilung eingehalten.
- **Visuell:** 1 Sim-Jahr bei 50x (9 min) plus optionaler 5-Jahres-Zeitraffer;
  mindestens eine Geburt und ein Tod im sichtbaren Lauf.
- **Chronik quantitativ:** ≤ 20 Alerts/Tag, ≤ 7 Story-of-the-Day/Tag,
  Dedup-Ratio > 80 %, mindestens 3 notable Ereignisse/Tag.
- **UI/Render:** Inspector < 100 ms, Familienbaum ≥ 3 Generationen, Follow
  60 s stabil; Nah/fern/Pan p95 ≤ 16 ms, kein Hänger > 250 ms.
- Save/Load vor/nach Geburt, Tod und Beziehungswechsel ist exakt.
- Replay ergibt denselben Verlauf; Chronik-Log-Kürzung ändert Replay nicht.
- Determinismus und Kameraunabhängigkeit bleiben grün.
- G1 gilt erst als bestanden, wenn **G1a und G1b** bestanden sind.

### 3.15 G0 — Planungsartefakte und Freigabe

Folgende G0-Artefakte liegen als Entwurf vor und werden über die
Review-Checkliste freigegeben:

1. `v3-plan.md` — Master: Entscheidungen, Gates, Links.
2. `v3-g1-spec.md` — G1a/G1b: Weltlayout, Agenten-Archetypen, Need-Raten,
   Tagesablauf, Arbeit, Nahrung, Lebenszyklus, UI und Abnahmetests.
3. `v3-architecture.md` — Module, Zustandsbesitzer, Event-/State-Verträge,
   Threading, Dateigrenzen.
4. `v3-data-model.md` — Schemas für Agenten, Needs, Jobs, Gebäude, Items,
   Siedlungen, Events und Save.
5. `v3-benchmark.md` — G0.5/G1a/G1b/G2–G5-Szenarien, Seeds, Warm-up,
   Laufzeiten, Kamerafahrten, Metriken, Hardware und 3-Lauf-Protokoll.
6. `v3-chronicle.md` — Event-Taxonomie, Wichtigkeit, Dedup, Tagesdigest,
   Story of the Day, Onboarding, Pacing und Retention.
7. `v3-fidelity.md` — A/B-Vertrag, preserved fields, Approximationen,
   Tests und Freigabepflicht.
8. `v3-risk-register.md` — Risiken, Auslöser und Gegenmaßnahmen.
9. `v3-g0.5-spike.md` — Spike-Fragen, Szenarien, Messwerte und Exit.
10. `v3-g0-review.md` — Review-Checkliste und Freigabe.
11. `v3-project-structure.md` — `V3/`-Skelettplan, Toolchain,
    Test-Runner, Benchmark-Harness, Git-Setup.
12. `v3-g1-workpackages.md` — Arbeitspakete mit Test-IDs und Gate-Zuordnung.
13. `reviews/v3-review-2026-11-13.md` — externe Reviews und Konsequenzen.

**G0-Exit:** Alle Dokumente sind reviewt und vom Nutzer freigegeben. Vorher
wird kein Code geschrieben.
**G0.5-Exit:** Messwerte, Sprach-/Portentscheidung und Budgets liegen vor; keine
Gameplay-Implementierung.

### 3.16 G1 — Arbeitspakete (Vorschlag)

| WP | Gate | Inhalt | Ergebnis | Prüfung |
|---|---|---|---|---|
| W1 | G1a | Kernel: Clock, `(time, seq)`-Scheduler, RNG-Streams, Event-Log, Snapshot | Deterministischer Kern | Wiederholte Läufe, Batch-Größen |
| W2 | G1a | Agenten-Store: SoA-Hot-Arrays, kalte Records, ID-Lebenszyklus | 10 Agenten mit stabilem Zustand | Struktur-/Determinismustests |
| W3a | G1a | Needs/Decisions: Hunger, Energie, Sozial; Schwellen; Zustandsautomat; Wake-ups | Need-basierter Tagesablauf | Übergänge, Unterbrechungen, keine Schleifen |
| W3b | G1b | Needs: Hygiene, Spaß, Gesundheit; Gesundheit als langsamer Zustand | Sechs-Needs-Modell | Wechselwirkungen, Determinismus |
| W4 | G1a | Welt: Weiler-Karte, 3 Häuser, Feld, Kornspeicher, Brunnen, Scheune, Wege, Occupancy | Begehbare lokale Welt | Erreichbarkeit, Kollisionen |
| W5a | G1a | Bewegung: Waypoint/gerade Linie, `position_at`, keine A*-Abhängigkeit | Zeitbasierte Bewegung | Ankunft exakt, keine Frame-Abhängigkeit |
| W5b | G2 | Lokaler A* plus Pfad-Cache und Occupancy-Optimierung | Skalierbare Navigation | Pfad-p95, Cache-Hit, Speicher |
| W6a | G1a | Arbeit/Nahrung: tägliche Arbeit, einfacher Kornspeicher, Essen | Kern-Nahrungskreislauf | Bilanz, Unterbrechungen |
| W6b | G1b | Voller Feldzyklus, Aussaat/Ernte, Jahresbilanz | Jahreswirtschaft | Bilanz, Determinismus |
| W7 | G1b | Lebenszyklus/Soziales: Alterung, Sterblichkeit, Partnerschaften, Geburten, Tod | Sichtbare Generationen | Verteilung, Determinismus, Save |
| W8a | G1a | Persistenz: Binär-Save, Snapshot, Restore | Exakte Fortsetzung | Save/Load vor/nach Entscheidung |
| W8b | G1b | Replay als Re-Simulation; Chronik-/Debug-Log getrennt | Reproduzierbarkeit | Seed+Snapshot, keine Log-Abhängigkeit |
| W9a | G1a | View/UI-Kern: Terrain, Sprites, Kamera, Tag/Nacht, Inspector, Zeit/Speed, Event-Log | Sichtbare Demo | Visueller Smoke, keine Sim-Mutation |
| W9b | G1b | Chronik-Tools: Familienbaum, Follow, Alerts, Story of the Day | Chronik-Produkt sichtbar | Quantitative DoD, keine Sim-Mutation |
| W10 | G1a/G1b | Benchmark/Abnahme: Szenarien, 3 Läufe, Metriken, headless + visuell | G1a-/G1b-Nachweis | Budgets, p50/p95/p99, 3 Läufe |
| W11 | G1b | Review/Doku: Code-Review, Doku, Risiko-Update, G1-Bericht | Freigabe G1 | Review-Checkliste |

**Reihenfolge:** G0.5 → W1 → W2 → W3a → W4 → W5a → W6a → W8a → W9a (G1a) →
W3b → W6b → W7 → W8b → W9b → W10 → W11 (G1b); W5b folgt in G2. Jedes WP endet
mit Tests; keine offenen „PARTIAL“-Punkte.

### 3.17 Risiken und Gegenmaßnahmen

| Risiko | Wirkung | Gegenmaßnahme | Auslöser |
|---|---|---|---|
| GDScript zu langsam | 10k/100k-Gates verfehlt | Bei G2/G3 profilen; Hot Paths nach C#/GDExtension portieren; schmale Kernel-Schnittstelle | Sim-p95 über Budget |
| Event-Explosion | Framezeit bricht ein | Hartes Event-Budget; analytische Needs; Batching; kein Pathfinding pro Event | Events/Frame > Budget |
| Single-scale sparse Welt zu komplex | Pfad-/Chunk-Kosten explodieren | Erst eine Siedlung; regionaler Graph ab G3/G4; kein globales A* | Pfad-p95 oder Speicher > Budget |
| Save/Replay fehleranfällig | Determinismus kaputt | Versioniertes Binär-Save ab G1; stabile IDs; Event-Log; Restore-Tests | Save/Load-Differenz |
| Scope Creep | G1 wird nie fertig | Harte G1-Nicht-Ziele; Gates; keine V1-Parität | Neue Features ohne Gate |
| G1-Needs zu breit | G1 wird zu groß, Balancing/UI dauern | G1a/G1b staffeln; Gesundheit als langsamer Zustand; keine Krankheiten | G1a nicht in Zeit |
| Optik/Maßstab passt nicht | Figuren unlesbar, Welt wirkt leer | G1-Visual-Kalibrierung; 1,5 m/16 px; frühe Screenshots | Figuren < 16 px oder Welt zu weit |
| KI-Prozess driftet | Monolithen, Parallelwahrheit | PM-Review; kleine Aufträge; keine Subagenten-Designentscheidungen; menschliche Freigabe | Datei > 1.000 Zeilen, Doku-Widerspruch |
| 100k@50x unmöglich | Vollziel verfehlt | 100k@10x Pflicht; 50x Stretch; B-Fallback vorbereiten | G4/G5-Messung |
| Daten-/Content-Pipeline unklar | Welt nicht erweiterbar | D-26 entschieden: JSON + prozedural; Schema in G0 festlegen | Neue Inhalte brauchen Codeänderung |
| Cursed-Beyond-Kopplung zu früh | Architektur überladen | D-31: Engine/Shell-Grenze jetzt, Netzwerk erst G6 | Netzwerk-/Serverarbeit vor G5 |

### 3.18 Beobachter-/Chronik-Produkt

Die Entscheidung für Beobachter/Chronist ändert den Produktschwerpunkt: Nicht
Eingriffe, sondern **Lesbarkeit und Erinnerung** sind der Spielwert. Daraus
folgen Mindestanforderungen:

- **Strukturierte Ereignisse:** Jedes relevante Ereignis hat Zeit, Akteure, Ort,
  Typ, Wichtigkeit und eine stabile ID. Das Event-Log ist zugleich Debug-,
  Replay- und Chronikquelle.
- **Inspector:** Agent auswählen, folgen, Needs/Beziehungen/Home/Job/Alter/
  Gesundheit sehen.
- **Chronik:** Filterbare Ereignisliste pro Agent, Familie, Siedlung und Nation;
  wichtige Ereignisse hervorgehoben.
- **Beziehungen:** Partner, Eltern, Kinder, Freunde/Feinde; einfache
  Familienbaum-Ansicht.
- **Zeitleiste:** Was ist wann passiert; Alerts für Geburt, Tod, Partnerschaft,
  Hungersnot, Krankheit, Streit, Ernte.
- **Sandbox:** Kein Game Over; Fortschritt ist die Geschichte, die entsteht.
- **Keine Eingriffe:** Keine Commands, keine direkte Steuerung; Zeit- und
  Kamerasteuerung sind Darstellung, keine Simulation.

**Wichtig:** Die Chronik ist kein nachträgliches UI-Feature. Ereignisstruktur,
Wichtigkeit und Biografie-Daten müssen ab G1 mitgedacht und getestet werden.

**Entschieden (D-38 bis D-43):** Kuratierte Chronik mit Wichtigkeitsscore,
Summaries und deutschen Templates; G1-Werkzeuge Inspector, Event-Log,
Familienbaum, Follow und Alerts; **kein Rewind** in V3; Erzählebenen
Individuum, Familie und Siedlung; „Story of the day“; keine LLM-Abhängigkeit.

### 3.19 Wirtschaft und Politik (G5)

G5 umfasst **Leben + Wirtschaft + Handel + Politik**. Das Ziel ist keine
vollständige Volkswirtschaft, sondern eine **lesbare, deterministische
Interdependenz**, die Geschichten erzeugt.

**Wirtschaftsschichten (Vorschlag):**

1. **Individuum:** Job, Lohn, getragene Güter, sichtbarer Konsum.
2. **Haushalt:** Einkommen, Nahrung, Brennstoff, Kleidung, Wohnen, Sparen.
3. **Siedlung:** Gebäude, Jobs, Lager, lokaler Markt, Preise, Steuern, Budget.
4. **Nation:** Schatzkammer, Steuersatz, Handelspolitik, Infrastruktur,
   Diplomatie.
5. **Region:** Karawanen, Handelsrouten, Preisunterschiede, Knappheit, Verträge.

**Produktion:** ~10–15 Kernwaren; Rohstoffe → Verarbeitung → Konsum; saisonale
Landwirtschaft; Gebäude mit Rezepten, Arbeit und Kapazität; lokale Lager.

**Handel:** physische Karawanen mit Ladung; lokale Preise; Handelsabkommen;
Zölle/Embargo später.

**Politik:** 3 Nationen mit Schatzkammer, Steuern, öffentlichem Budget,
Diplomatie und Verträgen; Krieg später.

**Krisen:** Ernteausfall, Knappheit, Preisspitze, Verschuldung, Hunger, Unruhe;
als Chronik-Ereignisse, kein Game Over.

**Performance:** Wirtschaft/Politik laufen tages-/wochenweise pro Siedlung/
Nation, nicht pro Agent und Tick; Transaktionen werden gebatcht; Karawanen sind
wenige sichtbare Agenten.

**Chronik:** Ernte, Knappheit, Preisänderung, Karawane, Baubeginn/-ende,
Steueränderung, Vertrag, Bündnis, Grenzstreit, Fest, Hunger, Abwanderung.

**Entschieden (D-44 bis D-49):** Haushalte, lokale Märkte, regionaler Handel
und nationale Schatzkammer; individuelle Löhne/Münzen für sichtbare Agenten,
Haushaltsbudget und Siedlungs-/Nationsledger; physische Karawanen mit Ladung
und Handelsabkommen; drei Nationen mit Steuern, öffentlichem Budget,
Diplomatie und Verträgen (kein Krieg in G5); Krisen als Chronik-Ereignisse ohne
Game Over; deterministische Utility-KI mit drei Ressourcen-Spezialisierungen.

### 3.20 Weitere Themen und vorgeschlagene Scope-Matrix

Der Nutzer hat weitere Themen genannt: Setting/Lore, Art/UI, Krieg/Kampf,
Soziales (Liebe/Geburten), Tiere/Wildleben, Untote, Drachen, Orks und mehr.
Vorschlag für die Abgrenzung:

| Thema | V3-Kern (G1–G5) | V3-Erweiterung (nach G5) | Später/optional |
|---|---|---|---|
| Setting/Lore | 3 menschliche Nationen, low-fantasy, mittelalterlich; Kultur/Ressourcen | weitere Regionen, Geschichte | Cursed-Beyond-Kopplung |
| Soziales | Liebe/Partnerschaft, Familie, Kinder, Freundschaften/Feindschaften, Reputation, einfache Emotionen | tiefere Psychologie, Erinnerungen, Trauma | LLM-gestützte Dialoge |
| Wirtschaft | Haushalte, Märkte, Karawanen, Schatzkammern, Steuern | Zölle, Embargo, Kredit | Finanzsektor |
| Politik | 3 Nationen, Steuern, Budget, Diplomatie, Verträge | Bündnisse, Grenzstreit, innere Fraktionen | Nachfolge, Gesetze |
| Krieg | nicht in G5; Politik ohne Krieg | Armeen, Belagerungen, Schlachten | Magie-Krieg |
| Tiere | Nutztiere in der Wirtschaft | Wildtiere, Ökosystem, Jagd, Fischerei | Monster |
| Fantasy | Untote/Orks/Drachen als Lore/Gerüchte, nicht simuliert | einzelne Fraktionen/Kreaturen | voll ausgebaute Fantasy |
| Art/UI | 3/4-Topdown-Pixelart, Inspector + Chronik + Familienbaum | Animations-Pass, mehr UI | handautorisierte Assets |

Die Matrix ist ein Vorschlag, keine Entscheidung. D-50 bis D-56 legen die
Grenzen fest.

**Entschieden (D-50 bis D-56):**

- **V3-Kern:** Leben + Soziales + Wirtschaft + Handel + Politik. Krieg, Tiere
  und Fantasy sind Erweiterungen nach G5.
- **Setting:** Low-Fantasy-Mittelalter mit 3 menschlichen Nationen; Magie
  selten; Fantasy existiert, ist aber nicht Teil des V3-Kerns.
- **Fantasy-Erweiterungen:** Untote als Unterfraktion mit Nekromant und
  Invasionen; Orks als eine der ersten JSON-getriebenen Addon-Fraktionen;
  später Zwerge, Elfen, Gnome usw.; Drachen als seltene Events.
- **Soziales:** Liebe/Partnerschaft, Ehe, Kinder, Familie, Haushalt,
  Freundschaften/Feindschaften, Reputation und einfache Emotionen.
- **Krieg:** nach G5 als Erweiterung; G5 bleibt Politik ohne Krieg.
- **Tiere:** Nutztiere in der G5-Wirtschaft; Wildtiere/Ökosystem später.
- **Art/UI:** 3/4-Topdown-Pixelart, warme mittelalterliche Palette, klare
  Silhouetten, Inspector-Sidebar, Chronik-Panel, Familienbaum-Overlay,
  Tag/Nacht-Tint.

### 3.21 Weitere Systeme: Vorschlag für V3

| Thema | V3-Vorschlag (leicht) | Stub ab | Echte Simulation |
|---|---|---|---|
| Magie/Religion | Tempel, Priester, Feste, Glauben, Reputation; Magie nur Lore/seltene Events | G2 | G4/G5 |
| Kultur/Technologie | Statische Kulturprofile pro Nation/Siedlung (Namen, Architektur, Kleidung, Essen, Technologie); leichte Effekte | G1/G2 | G4/G5 |
| Krankheit/Medizin | Leichte Krankheiten, Heilung, Sterblichkeitsrisiko; keine Epidemie-Simulation | G3 | G4/G5 |
| Wetter/Jahreszeiten | Tägliches Wetter, Jahreszeiten, Effekte auf Landwirtschaft/Reisen/Stimmung, Visuals | G2 | G4/G5 |
| Recht/Kriminalität | Leichte Gesetze, Diebstahl/Übergriffe, Wachen, Gerichte, Strafen, Reputation | G3 | G4/G5 |
| Bildung/Gilden | Lehrlinge, Skill-Level, Gildenzugehörigkeit, Jobanforderungen | G3 | G4/G5 |
| Feste/Kunst/Musik | Saisonfeste, Hochzeiten, Begräbnisse, Markttage, Stimmung/Soziales; Kunst/Musik als Flavor | G2 | G4/G5 |

**Wichtig:** Diese Systeme dürfen G1 nicht überladen. G1 bleibt Kern-Leben +
Soziales + Chronik. **G2/G3 führen nur Daten-/UI-Stubs ein; echte Simulation
ab G4/G5.**

**Entschieden (D-57):** Alle sieben Systeme kommen **leicht** in den V3-Kern,
aber als Stubs ab G2/G3 und echte Simulation ab G4/G5. Keine Tiefensimulation;
jedes Gate darf ein System verschieben, wenn das Budget oder die Qualität es
verlangt.

### 3.22 G0.5 — Technikspike-Ergebnis (2026-11-13)

**Status: bestanden.** Details: `docs/g0.5/v3-g0.5-results.md`.

| Messung | Ergebnis |
|---|---|
| Scheduler 10k/100k | 3,5–4,6 µs/Event, 218k–287k Events/s |
| SoA 10/1k/10k/100k | 0,41–0,48 µs/Agent/Tick; 100k-Sweep 41,5 ms |
| Needs | 9,52 Wakes/Agent/Tag (Plan: 8–10) |
| Pfad 128²/512² | 0,53–0,97 ms p95 ohne Cache; 96,8 % Hit mit Cache |
| Batch 100k | 0,52 µs/Event, p95 54 ms (nicht frame-fähig) |
| Save 100k | 5,8 MB, 45,8 ms Save / 86,8 ms Load |
| Render 100k Marker | 1 Draw Call, p95 < 0,61 ms; Build 29,2 ms |
| Determinismus | 3 Läufe identisch; C#-Parität bitgleich |
| GDScript vs. C# | 27–69× schneller in C# (Konsolen-Hotloop) |

**Entscheidung:** GDScript beibehalten; **kein Port vor G4a**. Port-Trigger:
Sim-Slice p95 > 6 ms in G4a/G5a, erzwungener Full-Agent-Sweep pro Frame, oder
reale Batch-p95 > 2 ms. Portmechanismus dann **GDExtension**, nicht Godot-C#
(kein .NET-Build; Interop ungemessen).

**Wichtig:** Die gemessene Need-Dichte 9,52/Tag liegt innerhalb der Planannahme
8–10/Tag. Es gibt **keinen Budgetbruch**; die Eventkosten liegen deutlich unter
den provisorischen Caps. Arbeit/Reise/Sozial/Wirtschaft erzeugen zusätzliche
Events und werden in G1a/G2 gemessen.

**Grenzen:** keine GPU-ms; Render ist eine Marker-Untergrenze; C# ist eine
Konsolen-App ohne Godot-Interop; keine echte Terrain-/UI-/Chronik-Last.

## 4. Entscheidungsstand

### 4.1 Runde 1 — entschieden

#### D-01 — Produktziel

**Entschieden:** Spielbare Wimmelbild-Lebenssimulation **und** Fundament für
Cursed Beyond. 10k ist ein Zwischenschritt; die Engine soll perspektivisch
~100k tragen. Erste sichtbare Tests mit 10 Akteuren.

#### D-02 — Failure-Definition

**Entschieden:** Performanceziel verfehlt; Architektur/Monolithen; Vertrauen in
den KI-Prozess; kein klares Ziel für Optik und Engine; nicht von Anfang an
durchgeplant.

#### D-03 — Nordstern / erste Abnahme

**Entschieden (final):** Eine Engine, die perspektivisch ~100k Individuen
tragen kann. Erste sichtbare Abnahme mit 10 Akteuren zum Tuning von Grafik und
Verhalten. Skalierung folgt stufenweise; 10k ist kein Endziel.

#### D-04 — Ausgangsbasis

**Entschieden:** Komplett frisches V3. Kein V1-/V2-Code; V1/V2 nur Referenz.

#### D-05 — Speed-/Fidelity-Richtung

**Entschieden:** 30-Tage-Jahr, 15 reale Minuten/Tag bei 1x, 1x/10x/50x,
need-basierte Entscheidungen, nicht tick-gebunden.

### 4.2 Runde 2 — entschieden

#### D-06 — Kalender-, Tages- und Lebenszeitmodell

**Entschieden:** 30 Tage/Jahr, 4 Jahreszeiten, 15 reale Minuten/Tag bei 1x,
Entscheidungsquantum 1 Sim-Minute. Lebensspanne ~50 Jahre mit hoher Variation;
viele sterben mit ~30, einzelne werden ~70. Keine feste Lebensdauer pro Agent.

#### D-07 — Skalenleiter und 100k-Härte

**Entschieden:** Siedlungstypen bestimmen die Skalenleiter:
10 → 100 → 1.000 → 10.000 → 100.000 Individuen. **100k@10x ist Pflicht für
G5a; 100k@50x ist Stretch.** Die frühere Formulierung „100k ist nur Stretch“
ist damit korrigiert.

#### D-08 — Weltmodell und Dichte

**Entschieden (provisional):** 3 Nationen (Untote und Orks zunächst außen vor),
jeweils 1 Großstadt, 1 Mittelstadt, 2 Kleinstädte und ein ländliches Umland aus
Kirchdörfern, größeren Dörfern, Bauerschaften und Einzelhöfen. Details sind
kalibrierbar.

#### D-09 — Erste sichtbare Scheibe

**Entschieden:** 10 Akteure, eine Siedlung, Bedürfnisse, Wohnung, Arbeit,
Nahrung, Tag/Nacht, einfache Beziehungen plus Alterung, Geburt und Tod.

#### D-10 — Optik und Maßstab

**Entschieden:** 2D-3/4-Topdown-Pixelart, schlicht, 16-px-Tiles, **final
~19–20-px-Figuren** bei 1,5 m/Tile, freie Kamera und Zoom. 24-px-Figuren sind
nur eine verworfene Alternative.

#### D-11 — Engine-/Produkt-Grenze

**Entschieden:** Wiederverwendbare deterministische Simulationsengine plus
dünne Spielschale. Command-/Event-API, Save/Replay ab Tag 1; noch kein Netzwerk.

#### D-12 — Arbeitsprozess und Gates

**Entschieden:** Hauptagent als PM/Reviewer, Subagenten für Implementierung,
eine Quelle der Wahrheit, ADRs, harte Gates, menschliche Freigabe pro
Meilenstein.

#### D-15 — Bevölkerungs- und Siedlungsprofil

**Entschieden:** Kompakt ~100k. 3 Nationen, ~90–120 Siedlungen, ~101k
Einwohner; Städte dominieren, Umland ist überschaubar.

#### D-16 — Lebenszyklus und Sterblichkeit in der ersten Scheibe

**Entschieden:** Alterung + Alterssterblichkeit mit Variation + einfache
Geburten/Partnerschaften. Keine Krankheiten/Gewalt in der ersten Scheibe.

#### D-17 — Messmatrix und harte Gates

**Entschieden:** 10k@50x und 100k@10x sind Pflicht-Gates; 100k@50x ist
Stretch. Budgets getrennt pro Szenario (siehe 3.9): 10k@50x ~74–93
Events/Frame, 100k@10x ~148–185, 100k@50x ~740–926. Gesamtframe p95 ≤ 16 ms,
Sim ≤ 6 ms, Render ≤ 6 ms, UI/Godot/GC ≤ 4 ms. 60 FPS ab G1a hart; Per-Event-/
Pfad-Budgets in G0.5/G2 kalibrieren, ab G3 hart.

### 4.3 Runde 3 — entschieden

#### D-13 — Räumliches Weltmodell

**Entschieden:** Single-scale sparse + Graph. Eine durchgehende Tile-Skala;
nur aktive Siedlungen/Wege/Chunks materialisiert; Fernreisen über Siedlungs-/
Straßen-Knoten; Bürger können lokale Wege bauen. Mehrstufig bleibt Fallback.

#### D-14 — Maßstabs-Kombination

**Entschieden:** 1,5 m/Tile, 16 px/Tile, Figuren ~19–20 px. 47.200 Tiles über
71 km; guter Kompromiss aus Lesbarkeit, schlichter Grafik und Kartengröße.

#### D-18 — Fidelity-Modell / AI-LOD

**Entschieden:** A starten, B als Fallback. Vollsimulation aller Agenten als
Start; deterministisches Tiering nur, wenn die Messung 10k@50x oder 100k@10x
verfehlt. Kamera-LOD ist ausgeschlossen, solange D-19 gilt.

**B-Vertrag (jetzt definiert):** B ist ein **eigenes deterministisches
Grobmodell**, keine exakte A-Kopie. Erhalten bleiben Identität, Alter,
Wohnung, Job, Familie, Lebenszyklus/Tod **innerhalb von B**, Wirtschaftsrolle,
Politik und Chronik-Events **innerhalb von B**; Save/Replay sind
B-konsistent. Nicht garantiert sind identische Zeitpunkte, Partnerwahl,
Jobwechsel oder Todesursachen im Vergleich zu A. Parität bedeutet
Invarianten/Toleranzen, nicht exakte Emergenz. Einführung nur per ADR,
Testmatrix und ausdrücklicher Nutzerfreigabe; kein stiller Einsatz.

#### D-19 — Kameraunabhängigkeit der Simulation

**Entschieden:** Strikt kameraunabhängig. Simulation liest niemals Kamera,
Zoom oder Sichtbarkeit; nur das Rendering darf LOD nutzen.

### 4.4 Runde 4 — entschieden

#### D-20 — Sprache und Runtime

**Entschieden:** GDScript zuerst. **G0.5 misst GDScript plus einen
verpflichtenden, minimalen Native-Hotloop (C#/GDExtension, wegwerfbar).** Der
Portentscheid ist am G0.5-Exit bindend für G1a und wird in G2 bestätigt. Die
Kernel-Schnittstelle bleibt schmal. Ein Throwaway-Native-Build außerhalb des
V3-Projekts ist ausdrücklich erlaubt. Profiling-Gate: G2/G3 als Bestätigung.

**G0.5-Ergebnis (2026-11-13):** GDScript beibehalten; kein Port vor G4a.
Trigger: Sim-Slice p95 > 6 ms in G4a/G5a, erzwungener Full-Agent-Sweep pro
Frame oder reale Batch-p95 > 2 ms. Portmechanismus dann GDExtension, nicht
Godot-C#. Details: `docs/g0.5/v3-g0.5-results.md`.

#### D-21 — Agentenspeicher und Ausführungsmodell

**Entschieden:** Custom SoA + eventgetrieben. Hot-Arrays für Position, Needs,
Aktivität, nächster Termin; kalte Records für Identität/Beziehungen/Historie;
keine Per-Agent-Dictionaries in Hot-Loops.

#### D-22 — Projektstruktur und Repository

**Entschieden:** Frisches `V3/` mit eigenem Godot-Projekt und eigenem Git-Repo.
Keine V1-/V2-Altlasten.

#### D-23 — G1-Setting und Startinhalt

**Entschieden:** Landwirtschaftlicher Weiler/Hofverbund mit 10 Agenten,
3 Haushalten, Feld, Speicher, Brunnen und Scheune. Arbeit = Feldarbeit,
Nahrung = Getreide.

#### D-24 — Zielhardware und Mess-Harness

**Entschieden:** Bestehende Zielhardware (Ryzen 5 5600 / RTX 5060) plus
identische headless-Läufe. 3 Läufe pro Gate.

#### D-25 — Meilenstein-Gates und Definition of Done

**Entschieden:** G0–G5 wie in 3.13, mit sichtbarer Demo, Determinismus,
Save/Load, Replay, Benchmark und Review pro Gate. Kein „PARTIAL“.

### 4.5 Runde 5 — entschieden

#### D-26 — Daten- und Content-Pipeline

**Entschieden:** Hybrid aus JSON und prozeduralen Regeln. JSON für Spezies,
Jobs, Gebäude, Items, Traits; Welt/Siedlungen prozedural aus Seed;
deterministisch und modding-freundlich.

#### D-27 — Art-Pipeline

**Entschieden:** Programmer Art/prozedurale Sprites für G1; Art-Pass später.
Kein Asset-Blocker für den ersten sichtbaren Slice.

#### D-28 — G1-Needs und Beziehungen

**Entschieden:** Hunger, Energie, Sozial, Hygiene, Spaß, Gesundheit;
Partner/Eltern/Kind; Kind/Erwachsener/Alter. Gesundheit ist ein langsamer
Zustand, der durch unerfüllte Needs und Alter sinkt; in G1 ohne Krankheiten
und Gewalt. **G1a** umfasst Hunger/Energie/Sozial; **G1b** ergänzt Hygiene/
Spaß/Gesundheit. Beide sind formale Gates mit eigener Abnahme; G1 ist erst
bestanden, wenn G1a und G1b bestanden sind.

#### D-29 — G1-Tages- und Arbeitsmodell

**Entschieden:** Lockere Routine mit Arbeitsfenstern und Need-Unterbrechungen.
Aufwachen, Essen, Feldarbeit, Mittag, Arbeit, Sozialisieren, Schlafen; Needs
unterbrechen und kehren zur Routine zurück.

#### D-30 — Test- und Benchmark-Harness

**Entschieden:** Minimaler eigener Godot-Test-Runner plus externes
3-Lauf-Harness (PowerShell/Python). Keine Fremdabhängigkeit, volle Kontrolle
über Seeds, Warm-up und Metriken.

#### D-31 — Cursed-Beyond-Schnittstelle

**Entschieden:** Jetzt nur die Grenze definieren: deterministische
Command-/Event-API, Save/Replay und headless Loop; kein Netzwerk. Die
Server-/Missionsimplementierung bleibt G6.

### 4.6 Runde 6 — entschieden

#### D-32 — Spielerrolle

**Entschieden:** Beobachter/Chronist. Keine Eingriffe in V3. Indirekter Einfluss
ist eine spätere Version/Variante, nicht Teil des V3-Umfangs.

#### D-33 — Kernschleife

**Entschieden:** Geschichten/Chronik. Der Spieler beobachtet, folgt und liest;
die Emergenz und ihre Lesbarkeit sind das Produkt.

#### D-34 — Gewinn, Verlust und Fortschritt

**Entschieden:** Sandbox ohne Game Over. Fortschritt = Weltentwicklung und
Chronik.

#### D-35 — Systemumfang des Vollziels (G5)

**Entschieden:** Leben + Wirtschaft + Handel + Politik. Krieg, Untote und Tiere
kommen später.

#### D-36 — Spielereingriffe und Determinismus

**Entschieden:** Keine Eingriffe in V3. Die Engine-Grenze (Command-/Event-API)
bleibt für eine spätere Einfluss-Version vorbereitet, wird aber nicht vom
Spieler genutzt.

#### D-37 — Beobachtungs-UX

**Entschieden:** Inspector + Chronik + Beziehungen + Zeitleiste + Alerts.

### 4.7 Runde 7 — entschieden

#### D-38 — Tiefe der Chronik

**Entschieden:** Kuratierte Chronik mit Wichtigkeitsscore, Summaries und
Templates. G1 startet mit einem strukturierten Event-Log plus Agenten-Biografie;
die kuratierte Chronik ist das Ziel. Keine LLM-Abhängigkeit.

#### D-39 — G1-Beobachtungswerkzeuge

**Entschieden:** Inspector, Event-Log, einfacher Familienbaum, Follow-Modus und
Alerts.

#### D-40 — Rewind und Zeitreise

**Entschieden:** Kein Rewind in V3. Save/Load plus Ereignis-Chronik. Keyframes/
Rewind bleiben eine spätere Option.

#### D-41 — Erzählebenen

**Entschieden:** Individuum + Familie + Siedlung; Nation später.

#### D-42 — Session- und Aufmerksamkeitsdesign

**Entschieden:** „Story of the day“ + Alerts + Follow-Modus. Eine Sitzung kann
einen Tag bei 1x (15 min) oder ein Jahr bei 50x (9 min) abdecken.

#### D-43 — Sprache und Textstil der Chronik

**Entschieden:** Strukturierte Daten plus deutsche Template-Texte; keine
LLM-Abhängigkeit.

### 4.8 Runde 8 — entschieden

#### D-44 — Tiefe des Wirtschaftsmodells

**Entschieden:** Haushalte, lokale Märkte, regionaler Handel und nationale
Schatzkammer. Kein voller Finanzsektor.

#### D-45 — Geld- und Accounting-Granularität

**Entschieden:** Individuelle Löhne/Münzen für sichtbare Agenten;
Haushaltsbudget; Siedlungs-/Nationsledger. Keine Transaktion pro Agent und Tick.

#### D-46 — Handelsmodell

**Entschieden:** Physische Karawanen mit Ladung, lokalen Preisen und
Handelsabkommen; sichtbar auf der Karte.

#### D-47 — Politik-Tiefe

**Entschieden:** 3 Nationen mit Schatzkammer, Steuern, öffentlichem Budget,
Diplomatie und Verträgen; kein Krieg in G5.

#### D-48 — Krisen und Rückkopplung

**Entschieden:** Knappheit, Preisspitzen, Hunger, Verschuldung und Unruhe als
Chronik-Ereignisse; kein Game Over.

#### D-49 — Entscheidungs-KI und Start-Spezialisierung

**Entschieden:** Deterministische Regel-/Utility-KI; 3 Nationen mit
unterschiedlichen Ressourcen und Spezialisierungen.

### 4.10 Runde 9 — entschieden

#### D-50 — V3-Scope-Grenze

**Entschieden:** V3-Kern = Leben + Soziales + Wirtschaft + Handel + Politik.
**Nutztiere sind Teil der G5-Wirtschaft.** Krieg, Wildtiere/Ökosystem und
Fantasy sind Erweiterungen nach G5.

#### D-51 — Setting/Lore-Ton

**Entschieden:** Low-Fantasy-Mittelalter mit 3 menschlichen Nationen,
unterschiedlichen Kulturen/Ressourcen und seltener Magie. Fantasy existiert,
ist aber nicht Teil des V3-Kerns.

#### D-52 — Fantasy-Elemente

**Entschieden:** Untote und Orks sind als spätere **JSON-getriebene
Addon-Fraktionen** geplant, nicht im V3-Kern. Untote: Unterfraktion mit
Nekromant, eigenen Zielen und Invasionen; Orks: eine der ersten
Addon-Fraktionen; später Zwerge, Elfen, Gnome usw.; Drachen als seltene Events.
In V3 nur Lore/Ferne, keine Simulation.

#### D-53 — Soziale Tiefe

**Entschieden:** Liebe/Partnerschaft, Ehe, Kinder, Familie, Haushalt,
Freundschaften/Feindschaften, Reputation und einfache Emotionen.

#### D-54 — Krieg und Kampf

**Entschieden:** Nach G5 als V3-Erweiterung; G5 bleibt Politik ohne Krieg.

#### D-55 — Tiere und Wildleben

**Entschieden:** Nutztiere in der G5-Wirtschaft; Wildtiere/Ökosystem als
V3-Erweiterung nach G5.

#### D-56 — Art/UI-Richtung

**Entschieden:** 3/4-Topdown-Pixelart, warme mittelalterliche Palette, klare
Silhouetten, Inspector-Sidebar, Chronik-Panel, Familienbaum-Overlay und
Tag/Nacht-Tint.

### 4.11 Runde 10 — entschieden

#### D-57 — Weitere Systeme im V3-Kern

**Entschieden:** Alle sieben Systeme kommen **leicht** in den V3-Kern, aber
**G2/G3 nur als Daten-/UI-Stubs**; echte Simulation ab G4/G5. Betroffen:
Magie/Religion (Lore + Tempel/Priester/Feste), Kultur/Technologie (statische
Profile), Krankheit/Medizin (leichte Krankheiten/Heilung), Wetter/Jahreszeiten
(tägliches Wetter/Effekte/Visuals), Recht/Kriminalität (leichte
Gesetze/Wachen/Gerichte), Bildung/Gilden (Lehrlinge/Skills/Gilden),
Feste/Kunst/Musik (Saisonfeste/Hochzeiten/Begräbnisse/Markttage). Keine
Tiefensimulation; Verschiebung pro Gate erlaubt.

### 4.12 G0-Freigabe — offen

Die Grundsatzentscheidungen sind vollständig. Offen ist die G0-Artefaktphase
(G1-Spec, Architektur, Datenmodell, Benchmark, Chronik-Design, Fidelity-Vertrag,
Risiko-Register, V3-Skelett) und danach der **G0.5-Technikspike**. Vor der
G0-Freigabe wird kein Code geschrieben; G0.5 ist der erste, eng begrenzte
Technikspike und keine Gameplay-Implementierung.

## 5. Vorläufige Nicht-Ziele für den V3-Kickoff

- Keine Wirtschaftssimulation, keine Fraktionen, kein Krieg, keine Untoten in
  der ersten sichtbaren Scheibe.
- Keine vollständige V1-Parität.
- Keine 10k-/100k-Skalierungsbehauptung aus der 10-Akteure-Scheibe.
- Keine 4096²-Welt, bevor das Raummodell steht.
- Keine Grafik-/Asset-Pipeline ohne vorherige Maßstabsentscheidung.
- Keine Kohorten-/Makro-/Performance-Modi als Ersatz für Detailtreue.
- Keine neuen Balancewerte ohne dokumentierte Entscheidung.
- Kein V1-/V2-Code in V3.

## 6. Nächste Schritte

1. **G0-Artefakte ausarbeiten:** G1-Spec, Architektur, Datenmodell, Benchmark,
   Chronik-Design, Fidelity-Vertrag, Risiko-Register, V3-Skelett.
2. **G0-Review:** Checkliste pro Artefakt; Widersprüche und Budgets prüfen.
3. **G0.5-Technikspike:** Scheduler, SoA, Needs, Pfad, Render,
   GDScript-vs-Native; Messwerte und Sprach-/Portentscheidung.
4. **G1a starten:** erst nach G0-Review und G0.5-Exit; keine Gameplay-Implementierung
   vorher.
5. Kein V1-/V2-Code, keine stillen Designänderungen.

## 7. Entscheidungslog

**Status-Legende:** `final` = entschieden und abnahmefähig; `provisional` =
entschieden, aber kalibrierbar; `offen` = nicht entschieden.

| ID | Entscheidung | Status | Datum | Begründung |
|---|---|---|---|---|
| D-01 | Produktziel | final | 2026-11-13 | Spielbare Wimmelbild-Sim + Cursed-Beyond-Fundament; 10k als Zwischenschritt |
| D-02 | Failure-Definition | final | 2026-11-13 | Performance, Architektur, KI-Prozess, unklares Gesamtziel |
| D-03 | Nordstern / erste Abnahme | final | 2026-11-13 | ~100k-Design, erste sichtbare Abnahme mit 10 Akteuren |
| D-04 | Ausgangsbasis | final | 2026-11-13 | Komplett frisches V3 |
| D-05 | Speed-/Fidelity-Richtung | final | 2026-11-13 | 30-Tage-Jahr, 15 min/Tag, 1x/10x/50x, need-basiert |
| D-06 | Kalender-/Zeitmodell | final | 2026-11-13 | 30 Tage/Jahr, 15 min/Tag, 1 Sim-Minute Quantum; Raten kalibrierbar |
| D-07 | Skalenleiter/100k-Härte | final | 2026-11-13 | 100k@10x Pflicht für G5a; 100k@50x Stretch |
| D-08 | Weltmodell/Dichte | provisional | 2026-11-13 | 3 Nationen, Siedlungshierarchie; Details kalibrierbar |
| D-09 | Erste sichtbare Scheibe | final | 2026-11-13 | 10 Akteure + Lebenszyklus |
| D-10 | Optik/Maßstab | final | 2026-11-13 | 1,5 m/Tile, 16 px/Tile, ~19–20 px Figuren |
| D-11 | Engine-/Produkt-Grenze | final | 2026-11-13 | Engine + dünne Spielschale |
| D-12 | Arbeitsprozess/Gates | final | 2026-11-13 | PM + Subagenten + harte Gates + menschliche Freigabe |
| D-13 | Räumliches Weltmodell | final | 2026-11-13 | Single-scale sparse + Graph |
| D-14 | Maßstabs-Kombination | final | 2026-11-13 | 1,5 m/Tile, 16 px/Tile, ~19–20 px Figuren |
| D-15 | Bevölkerungs-/Siedlungsprofil | final | 2026-11-13 | Kompakt ~100k, 3 Nationen |
| D-16 | Lebenszyklus/Sterblichkeit | final | 2026-11-13 | Alterung + Hazard + einfache Geburten |
| D-17 | Messmatrix/harte Gates | final | 2026-11-13 | 10k@50x + 100k@10x Pflicht; 100k@50x Stretch |
| D-18 | Fidelity-Modell/AI-LOD | final | 2026-11-13 | A starten, B als Fallback; kein Kamera-LOD |
| D-19 | Kameraunabhängigkeit | final | 2026-11-13 | Strikt kameraunabhängig |
| D-20 | Sprache/Runtime | final | 2026-11-13 | GDScript zuerst; Hot-Path-Port nach C#/GDExtension bei Bedarf |
| D-21 | Agentenspeicher/Ausführung | final | 2026-11-13 | Custom SoA + eventgetrieben |
| D-22 | Projektstruktur/Repo | final | 2026-11-13 | Frisches V3/ mit eigenem Git-Repo |
| D-23 | G1-Setting/Startinhalt | final | 2026-11-13 | Landwirtschaftlicher Weiler |
| D-24 | Zielhardware/Mess-Harness | final | 2026-11-13 | Ryzen 5 5600/RTX 5060 + headless |
| D-25 | Meilenstein-Gates/DoD | final | 2026-11-13 | G0–G5 mit Demo, Determinismus, Benchmark, Review |
| D-26 | Daten-/Content-Pipeline | final | 2026-11-13 | JSON + prozedurale Welt |
| D-27 | Art-Pipeline | final | 2026-11-13 | Programmer Art zuerst, Art-Pass später |
| D-28 | G1-Needs/Beziehungen | final | 2026-11-13 | Hunger/Energie/Sozial/Hygiene/Spaß/Gesundheit + Lebenszyklus |
| D-29 | G1-Tages-/Arbeitsmodell | final | 2026-11-13 | Lockere Routine mit Need-Unterbrechungen |
| D-30 | Test-/Benchmark-Harness | final | 2026-11-13 | Eigener Runner + externes 3-Lauf-Harness |
| D-31 | Cursed-Beyond-Schnittstelle | final | 2026-11-13 | Command-/Event-API jetzt, Netzwerk erst G6 |
| D-32 | Spielerrolle | final | 2026-11-13 | Beobachter/Chronist; Einfluss erst später |
| D-33 | Kernschleife | final | 2026-11-13 | Geschichten/Chronik |
| D-34 | Gewinn/Verlust/Fortschritt | final | 2026-11-13 | Sandbox ohne Game Over |
| D-35 | Systemumfang G5 | final | 2026-11-13 | Leben + Wirtschaft + Handel + Politik; Krieg/Tiere später |
| D-36 | Spielereingriffe/Determinismus | final | 2026-11-13 | Keine Eingriffe in V3; Engine-Grenze bleibt vorbereitet |
| D-37 | Beobachtungs-UX | final | 2026-11-13 | Inspector + Chronik + Beziehungen + Zeitleiste + Alerts |
| D-38 | Chronik-Tiefe | final | 2026-11-13 | Kuratierte Chronik mit Wichtigkeit/Summaries/Templates |
| D-39 | G1-Beobachtungswerkzeuge | final | 2026-11-13 | Inspector + Log + Familienbaum + Follow + Alerts |
| D-40 | Rewind/Zeitreise | final | 2026-11-13 | Kein Rewind in V3 |
| D-41 | Erzählebenen | final | 2026-11-13 | Individuum + Familie + Siedlung |
| D-42 | Session-/Aufmerksamkeitsdesign | final | 2026-11-13 | Story of the day + Alerts + Follow |
| D-43 | Sprache/Textstil der Chronik | final | 2026-11-13 | Deutsch + Templates, keine LLM-Abhängigkeit |
| D-44 | Tiefe Wirtschaftsmodell | final | 2026-11-13 | Haushalte + lokale Märkte + Handel + Schatzkammer |
| D-45 | Geld-/Accounting-Granularität | final | 2026-11-13 | Individuum + Haushalt + Siedlungs-/Nationsledger |
| D-46 | Handelsmodell | final | 2026-11-13 | Physische Karawanen mit Ladung und Abkommen |
| D-47 | Politik-Tiefe | final | 2026-11-13 | 3 Nationen, Steuern, Budget, Diplomatie; kein Krieg |
| D-48 | Krisen/Rückkopplung | final | 2026-11-13 | Chronik-Krisen ohne Game Over |
| D-49 | Entscheidungs-KI/Spezialisierung | final | 2026-11-13 | Utility-KI + 3 Ressourcen-Spezialisierungen |
| D-50 | V3-Scope-Grenze | final | 2026-11-13 | Leben + Soziales + Wirtschaft + Handel + Politik; Rest nach G5 |
| D-51 | Setting/Lore-Ton | final | 2026-11-13 | Low-Fantasy-Mittelalter, 3 menschliche Nationen |
| D-52 | Fantasy-Elemente | final | 2026-11-13 | Untote/Orks als JSON-Addon-Fraktionen, Drachen seltene Events; in V3 Lore |
| D-53 | Soziale Tiefe | final | 2026-11-13 | Liebe/Familie/Freundschaft/Reputation |
| D-54 | Krieg/Kampf | final | 2026-11-13 | Nach G5 als Erweiterung |
| D-55 | Tiere/Wildleben | final | 2026-11-13 | Nutztiere G5; Wildtiere/Ökosystem später |
| D-56 | Art/UI-Richtung | final | 2026-11-13 | 3/4-Topdown, Inspector + Chronik + Familienbaum |
| D-57 | Weitere Systeme im V3-Kern | final | 2026-11-13 | Alle sieben leicht; G2/G3 nur Stubs, echt ab G4/G5 |
| D-58 | G0.5-Technikspike | final | 2026-11-13 | Scheduler, SoA, Needs, Pfad, Render, GDScript-vs-Native |
| D-59 | G1a/G1b | final | 2026-11-13 | Zwei formale Gates; G1 erst nach G1a und G1b bestanden |
| D-60 | G4a/G4b und G5a/G5b | final | 2026-11-13 | Skalierung und Systeme getrennt abnehmen |
| D-61 | Chronik-Design | final | 2026-11-13 | G0-Artefakt vor G1 |
| D-62 | Budgetmatrix | final | 2026-11-13 | Pro Szenario/Event-Typ; in G0.5/G2 kalibrieren |
| D-63 | B-Fidelity-Vertrag | final | 2026-11-13 | Preserved fields/Approximationen jetzt definiert |
| D-64 | G0.5-Ergebnis/Portentscheid | final | 2026-11-13 | GDScript beibehalten; kein Port vor G4a; Trigger + GDExtension |
