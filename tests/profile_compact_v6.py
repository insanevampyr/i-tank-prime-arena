"""45P test-only TEMP project instrumentation. Never edits the source checkout."""
import hashlib,json,os,re,shutil,subprocess,sys,tempfile,time,threading
from pathlib import Path
REPO=Path(__file__).resolve().parents[1]
GODOT=Path('C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe')
TRACE='preload("res://tests/compact_v6_perf_trace.gd")'
TARGETS={
 'scripts/rewards/compact_character_v6_prototype.gd':('V6',['assemble','encode','decode','validate','validate_extension','digest','_ids','_projection','_chronology','_historical_credit_basis']),
 'scripts/rewards/character_persistence_coordinator.gd':('Coordinator',['_validate_continuity','_find_transaction','_validate_receipts','_authorize']),
 'scripts/rewards/character_profile_projection.gd':('Profiles',['hydrate','project','_ownership']),
 'tests/compact_v6_portable_backup.gd':('Portable',['transition','apply','verify_history','export_record','decode']),
 'tests/compact_v6_disposable_store.gd':('Disk',['_write','_read','_head','_document','_install_verified','load_current','repair_exact']),
 'tests/compact_v6_backup_store.gd':('BackupStore',['load_current','capsule','_publish_locked','restore','export_file','recover']),
}
def instrument(project,fine=False):
 project=Path(project).resolve()
 assert str(project).lower().startswith(str(Path(tempfile.gettempdir())).lower()+os.sep)
 for relative,(label,names) in TARGETS.items():
  p=project/relative
  if not p.exists():continue
  s=p.read_text(encoding='utf-8')
  if fine and label in ['V6','Coordinator']:
   if label=='V6':
    start=s.index('\tif previous.applied_ids !=');end=s.index('\tvar continuity :=',start)
    params='previous: Dictionary, candidate: Dictionary';args='previous,candidate';tag='lookup.lifetime';name='lifetime'
   else:
    start=s.index('\n',s.index('\tif not current.has("settlements")'))+1;end=s.index('\tfor key: String in ["purchases"]:',start)
    params='current: Dictionary, candidate: Dictionary';args='current,candidate';tag='lookup.settlements';name='settlements'
   body=s[start:end]
   s=s[:start]+f'\tvar _lookup_check := _perf_lookup_{name}({args})\n\tif not _lookup_check.success: return _lookup_check\n'+s[end:]
   s+=f'\nstatic func _perf_lookup_{name}({params}) -> Dictionary:\n\tvar frame: Variant = {TRACE}.enter("{tag}")\n\tvar result := _perf_lookup_original_{name}({args})\n\t{TRACE}.leave(frame)\n\treturn result\n\nstatic func _perf_lookup_original_{name}({params}) -> Dictionary:\n'+body+'\treturn {"success":true}\n'
  s=s.replace('JSON.stringify(',TRACE+'.stringify(')
  s=re.sub(r'\b([A-Za-z_]\w*(?:\.\w+)*)\.sha256_text\(\)',lambda m:TRACE+'.sha256('+m[1]+')',s)
  for name in names:
   pattern=re.compile(r'^(static )?func '+re.escape(name)+r'\((.*)\) -> ([A-Za-z_\[\]]+):$',re.M)
   def wrap(m):
    static=m[1] or '';params=m[2];typ=m[3]
    args=','.join(q.split(':')[0].split('=')[0].strip() for q in params.split(',') if q.strip())
    return f'{static}func {name}({params}) -> {typ}:\n\tvar frame: Variant = {TRACE}.enter("{label}.{name}")\n\tvar _perf_value: {typ} = _perf_original_{label}_{name}({args})\n\t{TRACE}.leave(frame)\n\treturn _perf_value\n\n{static}func _perf_original_{label}_{name}({params}) -> {typ}:'
   s,count=pattern.subn(wrap,s);assert count==1,(relative,name,count)
  p.write_bytes(s.encode('utf-8'))
 # Browser profiling stays in a TEMP harness, not the repository bridge.
 h=project/'tests/browser/compact_v6_wasm_harness.gd'
 if h.exists():
  s=h.read_text(encoding='utf-8').replace('var decoded := V6.decode(args.text,source)','if str(args.get("kind","")).begins_with("perf_"):\n\t\tresult = preload("res://tests/compact_v6_performance.gd").sample(args,source)\n\t\t_respond(job.id,result)\n\t\treturn\n\tvar decoded := V6.decode(args.text,source)',1)
  h.write_bytes(s.encode('utf-8'))
def prepare(phase):
 project=Path(tempfile.mkdtemp(prefix='arena45p-'+phase+'-'))/'project';project.mkdir()
 for folder in ['scripts','data','tests']:shutil.copytree(REPO/folder,project/folder)
 asset=Path('assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json')
 (project/asset).parent.mkdir(parents=True);shutil.copy2(REPO/asset,project/asset)
 (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Disposable 45P profiler"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf-8')
 instrument(project,'fine' in phase)
 r=subprocess.run([str(GODOT),'--headless','--path',str(project),'--editor','--import'],capture_output=True,text=True,timeout=180)
 (project.parent/'import.log').write_text(r.stdout+r.stderr,encoding='utf-8');assert r.returncode==0 and 'SCRIPT ERROR:' not in r.stdout+r.stderr,r.stdout+r.stderr
 print(project,flush=True)
 return project
def run(project,root,action,case):
 args=[str(GODOT),'--headless','--path',str(project),'--script','tests/compact_v6_performance_process.gd','--',action,str(root),case]
 start=time.monotonic()
 import psutil
 proc=subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 stopped=threading.Event();memory={'peak_working_set_bytes':0,'last_rss_bytes':0}
 def monitor():
  while not stopped.wait(0.1):
   try:
    for child in [psutil.Process(proc.pid),*psutil.Process(proc.pid).children(recursive=True)]:
     m=child.memory_info();memory['peak_working_set_bytes']=max(memory['peak_working_set_bytes'],getattr(m,'peak_wset',m.rss));memory['last_rss_bytes']=m.rss
   except psutil.Error:pass
 worker=threading.Thread(target=monitor,daemon=True);worker.start()
 try:stdout,stderr=proc.communicate(timeout=240)
 except subprocess.TimeoutExpired:
  # Kill only the console/engine tree created by this disposable invocation.
  try:
   for child in psutil.Process(proc.pid).children(recursive=True):child.kill()
  except psutil.Error:pass
  proc.kill();stdout,stderr=proc.communicate();stopped.set();worker.join()
  return {'success':False,'timeout_seconds':240,'case':case,'partial_stdout':stdout[-2000:],'process_memory':memory}
 stopped.set();worker.join()
 log=stdout+stderr;(project.parent/(action+'-'+Path(case).name+'.log')).write_text(log,encoding='utf-8')
 assert proc.returncode==0 and not re.search(r'SCRIPT ERROR:|ERROR:|leaked',log),log[-6000:]
 result=json.loads(next(l.removeprefix('45P_RESULT ') for l in log.splitlines() if l.startswith('45P_RESULT ')))
 result['wall_seconds']=time.monotonic()-start;result['process_memory']=memory;return result
if __name__=='__main__':
 mode=sys.argv[1]
 if mode=='instrument':instrument(sys.argv[2],'--fine' in sys.argv)
 elif mode=='prepare':prepare(sys.argv[2])
 elif mode=='run':
  project=Path(sys.argv[2]);root=Path(sys.argv[3]);phase=sys.argv[4]
  result={}
  for name in sys.argv[5:]:
   print('45P_START',phase,name,flush=True)
   result[name]=run(project,root,'workflow' if name=='workflow' else 'sample',name)
   print('45P_DONE',phase,name,json.dumps(result[name].get('samples',result[name])),flush=True)
   (root/('native-'+phase+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
 elif mode=='build':
  result=run(Path(sys.argv[2]),Path(sys.argv[3]),'build',sys.argv[4]);print(json.dumps(result))
