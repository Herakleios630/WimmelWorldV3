extends RefCounted

## G1b-Schritt 3: T-REVIEW-01.
## Prüft Doku, Dateigrenzen, Schema 5 und die Abwesenheit von G3-Features.
## G2-Module (A*/Cache) sind nach G2 ausdrücklich erlaubt.

const REPORT_PATH: String = "res://docs/g1b/v3-g1b-step3-report.md"
const README_PATH: String = "res://docs/g1b/README.md"

const NEW_FILES: Array = [
	"res://src/chronicle/chronicle_event.gd",
	"res://src/chronicle/chronicle_store.gd",
	"res://src/chronicle/chronicle_curator.gd",
	"res://src/chronicle/chronicle_io.gd",
	"res://src/chronicle/chronicle_summary.gd",
	"res://src/chronicle/story_of_day.gd",
	"res://src/chronicle/replay.gd",
	"res://src/view/alert_model.gd",
	"res://src/view/biography_model.gd",
	"res://src/view/chronicle_panel_model.gd",
	"res://src/view/chronicle_hud.gd",
	"res://src/view/family_tree_model.gd",
	"res://src/view/family_tree_view.gd",
	"res://src/view/follow_model.gd",
	"res://src/persistence/sim_save.gd",
]


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-REVIEW-01", "Review: Doku, Dateigrenzen, Schema 5, keine G3-Features")
	ctx.check(FileAccess.file_exists(REPORT_PATH), "Schritt-3-Report fehlt")
	ctx.check(FileAccess.file_exists(README_PATH), "G1b-README fehlt")
	if FileAccess.file_exists(REPORT_PATH):
		var report: String = FileAccess.get_file_as_string(REPORT_PATH)
		for term in ["Event-Taxonomie", "Importance", "Dedup", "Digest",
				"Story of the Day", "Retention", "Replay", "T-CHRON-01",
				"T-REPLAY-01", "T-REVIEW-01"]:
			ctx.check(report.contains(term), "Report-Begriff fehlt: " + term)
	if FileAccess.file_exists(README_PATH):
		var readme: String = FileAccess.get_file_as_string(README_PATH)
		ctx.check(readme.contains("Schritt 3"), "README ohne Schritt 3")
	for path in NEW_FILES:
		ctx.check(FileAccess.file_exists(path), "Datei fehlt: " + path)
		if FileAccess.file_exists(path):
			var text: String = FileAccess.get_file_as_string(path)
			var line_count: int = text.split("\n").size()
			ctx.check(line_count <= 1000, "Datei über 1000 Zeilen: %s (%d)" % [
				path, line_count])
			var lower: String = text.to_lower()
			ctx.check(not lower.contains("httprequest")
				and not lower.contains("http://") and not lower.contains("https://")
				and not lower.contains("openai") and not lower.contains("api_key"),
				"Netzwerk-Abhängigkeit in: " + path)
	ctx.check_eq(SimConfig.SCHEMA_VERSION, 5, "Config-Schema ist nicht 5")
	ctx.check_eq(SimSave.SCHEMA_VERSION, 5, "Save-Schema ist nicht 5")
	ctx.check(not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path("res://src/economy")),
		"G4-Wirtschaftsmodul vorhanden")
	ctx.check(not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path("res://src/politics")),
		"G5-Politikmodul vorhanden")
	ctx.check(FileAccess.file_exists("res://src/navigation/path_finder.gd"),
		"G2-PathFinder fehlt")
	ctx.check(FileAccess.file_exists("res://src/data/d57_stubs.gd"),
		"G2-D-57-Stubs fehlen")
	var suite_text: String = FileAccess.get_file_as_string("res://tests/g1b/g1b_suite.gd")
	for term in ["test_chronicle.gd", "test_chronicle_ui.gd",
			"test_replay.gd", "test_review.gd"]:
		ctx.check(suite_text.contains(term), "G1b-Suite lädt nicht: " + term)
