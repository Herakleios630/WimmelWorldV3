class_name FamilyTreeModel
extends RefCounted

## Familienbaum-Modell: Eltern/Kind-Kanten, Partner-Kanten, Generationen.
## Tote Agenten bleiben als historische Knoten enthalten. Read-only.


static func build(sim: Simulation) -> Dictionary:
	var nodes: Array = []
	var by_id: Dictionary = {}
	for record in sim.records:
		var rec: AgentRecord = record
		var row: int = sim.store.row_for_id(rec.id)
		var alive: bool = row >= 0 and sim.store.alive[row] != 0
		var node: Dictionary = {
			"id": rec.id,
			"name": rec.name,
			"sex": rec.sex,
			"birth_day": rec.birth_day,
			"death_day": rec.death_day,
			"death_cause": rec.death_cause,
			"alive": alive,
			"household_id": rec.household_id,
			"generation": 0,
		}
		nodes.append(node)
		by_id[rec.id] = node
	var parent_edges: Array = []
	var partner_edges: Array = []
	var edge_keys: Dictionary = {}
	var parent_map: Dictionary = {}
	for relationship in sim.relationships:
		var rel: RelationshipRecord = relationship
		if rel.type == RelationshipRecord.TYPE_PARENT:
			if not by_id.has(rel.a_agent_id) or not by_id.has(rel.b_agent_id):
				continue
			var key: String = "p:%d:%d" % [rel.a_agent_id, rel.b_agent_id]
			if edge_keys.has(key):
				continue
			edge_keys[key] = true
			parent_edges.append({"type": "parent", "a": rel.a_agent_id,
				"b": rel.b_agent_id})
			if not parent_map.has(rel.b_agent_id):
				parent_map[rel.b_agent_id] = PackedInt32Array()
			var parents: PackedInt32Array = parent_map[rel.b_agent_id]
			parents.append(rel.a_agent_id)
			parent_map[rel.b_agent_id] = parents
		elif rel.type == RelationshipRecord.TYPE_PARTNER:
			var a: int = mini(rel.a_agent_id, rel.b_agent_id)
			var b: int = maxi(rel.a_agent_id, rel.b_agent_id)
			var pkey: String = "r:%d:%d" % [a, b]
			if edge_keys.has(pkey):
				continue
			edge_keys[pkey] = true
			partner_edges.append({"type": "partner", "a": a, "b": b})
	var cache: Dictionary = {}
	var visiting: Dictionary = {}
	var max_generation: int = 0
	for node in nodes:
		var generation: int = _generation(int(node["id"]), parent_map, cache, visiting)
		node["generation"] = generation
		max_generation = maxi(max_generation, generation)
	var generations: Array = []
	for i in max_generation + 1:
		generations.append([])
	for node in nodes:
		(generations[int(node["generation"])] as Array).append(node)
	for generation_nodes in generations:
		(generation_nodes as Array).sort_custom(func(a, b):
			return int(a["id"]) < int(b["id"]))
	parent_edges.sort_custom(func(a, b):
		if int(a["a"]) != int(b["a"]):
			return int(a["a"]) < int(b["a"])
		return int(a["b"]) < int(b["b"]))
	partner_edges.sort_custom(func(a, b):
		if int(a["a"]) != int(b["a"]):
			return int(a["a"]) < int(b["a"])
		return int(a["b"]) < int(b["b"]))
	return {
		"nodes": nodes,
		"by_id": by_id,
		"parent_edges": parent_edges,
		"partner_edges": partner_edges,
		"generations": generations,
		"generation_count": max_generation + 1,
		"dead_count": _dead_count(nodes),
	}


static func _generation(agent_id: int, parent_map: Dictionary, cache: Dictionary,
		visiting: Dictionary) -> int:
	if cache.has(agent_id):
		return int(cache[agent_id])
	if visiting.has(agent_id):
		return 0
	visiting[agent_id] = true
	var generation: int = 0
	if parent_map.has(agent_id):
		for parent in parent_map[agent_id]:
			generation = maxi(generation,
				_generation(int(parent), parent_map, cache, visiting) + 1)
	visiting.erase(agent_id)
	cache[agent_id] = generation
	return generation


static func _dead_count(nodes: Array) -> int:
	var n: int = 0
	for node in nodes:
		if not bool(node["alive"]):
			n += 1
	return n
