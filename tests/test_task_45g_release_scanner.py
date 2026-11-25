"""Run the actual production JsonScan in a disposable native RELEASE scene.
No Web export, owner storage or project configuration writes. The runtime copy
is extracted from production at test time; the shim supplies only size/errors.
"""
import argparse, os, shutil, subprocess, tempfile
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument('--godot', default=str(Path.home()/'Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe'))
parser.add_argument('--templates', default=str(Path(os.environ['APPDATA'])/'Godot/export_templates/4.7.2.stable'))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = (root/'scripts/rewards/character_backup_contract.gd').read_text(encoding='utf-8')
scanner = source[source.index('class JsonScan extends RefCounted:'):source.index('\nstatic func scan_json')].replace('CharacterBackupContract', 'Boundary')
cache = Path(os.environ['LOCALAPPDATA'])/'itank-storage-tests'
cache.mkdir(exist_ok=True)
work = Path(tempfile.mkdtemp(prefix='45g-release-', dir=cache))
prefix = '''extends Node
class Boundary:
	const MAX_DEPTH := 64
	const MAX_TOKENS := 500000
	static func fail(reason: String) -> Dictionary: return {"success":false,"reason":reason}
	static func check_size(bytes: int, maximum: int) -> Dictionary: return {"success":bytes <= maximum}
'''
suffix = r'''
var assertions := 0
var failed := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failed += 1; push_error(message)
func _ready() -> void:
	check(not OS.is_debug_build(),"This must exercise a release runtime")
	var previous_style := RegEx.new()
	assert(previous_style.compile("a+") == OK)
	check(not previous_style.is_valid(),"The shipped initialization style is omitted by release")
	var text := JSON.stringify({"slashes":"\\".repeat(4096),"nested":{"a":1}})+" ".repeat(10000)
	var scanner := JsonScan.new(text,1000000)
	check(JsonScan.string_run.is_valid() and JsonScan.space_run.is_valid(),"Production release regex initialization executes")
	while scanner.result.get("state") == "pending": scanner.step(31)
	check(scanner.result.success,"Release accepts escaped/whitespace fixture")
	for bad: String in ['{"a":1,"\\u0061":2}',"[".repeat(65)+"]".repeat(65),'["unterminated']:
		scanner = JsonScan.new(bad,1000000)
		while scanner.result.get("state") == "pending": scanner.step(7)
		check(not scanner.result.success,"Release rejection preserved")
	var valid_spaces: RegEx = JsonScan.space_run
	JsonScan.space_run = RegEx.new()
	scanner = JsonScan.new("{}",1000000)
	check(scanner.result.get("reason") == "backup_scanner_unavailable","Uncompiled scanner fails closed without search errors")
	JsonScan.space_run = valid_spaces
	print("45G RELEASE CHECKS: ",assertions,"; failed=",failed,"; debug_build=",OS.is_debug_build())
	get_tree().quit(1 if failed else 0)
'''
(work/'probe.gd').write_bytes((prefix+scanner+suffix).encode('utf-8'))
(work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Disposable45GRelease"\nrun/main_scene="res://probe.tscn"\n', encoding='utf-8')
(work/'probe.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
(work/'.godot').mkdir()
(work/'.godot/global_script_class_cache.cfg').write_text('list=[]\n',encoding='utf-8')
files=['project.godot','probe.gd','probe.tscn','.godot/global_script_class_cache.cfg']
# JSON quoting creates literal GDScript strings; no shell interpolation.
import json
pack = 'extends SceneTree\nfunc _initialize() -> void:\n\tvar p := PCKPacker.new()\n\tif p.pck_start('+json.dumps(str(work/'probe.pck').replace('\\','/'))+') != OK: quit(1); return\n'
for name in files:
 pack += '\tif p.add_file('+json.dumps('res://'+name)+','+json.dumps(str(work/name).replace('\\','/'))+') != OK: quit(1); return\n'
pack += '\tquit(p.flush())\n'
(work/'pack.gd').write_text(pack,encoding='utf-8')
first=subprocess.run([args.godot,'--headless','--path',str(root),'--script',str(work/'pack.gd')],capture_output=True,text=True,timeout=60)
if first.returncode or 'ERROR' in first.stdout+first.stderr:raise RuntimeError(first.stdout+first.stderr)
for name in ['windows_release_x86_64.exe','windows_release_x86_64_console.exe']:
 shutil.copyfile(Path(args.templates)/name,work/('probe_console.exe' if '_console' in name else 'probe.exe'))
result=subprocess.run([str(work/'probe_console.exe'),'--headless'],capture_output=True,text=True,timeout=60)
print(result.stdout+result.stderr)
print('Disposable release fixture:',work)
if result.returncode or 'ERROR' in result.stdout+result.stderr:raise SystemExit(result.returncode or 1)
if 'failed=0; debug_build=false' not in result.stdout:raise SystemExit('Missing release evidence')
