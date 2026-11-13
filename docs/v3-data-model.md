# V3-Datenmodell

Status: G0-Artefakt, Entwurf  
Stand: 2026-11-13  
Bezug: `v3-plan.md`, `v3-architecture.md`.

## 1. Grundsätze

- Stabile Integer-IDs; keine Wiederverwendung nach Tod/Löschung.
- Ein autoritativer Besitzer pro Feld; abgeleitete Daten sind markiert.
- Arrays werden nach stabiler ID sortiert; keine Dictionary-Iteration in
  Simulationslogik.
- Save enthält autoritativen Zustand, keine Caches/Indizes.
- Versioniertes Schema; inkompatible Saves werden sichtbar abgelehnt.
- JSON nur für statische Katalogdaten; dynamischer Zustand im Save.

## 2. Entitäten

### Agent

```text
id: int
name: string
sex: enum
birth_day: int
age_years: int
alive: bool
household_id: int
home_building_id: int
job_id: int
workplace_building_id: int
activity: enum
next_event_time: int
position_tile: Vector2i
position_subtile: float
needs: {hunger, energy, social, hygiene, fun}
health: int
traits: [trait_id]
relationships: [relationship_id]
inventory: [item_stack]
```

### Household

```text
id: int
settlement_id: int
home_building_id: int
member_ids: [agent_id]
shared_food: int
shared_wood: int
money: int
relationships: [relationship_id]
```

### Settlement

```text
id: int
nation_id: int
name: string
center_tile: Vector2i
population: int
building_ids: [building_id]
stockpiles: {item_id: amount}
market_id: int
treasury: int
tax_rate: float
laws: [law_id]
```

### Nation

```text
id: int
name: string
culture_id: int
capital_settlement_id: int
settlement_ids: [settlement_id]
treasury: int
tax_rate: float
budget: {category: amount}
diplomacy: {nation_id: relation}
specialization: [item_id]
```

### Building

```text
id: int
settlement_id: int
type_id: int
footprint: [tile]
owner_household_id: int
occupant_ids: [agent_id]
job_slots: [job_id]
storage: {item_id: amount, capacity: int}
production: {recipe_id, progress, workers}
```

### Job

```text
id: int
building_id: int
occupation_id: int
work_window: {start_minute, end_minute}
wage: int
required_skill: int
assigned_agent_id: int
```

### Item / Recipe / Market

```text
Item: id, name, category, nutrition, value, stack_limit
Recipe: id, inputs, outputs, labor, building_type
Market: settlement_id, prices, supply, demand, last_update
```

### TradeRoute / Caravan

```text
TradeRoute: id, from_settlement, to_settlement, path_nodes, distance
Caravan: id, route_id, cargo, owner_nation, departure_time, arrival_time
```

### Relationship

```text
id: int
type: enum (partner, parent, child, friend, rival)
a_agent_id: int
b_agent_id: int
strength: int
since_day: int
```

### Event

```text
id: int
time: int
type: enum
importance: enum (routine, notable, major, historic)
actor_ids: [agent_id]
location: {settlement_id, building_id, tile}
causes: [event_id]
template_key: string
data: dictionary
```

### Save

```text
schema_version: int
seed: int
config: dictionary
clock: int
scheduler: [...]
rng: {stream: state}
agents: [...]
agent_cold: [...]
households: [...]
settlements: [...]
nations: [...]
buildings: [...]
market: [...]
agents_dead_archive: [...]
events_recent: [...]        # notable+, Ringpuffer, budgetiert
events_summary: [...]       # Tages-/Wochen-Summaries
historic_events: [...]      # dauerhaft, budgetiert
replay_meta: {seed, config_hash, snapshot_time}
chronicle_budget: {events_recent_bytes, summaries_bytes, historic_bytes}
```

## 3. ID- und Lebenszyklusregeln

- Agent-IDs werden nie wiederverwendet.
- Tote Agenten bleiben zunächst als Record erhalten und werden nach 1 Sim-Jahr
  zu einem **DeadAgentRecord** kompaktiert (Biografie, zentrale Beziehungen,
  Todesursache/-zeit, historische Event-IDs).
- Der DeadAgentRecord ersetzt den Hot-Record; das Save wächst nicht unbegrenzt.
- Gebäude-/Job-IDs bleiben stabil; Umbau erzeugt neue IDs.
- Beziehungen referenzieren Agent-IDs; bei Tod bleibt die Beziehung als
  historischer Record.
- Haushalte können sich auflösen; Mitglieder werden neu zugeordnet.
- Ereignisse referenzieren stabile IDs; historische Ereignisse bleiben.

```text
DeadAgentRecord:
  id, name, sex, birth_day, death_day, death_cause,
  household_id, home_id, job_id,
  partner_id, parent_ids, child_ids,
  biography_summary, historic_event_ids
```

## 4. Events und Chronik

- Jedes chronikwürdige Ereignis hat `importance`, `template_key`, `causes`.
- Routine-Ereignisse (Arbeit, Essen) werden aggregiert, nicht einzeln
  gespeichert.
- **Chronik-Log** und **Debug-Log** sind getrennt. Replay nutzt weder das eine
  noch das andere, sondern **Seed + Konfiguration + Save-Snapshot**.
- Retention (provisorisch): letzte 7 Sim-Tage notable+ (max. 250k Events/25 MB),
  1 Sim-Jahr Summaries (max. 50k/10 MB), historische Events (max. 10k/5 MB).
- Die Chronik liest nur Events, Summaries und abgeleitete Biografien, nie den
  Hot-Store direkt.

## 5. Datenkataloge (JSON)

- `species.json`, `traits.json`, `cultures.json`, `names.json`
- `jobs.json`, `buildings.json`, `items.json`, `recipes.json`
- `laws.json`, `festivals.json`, `religions.json` (ab G4/G5)
- `nations.json` (3 Startnationen, Spezialisierungen)
- Jeder Katalog hat `schema_version`, `id`, `name`, `validation`.
- Prozedurale Welt nutzt Seed + Regeln; keine handautorierten Karten in V3.

## 6. Versionierung und Migration

- Save-Header: `schema_version`, `game_version`, `config_hash`.
- Unbekannte Version: sichtbar ablehnen, nicht still laden.
- Migration nur explizit und getestet; alte V1-/V2-Saves werden nicht geladen.
- Save-Größe, Ladezeit und Peak-Speicher pro Gate messen.

## 7. Offene Punkte

- Genaue Feldtypen und Packing (G0.5/G1a).
- Event-Log-Retention und Summarization (G0-Chronik).
- ID-Indirektion für tote Agenten (G1a).
- Save-Kompression und Chunk-Speicherung (G2/G4).
- Wirtschafts-/Politik-Schema (G4b/G5b).
