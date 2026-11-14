# V3 G4b — Spezifikation: 10k + Wirtschaft/Politik

Status: G4b-Spezifikation, Entwurf  
Stand: 2026-11-14  
Bezug: `docs/g4/v3-g4-spec.md`, `docs/v3-plan.md` D-44..D-49,
`docs/v3-fidelity.md`, `docs/g4/v3-g4a-report.md`.

## 1. Ziel

G4b ergänzt den bestandenen 10k-Kern um eine **leichte, deterministische
Wirtschafts- und Politikschicht**:

- Haushaltsbudgets, Löhne, Steuern.
- Lokale Märkte mit Preisen, Angebot/Nachfrage.
- Physische Karawanen und externe Handelsknoten.
- Regionale Nation mit Schatzkammer, Steuersatz, Budget, Diplomatie/Verträgen.
- Krisen (Knappheit, Preisspitzen, Schulden, Unruhe) als Chronik.
- Kein Krieg, keine D-57-Simulation, keine G5-Nationen-Chronik.

G4b bleibt bei **10.000 Agenten**. Die 3 Nationen/100k sind G5.

## 2. Grunddesign (bewusst leicht)

- **Nahrung bleibt G4a:** Der öffentliche Kornspeicher deckt Mahlzeiten; die
  Wirtschaft ergänzt Geld/Markt/Budget, ohne die Grundversorgung zu brechen.
- **Güter:** Grain (Nahrung), Holz (Brennstoff/Bau), Werkzeug (Produktion),
  Geld. Kein voller Warenkorb.
- **Haushalte:** Budget, Lohn aus Jobs, Steuern, Käufe (Holz/Werkzeug,
  optional Grain); tägliche Batch-Buchung, keine Transaktion pro Agent/Tick.
- **Siedlung:** Markt mit Preisen, Lager, Steuern, öffentlichem Budget
  (Kornspeicher, Wege, Wachen).
- **Nation/Region:** Schatzkammer, Steuersatz, Budgetkategorien, Diplomatie
  mit **zwei abstrakten Nachbarn**, Verträge/Handelsabkommen; kein Krieg.
- **Handel:** 2–3 externe Knoten (abstrakt) plus **physische Karawanen** auf
  den Straßen; Ladung, Ankunft, lokale Preisdifferenz, Abkommen.
- **Politik-KI:** deterministische Utility-/Regel-KI, tägliche/wöchentliche
  Entscheidungen; keine LLM.
- **Krisen:** Knappheit, Preisspitze, Überschuldung, Unruhe; Chronik-Events,
  kein Game Over.

## 3. Markt/Preise

- Siedlungsmarkt mit Lager und Preis je Gut.
- Preis reagiert auf Lager/Nachfrage (z. B. `price = base * clamp(target_stock/stock)`),
  deterministisch und gedämpft.
- Haushalte kaufen pro Tag eine kleine Menge Holz/Werkzeug; Grain bleibt
  öffentlich, optional kleiner Marktanteil.
- Keine Preisspekulation, kein Kredit, kein Finanzsektor.

## 4. Haushalte/Budget

- Haushalt hat `money`, `income`, `taxes`, `spent`, `savings`.
- Löhne aus Feld-/Werkstattjobs; Haushaltsmitglieder bündeln.
- Steuern pro Haushalt/Siedlung; öffentliches Budget.
- Keine individuellen Konten pro Tick; Tagesbatch.

## 5. Nation/Politik

- Eine Region/Nation mit Schatzkammer, Steuersatz, Budget:
  Kornspeicher, Wege, Wachen; optional Notreserve.
- Zwei abstrakte Nachbarn mit Relation, Handelsabkommen, Tribut/Geschenk;
  Verträge; kein Krieg.
- Utility-KI reagiert auf Schatzkammer, Nahrung, Unruhe, Preise.
- Drei Ressourcen-Spezialisierungen als Platzhalter (Grain/Werkzeug/Holz).

## 6. Karawanen/Handel

- 2–3 externe Knoten mit eigenen Preisen/Stock.
- Karawanen als wenige sichtbare Agenten/Vehicles auf Straßen; Ladung,
  Start/Ziel, Ankunft; deterministische Route.
- Handelsabkommen senken Zölle/erhöhen Menge; keine freie Marktwirtschaft.
- Karawanen-Events in der Chronik; keine Per-Tick-Transaktionen.

## 7. Krisen/Chronik

- Knappheit: Kornspeicher/Stock unter Schwelle.
- Preisspitze: Marktpreis über Schwelle.
- Überschuldung: Schatzkammer negativ.
- Unruhe: hohe Steuern/Preise + schlechte Needs.
- Jeweils major/notable Chronik-Events; keine erfundenen Ursachen.

## 8. Save/Schema 8

- Schema **8** für das G4b-Profil: Haushaltsbudgets, Markt, Karawanen,
  Nation/Schatzkammer/Steuern/Budget, Diplomatie, Krisen, Chronik.
- G4a-Schema 7 bleibt im G4a-Profil ladbar.
- Schema 1–7 im G4b-Profil sichtbar ablehnen.
- Replay = Re-Simulation aus Seed + Config + Snapshot.
- Save-Budgets: ≤ 40 MB, Save ≤ 3 s, Load ≤ 12 s (provisorisch).

## 9. Gate-Scope-Test-Update (D-68)

Die historischen Gate-Suiten dürfen die Existenz späterer Gates nicht
verbieten. Für G4b werden **nur** die überholten Abwesenheits-/Token-Prüfungen
für `src/economy|politics|trade|caravan` und G4b-Fachbegriffe in den
Scope-Assertions von G1b, G2, G3 und G4a entfernt oder auf das jeweilige
Profil eingegrenzt.

**Unverändert bleiben:** alle Verhaltensprüfungen T01–T09 der Alt-Gates,
D-57-Stub-Prüfungen, Schema-/Determinismus-/Performance-Checks, G4a-Schema 7
im G4a-Profil. G4b bekommt eigene Scope-Tests (kein Krieg, keine
D-57-Simulation, keine G5-Features, Schema 8). Jede geänderte Scope-Zeile
wird im G4b-Report dokumentiert.

## 9.1 Tests

- T-G4b-01 Haushaltsbudgets/Löhne/Steuern.
- T-G4b-02 Marktpreise/Angebot/Nachfrage.
- T-G4b-03 Physische Karawanen/externe Knoten.
- T-G4b-04 Nation/Schatzkammer/Steuersatz/Budget.
- T-G4b-05 Diplomatie/Verträge mit zwei Nachbarn.
- T-G4b-06 Krisen + Chronik.
- T-G4b-07 120-Tage-Determinismus, 3 Läufe.
- T-G4b-08 Save/Load Schema 8.
- T-G4b-09 10k@50x Performance, 3 Läufe.
- T-G4b-10 UI: Markt/Schatzkammer/Diplomatie/Karawanen.
- T-G4b-11 Kein Krieg, keine D-57-Simulation, keine G5-Features.
- T-G4b-12 G1a/G1b/G2/G3/G4a-Regression.

## 10. Abnahme

- 10k@50x p95 ≤ 16 ms, p99 ≤ 20 ms, 60 FPS; 3 Läufe.
- 120-Tage-Determinismus; Wirtschaftsbilanz nachvollziehbar.
- Preise/Karawanen/Steuern/Budget/Diplomatie funktionieren.
- Krisen erzeugen Chronik; kein Game Over.
- Save/Load Schema 8 exakt; Budgets; kein Leak.
- Keine Kriege/Tiere/Fantasy/D-57-Simulation/G5-Features.
- G1–G4a-Suiten unverändert grün.
- **Abbruchregel:** Bei verfehltem 10k@50x oder gebrochener G4a-Abnahme
  kein `g4b`-Tag; `g4a` bleibt Rückfall.
- Tag `g4b` nur bei vollständiger Abnahme.

## 11. Nicht-Ziele

- Keine 100k/3 Nationen (G5), keine Kriege, keine Tiere/Fantasy.
- Keine D-57-Simulation; Stubs bleiben.
- Keine B-Integration in A.
- Keine Lesezeichen/Sammlungen/Zeitleiste/Nationen-Chronik.
- Keine vollständige Finanzwirtschaft/Kredit/Börse.
