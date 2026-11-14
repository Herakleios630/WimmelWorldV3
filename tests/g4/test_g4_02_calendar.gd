extends RefCounted

## T-G4a-02: 120-Tage-Jahr, 4x30 Seasons, saisonale Feldfenster.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-02", "120-Tage-Kalender, 4x30 Seasons, Feldfenster")
	var c: SimConfig = SimConfig.scale(1337)
	ctx.check_eq(c.year_days, 120, "Jahreslänge")
	ctx.check_eq(c.season_days, 30, "Season-Länge")
	ctx.check_eq(SimConfig.SEASONS, 4, "Season-Anzahl")
	ctx.check(c.seasonal_fields, "saisonale Felder aus")
	ctx.check_eq(c.season_index_for_day(0), 0, "Tag 0 nicht Frühling")
	ctx.check_eq(c.season_index_for_day(29), 0, "Tag 29 nicht Frühling")
	ctx.check_eq(c.season_index_for_day(30), 1, "Tag 30 nicht Sommer")
	ctx.check_eq(c.season_index_for_day(60), 2, "Tag 60 nicht Herbst")
	ctx.check_eq(c.season_index_for_day(90), 3, "Tag 90 nicht Winter")
	ctx.check_eq(c.season_index_for_day(119), 3, "Tag 119 nicht Winter")
	ctx.check_eq(c.season_index_for_day(120), 0, "Tag 120 nicht neues Jahr")
	ctx.check(c.is_spring_day(0) and not c.is_spring_day(30), "Frühlingsfenster")
	ctx.check(c.is_autumn_day(60) and c.is_autumn_day(89),
		"Herbstfenster")
	ctx.check(not c.is_autumn_day(59) and not c.is_autumn_day(90),
		"Herbstfenster zu breit")
	ctx.check_eq(c.year_of_day(0), 0, "Jahr 0")
	ctx.check_eq(c.year_of_day(119), 0, "Jahr 0 bei Tag 119")
	ctx.check_eq(c.year_of_day(120), 1, "Jahr 1 bei Tag 120")
	ctx.check_eq(c.autumn_start_day(0), 60, "Herbststart")
	ctx.check_eq(c.autumn_start_day(59), 60, "Herbststart Tag 59")
	ctx.check_eq(c.autumn_start_day(60), 60, "Herbststart am Herbstbeginn")
	ctx.check_eq(c.next_year_start_day(0), 120, "nächster Jahresstart")
	# Historische Profile bleiben unverändert.
	var g3: SimConfig = SimConfig.g3(1337)
	ctx.check_eq(g3.year_days, 120, "G3-Kalender verändert")
	ctx.check_eq(SimConfig.YEAR_DAYS, 30, "historisches Jahr verändert")
	ctx.check_eq(SimConfig.SEASON_DAYS, 30, "historische Season verändert")
