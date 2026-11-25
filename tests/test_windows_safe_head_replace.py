"""46I-1 Windows sentinel diagnostics. Stdlib only; no owner characters or formats.

Launches the source-built helper directly. Child .kill() is actual Windows
TerminateProcess; pause markers provide known before/after-native-call stages.
All mutable files are in unique LOCALAPPDATA/itank-storage-tests/minimal46i1_*.
"""
import argparse
import ctypes
from ctypes import wintypes as W
import hashlib
import json
import os
from pathlib import Path
import subprocess
import threading
import time


K = ctypes.WinDLL("kernel32", use_last_error=True)
K.CreateFileW.argtypes = [W.LPCWSTR, W.DWORD, W.DWORD, ctypes.c_void_p, W.DWORD, W.DWORD, W.HANDLE]
K.CreateFileW.restype = W.HANDLE
K.CloseHandle.argtypes = [W.HANDLE]
K.CloseHandle.restype = W.BOOL
K.ReadFile.argtypes = [W.HANDLE, ctypes.c_void_p, W.DWORD, ctypes.POINTER(W.DWORD), ctypes.c_void_p]
K.ReadFile.restype = W.BOOL
K.DeleteFileW.argtypes = [W.LPCWSTR]
K.DeleteFileW.restype = W.BOOL
INVALID = ctypes.c_void_p(-1).value
OLD = b"acknowledged old head\x00" * 67
NEW = b"intended new head\x00" * 79


class Diagnostic:
    def __init__(self, exe):
        self.exe = exe.resolve()
        self.assertions = 0
        self.observed = []
        self.timings = []
        self.prefix = f"minimal46i1_{os.getpid()}_{time.time_ns()}_"
        self.roots = []

    def check(self, value, message):
        self.assertions += 1
        if not value:
            raise AssertionError(message)

    def fixture(self, label, first=False, new=NEW):
        p = Path(os.environ["LOCALAPPDATA"]) / "itank-storage-tests" / (self.prefix + label)
        p.mkdir(parents=True, exist_ok=False)
        (p / "stage.bin").write_bytes(new)
        (p / "expected.bin").write_bytes(OLD)
        if not first:
            (p / "head.bin").write_bytes(OLD)
        self.roots.append(str(p))
        return p

    def run(self, p, mode="replace"):
        started = time.perf_counter_ns()
        r = subprocess.run([str(self.exe), mode, str(p), "none"], capture_output=True, text=True, timeout=20, shell=False)
        elapsed = (time.perf_counter_ns() - started) / 1e6
        self.check(not r.stderr, "No hidden native error output: " + r.stderr)
        v = json.loads(r.stdout)
        self.check(v["protocol"] == 1 and not v["power_loss_guaranteed"], "Explicit protocol, no power-loss claim")
        self.observed.append({"case": p.name.removeprefix(self.prefix), "exit": r.returncode, **v})
        self.timings.append({"case": p.name.removeprefix(self.prefix), "mode": mode, "process_ms": elapsed})
        return r.returncode, v

    def paused(self, p, at, mode="replace"):
        child = subprocess.Popen([str(self.exe), mode, str(p), at], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=False)
        until = time.monotonic() + 10
        while not (p / ("reached." + at)).exists():
            if child.poll() is not None:
                out, err = child.communicate()
                raise AssertionError(f"Child ended before diagnostic barrier: {out} {err}")
            if time.monotonic() > until:
                child.kill(); child.communicate()
                raise AssertionError("Child failed to reach barrier")
            time.sleep(.005)
        return child

    def verify(self, p, value):
        (p / "verify.bin").write_bytes(value)
        code, v = self.run(p, "verify")
        self.check(code == 0 and v["state"] == "exact", "Fresh-process exact verification of expected bytes")

    def hold(self, p, share=0, access=0x80000000):
        h = K.CreateFileW(str(p), access, share, None, 3, 128, None)
        self.check(h != INVALID, f"Actual Windows file handle opened, error {ctypes.get_last_error()}")
        return h

    def preservation(self, p, code, v):
        self.check(code != 0 and v["state"] in ["rejected", "failed_preserved"], "Failure must not claim publication")
        self.check((p / "head.bin").read_bytes() == OLD, "Known failure preserves exact acknowledged old authority")
        self.verify(p, OLD)

    def execute(self):
        p = self.fixture("normal")
        code, v = self.run(p)
        self.check(code == 0 and v["api_success"] and v["state"] == "published_verified", "Normal native replacement/readback")
        self.check(not (p / "stage.bin").exists(), "No copy/delete or lingering staged source on success")
        self.verify(p, NEW)

        for label, action, error in [
            ("missing_stage", lambda p: (p / "stage.bin").unlink(), 2),
            ("stale_expected", lambda p: (p / "expected.bin").write_bytes(b"different"), 1306),
            ("oversize_stage", lambda p: (p / "stage.bin").write_bytes(b"x" * 65537), 13),
            ("empty_stage", lambda p: (p / "stage.bin").write_bytes(b""), 13),
        ]:
            p = self.fixture(label); action(p)
            code, v = self.run(p)
            self.check(v["win32_error"] == error and not v["api_called"], "Exact preflight error, no native replacement")
            self.preservation(p, code, v)

        for label, target, share in [("locked_stage", "stage.bin", 3), ("locked_destination", "head.bin", 0)]:
            p = self.fixture(label); h = self.hold(p / target, share)
            try:
                code, v = self.run(p)
                self.check(v["win32_error"] == 32 and not v["api_called"], "Exact sharing-violation preflight")
            finally:
                K.CloseHandle(h)
            self.preservation(p, code, v)

        p = self.fixture("hardlink_stage")
        os.link(p / "stage.bin", p / "alias.bin")
        code, v = self.run(p)
        self.check(not v["api_called"] and v["win32_error"] == 13, "Hardlinks rejected rather than using ambiguous source identity")
        self.preservation(p, code, v)

        outside = Path(os.environ["TEMP"]) / ("arena46i1_forbidden_" + str(time.time_ns()))
        outside.mkdir()
        before = list(outside.iterdir())
        code, v = self.run(outside)
        self.check(code != 0 and v["phase"] == "disposable_context" and list(outside.iterdir()) == before,
                   "Outside-prefix directory rejected without writing lock or sentinel")

        # A reader sharing READ/WRITE but not DELETE permits validation reads,
        # then blocks the actual native replacement. This reaches MoveFileExW.
        p = self.fixture("native_destination_failure")
        h = self.hold(p / "head.bin", 3)
        try:
            code, v = self.run(p)
            self.check(v["api_called"] and not v["api_success"] and v["win32_error"] in [5, 32], "Actual native move error reported exactly")
        finally:
            K.CloseHandle(h)
        self.preservation(p, code, v)

        p = self.fixture("delete_sharing_reader")
        h = self.hold(p / "head.bin", 7)
        try:
            code, v = self.run(p)
            # Windows/filesystem may still reject a held destination. Either
            # old authority or the exact new file is legal; never missing data.
            self.check(v["api_called"], "Compatible reader reaches native call")
        finally:
            K.CloseHandle(h)
        if code == 0:
            self.verify(p, NEW)
        else:
            self.preservation(p, code, v)

        for label in ["first", "first_race"]:
            p = self.fixture(label, first=True)
            if label == "first_race":
                child = self.paused(p, "before_api", "first")
                (p / "head.bin").write_bytes(OLD)
                (p / "continue.before_api").write_bytes(b"continue")
                out, err = child.communicate(timeout=20)
                v = json.loads(out)
                self.check(child.returncode != 0 and v["api_called"] and not v["api_success"] and not err, "First publication cannot overwrite a destination created after precheck")
                self.verify(p, OLD)
            else:
                code, v = self.run(p, "first")
                self.check(code == 0 and v["api_success"], "First publication into empty destination")
                self.verify(p, NEW)
                (p / "stage.bin").write_bytes(OLD)
                code, v = self.run(p, "first")
                self.check(code != 0 and not v["api_called"] and v["win32_error"] == 80, "First mode refuses existing destination")
                self.verify(p, NEW)

        p = self.fixture("competing_writers")
        child = self.paused(p, "before_api")
        code, v = self.run(p)
        self.check(code != 0 and v["phase"] == "writer_lock" and v["win32_error"] == 32, "Competing real process cannot enter replacement")
        (p / "continue.before_api").write_bytes(b"continue")
        out, err = child.communicate(timeout=20)
        self.check(child.returncode == 0 and json.loads(out)["state"] == "published_verified" and not err, "Original owner alone publishes")
        self.verify(p, NEW)
        (p / "stage.bin").write_bytes(b"rival later candidate")
        code, v = self.run(p)
        self.check(code != 0 and v["win32_error"] == 1306, "Later writer cannot overwrite stale expected head")
        self.verify(p, NEW)

        # Kill actual OS processes at four known stages, repeat three times per
        # stage. This does not claim termination inside a kernel rename syscall.
        for mode in ["replace", "first"]:
            for at in ["before_flush", "before_api", "after_api", "after_readback"]:
                for repeat in range(3):
                    p = self.fixture(f"crash_{mode}_{at}_{repeat}", first=mode == "first")
                    child = self.paused(p, at, mode)
                    self.check(child.poll() is None, "Child demonstrably alive at diagnostic barrier")
                    child.kill(); out, err = child.communicate(timeout=10)
                    self.check(child.returncode != 0 and not out and not err, "Actual TerminateProcess, no false success response")
                    self.observed.append({"case": "crash", "mode": mode, "barrier": at, "repeat": repeat,
                                          "terminated_exit": child.returncode, "no_success_response": not out})
                    expected = NEW if at in ["after_api", "after_readback"] else (OLD if mode == "replace" else None)
                    if expected is None:
                        self.check(not (p / "head.bin").exists(), "Interrupted first publication remains absent before API")
                    else:
                        self.verify(p, expected)
                    if at in ["before_flush", "before_api"]:
                        code, v = self.run(p, mode)
                        self.check(code == 0, "Kernel-released writer handle allows exact retry after process death")
                        self.verify(p, NEW)

        # Success at syscall is not enough: deliberately make readback unknown.
        p = self.fixture("readback_missing")
        child = self.paused(p, "after_api")
        self.check(bool(K.DeleteFileW(str(p / "head.bin"))), "Inject removal of disposable new head after native call")
        (p / "continue.after_api").write_bytes(b"continue")
        out, err = child.communicate(timeout=20); v = json.loads(out)
        self.observed.append({"case": "injected_readback_missing", "exit": child.returncode, **v})
        self.check(child.returncode == 3 and v["state"] == "uncertain" and v["api_success"] and v["readback_error"] == 2 and not err,
                   "Missing independent readback remains uncertain, never acknowledged")

        # Continuous concurrent reader: sample complete files while repeated
        # native replacements run. Reader shares delete; a native rejection is
        # legal and must leave the old value intact.
        p = self.fixture("reader_stress", new=b"B" * 65536)
        (p / "head.bin").write_bytes(b"A" * 65536)
        choices = [b"A" * 65536, b"B" * 65536]
        stop = threading.Event(); read_errors = []; samples = []
        def reader():
            while not stop.is_set():
                h = K.CreateFileW(str(p / "head.bin"), 0x80000000, 7, None, 3, 128, None)
                if h == INVALID:
                    read_errors.append(("open", ctypes.get_last_error())); continue
                data = ctypes.create_string_buffer(65536); n = W.DWORD()
                ok = K.ReadFile(h, data, 65536, ctypes.byref(n), None); K.CloseHandle(h)
                if not ok or n.value != 65536 or data.raw not in choices:
                    read_errors.append(("partial", n.value))
                samples.append(1)
        thread = threading.Thread(target=reader); thread.start()
        published = rejected = 0; current = choices[0]
        try:
            for i in range(20):
                proposed = choices[1] if current == choices[0] else choices[0]
                (p / "expected.bin").write_bytes(current); (p / "stage.bin").write_bytes(proposed)
                code, v = self.run(p)
                if code == 0: current = proposed; published += 1
                else:
                    self.check(v["state"] == "failed_preserved", "Concurrent-reader rejection has exact old readback")
                    rejected += 1
        finally:
            stop.set(); thread.join(timeout=10)
        self.check(not thread.is_alive() and not read_errors and samples, "No missing, partial or invented bytes observed by concurrent readers")
        self.verify(p, current)
        self.observed.append({"case": "reader_stress_summary", "samples": len(samples), "published": published, "rejected_preserved": rejected})

        p = self.fixture("large_limit", new=b"Z" * 65536)
        code, v = self.run(p)
        self.check(code == 0, "Maximum bounded head size supported")
        self.verify(p, b"Z" * 65536)

        report = {"assertions": self.assertions, "failures": [], "exe_sha256": hashlib.sha256(self.exe.read_bytes()).hexdigest(),
                  "observations": self.observed, "timings": self.timings, "roots": self.roots,
                  "scope": "Sentinel primitive diagnostics only; no snapshot/storage/character or power-loss acceptance"}
        print(json.dumps(report, indent=2))
        return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    report = Diagnostic(args.exe).execute()
    if args.report:
        output = args.report.resolve()
        allowed = Path(os.environ["TEMP"]).resolve()
        if not output.is_relative_to(allowed): raise ValueError("Diagnostic report must stay in TEMP")
        output.write_text(json.dumps(report, indent=2), encoding="utf-8")
