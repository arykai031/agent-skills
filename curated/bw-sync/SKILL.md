---
name: bw-sync
description: 'Use this skill when the user needs to sync secrets from Bitwarden Secrets Manager to local targets — agents (QwenPaw, Hermes, Codex CLI), .env files, shell environments, or CI pipelines. Triggers: "bw-sync", "bitwarden sync", "sync secrets", "密钥同步", "bitwarden 密钥", "同步密码到本地".'
metadata:
  qwenpaw:
    emoji: "🔐"
---

# bw-sync — Bitwarden 密钥同步

从 **Bitwarden Secrets Manager** 同步密钥到本地目标系统（Agent、项目、配置文件等）的通用方案。Bitwarden 是唯一权威源，脚本只拉不写，配置驱动、目标无关。

## When to Use

- 用户需要把 Bitwarden 中的密钥同步到 QwenPaw / Hermes / Codex CLI / 项目 `.env` / CI 管道
- 新 agent 或新机器上需要**复用密钥同步能力**（一键安装+配置）
- 密钥变更后需要重新拉取到本地

## 使用流程（agent 执行）

> 本 skill 由 agent 按以下步骤操作。**首次使用时先走"第 0 步"引导**，确认 Bitwarden 侧骨架就绪，再继续安装配置。

### 第 0 步：前置引导（首次使用必做）

先向用户确认 Bitwarden 侧骨架是否已就绪。**不要假设用户已经有这些资料**，逐项询问。

#### 0.1 检查现状

```bash
# 检查本地工具（bws CLI + bw-sync）
bw-sync --version 2>/dev/null && echo "bw-sync 已安装" || echo "bw-sync 未安装"
command -v bws 2>/dev/null || ls ~/.local/bin/bws 2>/dev/null || echo "bws CLI 未安装"
```

#### 0.2 向用户收集/确认以下资料（缺失的逐项引导）

| # | 需要用户提供的东西 | 怎么获得 | 谁来做 |
|---|------------------|---------|--------|
| 1 | **Bitwarden 账号**（已注册） | https://vault.bitwarden.com 注册 | 👤 用户 |
| 2 | **Secrets Manager 已启用** | 账号内开启 Secrets Manager（免费层可用） | 👤 用户 |
| 3 | **项目 project_id**（或 organization_id） | Secrets Manager → Projects 创建项目，复制 UUID | 👤 用户创建，或 agent 用 bws 代建 |
| 4 | **密钥已录入项目** | Projects → 项目 → 添加 Secret（key=value） | 👤 用户（agent 可代建但需值） |
| 5 | **Machine Account + Access Token** | Machine Accounts → 创建 → 授予项目 Read 权限 → 生成 token（只显示一次） | 👤 用户手动（网页端） |
| 6 | **目标配置**：密钥同步到哪、用哪些密钥 | 👤 用户说目标（如"QwenPaw""Hermes 的 .env"），🤖 agent 据此选 output.mode 并配好 | 🤝 一起 |

**向用户说明的要点：**
- Machine Account 只给 **Read 权限**（bw-sync 只拉不写，最小权限）
- Access Token **只显示一次**，复制后立即保存，丢失需重新生成
- Access Token 建议每 90 天轮换一次

#### 0.3 若用户已有这些资料

直接进入第 1 步。把用户提供的 token / project_id / organization_id 记下来备用。

> 💡 **给 agent 的提示**：不要因为用户没给 token 就卡住。可以先完成第 1–2 步（安装工具），token 稍后补。但**必须明确告诉用户"缺什么、去哪拿"**，不要默默跳过。

---

### 第 1 步：一键安装

```bash
cd skills/bw-sync/scripts
bash install.sh --token "<BWS_ACCESS_TOKEN>" --deploy-dir "$HOME/a_work"
```

install.sh 会自动完成：装/查 bws CLI → 装 bw-sync 主脚本 → 写 token 文件 `~/.bw/env`（chmod 600）→ 生成配置文件。**安装目标是用户级收口目录**（脚本 → `<a_work>/scripts/bw-sync`，配置 → `<a_work>/configs/bw-sync.yaml`），不装系统级。

- 收口目录（通用 `a_work` 概念）自动探测：`$HOME/a_work` → `$(pwd)/a_work`，也可显式指定：`bash install.sh --deploy-dir "$HOME/a_work"`
- 未探测到收口目录时，兜底安装到标准用户级：`$HOME/.local/bin` + `$HOME/.config/bw-sync`
- 若用户已提供 token：`--token` 传入
- 若用户还没拿到 token：先运行 `bash install.sh`（跳过 token），**明确告诉用户下一步去 Bitwarden 控制台生成 token，拿到后补跑** `bash install.sh --token "<新token>"`

> 💡 **工作链**：技能部署后，日常同步操作直接使用收口目录中的脚本（`<a_work>/scripts/bw-sync`）与配置（`<a_work>/configs/bw-sync.yaml`），收口目录是实际使用版本。

### 第 2 步：生成配置文件

向用户确认以下信息后，编辑配置 `<a_work>/configs/bw-sync.yaml`。

**用户只需回答 3 个问题**（`output.mode` 等由 agent 根据目标推断，不要求用户懂技术）：

| # | 问用户的问题 | 用户提供 | 对应配置项 | 必填 |
|---|-------------|---------|-----------|:----:|
| 1 | "密钥在哪个 Bitwarden 项目？" | 项目/组织 UUID | `bitwarden.project_id` 或 `organization_id` | ✅ 必须 |
| 2 | "密钥要同步到哪里？" | 目标描述（如"QwenPaw""Hermes 的 .env""CI 管道"） | → agent 据此选 `output.mode` + 目标参数 | ✅ 必须 |
| 3 | "要同步哪些密钥？" | 密钥清单（环境变量名 ↔ Bitwarden key） | `secrets.MAP` | ✅ 必须 |

**agent 根据问题 2 的目标自行配置 `output.mode`**（用户不需要懂模式区别）：

| 用户说"同步到…" | agent 配置 `output.mode` | 附加参数 |
|----------------|-------------------------|---------|
| QwenPaw | `env_set` | `target_command: "qwenpaw env set"` |
| Hermes / Codex CLI / 任意程序 | `env_file` | `env_file_path: "<目标 .env 路径>"` |
| CI 管道 / 取 JSON 结果 | `stdout` | 无 |
| shell 环境注入 | `shell` | 无 |

**可选/有默认值，一般不用动**：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `secrets.pass_through` | `false` | `true` = Bitwarden key 直接当环境变量名，不用 MAP |
| `output.env_file_append` | `false` | `true` = 追加而非覆盖 .env |
| `output.only_keys` / `exclude_keys` | 空 | 可选过滤，默认同步全部 |
| `bitwarden.bws_path` | `"bws"` | 自动查找 PATH；仅当 bws 不在 PATH 时填绝对路径 |
| `bitwarden.token.*` | file + `~/.bw/env` | install.sh 已写好，不要动 |

> 💡 **给 agent 的提示**：配置完成后，把 `secrets.MAP` 里的 `EXAMPLE_KEY` 占位全部替换成真实密钥名，否则 dry-run 会报"部分密钥缺失"。

常见目标快速参考：

- **QwenPaw**：`mode: env_set`, `target_command: "qwenpaw env set"`
- **Hermes**：`mode: env_file`, `env_file_path: "~/.hermes/.env"`
- **Codex CLI**：`mode: env_file`, `env_file_path: "~/.codex/.env"`
- **Docker Compose**：`mode: env_file`, `env_file_path: "./.env.production"`
- **CI 管道**：`mode: stdout`（JSON 输出，`bw-sync > secrets.json`）

### 第 3 步：验证

```bash
# 预览（不实际写入）—— 使用收口目录脚本 + 配置
<a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml --dry-run

# 确认无误后执行
<a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml
```

**验证通过的标准**：dry-run 输出中每个 MAP 密钥都取到了值（`成功 N，失败 0`）。若有失败，检查：
- token 是否有效（报 401 → 回 0.2 重新生成）
- project_id 是否正确
- MAP 中的 key 名是否与 Bitwarden 里一致

### 第 4 步：设置定时同步（按需，需用户确认）

向用户说明定时同步的意义（Bitwarden 更新后自动拉到本地，无需手动），让用户选择方式。**定时命令统一使用收口目录中的脚本与配置**：

> 💡 **频率建议**：Bitwarden 密钥变动通常不频繁，**默认推荐"手动同步 + 低频定时兜底"**（如每 3 天凌晨 4 点）。仅当密钥高频变更时才用高频率定时。

| 环境 | 方式 | 命令/配置 |
|------|------|----------|
| **手动按需** | 本地需要新密钥时，人工在 Bitwarden 添加后手动执行 | `<a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml` |
| Supervisor 容器 | 启动前同步 | `command=/bin/sh -c "<a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml -q && exec my-app"` |
| Cron | 每 3 天凌晨 4 点 | `0 4 */3 * * <a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml -q` |
| Systemd Timer | 低频兜底 | `OnBootSec=30s` + `OnUnitActiveSec=3d`（每 3 天） |
| QwenPaw Cron | 每 3 天凌晨 4 点（北京时间） | `qwenpaw cron create --agent-id <id> --type agent --cron "0 4 */3 * *" --timezone "Asia/Shanghai" --text "请执行 Bitwarden 密钥同步：运行 <a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml -q" --silent` |

> 若用户不需要定时，可跳过此步，手动执行即可。

---

## 配置要点

```yaml
bitwarden:
  project_id: "xxxx"          # 与 organization_id 二选一
  bws_path: "bws"
  token:
    source: "file"            # file / env / arg
    file_path: "~/.bw/env"

output:
  mode: "env_file"            # env_set / env_file / stdout / shell
  target_command: "qwenpaw env set"   # env_set 模式用
  env_file_path: ".env"       # env_file 模式用
  env_file_append: false

secrets:
  pass_through: false         # true=Bitwarden key 直接当环境变量名
  MAP:                        # 手动映射：环境变量名 → Bitwarden key
    GITHUB_TOKEN: GITHUB_TOKEN
```

### 输出模式

| 模式 | 用途 | 示例 |
|------|------|------|
| `env_set` | 调目标命令写环境变量 | QwenPaw: `target_command: "qwenpaw env set"` |
| `env_file` | 写 `.env` 文件 | Hermes、Docker Compose |
| `stdout` | 输出 JSON | CI/CD 管道 |
| `shell` | 输出 export 语句 | `eval "$(bw-sync --config x.yaml --mode shell)"` |

## 安全注意

- Token 文件 `chmod 600`，仅 root 可读（install.sh 已处理）
- Machine Account 只给 **Read** 权限
- 配置文件里不存 Token（从独立文件/env 读）
- Access Token 建议每 90 天轮换

## 常见问题

| 问题 | 处理 |
|------|------|
| bws 调用失败 / 401 | Token 过期，去 Bitwarden 重新生成，`BWS_ACCESS_TOKEN="新token" bash install.sh --token "新token"` |
| 空结果 | 检查 project_id / organization_id 是否正确，或 Machine Account 未被授予项目权限 |
| 部分密钥缺失 | 检查 MAP 中的 key 名是否与 Bitwarden 一致 |
| 用户没有 Bitwarden 账号 | 引导注册 → 启用 Secrets Manager → 创建项目 → 录入密钥 → 创建 Machine Account 生成 token（0.2 流程） |

## 完整文档

详见本 skill 的 `README.md`（含 5 个场景示例：QwenPaw/Hermes/Codex CLI/GitHub Actions/Docker Compose）。
