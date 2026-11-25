"""Build the disposable native prerequisite with installed MSVC/SDK. No downloads.

Development-only stdlib script. Runtime helper uses static CRT + Windows system
APIs; no Python, shell, PowerShell, installed package or bundled DLL at runtime.
Artifacts must stay in a dedicated TEMP directory, never the repository.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def build(output: Path) -> Path:
    output = output.resolve()
    base = Path(tempfile.gettempdir()).resolve()
    if not output.is_relative_to(base) or not output.name.startswith("arena46i1_"):
        raise ValueError("Build directory must be a dedicated TEMP/arena46i1_* root")
    output.mkdir(parents=True, exist_ok=True)
    program_files = Path(os.environ["ProgramFiles(x86)"])
    vswhere = program_files / "Microsoft Visual Studio/Installer/vswhere.exe"
    installation = Path(subprocess.check_output([
        str(vswhere), "-latest", "-products", "*", "-requires",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath",
    ], text=True).strip())
    version = (installation / "VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt").read_text().strip()
    vc = installation / "VC/Tools/MSVC" / version
    sdk = program_files / "Windows Kits/10"
    sdk_version = max(p.name for p in (sdk / "Include").iterdir() if (p / "um/Windows.h").exists())
    compiler = vc / "bin/Hostx64/x64/cl.exe"
    source = Path(__file__).with_name("safe_head_replace.c").resolve()
    exe = output / "safe_head_replace.exe"
    args = [str(compiler), "/nologo", "/W4", "/WX", "/O2", "/MT", "/utf-8", "/TC",
            "/DUNICODE", "/D_UNICODE", "/D_WIN32_WINNT=0x0A00", str(source),
            "/Fo" + str(output / "safe_head_replace.obj"), "/Fe" + str(exe)]
    for include in [vc / "include", *(sdk / "Include" / sdk_version / name for name in ["ucrt", "shared", "um"])]:
        args += ["/I" + str(include)]
    args += ["/link", "/INCREMENTAL:NO", "/DYNAMICBASE", "/NXCOMPAT", "kernel32.lib"]
    for lib in [vc / "lib/x64", *(sdk / "Lib" / sdk_version / name / "x64" for name in ["ucrt", "um"])]:
        args += ["/LIBPATH:" + str(lib)]
    subprocess.run(args, cwd=output, check=True, shell=False)
    print(json.dumps({"exe": str(exe), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                      "exe_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(), "compiler": str(compiler),
                      "sdk": sdk_version, "bytes": exe.stat().st_size}))
    return exe


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args().output)
