#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
CONFIG_DIR=""
CONFIG_FILE=""
BACKUP_DIR=""
CONFIG_SOURCE=""
CONFIG_OVERRIDE="${OPENCODE_CONFIG:-}"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
API_BASE_URL="https://realmrouter.cn/v1"
DEFAULT_MODEL="gpt-5.4"

read -r -d '' MODELS_JSON <<'EOF' || true
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
EOF

print_info() {
    printf '[i] %s\n' "$1"
}

print_ok() {
    printf '[ok] %s\n' "$1"
}

print_warn() {
    printf '[!] %s\n' "$1"
}

print_error() {
    printf '[x] %s\n' "$1" >&2
}

usage() {
    cat <<'EOF'
用法:
  ./realm_opencode.sh
  ./realm_opencode.sh [--config <path>] install [--api-key <key>] [--skip-verify]
  ./realm_opencode.sh [--config <path>] update-key [--api-key <key>] [--skip-verify]
  ./realm_opencode.sh [--config <path>] switch-model [model-id]
  ./realm_opencode.sh [--config <path>] test
  ./realm_opencode.sh [--config <path>] restore
  ./realm_opencode.sh list-models

命令:
  install        备份并写入 RealmRouter 到 OpenCode 配置
  update-key     仅更新 RealmRouter API Key
  switch-model   设置 OpenCode 默认使用的 RealmRouter 模型
  test           测试当前 Key 和模型是否可以连通 RealmRouter
  restore        从备份恢复配置文件
  list-models    输出模型列表（优先实时获取）

配置路径查找顺序:
  1. --config 显式传入路径
  2. 环境变量 OPENCODE_CONFIG
  3. 已存在的 $XDG_CONFIG_HOME/opencode/opencode.json
  4. 已存在的 $HOME/.config/opencode/opencode.json
  5. 默认写入到上述优先级更高的目录
EOF
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        print_error "缺少依赖命令: $1"
        exit 1
    fi
}

ensure_env() {
    require_cmd python3
    require_cmd curl
}

resolve_config_path() {
    local xdg_home="${XDG_CONFIG_HOME:-}"
    local xdg_candidate=""
    local home_candidate="$HOME/.config/opencode/opencode.json"

    if [ -n "$xdg_home" ]; then
        xdg_candidate="$xdg_home/opencode/opencode.json"
    fi

    if [ -n "$CONFIG_OVERRIDE" ]; then
        CONFIG_FILE="$CONFIG_OVERRIDE"
        CONFIG_SOURCE="override"
    elif [ -n "$xdg_candidate" ] && [ -f "$xdg_candidate" ]; then
        CONFIG_FILE="$xdg_candidate"
        CONFIG_SOURCE="existing-xdg"
    elif [ -f "$home_candidate" ]; then
        CONFIG_FILE="$home_candidate"
        CONFIG_SOURCE="existing-home"
    elif [ -n "$xdg_candidate" ]; then
        CONFIG_FILE="$xdg_candidate"
        CONFIG_SOURCE="default-xdg"
    else
        CONFIG_FILE="$home_candidate"
        CONFIG_SOURCE="default-home"
    fi

    CONFIG_DIR="$(dirname "$CONFIG_FILE")"
    BACKUP_DIR="$CONFIG_DIR/backups"
}

ensure_config_dirs() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR"
}

prompt_api_key() {
    local key="${1:-}"
    if [ -n "$key" ]; then
        printf '%s' "$key"
        return 0
    fi
    read -r -p "请输入你的 RealmRouter API Key: " key
    if [ -z "$key" ]; then
        print_error "API Key 不能为空。"
        exit 1
    fi
    printf '%s' "$key"
}

backup_config() {
    if [ -f "$CONFIG_FILE" ]; then
        ensure_config_dirs
        local backup_file="$BACKUP_DIR/opencode.json.bak.$TIMESTAMP"
        cp "$CONFIG_FILE" "$backup_file"
        print_ok "已创建备份: $backup_file"
    else
        print_info "未发现已有配置，将创建新的配置文件。"
    fi
}

verify_api_key() {
    local key="$1"
    local model_id="${2:-$DEFAULT_MODEL}"
    local payload
    local response
    local http_code

    payload=$(python3 - "$model_id" <<'PY'
import json
import sys
print(json.dumps({
    "model": sys.argv[1],
    "messages": [{"role": "user", "content": "hi"}],
    "max_tokens": 1
}))
PY
)

    response=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE_URL/chat/completions" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null || true)

    http_code=$(printf '%s' "$response" | python3 -c 'import sys; lines=sys.stdin.read().splitlines(); print(lines[-1] if lines else "")')
    if [ "$http_code" = "200" ]; then
        print_ok "API 测试成功，模型: $model_id"
        return 0
    fi

    print_error "API 测试失败，模型: $model_id (HTTP ${http_code:-unknown})。"
    return 1
}

load_model_names() {
    local api_key="${1:-}"
    local models_json
    models_json=$(get_models_json "$api_key")
    MODELS_JSON_DATA="$models_json" python3 - <<'PY'
import json
import os
models = json.loads(os.environ['MODELS_JSON_DATA'])
for item in models:
    print(f"{item['group']}\t{item['id']}\t{item['name']}")
PY
}

fetch_remote_models_json() {
    local api_key="$1"
    [ -n "$api_key" ] || return 1

    local response
    local http_code
    response=$(curl -s -w "\n%{http_code}" -X GET "$API_BASE_URL/models" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" 2>/dev/null || true)
    http_code=$(printf '%s' "$response" | python3 -c 'import sys; lines=sys.stdin.read().splitlines(); print(lines[-1] if lines else "")')
    [ "$http_code" = "200" ] || return 1

    printf '%s' "$response" | python3 -c '
import json
import sys

def classify_provider(model_id):
    lower = model_id.lower()
    if lower.startswith("claude") or lower.startswith("anthropic/"):
        return "Anthropic"
    if lower.startswith("gemini") or lower.startswith("google/"):
        return "Google"
    if lower.startswith("moonshot") or "kimi" in lower:
        return "Moonshot"
    if lower.startswith("minimax") or "minimax" in lower:
        return "MiniMax"
    if lower.startswith("doubao") or "bytedance" in lower:
        return "ByteDance"
    if lower.startswith("zai-org/") or lower.startswith("glm"):
        return "Z.AI"
    if lower.startswith("qwen") or "qwen" in lower:
        return "Qwen"
    if lower.startswith("deepseek") or "deepseek" in lower:
        return "DeepSeek"
    if lower.startswith("gpt") or lower.startswith("openai/"):
        return "OpenAI"
    return "Other"

lines = sys.stdin.read().splitlines()
payload = json.loads("\n".join(lines[:-1]))
models = []
for item in payload.get("data", []):
    model_id = item.get("id")
    if not model_id:
        continue
    models.append({
        "id": model_id,
        "name": item.get("name") or model_id,
        "group": classify_provider(model_id),
    })
models.sort(key=lambda item: (item["group"], item["name"].lower()))
print(json.dumps(models, ensure_ascii=False))
' || return 1
}

get_models_json() {
    local api_key="${1:-}"
    local models_json
    if models_json=$(fetch_remote_models_json "$api_key"); then
        printf '%s' "$models_json"
        return 0
    fi
    if [ -n "$api_key" ]; then
        print_warn "实时拉取模型列表失败，已回退到内置模型列表。" >&2
    fi
    printf '%s' "$MODELS_JSON"
}

list_models() {
    local api_key=""
    api_key=$(get_current_key 2>/dev/null || true)
    load_model_names "$api_key" | while IFS=$'\t' read -r group model_id name; do
        printf '%-10s %s (%s)\n' "$group" "$model_id" "$name"
    done
}

choose_model_interactive() {
    local api_key="${1:-}"
    local models_json
    models_json=$(get_models_json "$api_key")
    MODELS_JSON_DATA="$models_json" python3 - <<'PY' >&2
import json
import os
models = json.loads(os.environ['MODELS_JSON_DATA'])
for idx, item in enumerate(models, start=1):
    print(f"[{idx}] {item['group']} | {item['name']} | {item['id']}")
PY
    local selection
    read -r -p "请输入模型编号: " selection
    MODELS_JSON_DATA="$models_json" python3 - "$selection" <<'PY'
import json
import os
import sys
models = json.loads(os.environ['MODELS_JSON_DATA'])
try:
    index = int(sys.argv[1]) - 1
except ValueError:
    sys.exit(1)
if 0 <= index < len(models):
    print(models[index]['id'])
    sys.exit(0)
sys.exit(1)
PY
}

write_or_update_config() {
    local api_key="$1"
    local model_id="${2:-$DEFAULT_MODEL}"
    local models_json
    models_json=$(get_models_json "$api_key")
    MODELS_JSON_DATA="$models_json" python3 - "$CONFIG_FILE" "$api_key" "$model_id" <<'PY'
import json
import os
import sys

config_path, api_key, default_model = sys.argv[1:4]

def load_json(path, fallback):
    if not os.path.exists(path):
        return fallback
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data if isinstance(data, type(fallback)) else fallback

config = load_json(config_path, {})
models = json.loads(os.environ['MODELS_JSON_DATA'])

config['$schema'] = 'https://opencode.ai/config.json'
provider = config.get('provider')
if not isinstance(provider, dict):
    provider = {}
config['provider'] = provider

provider['realmrouter'] = {
    'npm': '@ai-sdk/openai-compatible',
    'options': {
        'baseURL': 'https://realmrouter.cn/v1',
        'apiKey': api_key,
    },
    'models': {item['id']: {'name': item['name']} for item in models},
}

config['model'] = f'realmrouter/{default_model}'

with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write('\n')

print(config['model'])
PY
}

update_key_only() {
    local api_key="$1"
    local models_json
    models_json=$(get_models_json "$api_key")
    MODELS_JSON_DATA="$models_json" python3 - "$CONFIG_FILE" "$api_key" <<'PY'
import json
import os
import sys

config_path, api_key = sys.argv[1:3]
if not os.path.exists(config_path):
    print('missing')
    sys.exit(2)

with open(config_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

provider = config.get('provider')
if not isinstance(provider, dict) or 'realmrouter' not in provider:
    print('missing')
    sys.exit(2)

realm = provider['realmrouter']
options = realm.get('options')
if not isinstance(options, dict):
    options = {}
realm['options'] = options
options['baseURL'] = 'https://realmrouter.cn/v1'
options['apiKey'] = api_key
models = json.loads(os.environ['MODELS_JSON_DATA'])
realm['models'] = {item['id']: {'name': item['name']} for item in models}

with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write('\n')
print('ok')
PY
}

switch_model_config() {
    local model_id="$1"
    local api_key="${2:-}"
    local models_json
    models_json=$(get_models_json "$api_key")
    MODELS_JSON_DATA="$models_json" python3 - "$CONFIG_FILE" "$model_id" <<'PY'
import json
import os
import sys

config_path, model_id = sys.argv[1:3]
if not os.path.exists(config_path):
    print('missing-config')
    sys.exit(2)

models = json.loads(os.environ['MODELS_JSON_DATA'])
valid = {item['id'] for item in models}
if model_id not in valid:
    print('missing-model')
    sys.exit(3)

with open(config_path, 'r', encoding='utf-8') as f:
    config = json.load(f)

config['model'] = f'realmrouter/{model_id}'
with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write('\n')
print(config['model'])
PY
}

get_current_key() {
    python3 - "$CONFIG_FILE" <<'PY'
import json
import os
import sys
if not os.path.exists(sys.argv[1]):
    sys.exit(1)
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = json.load(f)
try:
    print(config['provider']['realmrouter']['options']['apiKey'])
except Exception:
    sys.exit(1)
PY
}

get_current_model() {
    python3 - "$CONFIG_FILE" <<'PY'
import json
import os
import sys
if not os.path.exists(sys.argv[1]):
    sys.exit(1)
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    config = json.load(f)
model = config.get('model', '')
if isinstance(model, str) and model.startswith('realmrouter/'):
    print(model.split('/', 1)[1])
    sys.exit(0)
sys.exit(1)
PY
}

restore_backup() {
    ensure_config_dirs
    if ! compgen -G "$BACKUP_DIR/opencode.json.bak.*" >/dev/null; then
        print_error "未在 $BACKUP_DIR 中找到备份文件。"
        exit 1
    fi

    local backups=()
    local file
    while IFS= read -r file; do
        backups+=("$file")
    done < <(python3 - "$BACKUP_DIR" <<'PY'
import glob
import os
import sys
files = sorted(glob.glob(os.path.join(sys.argv[1], 'opencode.json.bak.*')), reverse=True)
for path in files:
    print(path)
PY
)

    local i=1
    for file in "${backups[@]}"; do
        printf '[%d] %s\n' "$i" "$file"
        i=$((i + 1))
    done

    local selection
    read -r -p "请输入要恢复的备份编号: " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#backups[@]}" ]; then
        print_error "备份编号无效。"
        exit 1
    fi

    cp "${backups[$((selection - 1))]}" "$CONFIG_FILE"
    print_ok "备份已恢复到 $CONFIG_FILE"
}

install_command() {
    local api_key="$1"
    local skip_verify="$2"
    local default_model="$DEFAULT_MODEL"

    if [ "$skip_verify" != "true" ]; then
        verify_api_key "$api_key" "$default_model"
    fi

    backup_config
    ensure_config_dirs
    local configured_model
    configured_model=$(write_or_update_config "$api_key" "$default_model")
    print_ok "配置已写入 $CONFIG_FILE"
    print_info "默认模型已设置为 $configured_model"
    print_info "如 OpenCode 已在运行，请先重启；日常切换推荐在 OpenCode 内输入 /models。"
}

update_key_command() {
    local api_key="$1"
    local skip_verify="$2"
    local model_id
    model_id=$(get_current_model 2>/dev/null || printf '%s' "$DEFAULT_MODEL")

    if [ "$skip_verify" != "true" ]; then
        verify_api_key "$api_key" "$model_id"
    fi

    backup_config
    if ! update_key_only "$api_key" >/dev/null; then
        print_warn "未发现 RealmRouter provider，改为执行完整安装。"
        install_command "$api_key" "$skip_verify"
        return 0
    fi
    print_ok "RealmRouter API Key 已更新。"
}

switch_model_command() {
    local model_id="${1:-}"
    local api_key=""
    api_key=$(get_current_key 2>/dev/null || true)
    if [ -z "$model_id" ]; then
        if ! model_id=$(choose_model_interactive "$api_key"); then
            print_error "模型选择无效。"
            exit 1
        fi
    fi

    backup_config
    if ! switch_model_config "$model_id" "$api_key" >/tmp/realm_opencode_switch.out 2>/dev/null; then
        rm -f /tmp/realm_opencode_switch.out
        print_error "设置默认模型失败，请确认配置文件存在且模型 ID 正确。"
        exit 1
    fi
    rm -f /tmp/realm_opencode_switch.out
    print_ok "默认模型已设置为 realmrouter/$model_id"
    print_info "如 OpenCode 已在运行，请先重启；日常切换推荐在 OpenCode 内使用 /models。"
}

test_command() {
    local key
    local model_id
    key=$(get_current_key) || {
        print_error "无法从 $CONFIG_FILE 读取 RealmRouter API Key。"
        exit 1
    }
    model_id=$(get_current_model 2>/dev/null || printf '%s' "$DEFAULT_MODEL")
    verify_api_key "$key" "$model_id"
}

show_menu() {
    cat <<'EOF'
========================================
   RealmRouter OpenCode 管理工具
========================================
 [1] 安装/重置 RealmRouter 配置
 [2] 更新 API Key
 [3] 设置默认模型
 [4] 恢复备份
 [5] 测试连通性
 [6] 查看模型列表
 [q] 退出
EOF
}

interactive_main() {
    while true; do
        echo
        show_menu
        read -r -p "请选择菜单项: " choice
        case "$choice" in
            1)
                local api_key
                api_key=$(prompt_api_key "")
                install_command "$api_key" "false"
                ;;
            2)
                local api_key
                api_key=$(prompt_api_key "")
                update_key_command "$api_key" "false"
                ;;
            3)
                switch_model_command ""
                ;;
            4)
                restore_backup
                ;;
            5)
                test_command
                ;;
            6)
                list_models
                ;;
            q|Q)
                exit 0
                ;;
            *)
                print_warn "无效选项，请重新输入。"
                ;;
        esac
    done
}

main() {
    ensure_env

    local filtered_args=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --config)
                if [ $# -lt 2 ]; then
                    print_error "--config 需要提供路径。"
                    exit 1
                fi
                CONFIG_OVERRIDE="$2"
                shift 2
                ;;
            *)
                filtered_args+=("$1")
                shift
                ;;
        esac
    done

    resolve_config_path

    local command="${filtered_args[0]:-}"
    if [ ${#filtered_args[@]} -gt 0 ]; then
        if [ ${#filtered_args[@]} -gt 1 ]; then
            filtered_args=("${filtered_args[@]:1}")
            set -- "${filtered_args[@]}"
        else
            set --
        fi
    else
        set --
    fi

    case "$command" in
        "")
            interactive_main
            ;;
        install)
            local api_key=""
            local skip_verify="false"
            while [ $# -gt 0 ]; do
                case "$1" in
                    --api-key)
                        api_key="$2"
                        shift 2
                        ;;
                    --skip-verify)
                        skip_verify="true"
                        shift
                        ;;
                    *)
                        print_error "未知参数: $1"
                        usage
                        exit 1
                        ;;
                esac
            done
            api_key=$(prompt_api_key "$api_key")
            install_command "$api_key" "$skip_verify"
            ;;
        update-key)
            local api_key=""
            local skip_verify="false"
            while [ $# -gt 0 ]; do
                case "$1" in
                    --api-key)
                        api_key="$2"
                        shift 2
                        ;;
                    --skip-verify)
                        skip_verify="true"
                        shift
                        ;;
                    *)
                        print_error "未知参数: $1"
                        usage
                        exit 1
                        ;;
                esac
            done
            api_key=$(prompt_api_key "$api_key")
            update_key_command "$api_key" "$skip_verify"
            ;;
        switch-model)
            switch_model_command "${1:-}"
            ;;
        test)
            test_command
            ;;
        restore)
            restore_backup
            ;;
        list-models)
            list_models
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            print_error "未知命令: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
