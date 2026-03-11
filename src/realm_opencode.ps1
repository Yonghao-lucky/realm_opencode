# realm_opencode.ps1

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir = Split-Path -Parent $ScriptPath
$ConfigDir = Join-Path $env:USERPROFILE ".config/opencode"
$ConfigFile = Join-Path $ConfigDir "opencode.json"
$BackupDir = Join-Path $ConfigDir "backups"
$ApiBaseUrl = "https://realmrouter.cn/v1"
$DefaultModel = "gpt-5.4"

$ModelsJson = @'
[
  {"id": "deepseek-ai/DeepSeek-R1", "name": "DeepSeek R1", "group": "DeepSeek"},
  {"id": "deepseek-ai/DeepSeek-R1-0528", "name": "DeepSeek R1 (0528)", "group": "DeepSeek"},
  {"id": "deepseek-ai/DeepSeek-V3.1", "name": "DeepSeek V3.1", "group": "DeepSeek"},
  {"id": "deepseek-ai/DeepSeek-V3.1-Terminus", "name": "DeepSeek V3.1 Terminus", "group": "DeepSeek"},
  {"id": "deepseek-ai/DeepSeek-V3.2-Exp", "name": "DeepSeek V3.2 Exp", "group": "DeepSeek"},
  {"id": "claude-haiku-4.5", "name": "Claude Haiku 4.5", "group": "Anthropic"},
  {"id": "claude-sonnet-4-5", "name": "Claude Sonnet 4.5", "group": "Anthropic"},
  {"id": "gemini-3.1-pro-high", "name": "Gemini 3.1 Pro High", "group": "Google"},
  {"id": "gemini-3.1-pro-low", "name": "Gemini 3.1 Pro Low", "group": "Google"},
  {"id": "MiniMaxAI/MiniMax-M2.1", "name": "MiniMax M2.1", "group": "MiniMax"},
  {"id": "MiniMaxAI/MiniMax-M2.5", "name": "MiniMax M2.5", "group": "MiniMax"},
  {"id": "moonshotai/Kimi-K2.5", "name": "Kimi K2.5", "group": "Moonshot"},
  {"id": "moonshotai/Kimi-K2-Thinking", "name": "Kimi K2 Thinking", "group": "Moonshot"},
  {"id": "gpt-5.2", "name": "GPT-5.2", "group": "OpenAI"},
  {"id": "gpt-5.2-codex", "name": "GPT-5.2 Codex", "group": "OpenAI"},
  {"id": "gpt-5.3-codex", "name": "GPT-5.3 Codex", "group": "OpenAI"},
  {"id": "gpt-5.4", "name": "GPT-5.4", "group": "OpenAI"},
  {"id": "openai/gpt-oss-120b", "name": "GPT OSS 120B", "group": "OpenAI"},
  {"id": "doubao-seed-code-preview-251028", "name": "Doubao Seed Code Preview", "group": "ByteDance"},
  {"id": "zai-org/GLM-4.7", "name": "GLM 4.7", "group": "Z.AI"},
  {"id": "zai-org/GLM-4.6V", "name": "GLM 4.6V", "group": "Z.AI"},
  {"id": "zai-org/GLM-5", "name": "GLM 5", "group": "Z.AI"},
  {"id": "qwen3-coder-plus", "name": "Qwen3 Coder Plus", "group": "Qwen"},
  {"id": "qwen3-max", "name": "Qwen3 Max", "group": "Qwen"},
  {"id": "qwen3-max-preview", "name": "Qwen3 Max Preview", "group": "Qwen"},
  {"id": "qwen3-vl-plus", "name": "Qwen3 VL Plus", "group": "Qwen"},
  {"id": "qwen3-vl-max", "name": "Qwen3 VL Max", "group": "Qwen"},
  {"id": "Qwen/Qwen3-Coder-480B-A35B-Instruct", "name": "Qwen3 Coder 480B", "group": "Qwen"},
  {"id": "Qwen/Qwen3-Coder-Next", "name": "Qwen3 Coder Next", "group": "Qwen"},
  {"id": "Qwen/Qwen3.5", "name": "Qwen3.5", "group": "Qwen"}
]
'@

function Write-Info($Message) { Write-Host "[i] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[ok] $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Fail($Message) { Write-Host "[x] $Message" -ForegroundColor Red }

function Ensure-Environment {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

function Get-ModelCatalog {
    return $ModelsJson | ConvertFrom-Json
}

function Backup-Config {
    if (Test-Path $ConfigFile) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $BackupDir "opencode.json.bak.$timestamp"
        Copy-Item $ConfigFile $backupFile -Force
        Write-Ok "Backup created: $backupFile"
    } else {
        Write-Info "No existing config found. A new one will be created."
    }
}

function Get-ApiKey([string]$InputKey) {
    if ($InputKey) { return $InputKey }
    $key = Read-Host "Enter your RealmRouter API key"
    if (-not $key) {
        Write-Fail "API key cannot be empty."
        exit 1
    }
    return $key
}

function Test-RealmRouterApiKey {
    param(
        [string]$ApiKey,
        [string]$ModelId = $DefaultModel
    )

    $body = @{
        model = $ModelId
        messages = @(@{ role = "user"; content = "hi" })
        max_tokens = 1
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri "$ApiBaseUrl/chat/completions" -Method Post -Headers @{
            Authorization = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        } -Body $body | Out-Null
        Write-Ok "API test succeeded for model: $ModelId"
        return $true
    } catch {
        Write-Fail "API test failed for model $ModelId"
        return $false
    }
}

function Load-Config {
    if (-not (Test-Path $ConfigFile)) {
        return @{}
    }
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json -AsHashtable
        if ($null -eq $config) { return @{} }
        return $config
    } catch {
        Write-Fail "Existing config is not valid JSON."
        exit 1
    }
}

function Save-Config([hashtable]$Config) {
    $Config | ConvertTo-Json -Depth 100 | Set-Content $ConfigFile -Encoding UTF8
}

function Get-RealmProvider([string]$ApiKey) {
    $models = @{}
    foreach ($item in Get-ModelCatalog) {
        $models[$item.id] = @{ name = $item.name }
    }
    return @{
        npm = "@ai-sdk/openai-compatible"
        options = @{
            baseURL = "https://realmrouter.cn/v1"
            apiKey = $ApiKey
        }
        models = $models
    }
}

function Install-RealmRouter {
    param(
        [string]$ApiKey,
        [bool]$SkipVerify = $false
    )

    if (-not $SkipVerify) {
        if (-not (Test-RealmRouterApiKey -ApiKey $ApiKey -ModelId $DefaultModel)) {
            exit 1
        }
    }

    Backup-Config
    $config = Load-Config
    $config['$schema'] = 'https://opencode.ai/config.json'
    if (-not ($config['provider'] -is [hashtable])) {
        $config['provider'] = @{}
    }
    $config['provider']['realmrouter'] = Get-RealmProvider -ApiKey $ApiKey
    $config['model'] = "realmrouter/$DefaultModel"
    Save-Config $config
    Write-Ok "Config written to $ConfigFile"
    Write-Info "If OpenCode is already running, restart it first. Then run /models to switch to any RealmRouter model."
}

function Update-RealmRouterKey {
    param(
        [string]$ApiKey,
        [bool]$SkipVerify = $false
    )

    $config = Load-Config
    $modelId = $DefaultModel
    if ($config.ContainsKey('model') -and $config['model'] -like 'realmrouter/*') {
        $modelId = $config['model'].Substring('realmrouter/'.Length)
    }

    if (-not $SkipVerify) {
        if (-not (Test-RealmRouterApiKey -ApiKey $ApiKey -ModelId $modelId)) {
            exit 1
        }
    }

    Backup-Config
    if (-not ($config['provider'] -is [hashtable])) {
        $config['provider'] = @{}
    }
    if (-not ($config['provider']['realmrouter'] -is [hashtable])) {
        Write-Warn "RealmRouter provider not found. Running full install instead."
        Install-RealmRouter -ApiKey $ApiKey -SkipVerify:$true
        return
    }
    if (-not ($config['provider']['realmrouter']['options'] -is [hashtable])) {
        $config['provider']['realmrouter']['options'] = @{}
    }
    $config['provider']['realmrouter']['options']['baseURL'] = 'https://realmrouter.cn/v1'
    $config['provider']['realmrouter']['options']['apiKey'] = $ApiKey
    Save-Config $config
    Write-Ok "RealmRouter API key updated."
}

function Select-RealmRouterModel {
    $models = Get-ModelCatalog
    for ($i = 0; $i -lt $models.Count; $i++) {
        $item = $models[$i]
        Write-Host ("[{0}] {1} | {2} | {3}" -f ($i + 1), $item.group, $item.name, $item.id)
    }
    $selection = Read-Host "Choose a model number"
    if (-not ($selection -match '^[0-9]+$')) {
        Write-Fail "Invalid model selection."
        exit 1
    }
    $index = [int]$selection - 1
    if ($index -lt 0 -or $index -ge $models.Count) {
        Write-Fail "Invalid model selection."
        exit 1
    }
    return $models[$index].id
}

function Switch-RealmRouterModel([string]$ModelId) {
    $models = Get-ModelCatalog
    $validIds = @($models | ForEach-Object { $_.id })
    if ($validIds -notcontains $ModelId) {
        Write-Fail "Model id not found in bundled catalog: $ModelId"
        exit 1
    }

    if (-not (Test-Path $ConfigFile)) {
        Write-Fail "Config file not found: $ConfigFile"
        exit 1
    }

    Backup-Config
    $config = Load-Config
    $config['model'] = "realmrouter/$ModelId"
    Save-Config $config
    Write-Ok "Default model changed to realmrouter/$ModelId"
    Write-Info "If OpenCode is already running, restart it first. Then users can run /models after startup to pick another RealmRouter model."
}

function Restore-RealmRouterBackup {
    $backups = Get-ChildItem $BackupDir -Filter 'opencode.json.bak.*' | Sort-Object Name -Descending
    if (-not $backups) {
        Write-Fail "No backups found in $BackupDir"
        exit 1
    }

    for ($i = 0; $i -lt $backups.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $backups[$i].FullName)
    }

    $selection = Read-Host "Choose a backup number to restore"
    if (-not ($selection -match '^[0-9]+$')) {
        Write-Fail "Invalid backup selection."
        exit 1
    }

    $index = [int]$selection - 1
    if ($index -lt 0 -or $index -ge $backups.Count) {
        Write-Fail "Invalid backup selection."
        exit 1
    }

    Copy-Item $backups[$index].FullName $ConfigFile -Force
    Write-Ok "Restored backup to $ConfigFile"
}

function Test-RealmRouterCurrentConfig {
    $config = Load-Config
    try {
        $apiKey = $config['provider']['realmrouter']['options']['apiKey']
    } catch {
        Write-Fail "Could not read RealmRouter API key from $ConfigFile"
        exit 1
    }

    $modelId = $DefaultModel
    if ($config.ContainsKey('model') -and $config['model'] -like 'realmrouter/*') {
        $modelId = $config['model'].Substring('realmrouter/'.Length)
    }

    if (-not (Test-RealmRouterApiKey -ApiKey $apiKey -ModelId $modelId)) {
        exit 1
    }
}

function Show-Models {
    foreach ($item in Get-ModelCatalog) {
        Write-Host ("{0,-10} {1} ({2})" -f $item.group, $item.id, $item.name)
    }
}

function Show-Menu {
    Write-Host "========================================"
    Write-Host "   RealmRouter OpenCode Manager"
    Write-Host "========================================"
    Write-Host " [1] Install / Reset RealmRouter config"
    Write-Host " [2] Update API key"
    Write-Host " [3] Switch default model"
    Write-Host " [4] Restore backup"
    Write-Host " [5] Test connectivity"
    Write-Host " [6] List bundled models"
    Write-Host " [q] Quit"
}

function Start-InteractiveMenu {
    while ($true) {
        Write-Host ""
        Show-Menu
        $choice = Read-Host "Choose an option"
        switch ($choice) {
            '1' {
                $apiKey = Get-ApiKey ""
                Install-RealmRouter -ApiKey $apiKey
            }
            '2' {
                $apiKey = Get-ApiKey ""
                Update-RealmRouterKey -ApiKey $apiKey
            }
            '3' {
                $modelId = Select-RealmRouterModel
                Switch-RealmRouterModel -ModelId $modelId
            }
            '4' { Restore-RealmRouterBackup }
            '5' { Test-RealmRouterCurrentConfig }
            '6' { Show-Models }
            'q' { exit 0 }
            'Q' { exit 0 }
            default { Write-Warn "Unknown option." }
        }
    }
}

function Show-Usage {
    @"
Usage:
  .\realm_opencode.ps1
  .\realm_opencode.ps1 install [-ApiKey <key>] [-SkipVerify]
  .\realm_opencode.ps1 update-key [-ApiKey <key>] [-SkipVerify]
  .\realm_opencode.ps1 switch-model [-ModelId <id>]
  .\realm_opencode.ps1 test
  .\realm_opencode.ps1 restore
  .\realm_opencode.ps1 list-models
"@
}

Ensure-Environment

$Command = if ($args.Count -gt 0) { $args[0] } else { "" }

switch ($Command) {
    "" { Start-InteractiveMenu }
    "install" {
        $apiKey = ""
        $skipVerify = $false
        for ($i = 1; $i -lt $args.Count; $i++) {
            switch ($args[$i]) {
                "-ApiKey" { $i++; $apiKey = $args[$i] }
                "-SkipVerify" { $skipVerify = $true }
                default { Write-Fail "Unknown argument: $($args[$i])"; Show-Usage; exit 1 }
            }
        }
        $apiKey = Get-ApiKey $apiKey
        Install-RealmRouter -ApiKey $apiKey -SkipVerify:$skipVerify
    }
    "update-key" {
        $apiKey = ""
        $skipVerify = $false
        for ($i = 1; $i -lt $args.Count; $i++) {
            switch ($args[$i]) {
                "-ApiKey" { $i++; $apiKey = $args[$i] }
                "-SkipVerify" { $skipVerify = $true }
                default { Write-Fail "Unknown argument: $($args[$i])"; Show-Usage; exit 1 }
            }
        }
        $apiKey = Get-ApiKey $apiKey
        Update-RealmRouterKey -ApiKey $apiKey -SkipVerify:$skipVerify
    }
    "switch-model" {
        $modelId = if ($args.Count -gt 1) { $args[1] } else { Select-RealmRouterModel }
        Switch-RealmRouterModel -ModelId $modelId
    }
    "test" { Test-RealmRouterCurrentConfig }
    "restore" { Restore-RealmRouterBackup }
    "list-models" { Show-Models }
    "-h" { Show-Usage }
    "--help" { Show-Usage }
    "help" { Show-Usage }
    default {
        Write-Fail "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}
