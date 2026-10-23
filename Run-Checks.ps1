param([string]$Engine = $env:GODOT_EXE)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Engine)) {
    $engineCommand = Get-Command godot,godot4 -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($engineCommand) { $Engine = $engineCommand.Source }
} elseif (Test-Path -LiteralPath $Engine -PathType Leaf) {
    $Engine = (Resolve-Path -LiteralPath $Engine).Path
} else {
    $engineCommand = Get-Command $Engine -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($engineCommand) { $Engine = $engineCommand.Source }
}
if ([string]::IsNullOrWhiteSpace($Engine) -or -not (Test-Path -LiteralPath $Engine -PathType Leaf)) {
    throw 'Godot 4.6.3 or later was not found. Pass -Engine "path\to\Godot.exe", set GODOT_EXE, or add godot/godot4 to PATH.'
}

$projectRoot = $PSScriptRoot
$qaDir = Join-Path $projectRoot '.qa'
$runtimeDir = Join-Path $qaDir 'runtime'
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$savedTemp = $env:TEMP
$savedTmp = $env:TMP
New-Item -ItemType Directory -Path $qaDir -Force | Out-Null

function Invoke-GodotCheck {
    param([string[]]$Arguments, [string]$LogName)
    $savedErrorPreference = $ErrorActionPreference
    try {
        # Windows PowerShell can wrap harmless native stderr as an ErrorRecord.
        # Keep the output in the log and use Godot's exit code to decide failure.
        $ErrorActionPreference = 'Continue'
        & $Engine @Arguments 2>&1 | Tee-Object -FilePath (Join-Path $qaDir $LogName)
        $engineExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorPreference
    }
    if ($engineExitCode -ne 0) { throw "Godot failed with exit code ${engineExitCode}; see .qa/$LogName" }
}

try {
    # Process-local test profile. Never changes Windows settings or player saves.
    $env:APPDATA = Join-Path $runtimeDir 'AppData'
    $env:LOCALAPPDATA = Join-Path $runtimeDir 'LocalAppData'
    $env:TEMP = Join-Path $runtimeDir 'Temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA,$env:TEMP -Force | Out-Null
    $godotProject = Join-Path $projectRoot 'godot'
    Invoke-GodotCheck -Arguments @('--headless','--path',$godotProject,'--editor','--import','--quit') -LogName 'import.log'
    foreach ($suite in @('verify','hero_scale_verify','audio_verify','map_verify','map_view_verify','atmosphere_verify','theme_atmosphere_verify','enemy_animation_verify','hanshui_layout_verify','hanshui_world_layout_verify','hanshui_enemy_verify','hanshui_visual_verify','hanshui_flow_verify','combat_loop_verify','battle_art_verify','hanshui_pacing_verify','chapter_progression_verify','first_minutes_verify','combat_clarity_verify','huangzhong_support_verify','scenery_occlusion_verify','painted_assets_verify','jigu_layout_verify','jigu_flow_verify','jigu_campaign_verify','vanguard_enemy_verify','vanguard_visual_verify')) {
        Invoke-GodotCheck -Arguments @('--headless','--path',$godotProject,'--script',"res://tests/$suite.gd") -LogName "$suite.log"
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
    $env:TEMP = $savedTemp
    $env:TMP = $savedTmp
}
