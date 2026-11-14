# V3-Fidelity-Vertrag: A (1x autoritativ) und B (150x Zeitraffer)

Status: **entschieden 2026-11-14**  
Bezug: `v3-plan.md`, D-18, D-19, D-63, D-65.

## 1. Zwei Produkte, zwei Modi

- **Cursed Beyond:** läuft immer **1x**, serverautoritativ, **A: Vollsimulation**.
  Deterministisch, save-/replay-fähig, keine Simulations-LOD.
- **WimmelWorld standalone:** eigener **150x-Zeitraffer-Modus**, **B:
  deterministisches Tiering/Coarse**. Sichtbar als „Zeitraffer“ markiert,
  separates Welt-/Save-Modell, **nicht replay-äquivalent zu A**.
- **Getrennte Welten:** Cursed Beyond und WimmelWorld standalone teilen keine
  persistente Geschichte. Ein 150x-Lauf schreibt nicht in die autoritative
  1x-Welt zurück.
- **Kein Kamera-LOD:** Weder A noch B lesen Kamera, Zoom oder Sichtbarkeit.
- **Kein stiller Speed-Schalter:** Der Modus ist im UI und Save sichtbar.

## 2. A — Vollsimulation (1x, Cursed Beyond)

- Alle Agenten haben individuelle Zustände, Termine und Ereignisse.
- Keine statistischen Hintergrundkohorten.
- Rendering-LOD ist erlaubt, Simulation-LOD nicht.
- Determinismus, Save/Load und Replay sind Pflicht.
- **100k@1x ist performancemäßig machbar:** ca. 15–19 Events/Frame bei
  8–10 Events/Agent/Tag.
- A ist die autoritative Welt für Cursed Beyond.

## 3. B — Deterministisches Tiering (150x, WimmelWorld standalone)

B ist ein **eigenes deterministisches Grobmodell** für den Zeitraffer, keine
exakte A-Kopie. Es ist der **primäre 100k@150x-Modus** für das Standalone-Spiel,
kein heimlicher Fallback.

### 3.1 Persistente Datensätze

Alle 100k Agenten behalten:

- Identität, Name, Geschlecht, Geburtstag, Alter.
- Haushalt, Wohnung, Job, Arbeitsplatz.
- Familienbande und zentrale Beziehungen.
- Lebenszyklusstufe, Gesundheit und Todeszeitpunkt **innerhalb von B**.
- Wirtschaftsrolle, Einkommensklasse, politische Zugehörigkeit.
- Chronikwürdige Ereignisse **innerhalb von B**.
- Save-/Replay-Konsistenz innerhalb von B.

### 3.2 Detail- und Hintergrundtier

- **Detailtier:** eine deterministisch gewählte Teilmenge (Zielgröße im Spike
  messen, z. B. 1.000–5.000 Agenten) mit Needs, Wegen, Entscheidungen und
  Ereignissen.
- **Hintergrundtier:** der Rest wird pro Siedlung/Kohorte coarse aktualisiert
  (z. B. täglich/wöchentlich), nicht pro Agent und Minute.
- **Tier-Auswahl:** simulationsgetrieben, nicht kameragetrieben:
  Ereignisnähe, Reisen, Alter, Beziehungen, Wirtschaftsrolle, rotierende
  stabile Hash-Stichprobe.
- **Promotion/Demotion:** deterministisch, mit Catch-up aus dem letzten
  autoritativen B-Record; kein Teleport, kein Zeitsprung, keine erfundenen
  Events.
- **Kein Kamera-Einfluss:** Follow/Inspector ändern die Tier-Auswahl nicht.

### 3.3 Approximiert erlaubt

- Minuten-genaue Need-Kurven im Hintergrund.
- Exakte Wege/Bewegung/Pfadgeometrie.
- Routine-Mikroentscheidungen (Essen, Waschen, Plaudern).
- Exakte Konsumzeitpunkte.
- Nicht-chronikwürdige Alltagsdetails.

### 3.4 B-Modus ist sichtbar

- UI-Label: **„Zeitraffer (150x, grob)“**.
- Save markiert `fidelity_mode = B`.
- Der Modus ist nicht replay-äquivalent zu A; ein A-Save wird nicht als B
  geladen und umgekehrt.
- Die Chronik ist innerhalb von B konsistent, kennzeichnet aber den
  Zeitraffer-Modus.

### 3.5 A/B-Äquivalenz: Makro ähnlich, Mikro unterschiedlich

- **Makro:** Bevölkerung, Altersverteilung, Haushalte, Jobs, Nahrung,
  Gesundheit, Krisen und Siedlungswachstum sollen über dieselben Seeds und
  Zeitfenster **innerhalb definierter Toleranzen** ähnlich sein.
- **Ereigniszahlen:** Geburten, Tode, Ehen, Jobwechsel und Krisen pro
  Siedlung/Jahr innerhalb der Toleranz.
- **Mikro:** **Welches Individuum** ein Ereignis erlebt, darf abweichen. Das
  ist gewollt, kein Fehler. B erzeugt plausible, deterministische Individuen,
  aber nicht dieselben wie A.
- **Anker-Agenten:** Benannte/gefolgte Herrscher, Hauptfiguren oder explizit
  markierte Agenten werden exakt erhalten oder deterministisch promoviert;
  Hintergrundidentitäten dürfen abweichen.
- **Horizonte:** Vergleich nach 1, 5, 10 und 50 Sim-Jahren. Individuelle
  Abweichungen können kaskadieren; B wird nachkalibriert, wenn Makro-Bänder
  verlassen werden.
- **Keine Bit-Gleichheit A/B** und kein A/B-Replay. A und B sind getrennte
  Welten; A ist autoritativ für Cursed Beyond, B für den Standalone-Zeitraffer.
- **Krieg/Kampf** ist post-G5. Für V3 dienen Hunger, Krankheit, Unfall und
  Ernteausfall als A/B-Testfälle: Anzahl/Typ ähnlich, konkrete Person anders.
- **A/B-Harness:** gleicher Seed/Config, Telemetrie pro Jahr/Siedlung,
  Toleranzbänder, Anker-Agenten, Bericht über Makro-Drift und Mikro-Divergenz.

## 4. Performance-Ziele

| Modus | Population | Speed | Ziel |
|---|---|---:|---|
| A | 100k | 1x | 15–19 Events/Frame; p95 ≤ 16 ms |
| A | 10k | 50x | 10k-Gate; p95 ≤ 16 ms |
| B | 100k | 150x | 100k-Zeitraffer; Events/Frame im Spike messen |
| B | 100k | 200x | Stretch; nur wenn B-Spike es belegt |

100k@150x mit A ist **nicht** Ziel: 2.222–2.778 Events/Frame sind mit
GDScript nicht tragbar. 100k@1x mit A ist Ziel; 150x ist B.

## 5. Tests

- A: Determinismus, Save/Load, Replay, Kameraunabhängigkeit, 100k@1x.
- B: Determinismus innerhalb B, Save/Load, Tier-Wechsel, Key-Event-Erhalt,
  Kameraunabhängigkeit, 100k@150x/200x.
- A/B: Makro-Invarianten und Ereigniszahlen innerhalb der Toleranz; Mikro-
  Identitäten dürfen abweichen; Anker-Agenten erhalten.
- Keine A/B-Replay-Gleichheit; kein Bit-Vergleich.
- Kein Leak, keine stillen Events, keine verlorenen Identitäten.

## 6. Entscheidungspfad

1. B-Spike: 100k Records, Detailtier 1k/5k, Hintergrund-Coarse, 150x/200x.
2. Messen: Events/Frame, Batch-Kosten, Speicher, Save/Load, Determinismus.
3. Bei Erfolg: B als Standalone-150x-Modus, A als Cursed-Beyond-1x-Modus.
4. Bei Misserfolg: Detailtier/Cadence anpassen oder 100k@150x als Native-
   Stretch behandeln.
5. Kein vollständiger Sprachwechsel vor diesem Spike.

## 7. Balancing und Telemetrie

- **150x/B** ist ein **qualitatives Balancing- und Beobachtungswerkzeug**:
  lange Zeiträume, Generationen, Jahreszeiten, Krisen, Siedlungswachstum.
- **Quantitative Balance** läuft auf **A headless mit voller CPU-Geschwindigkeit**
  und denselben Seeds, nicht auf B. A ist das autoritative 1x-Modell; B
  approximiert Routine und kann bei Wirtschaft/Demografie driften.
- **A/B-Vergleich:** gleiche Seeds, Invarianten vergleichen (Bevölkerung,
  Altersverteilung, Haushalte, Jobs, Nahrung, Krisen). Bei zu großer Drift
  B kalibrieren oder 150x nur als Beobachtung, nicht als Balance, nutzen.
- **Telemetrie:** pro Jahr/Season/Siedlung CSV mit Geburten, Toden,
  Bevölkerung, Altersstruktur, Grain, Jobs, Gesundheit, Krisen, Wanderung,
  Siedlungswachstum. Das macht 150x zum echten Design-/QA-Werkzeug.
- **Cursed Beyond** wird nicht auf B gebalanced; Cursed Beyond ist A bei 1x.

## 8. Nicht verhandelbar

- Keine kameraabhängige Simulation.
- Keine stillen Zeit-/Event-Sprünge.
- Keine verlorenen Identitäten oder Lifecycle-Events.
- Keine unmarkierte Abweichung zwischen A und B.
- Kein B ohne Messung und Freigabe.
- Cursed Beyond bleibt A bei 1x.
