# Review-Prompt Runde 2: WimmelWorld V3 G0

Du bist ein unabhängiger, kritischer Reviewer. Dies ist die **zweite
Review-Runde** für das V3-Projekt. Die erste Runde hat Widersprüche und einen
fehlenden Machbarkeitsnachweis gefunden; der Plan wurde überarbeitet. Prüfe, ob
die Findings wirklich gelöst sind und ob G0 freigegeben werden kann.

## Kontext

- WimmelWorld V3, Godot 4.7.2, GDScript zuerst, SoA + eventgetrieben.
- Beobachter-/Chronik-Sandbox: keine Eingriffe, kein Game Over.
- 3 menschliche Nationen, ~100k Einwohner, 30-Tage-Jahr, 1,5 m/Tile, 16 px,
  3/4-Topdown.
- Gates: G0 → G0.5 → G1a/G1b → G2 → G3 → G4a/G4b → G5a/G5b → G6.
- Erste Review: `V3/docs/reviews/v3-review-2026-11-13.md`.
- Überarbeiteter Master: `V3/docs/v3-plan.md`.
- G0-Artefakte:
  - `V3/docs/v3-g1-spec.md`
  - `V3/docs/v3-architecture.md`
  - `V3/docs/v3-data-model.md`
  - `V3/docs/v3-benchmark.md`
  - `V3/docs/v3-chronicle.md`
  - `V3/docs/v3-fidelity.md`
  - `V3/docs/v3-risk-register.md`
  - `V3/docs/v3-g0.5-spike.md`
  - `V3/docs/v3-project-structure.md`
  - `V3/docs/v3-g0-review.md`
- Der V3-Ordner enthält **nur Dokumente**, noch keinen Spielcode und kein
  `project.godot`.

## Aufgaben

1. **Resolution-Matrix:** Prüfe für jedes Finding der ersten Review, ob es
   gelöst, teilweise gelöst oder offen ist. Belegstelle (Datei/Abschnitt/D-ID)
   angeben.
2. **Neue Widersprüche:** Zahlen, Gates, Budgets, G1a/G1b, D-57-Stubs,
   B-Vertrag, Chronik, Retention, Save/Replay.
3. **G0-Vollständigkeit:** Fehlt ein Artefakt? Ist die Review-Checkliste
   ausreichend? Ist G0 damit freigabefähig?
4. **G1a/G1b:** Ist G1a wirklich minimal? Ist G1b abnahmefähig? Was muss aus
   G1a/G1b heraus oder hinein?
5. **Budgets:** Sind die Szenarien und Per-Event-Caps plausibel? Welche Messung
   fehlt? Sind 10k@50x und 100k@10x mit GDScript realistisch?
6. **G0.5:** Ist der Spike richtig geschnitten? Sollte er einen
   Native-Vergleich (C#/GDExtension) enthalten? Was ist der minimale Spike?
7. **B-Vertrag:** Reicht er für Determinismus, Save/Replay und Chronik? Ist er
   testbar?
8. **Chronik:** Reicht das Design für 15–60 Minuten? Fehlen Onboarding, Pacing,
   Dedup, Retention oder Kausalität?
9. **G0-Go/No-Go:** Kann G0 freigegeben werden? Wenn nein, welche konkreten
   Änderungen sind vor G0 zwingend?
10. **Top-5-Risiken und drei konkrete Änderungen.**

## Prüfe besonders

- Ist G1a mit 10 Agenten, drei Needs, Arbeit, Nahrung, Inspector, Event-Log,
  Save/Load und visueller Demo noch zu groß?
- Ist G1b mit drei weiteren Needs, Soziales/Lebenszyklus, Familienbaum, Follow,
  Alerts, Story of the Day und kuratierter Chronik realistisch?
- Ist die G1a/G1b-Teilung eine echte Entlastung oder nur eine Umbenennung?
- Sind 10k@50x und 100k@10x mit den genannten Event-/Frame-Zahlen plausibel?
- Sind 50 µs/Event, 100 µs/Ankunft und 5 ms/Pfad in GDScript realistisch?
- Ist der B-Fallback ohne Kameraabhängigkeit und ohne stille Abweichung
  ausreichend definiert?
- Ist die Chronik mehr als ein Event-Log, und ist die Retention mit Save-Größe
  vereinbar?
- Ist der G0.5-Spike ohne Gameplay/UI/Save ausreichend für die
  Sprach-/Portentscheidung?
- Fehlt ein G0-Artefakt für Render-/UI-/Chronik-Abnahme?
- Ist die V3-Ordner-/Dokumentstruktur sauber und ohne Parallelwahrheit?

## Regeln

- Kein Code, keine Implementierung.
- Keine stillen neuen Features oder Balancewerte; Empfehlungen klar markieren.
- Unterscheide: **Muss vor G0**, **Sollte vor G1**, **Später**.
- Zitiere Datei/Abschnitt/D-ID.
- Keine Lobhudelei; Fokus auf Schwachstellen.
- Wenn eine Annahme nicht prüfbar ist, sag es.
- Sprache: Deutsch.

## Ausgabeformat

1. **Kurzfazit (5 Sätze)**
2. **Resolution-Matrix der ersten Review** (Finding, Status, Beleg, Restarbeit)
3. **Neue Findings** (Tabelle: Ort, Problem, Folge, Fix, Priorität)
4. **G0.5-Scope-Empfehlung** (inkl. Native ja/nein und minimaler Umfang)
5. **G1a/G1b-Bewertung**
6. **Budget-/Performance-Bewertung**
7. **Chronik-/B-Vertrag-Bewertung**
8. **Muss vor G0 / Sollte vor G1 / Später**
9. **G0-Go/No-Go mit Begründung**
