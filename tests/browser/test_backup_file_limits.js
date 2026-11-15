"use strict";

// Isolated Node DOM/file-picker stub executing the production Web bridge.
// No IndexedDB, browser profile, output file or network access.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { File } = require("node:buffer");
const root = path.resolve(__dirname, "../..");
const source = fs.readFileSync(path.join(root, "scripts/ui/character_backup_files.gd"), "utf8");
const actions = fs.readFileSync(path.join(root, "scripts/ui/character_backup_actions.gd"), "utf8");
const cap = 130 * 1024 * 1024 + 1024;
let input;
let assertions = 0;
const check = (value, message) => { assertions++; assert.ok(value, message); };
const context = {
  window: {}, TextDecoder, Blob,
  document: {
    createElement: () => (input = { style: {}, click() {}, remove() {} }),
    body: { appendChild() {} }
  }
};
vm.runInNewContext(source.match(/const BRIDGE := """\r?\n([\s\S]*?)"""/)[1], context);
const bridge = context.window.ArenaBackupFiles;
async function select(file) {
  check(bridge.choose(cap), "Selection starts");
  check(!bridge.choose(cap), "Selection remains single-flight");
  input.files = [file];
  await input.onchange();
  return JSON.parse(bridge.poll());
}

(async () => {
  check(actions.includes("_bridge.choose(Backup.MAX_FILE_BYTES)"), "Web receives the encoded-file budget");
  check(source.includes("Backup.check_size(file.get_length(),Backup.MAX_FILE_BYTES)"), "Desktop uses the same file budget");
  const text = "é🙂" + " ".repeat(16 * 1024 * 1024);
  const large = await select(new File([text], "large.itankbackup.json"));
  check(large.state === "selected" && large.text === text, "Real UTF-8 file above the old 16 MiB limit is transferred without truncation");
  // Mock file metadata exercises the actual cap without allocating 130 MiB.
  for (const size of [cap - 1, cap]) {
    const result = await select({ size, arrayBuffer: async () => new TextEncoder().encode("{}").buffer });
    check(result.state === "selected" && result.text === "{}", "File-byte boundary is inclusive");
  }
  let reads = 0;
  const oversized = await select({ size: cap + 1, arrayBuffer() { reads++; throw Error("must not read"); } });
  check(oversized.reason === "backup_size_limit" && reads === 0, "Oversized input is rejected before allocation/read");
  const malformed = await select(new File([new Uint8Array([0xc3, 0x28])], "bad.itankbackup.json"));
  check(malformed.reason === "backup_file_read_failed", "Malformed UTF-8 remains rejected");
  const missing = await select(undefined);
  check(missing.state === "cancelled", "Empty selection changes nothing");
  check(bridge.choose(cap), "Cancellation fixture starts");
  const stale = input;
  bridge.cancel();
  stale.files = [new File(["{}"], "stale.json")];
  await stale.onchange();
  check(JSON.parse(bridge.poll()).state === "idle", "Canceled stale callback cannot select a file");
  console.log(`PASS: backup Web file bridge: ${assertions} assertions (isolated DOM stub; no live browser).`);
})().catch(error => { console.error(error); process.exitCode = 1; });
