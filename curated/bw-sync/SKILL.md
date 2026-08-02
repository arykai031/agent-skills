---
name: bw-sync
description: Use this skill when the user needs to sync secrets from Bitwarden Secrets Manager to local targets — agents (QwenPaw, Hermes, Codex CLI), .env files, shell environments, or CI pipelines. Triggers: "bw-sync", "bitwarden sync", "sync secrets", "密钥同步", "bitwarden 密钥", "同步密码到本地".
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

> 本 skill 由 agent 按以下步骤操作，用户只需提供 Bitwarden token 和 project/organization ID。

### 第 1 步：检查是否已安装

```bash
bw-sync --version 2>/dev/null && echo "已安装" || echo "未安装"
```

### 第 2 步：一键安装

```bash
cd skills/bw-sync/scripts
bash install.sh --token "<BWS_ACCESS_TOKEN>"
```

install.sh 会自动完成：装/查 bws CLI → 装 bw-sync 主脚本 → 写 token 文件 `~/.bw/env`（chmod 600）→ 生成配置模板 `/etc/bw-sync/config.yaml`。

如果用户没给 token，可先跳过（`bash install.sh` 会提示交互输入，agent 场景请让用户提供后传入 `--token`）。

### 第 3 步：生成配置文件

向用户确认以下信息后，编辑 `/etc/bw-sync/config.yaml`：

| 配置项 | 说明 | 需要用户提供 |
|--------|------|-------------|
| `bitwarden.project_id` 或 `organization_id` | 密钥所在项目/组织 | ✅ 必须 |
| `output.mode` | `env_set`（agent 环境）/ `env_file`（.env 文件）/ `stdout` / `shell` | ✅ 按目标选 |
| `output.target_command` | 仅 env_set 模式，如 `qwenpaw env set` | 按 agent 定 |
| `secrets.MAP` | 环境变量名 → Bitwarden key 映射 | ✅ 按需同步的密钥 |
| `secrets.pass_through` | true = Bitwarden key 直接当环境变量名 | 可选 |

常见目标快速参考：

- **QwenPaw**：`mode: env_set`, `target_command: "qwenpaw env set"`
- **Hermes**：`mode: env_file`, `env_file_path: "~/.hermes/.env"`
- **Codex CLI**：`mode: env_file`, `env_file_path: "~/.codex/.env"`
- **Docker Compose**：`mode: env_file`, `env_file_path: "./.env.production"`
- **CI 管道**：`mode: stdout`（JSON 输出，`bw-sync > secrets.json`）

### 第 4 步：验证

```bash
# 预览（不实际写入）
bw-sync -c /etc/bw-sync/config.yaml --dry-run

# 确认无误后执行
bw-sync -c /etc/bw-sync/config.yaml
```

### 第 5 步：设置定时同步（按需）

- **Supervisor 容器**：`command=/bin/sh -c "bw-sync -c /etc/bw-sync/config.yaml -q && exec my-app"`
- **Cron**：`*/5 * * * * /usr/local/bin/bw-sync -c /etc/bw-sync/config.yaml -q`
- **Systemd Timer**：`OnBootSec=30s` + `OnUnitActiveSec=5min`
- **QwenPaw Cron**：`qwenpaw cron create --agent-id <id> --type agent --cron "*/30 * * * *" --text "运行 bw-sync -c /etc/bw-sync/config.yaml -q"`

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
| 空结果 | 检查 project_id / organization_id 是否正确 |
| 部分密钥缺失 | 检查 MAP 中的 key 名是否与 Bitwarden 一致 |

## 完整文档

详见本 skill 的 `README.md`（含 5 个场景示例：QwenPaw/Hermes/Codex CLI/GitHub Actions/Docker Compose）。
