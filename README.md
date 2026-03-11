# RealmRouter OpenCode Manager

**RealmRouter OpenCode Manager** 是一个用于管理 OpenCode 配置文件的脚本工具，专为希望在 OpenCode 中一键接入 RealmRouter 大模型的用户设计。

它可以帮助用户快速把 RealmRouter 的模型配置写入 OpenCode，避免手动编辑 JSON 配置出错；同时提供 API Key 更新、默认模型切换、配置备份与恢复、连通性测试等能力，让接入和日常使用都更省心。

> 💖 **Special Sponsor / 特别赞助**
>
> 本项目由 **[RealmRouter](https://realmrouter.cn)** 独家赞助支持。
>
> **🚀 限时福利活动进行中：**
> * **新人礼包**：注册即送 **5 元** 体验金，轻松体验多种主流大模型。
> * **邀请双赢**：每邀请一位好友注册，双方各得 **5 元** 余额。
>
> 👉 **[立即注册 RealmRouter](https://realmrouter.cn)**

## 功能特性

* **一键安装/重置**：自动将 RealmRouter 配置写入 `opencode.json`，并设置默认模型。
* **API Key 管理**：支持更新 RealmRouter API Key，无需手动改配置文件。
* **模型切换**：内置完整模型列表，可切换 OpenCode 默认使用的 RealmRouter 模型。
* **连通性测试**：使用当前 Key 和模型发起真实请求，快速检查配置是否可用。
* **配置备份与恢复**：修改前自动备份，支持从历史备份中恢复。
* **中文交互体验**：Linux/macOS 脚本提供中文菜单，更适合中文用户使用。

## 快速开始

### 方式一：使用源码运行（Linux/macOS）

如果您熟悉 Shell 脚本，推荐直接使用源码运行：

```bash
git clone https://github.com/Yonghao-lucky/realm_opencode.git
cd realm_opencode
chmod +x src/realm_opencode.sh src/install_realm_opencode.sh
./src/realm_opencode.sh
```

也可以直接执行安装命令：

```bash
./src/install_realm_opencode.sh --api-key sk-xxxx
```

### 方式二：Windows PowerShell

Windows 用户可以直接下载 PowerShell 脚本后运行：

```powershell
# 下载并运行
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Yonghao-lucky/realm_opencode/main/src/realm_opencode.ps1" -OutFile "realm_opencode.ps1"
.\realm_opencode.ps1
```

或从源码运行：

```powershell
git clone https://github.com/Yonghao-lucky/realm_opencode.git
cd realm_opencode
.\src\realm_opencode.ps1
```

> **注意**：如果遇到执行策略限制，请先运行：
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

## 使用指南

Linux/macOS 脚本启动后，您将看到如下主菜单：

```text
========================================
   RealmRouter OpenCode 管理工具
========================================
 [1] 安装/重置 RealmRouter 配置
 [2] 更新 API Key
 [3] 切换默认模型
 [4] 恢复备份
 [5] 测试连通性
 [6] 查看内置模型
 [q] 退出
```

### [1] 安装/重置 RealmRouter 配置

首次使用时建议先执行这个选项。

* 输入您的 RealmRouter API Key。
* 脚本会先测试 Key 是否可用。
* 如果本地已存在 `~/.config/opencode/opencode.json`，会先自动备份。
* 然后将 RealmRouter provider 和模型列表写入 OpenCode 配置。
* 默认模型会设置为 `realmrouter/gpt-5.4`。

### [2] 更新 API Key

当您的 API Key 更新、失效或想切换账号时使用。

* 输入新的 RealmRouter API Key。
* 脚本会先验证 Key。
* 验证成功后，仅更新 RealmRouter 的 API Key。

### [3] 切换默认模型

如果您希望 OpenCode 默认使用其他 RealmRouter 模型，可以使用这个选项。

* 脚本会列出全部内置模型。
* 选择目标模型后，会自动更新 `opencode.json` 中的默认模型。

### [4] 恢复备份

每次修改配置前，脚本都会自动备份当前配置。

* 进入恢复菜单后，可以看到历史备份列表。
* 选择一个备份即可恢复。

### [5] 测试连通性

当您怀疑配置是否生效，或模型调用失败时，可以用这个选项快速排查。

* 脚本会读取当前配置中的 API Key 和默认模型。
* 发起一次真实请求测试连通性。
* 如果 Key 无效、模型错误或网络异常，会直接报错提示。

### [6] 查看内置模型

列出脚本当前内置支持的所有 RealmRouter 模型，方便查看和确认。

## 配置完成后怎么使用

完成配置后，启动 OpenCode，输入以下命令：

```text
/model
```

然后就可以在 OpenCode 中选择并使用 RealmRouter 的模型。

这也是推荐给用户的核心使用方式。

## 配置文件位置

本工具主要修改 OpenCode 配置文件：

```text
~/.config/opencode/opencode.json
```

写入的 RealmRouter provider 配置包括：

* `npm`: `@ai-sdk/openai-compatible`
* `baseURL`: `https://realmrouter.cn/v1`
* 默认模型：`realmrouter/gpt-5.4`

## 常用命令

### Linux/macOS

```bash
./src/realm_opencode.sh install --api-key sk-xxxx
./src/realm_opencode.sh update-key --api-key sk-xxxx
./src/realm_opencode.sh switch-model gpt-5.4
./src/realm_opencode.sh test
./src/realm_opencode.sh restore
./src/realm_opencode.sh list-models
```

### Windows PowerShell

```powershell
.\src\realm_opencode.ps1 install -ApiKey sk-xxxx
.\src\realm_opencode.ps1 update-key -ApiKey sk-xxxx
.\src\realm_opencode.ps1 switch-model gpt-5.4
.\src\realm_opencode.ps1 test
.\src\realm_opencode.ps1 restore
.\src\realm_opencode.ps1 list-models
```

## 内置模型

当前脚本内置支持多种主流模型，包括但不限于：

### DeepSeek
* `deepseek-ai/DeepSeek-R1`
* `deepseek-ai/DeepSeek-R1-0528`
* `deepseek-ai/DeepSeek-V3.1`
* `deepseek-ai/DeepSeek-V3.1-Terminus`
* `deepseek-ai/DeepSeek-V3.2-Exp`

### Anthropic
* `claude-haiku-4.5`
* `claude-sonnet-4-5`

### Google
* `gemini-3.1-pro-high`
* `gemini-3.1-pro-low`

### MiniMax
* `MiniMaxAI/MiniMax-M2.1`
* `MiniMaxAI/MiniMax-M2.5`

### Moonshot
* `moonshotai/Kimi-K2.5`
* `moonshotai/Kimi-K2-Thinking`

### OpenAI
* `gpt-5.2`
* `gpt-5.2-codex`
* `gpt-5.3-codex`
* `gpt-5.4`
* `openai/gpt-oss-120b`

### 字节跳动 (ByteDance)
* `doubao-seed-code-preview-251028`

### Z.AI
* `zai-org/GLM-4.7`
* `zai-org/GLM-4.6V`
* `zai-org/GLM-5`

### Qwen (通义千问)
* `qwen3-coder-plus`
* `qwen3-max`
* `qwen3-max-preview`
* `qwen3-vl-plus`
* `qwen3-vl-max`
* `Qwen/Qwen3-Coder-480B-A35B-Instruct`
* `Qwen/Qwen3-Coder-Next`
* `Qwen/Qwen3.5`

## 注意事项

* 如果 `opencode.json` 已存在，脚本会先自动备份，再执行修改。
* `update-key` 在已存在 RealmRouter 配置时只更新 Key；如果未安装过，会自动回退到完整安装。
* `test` 会发起真实请求，因此需要网络正常且 API Key 有效。
* 推荐用户使用脚本接入，不建议手动改 JSON 配置，避免格式错误或字段遗漏。

## 免责声明

本工具仅作为第三方 OpenCode 配置辅助工具，与 OpenCode 或 RealmRouter 官方无直接关联。使用前请自行确认配置内容并备份重要数据。
