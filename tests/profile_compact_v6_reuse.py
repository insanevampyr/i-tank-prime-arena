"""45Y native-only TEMP instrumentation; no production profile/export access."""
import hashlib, json, os, pathlib, re, shutil, subprocess, sys, tempfile, threading, time
REPO = pathlib.Path(__file__).resolve().parents[1]
GODOT = pathlib.Path('C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe')
TRACE = 'preload("res://tests/compact_v6_perf_trace.gd")'

def prepare(label):
    project = pathlib.Path(tempfile.mkdtemp(prefix='arena45y-'+label+'-'))/'project'
    project.mkdir()
    for folder in ['scripts','data','tests']:
        shutil.copytree(REPO/folder,project/folder,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    asset=pathlib.Path('assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json')
    (project/asset).parent.mkdir(parents=True); shutil.copy2(REPO/asset,project/asset)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Disposable 45Y proof test"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    hooks = {
        'scripts/rewards/compact_character_v6_prototype.gd':('v6',['validate','validate_extension','decode','encode']),
        'scripts/rewards/character_persistence_coordinator.gd':('authority',['_authorize']),
        'scripts/rewards/compact_v6_snapshot_package.gd':('package',['cold_verify']),
    }
    for name,(tag,methods) in hooks.items():
        p=project/name; code=p.read_text()
        for method in methods:
            pattern=re.compile(r'^static func '+re.escape(method)+r'\((.*)\) -> Dictionary:$',re.M)
            def wrap(m):
                args=','.join(v.split(':')[0].split('=')[0].strip() for v in m[1].split(','))
                return f'static func {method}({m[1]}) -> Dictionary:\n\tvar frame: Variant = {TRACE}.enter("{tag}.{method}")\n\tvar value := _45y_original_{method}({args})\n\t{TRACE}.leave(frame)\n\treturn value\n\nstatic func _45y_original_{method}({m[1]}) -> Dictionary:'
            code,n=pattern.subn(wrap,code); assert n==1,(name,method,n)
        p.write_text(code,newline='\n')
    (project/'tests/45y_runner.gd').write_text('extends SceneTree\nfunc _initialize() -> void: call_deferred("run")\nfunc run() -> void:\n\tvar test := preload("res://tests/test_compact_v6_validation_reuse.gd").new()\n\tvar failed: Array[String] = test.run()\n\tprint("45Y_DONE "+str(failed))\n\tquit(0 if failed.is_empty() else 1)\n')
    p=subprocess.run([str(GODOT),'--headless','--path',str(project),'--editor','--import'],capture_output=True,text=True,timeout=180)
    log=p.stdout+p.stderr; (project.parent/'import.log').write_text(log)
    assert p.returncode==0 and not re.search('SCRIPT ERROR:|ERROR:',log),log[-6000:]
    print(project,flush=True)

def run(project,checked,label):
    import psutil
    project=pathlib.Path(project)
    assert project.parent.name.startswith('arena45y-') and project.name=='project'
    env=os.environ.copy(); env['ARENA45Y_CHECKED']=checked; env['ARENA45X_CASE']='remaining'; env['ARENA45X_SHORT']=''
    env['ARENA45X_LEGACY_BUNDLE']=(pathlib.Path(env['TEMP'])/'arena45s-frozen-bundle.txt').read_text().strip()
    started=time.monotonic(); stop=threading.Event(); mem={'peak_working_set':0,'peak_private':0}
    p=subprocess.Popen([str(GODOT),'--headless','--path',str(project),'--script','tests/45y_runner.gd'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
    def sample():
        while not stop.wait(.25):
            try:
                for q in [psutil.Process(p.pid),*psutil.Process(p.pid).children(recursive=True)]:
                    m=q.memory_info(); mem['peak_working_set']=max(mem['peak_working_set'],getattr(m,'peak_wset',m.rss));mem['peak_private']=max(mem['peak_private'],getattr(m,'private',m.vms))
            except psutil.Error: pass
    t=threading.Thread(target=sample,daemon=True);t.start()
    try: out,err=p.communicate(timeout=600)
    except subprocess.TimeoutExpired:
        # Only the tree created by this invocation; no unrelated process cleanup.
        try:
            for child in psutil.Process(p.pid).children(recursive=True): child.kill()
        except psutil.Error: pass
        p.kill();out,err=p.communicate()
        (project.parent/(label+'-timeout.log')).write_text(out+err)
        raise RuntimeError('Disposable 45Y test exceeded 600 seconds')
    finally: stop.set();t.join()
    log=out+err;(project.parent/(label+'.log')).write_text(log)
    assert p.returncode==0 and not re.search('SCRIPT ERROR:|ERROR:|leaked',log),log[-9000:]
    result=json.loads(next(l[12:] for l in log.splitlines() if l.startswith('45X_METRICS ')))
    result.update({'process_memory':mem,'wall_seconds':time.monotonic()-started,'checks':json.loads(next(l.removeprefix('45Y_CHECKS ') for l in log.splitlines() if l.startswith('45Y_CHECKS ')))})
    (project.parent/(label+'.json')).write_text(json.dumps(result,separators=(',',':')))
    print(json.dumps({'result':str(project.parent/(label+'.json')),'checks':result['checks'],'wall_seconds':result['wall_seconds'],'memory':mem}),flush=True)

if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare(sys.argv[2])
    elif sys.argv[1]=='run':run(sys.argv[2],sys.argv[3],sys.argv[4])
