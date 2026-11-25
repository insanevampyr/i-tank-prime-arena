extends RefCounted
const Historical = preload("res://tests/test_historical_vaelis_admission.gd")
var failures: Array[String] = []
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func run() -> Array[String]:
	for digest: String in ["3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20","229feacd9264c8088abc7eb0654fde29715a33cee594ff9e926fc88f8c209ae3"]:
		var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",digest)
		check(starter.success and starter.actor.get_combat_stat("dt") == 6 and starter.actor.get_combat_stat("dp") == 3,"Exact historical lineage receives approved 6/3 runtime split.")
		check(CharacterProfileProjection.fingerprint(starter.source.to_dictionary()) == digest and starter.source.combat_stats.dt == 3 and starter.source.combat_stats.dp == 6,"Immutable historical fingerprint/source stays 3/6.")
		var original: Dictionary = starter.source.to_dictionary()
		var record: Dictionary = CharacterDevelopment.create(9,3,6).record
		for score in range(10,13): record = CharacterDevelopment.append(record,"dex_purchase_%d" % score,"dex_purchase",{"before":score-1,"after":score,"allocation":"dt"}).record
		var raw := CharacterDevelopment.inspect(record)
		var corrected := CharacterDevelopment.runtime_allocation(raw.allocation,starter.runtime_source)
		var totals: Dictionary = DexAllocation.validate(corrected).totals
		check(totals.dex == 12 and totals.dt == 9 and totals.dp == 3,"Independent expected DEX12: three original DT choices yield DT9/DP3.")
		check(DexAllocation.validate(raw.allocation).totals.dt == 6 and DexAllocation.validate(raw.allocation).totals.dp == 6 and starter.source.to_dictionary() == original,"Raw allocation and source are never rewritten.")
		var sim := CombatSimulation.new(45045)
		sim.register_actor(starter.actor)
		var actor: CombatActorDefinition = starter.actor
		actor.attributes.dex = 12
		sim.get_actor_state(&"player").progression["development"] = record
		sim._apply_development_base(&"player")
		check(actor.base_combat_stats.dt == 9 and actor.base_combat_stats.dp == 3 and sim.get_effective_actor_combat_stat(&"player","dt") == 9 and sim.get_effective_actor_combat_stat(&"player","dp") == 3,"Base and actual defensive consumers agree on corrected allocation.")
		var rng := sim.random.wave_entry_state()
		sim.get_actor_state(&"player").timed_stat_effects["control"] = {"stat_modifiers":{"dt":-2,"dp":1}}
		check(sim.get_effective_actor_combat_stat(&"player","dt") == 7 and sim.get_effective_actor_combat_stat(&"player","dp") == 4 and sim.random.wave_entry_state() == rng,"Modifiers remain separate and correction consumes zero RNG.")
		var forged: CombatCharacterDefinitionResource = starter.source.duplicate(true)
		forged.attributes.str += 1
		check(not CharacterDevelopment.legacy_vaelis_split(forged),"Unknown/tampered historical sources never receive the correction.")
	# Frozen pre-correction purchase history: four legitimate levels fund the
	# original 3,000 + 3,000 + 5,000 EXPC transactions alongside the fixed V5 credit.
	var frozen := preload("res://tests/test_wisdom_mana_replay.gd").new().history(["level","level","level","level"])
	var payload: Dictionary = frozen.payload.duplicate(true)
	var development: Dictionary = CharacterDevelopment.create(9,3,6).record
	for score in range(10,13):
		payload.purchases.append({"purchase_id":"dev_vaelis_thorn/starter_admission/dex_%d" % score,"purchase_kind":"attribute","target_id":"dex","value_before":score-1,"value_after":score,"allocation":"dt","cost":3000 if score <= 11 else 5000,"source_ref":PrimeV3AdvancementCatalog.PURCHASE_SOURCE_REF})
		development = CharacterDevelopment.append(development,"dex_purchase_%d" % score,"dex_purchase",{"before":score-1,"after":score,"allocation":"dt"}).record
	payload.permanent["development"] = development
	payload.permanent.xp_baseline.spent = 11000
	payload.xp.spent = 11000
	payload.xp.unspent = 10000+int(payload.xp.earned)-11000
	var immutable := payload.duplicate(true)
	var hydrated := CharacterProfileProjection.hydrate(payload,frozen.source,"dev_vaelis_thorn",PlayableCharacterAdmission.RULES,frozen.verifier)
	check(hydrated.success and hydrated.actor_definition.attributes.dex == 12 and hydrated.actor_definition.get_combat_stat("dt") == 9 and hydrated.actor_definition.get_combat_stat("dp") == 3,"Actual V5 hydration corrects old DEX12/DT6/DP6 to live9/3 while replaying all original DT receipts.")
	check(payload == immutable and hydrated.permanent.development == development and hydrated.xp == payload.xp,"No baseline, growth, XP or purchase receipt is rewritten during correction.")
	var encoded := CharacterSaveContract.encode(payload)
	check(encoded.success and CharacterSaveContract.decode(encoded.text).payload == payload,"Original V5 numerical and allocation history round-trips unchanged.")
	var changed := payload.duplicate(true)
	changed.purchases.back().allocation = "dp"
	check(not CharacterProfileProjection.hydrate(changed,frozen.source,"dev_vaelis_thorn",PlayableCharacterAdmission.RULES,frozen.verifier).success,"Conflicting historical purchase/allocation evidence is still rejected.")
	PlayableCharacterPersistence.test_nonpersistent = false
	var h := Historical.new()
	h.root = OS.get_cache_dir().path_join("itank-storage-tests/dex45d_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	for mode: String in ["normal","dev_normal"]:
		var f := h.make_history(mode,"3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20",4,mode)
		check(f.get("success",false),"Disposable V4 historical profile builds.")
		if not f.get("success",false): continue
		h.check_loading(f,mode,"3df0412b72ba5d966b2eb645887fedfbb591782cffc7bff41c192e52583c6d20")
	check(h.failures.is_empty() and h.helper._failures.is_empty() and h.web.failures.is_empty(),"Historical Desktop/Web load, cancellation and unchanged canonical payload checks pass: %s" % [h.failures])
	h.helper._remove_fixture(h.root)
	PlayableBrowserPersistence.test_factory = Callable()
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_run_id = ""
	print("45D DEX correction: %d assertions." % assertions)
	return failures
