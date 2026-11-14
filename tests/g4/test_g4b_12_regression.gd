extends RefCounted

## T-G4b-12: G1a/G1b/G2/G3/G4a-Regression. Die kurzen Referenzläufe sind vor
## der G4b-Implementierung eingefroren; die vollständigen Alt-Suiten werden
## zusätzlich extern ausgeführt und im G4b-Report dokumentiert.

const G1_STATE: int = 0xED89E8C5
const G1_EVENT: int = 0x81EB3DE4
const G1_CHRONICLE: int = 0x2DD7F835
const G2_STATE: int = 0x465B30E9
const G2_EVENT: int = 0x7E05F14A
const G2_CHRONICLE: int = 0x3E8117B7
const G3_STATE: int = 0x81FAADA0
const G3_EVENT: int = 0x56070A4E
const G3_CHRONICLE: int = 0xA8C576AC
const G4A_STATE: int = 0xD55A9EA9
const G4A_EVENT: int = 0xE1775912
const G4A_CHRONICLE: int = 0xBD28E5A2


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-12", "G1a/G1b/G2/G3/G4a-Regression")
	_check(ctx, "G1", SimConfig.new(), 10, G1_STATE, G1_EVENT, G1_CHRONICLE, 10)
	_check(ctx, "G2", SimConfig.g2(1337), 30, G2_STATE, G2_EVENT,
		G2_CHRONICLE, 104)
	_check(ctx, "G3", SimConfig.g3(1337), 30, G3_STATE, G3_EVENT,
		G3_CHRONICLE, 991)
	_check(ctx, "G4A", SimConfig.scale(1337), 20, G4A_STATE, G4A_EVENT,
		G4A_CHRONICLE, 9976)
	for path in ["res://tests/g1a/g1a_suite.tscn",
			"res://tests/g1b/g1b_suite.tscn",
			"res://tests/g2/g2_suite.tscn",
			"res://tests/g3/g3_a_suite.tscn",
			"res://tests/g4/g4_a_suite.tscn"]:
		ctx.check(FileAccess.file_exists(path), "Regression-Suite fehlt: %s" % path)
	ctx.check_eq(SimConfig.scale(1337).save_schema_version(), 7,
		"G4a-Profil-Schema verändert")
	ctx.check_eq(SimConfig.g3(1337).save_schema_version(), 6,
		"G3-Profil-Schema verändert")
	ctx.check_eq(SimConfig.new().save_schema_version(), 5,
		"historisches Profil-Schema verändert")


static func _check(ctx: G1aTestContext, label: String, config: SimConfig,
		days: int, expected_state: int, expected_event: int,
		expected_chronicle: int, expected_alive: int) -> void:
	var sim: Simulation = Simulation.create(config)
	var target: int = sim.clock.now + days * SimConfig.TICKS_PER_DAY
	G4BTestUtil.advance_chunked(sim, target, 3600)
	print("G4B_REGRESSION %s state=%s event=%s chronicle=%s alive=%d" % [
		label, HashUtil.hex(sim.state_hash()), HashUtil.hex(sim.event_hash()),
		HashUtil.hex(sim.curated_chronicle_hash()), sim.count_alive()])
	ctx.check_eq(sim.state_hash(), expected_state, label + " State verändert")
	ctx.check_eq(sim.event_hash(), expected_event, label + " Event verändert")
	ctx.check_eq(sim.curated_chronicle_hash(), expected_chronicle,
		label + " Chronik verändert")
	ctx.check_eq(sim.count_alive(), expected_alive, label + " Bevölkerung verändert")
