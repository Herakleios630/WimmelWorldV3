# V3-Fidelity-Vertrag (A/B)

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, D-18, D-19, D-63.

## 1. Ziel

V3 startet mit **A: Vollsimulation**. **B: deterministisches Tiering** ist ein
streng definierter Fallback, kein stiller Performance-Modus. Kamera-/Relevanz-
LOD (C) ist ausgeschlossen.

## 2. A — Vollsimulation

- Alle Agenten haben individuelle Zustände, Termine und Ereignisse.
- Keine statistischen Hintergrundkohorten.
- Rendering-LOD ist erlaubt, Simulation-LOD nicht.
- Kamera/Zoom/Sichtbarkeit lesen die Simulation nie.
- Deterministisch, save-/replay-fähig.
- Pflichtziele: 10k@50x, 100k@10x; 100k@50x Stretch.

## 3. B — Deterministisches Tiering

B darf nur eingeführt werden, wenn A die Pflichtziele nachweislich verfehlt.
Einführung nur per ADR, Testmatrix und ausdrücklicher Nutzerfreigabe.

### 3.1 B ist ein eigenes Grobmodell, keine exakte A-Kopie

B ist ein **separates, deterministisches autoritatives Grobmodell** für
Hintergrundsegmente. Es approximiert nicht A im Sinne exakter emergenter
Outcomes, sondern erzeugt eigene konsistente Lebensläufe mit denselben
Invarianten. Ein „exakter Todeszeitpunkt wie in A“ ist bei approximierten
Needs/Konsum/Wegen kausal nicht haltbar.

**Erhalten bleiben:**

- Identität, Name, Geschlecht, Geburtstag, Alter.
- Haushalt, Wohnung, Job, Arbeitsplatz.
- Familienbande und zentrale Beziehungen.
- Lebenszyklusstufe, Gesundheitszustand und Todeszeitpunkt **innerhalb von B**.
- Wirtschaftsrolle, Einkommensklasse, politische Zugehörigkeit.
- Chronikwürdige Ereignisse **innerhalb von B** (Geburt, Tod, Ehe, Jobwechsel,
  Krise, Vertrag, historische Events).
- Save-/Replay-Konsistenz innerhalb von B.

**Nicht garantiert:** identische Ereigniszeitpunkte, identische Partnerwahl,
identische Jobwechsel oder identische Todesursachen im Vergleich zu A.

### 3.2 Approximiert erlaubt

- Minuten-genaue Need-Kurven im Hintergrund.
- Exakte Wege/Bewegung und Pfadgeometrie.
- Routine-Mikroentscheidungen (Essen, Waschen, Plaudern).
- Exakte Konsumzeitpunkte.
- Nicht-chronikwürdige Alltagsdetails.

### 3.3 Tier-Auswahl

- Deterministisch, nicht kamerabasiert.
- Kriterien: Siedlung, Simulationsereignis (nicht Sichtbarkeit), Reise, Alter,
  Beziehungen, rotierende Stichprobe, Wirtschafts-/Politikrolle.
- Kein Agent wird allein wegen Sichtbarkeit hoch-/runtergestuft.
- Tier-Wechsel werden im Debug-Log dokumentiert, nicht als Chronik-Rauschen.

### 3.4 Promotion/Demotion

- Promotion: Hintergrundagent wird in B detaillierter; Zustand wird
  deterministisch aus dem letzten B-Record fortgeschrieben.
- Demotion: Detailzustand wird in den B-Record verdichtet; keine erfundenen
  Ereignisse.
- Kein Teleport, kein Zeitsprung, keine stillen Events.

### 3.5 Parität und Tests

- **B-intern:** deterministisch, save-/replay-fähig, kameraunabhängig.
- **Invarianten A↔B:** Bevölkerungszahl, Altersverteilung, Haushaltsstruktur,
  Berufsverteilung und Ereigniskategorien innerhalb definierter Toleranzen.
- **Keine exakte A/B-Gleichheit** für emergente Zeitpunkte oder Partnerwahl.
- **Chronik:** B-Ereignisse sind innerhalb von B konsistent; die Chronik
  kennzeichnet B nicht als „falsch“, aber der Fidelity-Modus ist im Save/UI
  sichtbar.
- **Tests:** B-Determinismus, Invarianten, Save/Replay über Tier-Wechsel,
  Kamera-/Sichtbarkeitsvergleich, Performance.
- **Performance:** B muss die verfehlten Gates nachweislich verbessern.

## 4. C — Kamera-/Relevanz-LOD

- Nicht erlaubt.
- Beobachtung darf das Leben nicht verändern.
- Cursed Beyond braucht eine serverautoritative, beobachtungsunabhängige Welt.

## 5. Entscheidungspfad

1. A implementieren und messen.
2. G4a/G5a: A gegen 10k@50x/100k@10x prüfen.
3. Bei Verfehlung: B-ADR mit preserved/approximated fields, Tier-Regeln,
   Tests, Save-/Replay-Semantik.
4. Nutzerfreigabe.
5. B implementieren, A/B-Paritätstests, Performance-Gate.
6. Chronik kennzeichnet keine erfundenen Details; approximierte Routine ist
   zulässig, solange die Biografie konsistent bleibt.

## 6. Nicht verhandelbar

- Keine kameraabhängige Simulation.
- Keine stillen Zeit-/Event-Sprünge.
- Keine verlorenen Identitäten oder Lifecycle-Events.
- Keine unmarkierte Abweichung von A.
- Kein B ohne Messung und Freigabe.
