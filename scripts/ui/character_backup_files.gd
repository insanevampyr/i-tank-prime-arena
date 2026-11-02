class_name CharacterBackupFiles
extends RefCounted

const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const EXTENSION := ".itankbackup.json"
# A separate file-transfer bridge. No profile storage API or network calls.
const BRIDGE := """
(()=>{if(window.ArenaBackupFiles)return;
let status={state:'idle'},input=null,sequence=0;
window.ArenaBackupFiles={
 choose(limit){
  if(status.state==='pending')return false;
  const current=++sequence;status={state:'pending'};input=document.createElement('input');
  input.type='file';input.accept='.itankbackup.json,.json,application/json';input.style.display='none';
  const finish=r=>{if(current!==sequence)return;status=r;if(input){input.remove();input=null;}};
  input.oncancel=()=>finish({state:'cancelled'});
  input.onchange=async()=>{try{const f=input.files[0];if(!f){finish({state:'cancelled'});return;}
   if(f.size>limit){finish({state:'failed',reason:'backup_size_limit'});return;}
   const text=new TextDecoder('utf-8',{fatal:true}).decode(await f.arrayBuffer());
   finish({state:'selected',text});
  }catch(e){finish({state:'failed',reason:'backup_file_read_failed'});}};
  document.body.appendChild(input);input.click();return true;
 },
 poll(){const r=JSON.stringify(status);if(status.state!=='pending')status={state:'idle'};return r;},
 download(text,name){const url=URL.createObjectURL(new Blob([text],{type:'application/json;charset=utf-8'}));
  const a=document.createElement('a');a.href=url;a.download=name;document.body.appendChild(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000);return true;},
 cancel(){++sequence;if(input)input.remove();input=null;status={state:'idle'};}
};})();
"""

static func web_bridge() -> JavaScriptObject:
	JavaScriptBridge.eval(BRIDGE,true)
	return JavaScriptBridge.get_interface("ArenaBackupFiles")

static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return Backup.fail("backup_file_read_failed")
	if file.get_length() > Backup.MAX_BYTES:
		file.close()
		return Backup.fail("backup_size_limit")
	var bytes := file.get_buffer(file.get_length())
	var error := file.get_error()
	file.close()
	var text := bytes.get_string_from_utf8()
	if error != OK or text.to_utf8_buffer() != bytes: return Backup.fail("invalid_or_unreadable_utf8")
	return {"success":true,"text":text}

static func save_new_file(path: String, text: String) -> Dictionary:
	if not path.ends_with(EXTENSION) or text.to_utf8_buffer().size() > Backup.MAX_BYTES: return Backup.fail("invalid_backup_output")
	var actual := ProjectSettings.globalize_path(path).replace("\\","/").simplify_path()
	var profiles := ProjectSettings.globalize_path(CharacterSaveStorage.DEFAULT_ROOT).replace("\\","/").simplify_path()
	if actual.to_lower().begins_with(profiles.to_lower()+"/"): return Backup.fail("backup_cannot_target_profile_storage")
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".pending"): return Backup.fail("backup_output_already_exists")
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	if file == null: return Backup.fail("backup_output_unavailable")
	file.store_buffer(text.to_utf8_buffer())
	file.flush()
	var error := file.get_error()
	file.close()
	var readback := read_file(path+".pending")
	if error != OK or not readback.success or readback.text != text: return Backup.fail("backup_output_verification_failed")
	if FileAccess.file_exists(path) or DirAccess.rename_absolute(path+".pending",path) != OK: return Backup.fail("backup_output_publish_failed")
	readback = read_file(path)
	if not readback.success or readback.text != text: return Backup.fail("backup_output_verification_failed")
	return {"success":true,"path":actual,"verified":true}
