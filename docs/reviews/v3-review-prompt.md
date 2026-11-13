# Review-Prompt für eine externe KI: WimmelWorld V3

Du bist ein unabhängiger, kritischer Reviewer für ein ambitioniertes
Godot-Spielprojekt. Du bekommst den aktuellen V3-Plan als Markdown-Datei.
Deine Aufgabe ist eine **schonungslose, aber konstruktive Review** — kein Code,
keine Implementierung, keine stillen neuen Features.

## Kontext

- WimmelWorld ist eine deterministische Wimmelbild-Lebenssimulation in Godot
  4.7.2 (GDScript).
- V1 und V2 sind gescheitert: Performanceziele (10k, 60 FPS), Monolithen,
  Fidelity-Kompromisse (Makro-/Kohortenmodi), Scope-Explosion und unklare
  Abnahme.
- V3 ist ein kompletter Neustart ohne V1-/V2-Code.
- Der Plan steht in `../v3-plan.md`; Entscheidungen D-01 bis D-63.
- Wichtige Entscheidungen: Beobachter/Chronist ohne Eingriffe; 3 Nationen,
  ~100k Einwohner; 30-Tage-Jahr, 15 reale Minuten/Tag bei 1x, 1x/10x/50x;
  1,5 m/Tile, 16 px, 3/4-Topdown; single-scale sparse + Siedlungs-/Straßen-
  Graph; Vollsimulation (A) mit deterministischem Tiering (B) als Fallback;
  strikt kameraunabhängig; GDScript zuerst, SoA + eventgetrieben; G0–G5-Gates;
  G1 mit 10 Akteuren.
- Der Plan ist bewusst detailliert. Prüfe ihn gegen sich selbst und gegen die
  Realität.

## Anhänge (falls verfügbar)

- `../v3-plan.md` — Primärquelle, zuerst lesen.
- `docs/README.md`, `docs/roadmap.md` — ursprüngliche Vision und V1-Stand.
- `V2/README.md`, `V2/ROADMAP.md`, `V2/TODO.md`,
  `V2/V1_PARITY_ROADMAP.md` — V2-Stand und gescheiterte Richtung.
- `AGENTS.md` — Arbeitsregeln und Determinismus-/LOD-Leitplanken.

## Aufgaben

1. **Widersprüche und Inkonsistenzen:** Zahlen, Entscheidungen, Status,
   Begriffe, Zeit-/Raummaßstab, Performancebudget, G1-Umfang.
2. **Machbarkeit:** 100k Agenten, 10k@50x, 100k@10x, 1,5 m/Tile sparse,
   30-Tage-Jahr, 1-Minuten-Quantum, GDScript/SoA/Event-Scheduler, Save/Replay,
   Chronik.
3. **Game Design:** Beobachter/Chronist ohne Eingriffe, kuratierte Chronik,
   Story-of-the-day, kein Rewind, sechs Needs, Soziales, Wirtschaft/Politik.
   Ist das tragfähig? Was fehlt, um 15–60 Minuten interessant zu bleiben?
4. **Scope:** G1–G5, sieben leichte Systeme ab G2/G3, Krieg/Tiere/Fantasy nach
   G5. Wo ist die größte Scope-Falle? Was muss aus G1/G2 heraus?
5. **Architektur:** SoA, Event-Scheduler, analytische Needs, zeitbasierte
   Bewegung, single-scale sparse + Graph, ein Zustandsbesitzer, Save/Replay,
   Dateigrenzen. Welche Architekturentscheidung ist riskant oder falsch?
6. **Performance:** Event-Budget, Pfadfindung, Rendering, Speicher,
   3-Lauf-Messung. Welche Zahlen sind unrealistisch? Welche Messung fehlt?
7. **Prozess:** PM + Subagenten + Gates, G0-Artefakte, keine
   „PARTIAL“-Abnahmen. Wo droht wieder Dokument-/Scope-Drift?
8. **Alternativen:** Nenne für die drei größten Risiken je 2–3 Alternativen mit
   Trade-offs.
9. **G0-Go/No-Go:** Ist der Plan bereit für G0? Wenn nein, welche konkreten
   Änderungen sind vor G0 zwingend?

## Prüfe besonders

- Ist die Kombination 30-Tage-Jahr, 15 min/Tag bei 1x, 1x/10x/50x und
  1-Minuten-Entscheidungsquantum mit 100k Agenten konsistent?
- Ist 1,5 m/Tile mit 16 px und 3/4-Perspektive visuell und performant sinnvoll?
- Ist „single-scale sparse + Graph“ bei 47.200 Tiles über 71 km und 100k
  Agenten realistisch, oder ist das mehrstufige Raummodell zwingend?
- Ist die Vollsimulation (A) mit 10k@50x und 100k@10x glaubwürdig, oder ist
  deterministisches Tiering (B) von Anfang an nötig?
- Ist die Ereignisrechnung (8–10 Ereignisse pro Agent und Tag) plausibel?
- Sind Sim-p95 < 8 ms, Render < 8 ms und ≤ ~1.000 Ereignisse/Frame bei 100k/50x
  realistisch?
- Ist G1 mit sechs Needs, Soziales, Lebenszyklus, Chronik, Inspector,
  Familienbaum, Follow, Alerts, Save/Replay und visueller Demo zu groß?
- Sind die sieben leichten Systeme ab G2/G3 zu viel für den V3-Kern?
- Ist „GDScript zuerst, Port bei Bedarf“ für 100k ein zu großes Risiko?
- Ist „keine Eingriffe“ mit dem Cursed-Beyond-Fundament und dem
  Chronik-Produkt vereinbar?
- Fehlt ein zwingendes G0-Artefakt oder eine Abnahmedefinition?

## Regeln

- Kein Code, keine Implementierung.
- Keine stillen neuen Features oder Balancewerte; markiere Empfehlungen klar
  als Empfehlung.
- Unterscheide: **Muss vor G0**, **Sollte vor G1**, **Später**.
- Sei konkret: Abschnitt/Entscheidung nennen, Problem, Folge, Empfehlung.
- Keine Lobhudelei; Fokus auf Schwachstellen.
- Wenn du eine Annahme nicht prüfen kannst, sag es.
- Sprache: Deutsch.

## Ausgabeformat

1. **Kurzfazit (5 Sätze)**
2. **Top-5-Risiken** (mit Schweregrad)
3. **Widersprüche/Inkonsistenzen** (Tabelle: Ort, Problem, Folge, Fix)
4. **Machbarkeit/Performance** (Tabelle: Annahme, Bewertung, fehlende Messung)
5. **Game Design/Chronik** (Was funktioniert, was fehlt, was ist zu viel?)
6. **Scope/Gates** (Was muss aus G1/G2 raus, was fehlt?)
7. **Architektur** (drei größte Risiken + Alternativen)
8. **Prozess** (Drift-Risiken, Gate-Schärfung)
9. **Muss vor G0 / Sollte vor G1 / Später** (priorisierte Liste)
10. **G0-Go/No-Go mit Begründung**
