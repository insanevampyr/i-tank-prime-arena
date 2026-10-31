param([string]$Godot = 'C:\Users\mxz\Desktop\GoDot\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'itank-arena-36k-playable-web'
New-Item -ItemType Directory -Path (Join-Path $testRoot 'out') -Force | Out-Null
# Deliberately enumerate only runtime directories and the one authored JSON.
# Never copy or inspect tmp/, the boss DOC/lock, or actual player save files.
foreach ($folder in @('scripts','data','scenes')) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot $folder) -Destination $testRoot -Recurse -Force
}
New-Item -ItemType Directory -Path (Join-Path $testRoot 'assets/Character Choices') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json') -Destination (Join-Path $testRoot 'assets/Character Choices') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'playable_persistence_acceptance.gd') -Destination $testRoot -Force
@'
config_version=5
[application]
config/name="Arena 36K Disposable Playable Persistence"
run/main_scene="res://main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $testRoot 'project.godot')
@'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://playable_persistence_acceptance.gd" id="1"]
[node name="WebAcceptance" type="Node"]
script = ExtResource("1")
'@ | Set-Content -LiteralPath (Join-Path $testRoot 'main.tscn')
@'
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="scripts/rewards/character_browser_store.js,assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json"
exclude_filter="out/*"
export_path="out/index.html"
[preset.0.options]
variant/thread_support=false
vram_texture_compression/for_desktop=true
html/canvas_resize_policy=2
'@ | Set-Content -LiteralPath (Join-Path $testRoot 'export_presets.cfg')
& $Godot --headless --editor --path $testRoot --quit *> (Join-Path $testRoot 'import.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $testRoot 'import.log') -Pattern 'SCRIPT ERROR|ERROR:')) { throw "Isolated import failed; inspect $testRoot/import.log" }
& $Godot --headless --path $testRoot --export-release Web (Join-Path $testRoot 'out/index.html') *> (Join-Path $testRoot 'export.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $testRoot 'export.log') -Pattern 'SCRIPT ERROR|ERROR:')) { throw "Isolated export failed; inspect $testRoot/export.log" }
Write-Output "Isolated playable Web build ready: $testRoot/out"
