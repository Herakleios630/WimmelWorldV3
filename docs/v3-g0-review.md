# V3 G0 — Review-Checkliste und Freigabe

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, `reviews/v3-review-2026-11-13.md`.

## 1. Zweck

G0 ist bestanden, wenn alle Artefakte vollständig, konsistent und prüfbar sind.
Kein Code vor G0-Freigabe. G0.5 ist der erste, eng begrenzte Technikspike.

## 2. Artefakte und Kriterien

| Artefakt | Datei | Muss enthalten | Status |
|---|---|---|---|
| Master-Plan | `v3-plan.md` | Entscheidungen, Gates, Budgets, Links, Status | Entwurf |
| G1-Spezifikation | `v3-g1-spec.md` | G1a/G1b, Welt, Agenten, Needs, Lifecycle, UI, Save, Abnahme | Entwurf |
| Architektur | `v3-architecture.md` | Schichten, Ownership, Determinismus, Threading, Grenzen | Entwurf |
| Datenmodell | `v3-data-model.md` | Entitäten, IDs, Events, Save, Retention, JSON | Entwurf |
| Benchmark | `v3-benchmark.md` | Hardware, 3 Läufe, Szenarien, Budgets, Render/Save/Determinismus | Entwurf |
| Chronik | `v3-chronicle.md` | Taxonomie, Importance, Dedup, Digest, Onboarding, Pacing, Retention | Entwurf |
| Fidelity | `v3-fidelity.md` | A/B-Vertrag, preserved/approx, Tests, Freigabe | Entwurf |
| Risiko-Register | `v3-risk-register.md` | Top-Risiken, Auslöser, Gegenmaßnahmen, Kadenz | Entwurf |
| G0.5-Spike | `v3-g0.5-spike.md` | Fragen, Szenarien, Messwerte, Exit | Entwurf |
| Projektstruktur | `v3-project-structure.md` | Repo, Toolchain, Tests, Bench, Git | Entwurf |
| G1-Arbeitspakete | `v3-g1-workpackages.md` | WPs, Test-IDs, Gate-Zuordnung | Entwurf |
| Review | `reviews/v3-review-2026-11-13.md` | Externe Findings, Bewertung, Konsequenzen | eingearbeitet |

## 3. Konsistenzprüfung

- [x] D-07/D-17: 100k@10x Pflicht, 100k@50x Stretch.
- [x] D-10/D-14: 19–20 px Figuren, 1,5 m/Tile, 16 px/Tile.
- [x] D-28/W3a/W3b: sechs Needs, G1a/G1b formal.
- [x] G1a/G1b: alle Tools in W9a/W9b und in der Abnahme.
- [x] D-50/D-55: Nutztiere G5, Wildtiere nach G5.
- [x] D-57: G2/G3 nur Stubs, echte Systeme G4/G5.
- [x] G0.5, G1a/G1b, G4a/G4b, G5a/G5b in Master und Benchmark.
- [x] B-Vertrag definiert; kein stiller Fallback.
- [x] Budgetmatrix pro Szenario/Event-Typ.
- [x] Chronik-Design und Retention vorhanden.
- [x] Replay = Seed + Konfiguration + Snapshot, nicht Event-Log.
- [x] Retention mit numerischem Event-/Byte-Budget.
- [x] G0.5-Native-Vergleich verpflichtend; D-20 konsistent.
- [x] G1a auf Waypoint/einfachen Speicher/kein Replay reduziert.
- [x] Arbeitspakete mit Test-IDs vorhanden.
- [x] Kein Widerspruch zwischen Master, G1-Spec, Architektur und Benchmark
  (finale Querprüfung nach N1–N26 bestanden).

**Hinweis:** Die Häkchen bedeuten „im Dokument nachgebessert“, nicht
„G0 bestanden“. Die finale Querprüfung und Nutzerfreigabe stehen aus.

## 4. Prüfragen

1. Ist jede Entscheidung **final**, **provisional** oder **offen** markiert?
2. Hat jedes Gate eine vollständige, messbare Abnahme?
3. Ist G1a ohne G1b klar abgrenzbar und nicht „PARTIAL“?
4. Sind Event-, Pfad-, Render-, Save- und Chronik-Budgets prüfbar?
5. Ist der B-Fallback ohne Kameraabhängigkeit und ohne stille Abweichung?
6. Ist die Chronik mehr als ein Event-Log?
7. Ist der Plan frei von V1-/V2-Code und Parallelwahrheit?
8. Sind die größten Risiken mit Auslösern und Gegenmaßnahmen hinterlegt?
9. Ist G0.5 ohne Gameplay und mit klaren Exit-Kriterien definiert?
10. Ist der nächste Schritt eindeutig: G0.5, nicht G1?

## 5. Freigabe

**G0-Go:** wenn alle Artefakte vorhanden, konsistent und reviewt sind.  
**G0.5-Go:** nach G0-Go; Technikspike gemäß `v3-g0.5-spike.md`.  
**G1a-Go:** erst nach G0.5-Exit und Sprach-/Budgetentscheidung.

| Rolle | Name | Datum | Ergebnis |
|---|---|---|---|
| Nutzer | — | 2026-11-13 | **G0-Go bestätigt** |
| PM/Review | Kilo | 2026-11-13 | Finale Querprüfung bestanden; G0-Go empfohlen |

## 6. Offene Punkte vor G0-Go

- [x] N1: D-Log, §3.1 und D-10 auf den korrigierten Stand bringen.
- [x] N2: Status final/provisional/offen durchgängig führen.
- [x] N3: G0-Status vereinheitlichen; keine Selbstzertifizierung.
- [x] N4: Arbeitspaket-Artefakt mit Test-IDs anlegen.
- [x] N5/N6: G1b-Demografie und Sterbetafel konsistent machen.
- [x] N7/N8/N19: Replay-Quelle, Retention und Dead-Agent-Archiv definieren.
- [x] N9: B-Vertrag kausal konsistent und testbar neu fassen.
- [x] N10/N11: D-20 vs. G0.5-Portentscheidung klären; Native verpflichtend.
- [x] N12/N14: Sim-Zeit-Matrix, Pfad-/Frame- und Burst-Budgets.
- [x] N13/N15/N18: quantitative Chronik-/UI-DoD, Fokus, Gate-Zuordnung.
- [x] N16/N17/N21: G1a-Scope, Rollen-Schedules, Haushalt/Fertilität.
- [x] N20/N23/N24/N25/N26: Dedup-Ursache, Stub-Definition, Docs-Verweise,
  Gate-Wording, R5-Status.
- [x] Finale Querprüfung aller Dokumente (Zahlen, Pfade, Test-IDs).
- [ ] Budgets als provisional bestätigen; G0.5-Kalibrierung akzeptieren.
- [ ] Nutzerfreigabe für G0.

## 7. Review-Ergebnis 2026-11-13

- **Runde 1:** Strukturelle Findings und fehlender Machbarkeitsnachweis.
- **Runde 2:** Die Struktur war überarbeitet, aber G0 war **nicht
  freigabefähig**.
- **Nacharbeit:** N1–N26 sind eingearbeitet; die frühere
  Selbstzertifizierung ist zurückgenommen.
- **Finale Querprüfung:** Zahlen, Pfade, Gate-Namen und Test-IDs sind
  konsistent; die verbliebenen Budgets sind bewusst provisional und werden in
  G0.5/G2 kalibriert.
- **Empfehlung:** **G0-Go** für die Nutzerfreigabe. Danach G0.5 starten.
- **Vorbehalt:** G0.5 muss die provisional Budgets bestätigen oder korrigieren;
  G1a/G1b-Test-IDs sind Entwürfe bis zum jeweiligen Gate.
