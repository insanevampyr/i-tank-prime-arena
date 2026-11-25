'use strict';
// Only an OS-TEMP project, own Edge profile and random loopback origin.
// No IndexedDB bridge or full #46J matrix is invoked. Its frozen oracle is read-only.
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const cp = require('node:child_process'), http = require('node:http');
const assert = require('node:assert/strict'), crypto = require('node:crypto');
const repo = path.resolve(__dirname, '../..');
const root = fs.readFileSync(path.join(os.tmpdir(), 'arena46j1-current-root.txt'), 'utf8').trim();
assert(path.resolve(root).startsWith(path.join(os.tmpdir(), 'arena46j1-')));
const fixtures = fs.readFileSync(path.join(root, 'fixture_directory.txt'), 'utf8').trim();
assert(path.resolve(fixtures).startsWith(path.join(os.tmpdir(), 'arena46j-')));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const baselineBytes = fs.readFileSync(path.join(root, 'native-before.json'));
const baseline = JSON.parse(baselineBytes);
assert.deepStrictEqual(baseline.failures, []);
const project = path.join(root, 'release-project'), web = path.join(project, 'web');
fs.mkdirSync(web, { recursive: true });
for (const folder of ['scripts', 'data', 'tests', 'scenes']) {
  fs.cpSync(path.join(repo, folder), path.join(project, folder), { recursive: true, filter: file => !file.includes('__pycache__') });
}
for (const file of cp.execFileSync('git', ['ls-files', '--', 'assets'], { cwd: repo, encoding: 'utf8' }).trim().split('\n')) {
  if (!file) continue;
  assert(!/Rare Human Warrior \(Boss\)\.doc|^character saves\/|^tmp\//.test(file));
  const target = path.join(project, file);
  fs.mkdirSync(path.dirname(target), { recursive: true }); fs.copyFileSync(path.join(repo, file), target);
}
fs.writeFileSync(path.join(project, 'project.godot'), 'config_version=5\n[application]\nconfig/name="Disposable Dodge Release Verification"\nrun/main_scene="res://probe.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n');
fs.writeFileSync(path.join(project, 'probe.tscn'), '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="DodgeProbe" type="Node"]\nscript = ExtResource("1")\n');
fs.writeFileSync(path.join(project, 'probe.gd'), `extends Node
const Probe = preload("res://tests/test_dodge_release_correction.gd")
var callback: JavaScriptObject
func _ready() -> void:
 callback = JavaScriptBridge.create_callback(_run)
 JavaScriptBridge.get_interface("window").dodgeNative = callback
 JavaScriptBridge.eval("window.dodgeReady=true;",true)
func _run(args: Array) -> void:
 var input: Dictionary = JSON.parse_string(str(args[0]))
 var probe := Probe.new()
 var failures := probe.run()
 var checkpoints := {}
 for kind: String in ["normal","dev_normal"]:
  checkpoints[kind] = probe.checkpoint_sample(input[kind])
 var value := {"assertions":probe.assertions,"failures":failures,"samples":probe.samples,"checkpoints":checkpoints}
 JavaScriptBridge.eval("window.dodgeResolve("+JSON.stringify({"debug":OS.is_debug_build(),"web":OS.has_feature("web"),"value":value},"",true,true)+");",true)
`);
const preset = fs.readFileSync(path.join(repo, 'export_presets.cfg'), 'utf8')
  .replace('name="Web"', 'name="Disposable Dodge Web"')
  .replace(/^include_filter=.*$/m, 'include_filter="scripts/**/*.js,assets/Character Choices/*.json"')
  .replace(/^exclude_filter=.*$/m, 'exclude_filter=""')
  .replace(/^export_path=.*$/m, 'export_path="web/index.html"');
fs.writeFileSync(path.join(project, 'export_presets.cfg'), preset);
for (const [extra, label] of [[['--editor', '--import'], 'import'], [['--export-release', 'Disposable Dodge Web', 'web/index.html'], 'export']]) {
  const result = cp.spawnSync('C:/Users/mxz/Desktop/GoDot/Godot_v4.7.2-stable_win64_console.exe', ['--headless', '--path', project, ...extra], { windowsHide: true, encoding: 'utf8', timeout: 180000, maxBuffer: 12 * 1024 * 1024 });
  const log = (result.stdout || '') + (result.stderr || '');
  fs.writeFileSync(path.join(root, label + '.log'), log);
  assert(result.status === 0 && !/SCRIPT ERROR:|Parse Error:|^ERROR:/m.test(log), label + ': ' + log.slice(-6000));
}

(async () => {
  let server, edge, ws, call; const messages = []; let assertions = 0;
  const check = (value, label) => { assertions++; assert.ok(value, label); };
  try {
    server = http.createServer((request, response) => {
      const name = new URL(request.url, 'http://localhost').pathname;
      const file = path.join(web, name === '/' ? 'index.html' : path.basename(name));
      response.setHeader('Cache-Control', 'no-store');
      if (!fs.existsSync(file)) { response.statusCode = 404; response.end(); return; }
      response.setHeader('Content-Type', file.endsWith('.wasm') ? 'application/wasm' : file.endsWith('.js') ? 'text/javascript' : file.endsWith('.html') ? 'text/html' : 'application/octet-stream');
      fs.createReadStream(file).pipe(response);
    });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const profile = path.join(root, 'edge-dodge-' + Date.now());
    edge = cp.spawn('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', ['--headless=new', '--disable-extensions', '--disable-gpu', '--enable-unsafe-swiftshader', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0', '--user-data-dir=' + profile, 'about:blank'], { windowsHide: true, stdio: 'ignore' });
    let endpoint;
    for (let i = 0; i < 150; i++) {
      try { endpoint = fs.readFileSync(path.join(profile, 'DevToolsActivePort'), 'utf8').split('\n'); break; } catch { await delay(100); }
    }
    check(endpoint, 'Own isolated Edge endpoint');
    ws = new WebSocket('ws://127.0.0.1:' + endpoint[0] + endpoint[1]);
    await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
    let serial = 0; const jobs = new Map();
    ws.onmessage = event => {
      const message = JSON.parse(event.data);
      if (jobs.has(message.id)) {
        const job = jobs.get(message.id); jobs.delete(message.id); clearTimeout(job.timer);
        message.error ? job.reject(Error(JSON.stringify(message.error))) : job.resolve(message.result);
      }
      if (message.method === 'Runtime.consoleAPICalled') messages.push(message.params.args.map(value => value.value || value.description || '').join(' '));
      if (message.method === 'Runtime.exceptionThrown') messages.push('JS_EXCEPTION ' + JSON.stringify(message.params.exceptionDetails));
    };
    call = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
      const id = ++serial;
      const timer = setTimeout(() => { jobs.delete(id); reject(Error('CDP timeout ' + method)); }, 120000);
      jobs.set(id, { resolve, reject, timer }); ws.send(JSON.stringify({ id, method, params, sessionId }));
    });
    const version = await call('Browser.getVersion');
    const target = await call('Target.createTarget', { url: 'about:blank' });
    const session = (await call('Target.attachToTarget', { targetId: target.targetId, flatten: true })).sessionId;
    await call('Runtime.enable', {}, session); await call('Page.enable', {}, session);
    const evaluate = async expression => {
      const result = await call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, session);
      assert(!result.exceptionDetails, JSON.stringify(result.exceptionDetails)); return result.result.value;
    };
    await call('Page.navigate', { url: 'http://127.0.0.1:' + server.address().port + '/' }, session);
    let ready = false;
    for (let i = 0; i < 1200; i++) { ready = await evaluate('!!window.dodgeReady'); if (ready) break; await delay(100); }
    check(ready, 'Actual release-WASM probe ready');
    const engineDatabases = (await evaluate('indexedDB.databases().then(a=>a.map(d=>d.name).sort())'));
    const input = Object.fromEntries(['normal', 'dev_normal'].map(kind => [kind, fs.readFileSync(path.join(fixtures, kind + '.json'), 'utf8')]));
    const result = await evaluate(`new Promise(resolve=>{window.dodgeResolve=resolve;window.dodgeNative(${JSON.stringify(JSON.stringify(input))});})`);
    fs.writeFileSync(path.join(root, 'release-result.json'), JSON.stringify(result, null, 2));
    check(result.web && !result.debug, 'Actual web release, assertions disabled');
    check(result.value.assertions === 49 && result.value.failures.length === 0, 'All 49 actual release Dodge assertions pass');
    assert.deepStrictEqual(result.value, baseline); assertions++;
    for (const kind of ['normal', 'dev_normal']) {
      const oracleBytes = fs.readFileSync(path.join(fixtures, kind + '_oracle.json'));
      const oracle = JSON.parse(oracleBytes);
      assert.deepStrictEqual(result.value.checkpoints[kind].body, oracle.body); assertions++;
      assert.deepStrictEqual(result.value.checkpoints[kind].simulation, oracle.simulation); assertions++;
    }
    check(!messages.some(value => /SCRIPT ERROR:|^ERROR:|JS_EXCEPTION/.test(value)), 'No Godot/JS runtime errors');
    const afterDatabases = await evaluate('indexedDB.databases().then(a=>a.map(d=>d.name).sort())');
    console.log('ISOLATED_DATABASES ' + JSON.stringify({before:engineDatabases,after:afterDatabases}));
    check(JSON.stringify(afterDatabases) === JSON.stringify(engineDatabases), 'Dodge probe opens no database beyond engine startup');
    assert.deepStrictEqual(fs.readFileSync(path.join(root, 'native-before.json')), baselineBytes); assertions++;
    const output = { success: true, assertions, gdscript_assertions: result.value.assertions, browser: version, messages, native_baseline_sha256: sha(baselineBytes), pck_sha256: sha(fs.readFileSync(path.join(web, 'index.pck'))), combat_source_sha256: sha(fs.readFileSync(path.join(repo, 'scripts/combat/combat_simulation.gd'))), oracle_sha256: Object.fromEntries(['normal', 'dev_normal'].map(kind => [kind, sha(fs.readFileSync(path.join(fixtures, kind + '_oracle.json')))])), scope: 'Dodge only; no full 46J matrix or storage publication', engine_databases: engineDatabases, after_databases: afterDatabases, profile };
    fs.writeFileSync(path.join(root, 'edge-results.json'), JSON.stringify(output, null, 2)); console.log(JSON.stringify(output));
    await call('Browser.close'); ws.close(); ws = null;
  } finally {
    fs.writeFileSync(path.join(root, 'edge-console.json'), JSON.stringify({ assertions, messages }, null, 2));
    if (ws && call) await Promise.race([call('Browser.close').catch(() => {}), delay(2000)]);
    if (ws) ws.close(); if (server) await new Promise(resolve => server.close(resolve));
    if (edge && edge.exitCode === null) edge.kill();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
