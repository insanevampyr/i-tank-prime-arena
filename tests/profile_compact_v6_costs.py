"""45Z fine-grained native profiling in unique disposable TEMP projects only."""
import contextlib
import io
import pathlib
import re
import runpy
import subprocess
import sys

BASE = runpy.run_path(str(pathlib.Path(__file__).with_name('profile_compact_v6_reuse.py')))
TRACE = 'preload("res://tests/compact_v6_perf_trace.gd")'


def hook(code, method, tag, indent=''):
    pattern = re.compile(r'^' + indent + r'(static )?func ' + re.escape(method)
                         + r'\((.*)\) -> ([\w\[\]]+):(.*)$', re.M)

    def wrapped(match):
        prefix = match[1] or ''
        signature, result, inline = match[2], match[3], match[4]
        args = ','.join(arg.split(':')[0].split('=')[0].strip()
                        for arg in signature.split(','))
        pad = indent + '\t'
        start = (f'{indent}{prefix}func {method}({signature}) -> {result}:\n'
                 f'{pad}var _cost_frame: Variant = {TRACE}.enter("{tag}")\n'
                 f'{pad}var _cost_value: {result} = _45z_original_{method}({args})\n'
                 f'{pad}{TRACE}.leave(_cost_frame)\n{pad}return _cost_value\n\n'
                 f'{indent}{prefix}func _45z_original_{method}({signature}) -> {result}:')
        return start + ('\n' + pad + inline.strip() if inline.strip() else '')

    code, count = pattern.subn(wrapped, code)
    assert count == 1, (method, count)
    return code


def prepare(label):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        BASE['prepare']('45z-' + label)
    project = pathlib.Path(output.getvalue().strip())
    methods = {
        'compact_v6_checked_operation.gd': ['guard', '_identity', 'matches', 'bind',
            'encode_candidate', 'package_input', 'remember_package'],
        'compact_v6_gameplay_candidate.gd': ['head', '_binding_for', '_context',
            '_unchanged_events', '_ordered_delta', 'check'],
        'compact_v6_incremental_snapshot.gd': ['_fresh', '_delta'],
        'compact_v6_snapshot_package.gd': ['_state', '_pack_verified'],
        'compact_character_v6_prototype.gd': ['_projection', '_extension_rules', 'assemble', 'digest'],
        'character_save_contract.gd': ['encode', 'decode'],
        'character_profile_projection.gd': ['hydrate'],
    }
    for name, selected in methods.items():
        p = project / 'scripts/rewards' / name
        code = p.read_text(encoding='utf-8')
        for method in selected:
            code = hook(code, method, name.removesuffix('.gd') + '.' + method)
        if name == 'compact_v6_gameplay_candidate.gd':
            code = hook(code, 'copy', 'sealed.s2_copy', '\t')
        # Only disposable copies: preserve original return values and timings.
        code = code.replace('JSON.parse_string(', TRACE + '.parse(')
        code = code.replace('JSON.stringify(', TRACE + '.stringify(')
        p.write_text(code, encoding='utf-8', newline='\n')
    trace = project / 'tests/compact_v6_perf_trace.gd'
    trace.write_text(trace.read_text(encoding='utf-8') + '''
static func parse(text: String) -> Variant:
\tvar frame: Variant = enter("json.parse")
\tvar value: Variant = JSON.parse_string(text)
\tleave(frame); return value
''', encoding='utf-8', newline='\n')
    imported = subprocess.run([str(BASE['GODOT']), '--headless', '--path', str(project),
        '--editor', '--import'], capture_output=True, text=True, timeout=180)
    log = imported.stdout + imported.stderr
    (project.parent / 'fine-import.log').write_text(log, encoding='utf-8')
    assert imported.returncode == 0 and not re.search(r'SCRIPT ERROR:|ERROR:', log), log[-9000:]
    parsed = subprocess.run([str(BASE['GODOT']), '--headless', '--path', str(project),
        '--check-only', '--script', 'tests/45y_runner.gd'], capture_output=True, text=True, timeout=60)
    checked = parsed.stdout + parsed.stderr
    (project.parent / 'fine-parse.log').write_text(checked, encoding='utf-8')
    assert parsed.returncode == 0 and not re.search(r'SCRIPT ERROR:|ERROR:', checked), checked[-9000:]
    print(project, flush=True)


if __name__ == '__main__':
    if sys.argv[1] == 'prepare':
        prepare(sys.argv[2])
    elif sys.argv[1] == 'run':
        BASE['run'](sys.argv[2], '1', sys.argv[3])
