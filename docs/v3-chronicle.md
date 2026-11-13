# V3-Chronik-Design

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, D-33, D-37, D-38, D-39, D-41, D-42, D-43, D-61.

## 1. Produktziel

V3 ist ein **Beobachter-/Chronik-Spiel**. Der Spieler greift nicht ein. Der
Wert entsteht aus lesbaren, erinnerbaren Geschichten: Biografien, Familien,
Siedlungshistorie, Wirtschafts- und Politikkrisen. Die Chronik ist kein
nachträgliches UI-Feature, sondern Teil des Simulationsdesigns.

## 2. Ebenen

- **Individuum:** Leben, Bedürfnisse, Arbeit, Beziehungen, Gesundheit, Tod.
- **Familie/Haushalt:** Partnerschaft, Kinder, Wohnen, Budget, Konflikte.
- **Siedlung:** Ernte, Knappheit, Bauwerke, Feste, Recht, Krisen.
- **Nation:** Steuern, Budget, Diplomatie, Verträge, Handel (ab G5).
- **Welt:** spätere Erweiterungen; in V3 nur Ferne/Lore.

## 3. Event-Taxonomie

| Kategorie | Beispiele | Standard-Wichtigkeit |
|---|---|---|
| Leben | Geburt, Tod, Krankheit, Genesung | notable/major |
| Sozial | Partnerschaft, Ehe, Freundschaft, Streit, Trennung | notable |
| Arbeit | Jobwechsel, Ausbildung, Beförderung, Arbeitslosigkeit | routine/notable |
| Wirtschaft | Ernte, Knappheit, Preisänderung, Karawane, Baubeginn | notable/major |
| Politik | Steueränderung, Vertrag, Bündnis, Grenzstreit | notable/major |
| Krise | Hunger, Seuche, Unruhe, Verschuldung | major/historic |
| Wetter | Sturm, Dürre, Frost, gute Ernte | routine/notable |
| Feste | Markttag, Hochzeit, Begräbnis, Saisonfest | routine/notable |
| Reise | Aufbruch, Ankunft, Blockade | routine/notable |

## 4. Importance-Stufen

- **routine:** alltäglich, wird aggregiert; nicht einzeln in der Chronik.
- **notable:** persönlich relevant; im Inspector/Biografie sichtbar.
- **major:** Familie/Siedlung betreffend; Alert und Chronik.
- **historic:** dauerhaft; Nation/Chronik, nie automatisch gelöscht.

## 5. Event-Record

Jedes chronikwürdige Event hat:

```text
id, time, type, importance,
actor_ids, location,
causes: [event_id],
template_key,
data,
related_ids
```

`template_key` verweist auf einen deutschen Textbaustein; `data` liefert die
Einsetzwerte. Keine LLM-Abhängigkeit.

## 6. Deduplizierung und Aggregation

- Wiederholte Routineereignisse werden zu Zeitfenstern zusammengefasst
  (z. B. „arbeitete 5 Tage auf dem Feld“).
- Wiederholte Hungertage werden zu einer Krise aggregiert.
- Mehrere Todesfälle im selben Zeitfenster werden **nur dann** zu
  „Seuche“/„Unglück“ zusammengeführt, wenn eine simulierte Ursache existiert.
  Sonst wird neutral formuliert („mehrere Todesfälle“).
- Aggregation ist deterministisch und versioniert.
- Routine-Events werden an der Quelle aggregiert und nie einzeln gespeichert;
  ein separates Debug-Log ist nicht die Chronik-Quelle.

## 7. Kuratierung

- **Story of the Day:** Auswahl aus major/historic plus einer persönlichen
  notable-Geschichte; deterministisch nach Wichtigkeit und Abwechslung. Der
  Beobachtungsfokus ist **reiner View-Input** und verändert keine
  Chronik-Events; bei festem Fokuspfad ist die Auswahl deterministisch.
- **Tagesdigest:** 3–7 Zeilen; keine Event-Flut.
- **Ruhephasen:** Tage ohne major-Events bleiben ruhig; keine künstlichen
  Alerts.
- **Krisen-Arcs:** Knappheit → Preise → Haushalte → Hunger → Tod; als
  zusammenhängende Kette verknüpft.
- **Causal Links:** „Warum?“ verweist auf Ursachen-Events (Ernte, Preis,
  Politik, Beziehung).

## 8. UI und Interaktion

- **Inspector:** Agent, Needs, Gesundheit, Home, Job, Beziehungen, Biografie.
- **Event-Log:** Filter nach Agent/Familie/Siedlung/Nation, Kategorie,
  Wichtigkeit, Zeitraum.
- **Familienbaum:** Partner, Eltern, Kinder; einfache Grafik.
- **Follow:** Kamera folgt einem Agenten; Inspector bleibt sichtbar.
- **Alerts:** nur major/historic; keine Dauerflut.
- **Zeitleiste:** Siedlungs-/Familienhistorie; kein Rewind in V3.
- **Lesezeichen:** Agenten/Familien/Siedlungen merken.
- **Sammlungen:** bemerkenswerte Leben, lange Ehen, Überlebende, Aufsteiger.

**Gate-Zuordnung:**

- **G1b:** Inspector, Event-Log, Familienbaum, Follow, Alerts, Story of the
  Day, Basis-Biografie.
- **G2:** Filter, Lesezeichen, Tagesdigest-Feinschliff.
- **G3:** Zeitleiste, Sammlungen, erweiterte Biografien.
- **G5:** Nationen-Chronik, Diplomatie-/Handelschronik.

## 9. Onboarding

- Start mit einer **Featured Family** (H1) und einem kurzen „Was du siehst“.
- Erste Follow-Vorschläge: Haushalt, Kinder, Elder.
- Erste Alerts: Geburt, Tod, Partnerschaft, erste Ernte.
- Kein Tutorial-Textblock; die Chronik erklärt durch Ereignisse.

## 10. Pacing

- Alerts haben Priorität, Cooldown und Relevanzfilter.
- Nach einem major-Event mindestens eine ruhige Phase, außer es ist eine Krise.
- Jahreszeiten/Feste strukturieren das Jahr.
- Lange Sessions (1 Jahr bei 50x = 9 min) brauchen einen Tagesdigest, keine
  Echtzeit-Eventflut.

## 11. Retention und Speicher

**Provisorische Budgets (G0.5/G2 kalibrieren):**

- **Ringpuffer:** letzte **7 Sim-Tage**, nur notable+, max. **250k Events /
  25 MB** bei 100k Agenten.
- **Mittel:** Tages-/Wochen-Summaries für **1 Sim-Jahr**, max. **50k
  Summaries / 10 MB**.
- **Alt:** historische Ereignisse dauerhaft, max. **10k Events / 5 MB**.
- **Routine:** wird an der Quelle aggregiert, nie einzeln gespeichert.
- **Tote Agenten:** nach 1 Sim-Jahr zu einem kompakten Biografie-Record
  archiviert; nicht unbegrenzt im Hot-Save.
- Biografien werden aus Events verdichtet, nicht als Rohlog gespeichert.
- Retention-/Save-Budget in G0.5/G2 messen; bei Überschreitung ältere
  Einträge früher aggregieren.

## 12. Text und Sprache

- Deutsch, Template-Texte, keine LLM-Abhängigkeit.
- Platzhalter: Name, Ort, Beruf, Beziehung, Zahl, Jahreszeit.
- Ton: schlicht, beobachtend, nicht melodramatisch.
- Keine erfundenen Fakten; jede Aussage muss aus Event-Daten ableitbar sein.

## 13. Abnahme

- Ein G1b-Lauf erzeugt eine lesbare Chronik ohne manuelles Eingreifen.
- **Quantitativ:** ≤ 20 Alerts/Tag, ≤ 7 Story-of-the-Day-Einträge/Tag,
  Dedup-Ratio > 80 %, mindestens 3 notable Ereignisse/Tag, keine
  Routine-Event-Flut.
- Story of the Day ist bei festem Fokuspfad deterministisch und nicht
  redundant.
- **Fokusunabhängigkeit:** Unterschiedliche Kamera-/Fokuspfade verändern die
  zugrunde liegenden Chronik-Events nicht; nur der Tagesdigest darf abweichen.
- Familienbaum und Follow funktionieren ohne Simulationsmutation.
- Kausalitätslinks sind vorhanden.
- Event-Log/Retention bleibt im Budget.
- Keine LLM-/Netzwerkabhängigkeit.
