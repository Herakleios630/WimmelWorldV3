extends RefCounted

## T-G3-02: 120-Tage-Kalender, 4x30-Tage-Seasons; G1/G2 bleiben 30-Tage-Jahr.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-02", "120-Tage-Jahr, 4x30 Seasons, historische Profile unverändert")
	var c: SimConfig = SimConfig.g3(1337)
	ctx.check_eq(c.year_days, 120, "Jahreslänge")
	ctx.check_eq(c.season_days, 30, "Season-Länge")
	ctx.check_eq(SimConfig.SEASONS, 4, "Season-Anzahl")
	ctx.check(c.seasonal_fields, "seasonal_fields aus")
	ctx.check_eq(c.season_index_for_day(0), 0, "Tag 1 nicht Frühling")
	ctx.check_eq(c.season_index_for_day(29), 0, "Tag 30 nicht Frühling")
	ctx.check_eq(c.season_index_for_day(30), 1, "Tag 31 nicht Sommer")
	ctx.check_eq(c.season_index_for_day(59), 1, "Tag 60 nicht Sommer")
	ctx.check_eq(c.season_index_for_day(60), 2, "Tag 61 nicht Herbst")
	ctx.check_eq(c.season_index_for_day(89), 2, "Tag 90 nicht Herbst")
	ctx.check_eq(c.season_index_for_day(90), 3, "Tag 91 nicht Winter")
	ctx.check_eq(c.season_index_for_day(119), 3, "Tag 120 nicht Winter")
	ctx.check_eq(c.season_index_for_day(120), 0, "Tag 121 nicht Frühling")
	ctx.check_eq(c.season_name_for_day(0), "Frühling", "Season-Name 1")
	ctx.check_eq(c.season_name_for_day(60), "Herbst", "Season-Name 2")
	ctx.check_eq(c.autumn_start_day(0), 60, "Herbststart Tag 1")
	ctx.check_eq(c.autumn_start_day(60), 60, "Herbststart Tag 61")
	ctx.check_eq(c.autumn_start_day(119), 60, "Herbststart Tag 120")
	ctx.check_eq(c.autumn_start_day(120), 180, "Herbststart Jahr 2")
	ctx.check_eq(c.next_year_start_day(120), 240, "Jahreswechsel")
	ctx.check_eq(c.year_of_day(119), 0, "Jahr 0")
	ctx.check_eq(c.year_of_day(120), 1, "Jahr 1")
	# G1/G2 bleiben beim 30-Tage-Jahr und ganzjährigen Feldzyklus.
	var g1: SimConfig = SimConfig.new()
	var g2: SimConfig = SimConfig.g2(1337)
	ctx.check_eq(g1.year_days, 30, "G1-Jahr verändert")
	ctx.check_eq(g2.year_days, 30, "G2-Jahr verändert")
	ctx.check(not g1.seasonal_fields and not g2.seasonal_fields,
		"G1/G2 versehentlich saisonal")
	ctx.check_eq(g1.save_schema_version(), 5, "G1-Schema verändert")
	ctx.check_eq(g2.save_schema_version(), 5, "G2-Schema verändert")
	ctx.check_eq(c.save_schema_version(), 6, "G3-Schema nicht 6")
	ctx.check_eq(SimConfig.G3_SCHEMA_VERSION, 6, "G3-Schema-Konstante")
