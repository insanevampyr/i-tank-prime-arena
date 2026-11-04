extends RefCounted

const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")
const SOURCE := "res://docs/audits/TASK_37C_VERIFIED_SOURCE_CATALOG.json"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> Array[String]:
	# This fixture was frozen before Phase 1, extracted by pdfplumber, visually
	# reviewed and independently compared with fresh PDF text. Never build expected
	# results from the engine tables. Verify its original checksum before use.
	var text := FileAccess.get_file_as_string(SOURCE)
	var checksum := FileAccess.get_file_as_string(SOURCE.replace(".json",".sha256")).split(" ")[0]
	check(not text.is_empty() and text.sha256_text() == checksum,"Independent audit fixture checksum must validate.")
	if text.is_empty() or text.sha256_text() != checksum: return failures
	var fixture: Dictionary = JSON.parse_string(text)
	var sim := CombatSimulation.new(37)
	sim.register_actor(PrimeV3VerticalSliceFixture.make_player_actor(&"vaelis_thorn"))
	var before := sim.get_state_snapshot()
	var draws := sim.random.get_draw_count()
	var comparisons := 0
	var scalar_checks := 0
	var primary_names := {"STR":"Strength","END":"Endurance","SPD":"Speed","DEX":"Dexterity","WIS":"Wisdom","INT":"Intelligence","WIT":"Wits","MAN":"Mannerisms","LUK":"Luck","APP":"Appearance"}
	for mode: String in ["mana","regular"]:
		for row: Dictionary in fixture.charts[mode]:
			for primary: String in row.cells:
				var result := Rules.lookup(primary,int(row.score),mode)
				if not result.success:
					check(false,"Verified integer score unexpectedly rejected: %s %s %s" % [primary,row.score,mode])
					continue
				var raw: String = row.cells[primary]
				check(result.success and result.printed_cell.replace(" ","") == raw.replace(" ","").replace("\n",""),"Printed cell differs: %s %s %s" % [mode,row.score,primary])
				# Owner-corrected manuscript numbering; frozen extraction metadata is historical.
				var pages: Array = [51,52] if mode == "mana" else [53,54]
				check(result.printed_page == pages[0 if int(row.score) <= 20 else 1] and not result.grants_eligibility and not result.entitlements_granted,"Lookup must use corrected printed pages and grant nothing.")
				comparisons += 1
				var ids: Variant = fixture.component_order[primary]
				if ids is Dictionary: ids = ids[mode]
				var tokens := raw.replace("ACC = ","").replace("\n","").replace(" ","").replace("+","-").split("-")
				for i in range(ids.size()):
					var actual: Dictionary = result.values[ids[i]]
					if raw == "DEAD": check(actual == {"kind":"dead"},"DEAD must not become zero or trigger actor death.")
					elif tokens[i] == "*": check(actual == {"kind":"unlimited"},"Unlimited must not become a guessed numeric cap.")
					else: check(actual == {"kind":"integer","value":int(tokens[i])},"Source component differs: %s %s %s %s" % [mode,row.score,primary,ids[i]])
					scalar_checks += 1
				if primary == "DEX": check(result.values.DT.kind == "allocation_required" and result.values.DP.kind == "allocation_required","DEX chart cannot fabricate a Dodge split.")
	for primary: String in fixture.derived_catalog:
		check(Rules.primary_descriptor(primary).name == primary_names[primary],"Exact primary terminology must match V3.")
		for mode: String in ["mana","regular"]:
			var described := Rules.derived_descriptors(primary,mode)
			var expected_ids: Array[String] = []
			for term: Dictionary in fixture.derived_catalog[primary].derived:
				if mode == "regular" and term.abbreviation in ["MR/H","MNS"]: continue
				if mode == "mana" and term.abbreviation == "MRF": continue
				expected_ids.append(term.abbreviation)
			check(described.entries.size() == expected_ids.size(),"No derived descriptor may be omitted or invented for this mode.")
			for entry: Dictionary in described.entries:
				check(expected_ids.has(entry.abbreviation),"Inapplicable derived descriptor.")
				var expected := ""
				for term: Dictionary in fixture.derived_catalog[primary].derived:
					if term.abbreviation == entry.abbreviation: expected = term.printed_name
				check(entry.name == expected and entry.governing_primary == primary,"Exact derived name/dependency mismatch: "+entry.abbreviation)
				if entry.abbreviation == "RCL": check(entry.definition_page == 22,"RCL definition continues on printed p.22.")
			for score in range(36):
				check(Rules.lookup(primary,score,mode).success,"Every verified score must be queryable without granting eligibility.")
			for invalid: Variant in [-1,36,100,1.5,"9",true,null]:
				check(not Rules.lookup(primary,invalid,mode).success,"Unsupported score/type must fail closed.")
	for score in range(36):
		var man := Rules.lookup("MAN",score,"mana")
		check(man.outcome == "allocation_required" and man.values.AP.kind == "allocation_required" and man.values.KP.kind == "allocation_required","MAN must not have fabricated chart values.")
		check(man.allocation.new_standard_policy == "balanced_50_50_whole_points" and man.allocation.confirmed_allocations_locked and not man.allocation.temporary_manual_redistribution,"MAN descriptor must preserve approved allocation rules.")
		check(man.allocation.negative_policy == "higher_first" and man.allocation.negative_tie_first == "AP","MAN negative policy must remain distinct from a live implementation.")
		for primary: String in ["STR","END","SPD","DEX","INT","LUK","APP"]:
			check(Rules.lookup(primary,score,"mana").values == Rules.lookup(primary,score,"regular").values,"Only WIS/WIT printed columns differ by mode.")
	check(Rules.lookup("WIS",10,"mana").values.has("MR/H") and not Rules.lookup("WIS",10,"regular").values.has("MR/H"),"Regular mode has no MR/H column.")
	check(Rules.lookup("WIT",10,"mana").values.MNS.value == 16 and Rules.lookup("WIT",10,"regular").values.MRF.value == 3,"MNS and MRF are different source statistics.")
	check(Rules.primary_descriptor("APP").name == "Appearance" and Rules.primary_descriptor("APP").definition_page == 24,"APP definition is printed p.24.")
	for mode: String in ["mana","regular"]:
		for descriptor: Dictionary in Rules.derived_descriptors("APP",mode).entries:
			check(descriptor.definition_page == 24 and descriptor.governing_primary == "APP","PAR/CHA definitions must inherit APP printed p.24.")
			check(descriptor.name == ("Personal Appearance Rating" if descriptor.abbreviation == "PAR" else "Charisma"),"Appearance-derived terminology remains exact.")
	for score in [20,21,25,26,35]:
		check(not Rules.lookup("STR",score,"mana").grants_eligibility,"High chart rows never grant magical/Immortality permissions.")
	check(Rules.lookup("STR",21,"mana").eligibility == "qualifying_special_or_special_imbued_equipment_required" and Rules.lookup("STR",26,"mana").eligibility == "verified_immortality_required","Eligibility boundaries must be explicit.")
	for id: String in ["SR","TB"]:
		var resistance := Rules.resistance_descriptor(id)
		check(resistance.success and resistance.category == "resistance" and resistance.governing_primary == null and not resistance.generates_value and not resistance.purchase_authorized,"Resistances must be independent descriptors, not derived formulas or purchases.")
	check(Rules.resistance_descriptor("SR").name == "Special Resistance" and Rules.resistance_descriptor("TB").name == "Tolerance Bonus","Exact resistance terminology.")
	check(Rules.purchase_label("talent_bonus") == {"success":true,"storage_kind":"talent_bonus","label":"Tolerance Bonus"},"Visible label mapping must preserve historical purchase kind.")
	check(not Rules.resistance_descriptor("END").success and not Rules.resistance_descriptor("talent_bonus").success,"A primary/purchase kind is not a resistance identity.")
	check(not Rules.lookup("CON",9,"mana").success and not Rules.lookup("STR",9,"invalid").success and not Rules.derived_descriptors("CON","mana").success,"No familiar-RPG substitution or unknown mode.")
	check(not Rules.allocation_descriptor("STR").success and not Rules.purchase_label("tolerance_bonus").success,"No new unapproved identifiers or allocation rules.")
	var mutated := Rules.lookup("STR",9,"mana")
	mutated.values.SB.value = 999
	var descriptor := Rules.allocation_descriptor("MAN")
	descriptor.fields.append("extra")
	check(Rules.lookup("STR",9,"mana").values.SB.value == 2 and Rules.allocation_descriptor("MAN").fields.size() == 2,"Returned data must not mutate later queries.")
	check(sim.get_state_snapshot() == before and sim.random.get_draw_count() == draws,"Queries must preserve authoritative actors, resources, events and RNG.")
	check(comparisons == 648,"All independent source cells must be checked.")
	print("37C comparisons: %s printed cells; %s source components; ten primary descriptors and mode/identity/purity boundaries." % [comparisons,scalar_checks])
	return failures
