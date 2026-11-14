class_name ChronicleCurator
extends RefCounted

## Event-Taxonomie und deutsche Template-Texte.
##
## Die Kuratierung ist deterministisch und rein ableitend. Es gibt keine
## LLM-/Netzwerkabhängigkeit und keine erfundenen Ursachen: Kausalitätslinks
## entstehen nur aus bereits simulierten Events.

const CAT_LIFE: String = "leben"
const CAT_SOCIAL: String = "sozial"
const CAT_WORK: String = "arbeit"
const CAT_ECONOMY: String = "wirtschaft"
const CAT_CRISIS: String = "krise"
const CAT_TRAVEL: String = "reise"
const CAT_SYSTEM: String = "system"

const ALL_CATEGORIES: Array = [
	CAT_LIFE, CAT_SOCIAL, CAT_WORK, CAT_ECONOMY, CAT_CRISIS,
	CAT_TRAVEL, CAT_SYSTEM,
]


static func classify(event: SimEvent) -> Dictionary:
	var category: String = CAT_SYSTEM
	var importance: int = event.importance
	var template: String = event.template_key
	match event.type:
		SimEvent.T_SIM_START:
			category = CAT_SYSTEM
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "sim_start"
		SimEvent.T_DAY_START:
			category = CAT_SYSTEM
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "day_start"
		SimEvent.T_AGE_UP:
			category = CAT_LIFE
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "age_up"
		SimEvent.T_BIRTH:
			category = CAT_LIFE
			importance = SimEvent.IMPORTANCE_MAJOR
			template = "birth"
		SimEvent.T_DEATH:
			category = CAT_LIFE
			importance = SimEvent.IMPORTANCE_MAJOR
			template = "death"
		SimEvent.T_PREGNANCY:
			category = CAT_LIFE
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "pregnancy"
		SimEvent.T_PARTNER_FORMED:
			category = CAT_SOCIAL
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "partner_formed"
		SimEvent.T_SOCIAL_START, SimEvent.T_SOCIAL_END:
			category = CAT_SOCIAL
			importance = SimEvent.IMPORTANCE_ROUTINE
		SimEvent.T_HOUSEHOLD_DISSOLVED:
			category = CAT_SOCIAL
			importance = SimEvent.IMPORTANCE_MAJOR
			template = "household_dissolved"
		SimEvent.T_HOUSEHOLD_REASSIGN:
			category = CAT_SOCIAL
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "household_reassign"
		SimEvent.T_HOUSEHOLD_WARD:
			category = CAT_SOCIAL
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "household_ward"
		SimEvent.T_ROLE_CHANGE:
			category = CAT_WORK
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "role_change"
		SimEvent.T_WORK_START, SimEvent.T_WORK_END:
			category = CAT_WORK
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "work"
		SimEvent.T_NEED_INTERRUPT:
			category = CAT_WORK
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "need_interrupt"
		SimEvent.T_ACTIVITY_START, SimEvent.T_ACTIVITY_END:
			category = CAT_WORK
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "activity"
		SimEvent.T_MEAL_START, SimEvent.T_MEAL_END:
			category = CAT_WORK
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "meal"
		SimEvent.T_SLEEP_START, SimEvent.T_WAKE_UP, SimEvent.T_NAP_START, SimEvent.T_NAP_END:
			category = CAT_LIFE
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "rest"
		SimEvent.T_MEAL_SKIPPED:
			category = CAT_CRISIS
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "meal_skipped"
		SimEvent.T_SHORTAGE:
			category = CAT_CRISIS
			importance = SimEvent.IMPORTANCE_MAJOR
			template = "shortage"
		SimEvent.T_FIELD_STAGE:
			category = CAT_ECONOMY
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "field_stage"
		SimEvent.T_FIELD_SOWN:
			category = CAT_ECONOMY
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "field_sown"
		SimEvent.T_FIELD_RIPE:
			category = CAT_ECONOMY
			importance = SimEvent.IMPORTANCE_NOTABLE
			template = "field_ripe"
		SimEvent.T_FIELD_HARVEST:
			category = CAT_ECONOMY
			importance = SimEvent.IMPORTANCE_MAJOR
			template = "field_harvest"
		SimEvent.T_YEAR_SUMMARY:
			category = CAT_ECONOMY
			importance = SimEvent.IMPORTANCE_HISTORIC
			template = "year_summary"
		SimEvent.T_GRAIN_AWARD:
			category = CAT_ECONOMY
			importance = SimEvent.IMPORTANCE_ROUTINE
			template = "grain_award"
		SimEvent.T_TRAVEL_START, SimEvent.T_ARRIVE:
			category = CAT_TRAVEL
			importance = SimEvent.IMPORTANCE_ROUTINE
		SimEvent.T_SAVE, SimEvent.T_LOAD:
			category = CAT_SYSTEM
			importance = SimEvent.IMPORTANCE_ROUTINE
	if template == "":
		template = SimEvent.type_name(event.type)
	return {
		"category": category,
		"importance": importance,
		"template_key": template,
	}


static func dedup_key(event: SimEvent, meta: Dictionary) -> String:
	var day: int = event.time / SimConfig.TICKS_PER_DAY
	match event.type:
		SimEvent.T_MEAL_SKIPPED:
			return "meal_skipped:%d:%d" % [event.agent_id, day]
		SimEvent.T_SHORTAGE:
			return "shortage:%d:%d" % [event.agent_id, day]
		SimEvent.T_NEED_INTERRUPT:
			return "need_interrupt:%d:%d" % [event.agent_id, day]
		SimEvent.T_AGE_UP:
			return "age_up:%d:%d" % [event.agent_id, day]
	return ""


static func related_agent_ids(event: SimEvent) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	match event.type:
		SimEvent.T_PARTNER_FORMED:
			if event.data > 0:
				out.append(event.data)
		SimEvent.T_BIRTH:
			if event.data > 0:
				out.append(event.data)
		SimEvent.T_PREGNANCY:
			if event.data > 0:
				out.append(event.data)
	return out


static func text_for(event: SimEvent, sim: Simulation) -> String:
	var who: String = _name(sim, event.agent_id)
	match event.type:
		SimEvent.T_BIRTH:
			return "Geburt von %s" % who
		SimEvent.T_DEATH:
			return "%s stirbt (%s)" % [who, LifecycleRules.cause_name(event.data)]
		SimEvent.T_PREGNANCY:
			return "%s ist schwanger" % who
		SimEvent.T_PARTNER_FORMED:
			return "%s und %s werden ein Paar" % [who, _name(sim, event.data)]
		SimEvent.T_ROLE_CHANGE:
			return "%s: Rollenwechsel zu %s" % [who, AgentStore.role_name(event.data)]
		SimEvent.T_FIELD_STAGE:
			return "Feld: %s" % event.text
		SimEvent.T_FIELD_HARVEST:
			return "Ernte: %d Grain eingelagert" % event.data
		SimEvent.T_SHORTAGE:
			return "%s: Nahrungsknappheit" % who
		SimEvent.T_MEAL_SKIPPED:
			return "%s erhält keine Mahlzeit" % who
		SimEvent.T_HOUSEHOLD_DISSOLVED:
			return "Haushalt %d aufgelöst" % event.data
		SimEvent.T_HOUSEHOLD_REASSIGN:
			return "%s zieht in Haushalt %d" % [who, event.data]
		SimEvent.T_HOUSEHOLD_WARD:
			return "%s hat keinen Haushalt" % who
		SimEvent.T_NEED_INTERRUPT:
			return "%s: %s" % [who, event.text]
		SimEvent.T_AGE_UP:
			return "%s wird %d" % [who, event.data]
		SimEvent.T_YEAR_SUMMARY:
			return event.text
	if event.text != "":
		return event.text
	return event.template_key


static func _name(sim: Simulation, agent_id: int) -> String:
	if agent_id <= 0:
		return "Weiler"
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, agent_id)
	return rec.name if rec != null else ("A%d" % agent_id)
