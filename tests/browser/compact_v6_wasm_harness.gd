extends Node
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Portable = preload("res://tests/compact_v6_portable_backup.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var source: CombatCharacterDefinitionResource
var catalog: CombatDefinitionCatalog
var callback: JavaScriptObject
func _ready() -> void:
	catalog = CombatDefinitionCatalog.load_default_fixture_catalog()
	source = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://tests/browser/compact_v6_store.js"))
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://tests/browser/compact_v6_backup_store.js"))
	callback = JavaScriptBridge.create_callback(_request)
	JavaScriptBridge.get_interface("window").v6NativeRequest = callback
	JavaScriptBridge.eval("window.v6Harness={results:{},next:0,call(value){const id=++this.next;return new Promise(resolve=>{this.results[id]=resolve;window.v6NativeRequest(JSON.stringify({id,value}));});}};window.v6Ready=true;")
func _request(values: Array) -> void:
	if values.size() != 1 or not values[0] is String: return
	var input: String = values[0]
	var job: Dictionary = JSON.parse_string(input)
	var args: Dictionary = CharacterSaveContract._normalize_json_numbers(job.value)
	var result := {}
	if str(args.get("kind","")).begins_with("portable_"):
		result = _portable_request(args)
		_respond(job.id,result)
		return
	var decoded := V6.decode(args.text,source)
	if decoded.success:
		if args.get("kind") in ["next","replay_award"]:
			var previous: Dictionary = decoded.record
			var candidate: Dictionary = previous.duplicate(true)
			candidate.head.sequence += 1
			candidate.head.parent_digest = V6.digest(previous)
			candidate.current.generation += 1
			candidate.operations.append({"id":args.id,"request_digest":V6.digest({"id":args.id,"preferences":0})})
			if args.get("kind") == "replay_award": candidate.evidence.awards.append(candidate.evidence.awards[0])
			candidate = V6.assemble(candidate.current,candidate.evidence,candidate.operations,candidate.head,source,candidate.compact_version)
			if args.get("kind") == "replay_award":
				# Deliberately forged fixture envelope: the real storage verifier
				# must reject it, rather than the fixture builder hiding the case.
				var body := JSON.stringify(candidate,"",true,true)
				result = {"success":true,"text":JSON.stringify({"format":"itank_arena_character","version":6,"payload_json":body,"sha256":body.sha256_text()},"",true,true)}
			else: result = V6.encode(candidate,source)
		elif args.get("parent") != null and args.parent != args.text:
			var parent := V6.decode(args.parent,source)
			result = V6.validate_extension(parent.record,decoded.record,source) if parent.success else parent
		else: result = {"success":true}
		if result.success and args.get("kind") not in ["next","replay_award"]: result = {"success":true,"record":decoded.record,"profile":decoded.record.current.character_id,"namespace":decoded.record.current.profile_namespace,"epoch":decoded.record.head.epoch,"sequence":decoded.record.head.sequence}
	else: result = decoded
	_respond(job.id,result)

func _respond(id: Variant, result: Dictionary) -> void:
	JavaScriptBridge.eval("{const id="+str(int(id))+";const resolve=window.v6Harness.results[id];delete window.v6Harness.results[id];resolve("+JSON.stringify(result,"",true,true)+");}")

func _portable_request(args: Dictionary) -> Dictionary:
	if args.kind == "portable_encode": return Portable.export_record(args.text,args.history,source)
	if args.kind == "portable_delta":
		var a := V6.decode(args.parent,source); var b := V6.decode(args.text,source)
		if not a.success: return a
		if not b.success: return b
		return Portable.transition(a.record,b.record,source)
	var p := Portable.decode(args.portable,source)
	if not p.success: return p
	if args.kind == "portable_prepare":
		if p.preview.profile != args.profile or p.preview.namespace != args.namespace: return Portable.fail("restore_identity_mismatch")
		p.confirmation = Portable.confirmation(args.portable.sha256_text(),args.expected,args.profile,args.namespace)
	if args.kind == "portable_relationship":
		var current := {}
		if args.get("current") != null:
			var d := V6.decode(args.current,source)
			if not d.success: return d
			current = d.record
		return Portable.relationship(p,current,str(args.get("current","")).sha256_text(),source)
	if not p.previous.is_empty(): p.previous_text = V6.encode(p.previous,source).text
	return p
