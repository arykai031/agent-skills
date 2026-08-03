# bw-sync — Bitwarden 密钥同步方案

## 概述

从 **Bitwarden Secrets Manager** 同步密钥到本地目标系统（Agent、项目、配置文件等）的通用方案。

### 设计原则

| 原则 | 说明 |
|------|------|
| **Bitwarden 是唯一权威源** | 所有密钥只在一个地方维护，不在多个配置文件里散落 |
| **只拉不写** | 同步脚本只从 Bitwarden 读取，绝不回写 |
| **本地缓存兜底** | Bitwarden 不可用时，使用上次同步的缓存值，不影响服务运行 |
| **配置驱动** | 同步脚本通过 YAML/JSON 配置，无需修改代码 |
| **目标无关** | 支持多种输出模式，适配不同的 Agent 和项目 |

### 架构

```
                     Bitwarden Cloud
                    （权威源，唯一写入入口）
                          │
               ┌──────────┼──────────┐
               │          │          │
           QwenPaw    Hermes    Codex CLI
               │          │          │
               └──────────┼──────────┘
                          │
               ┌──────────▼──────────┐
               │    bw-sync 脚本       │
               │  (通用同步工具)       │
               └──────────┬──────────┘
                          │ 多输出模式
          ┌───────────────┼────────────────┐
          ▼               ▼                ▼
     env_set       env_file/shell      stdout
  (Agent env)     (.env 文件/export)   (JSON 管道)
```

---

## 快速开始

### 前置条件

| 依赖 | 说明 | 谁准备 |
|------|------|--------|
| **Bitwarden 账号** | 注册 [bitwarden.com](https://bitwarden.com) | 👤 用户 |
| **Secrets Manager** | 激活免费 Plan（3 个 Machine Account，不限 Secret 数） | 👤 用户 |
| **bws CLI** | `install.sh` 自动安装；也可手动 `curl -fsSL https://bws.bitwarden.com/install | sh` | 🤖 自动 |
| **Python 3** | 脚本基于 Python 3.6+ | 🤖 自动检查 |
| **PyYAML**（可选） | 使用 YAML 配置时需要：`pip install pyyaml` | 🤖 自动检查 |

### 0. 首次使用引导（Bitwarden 侧骨架）

**在使用前，需要确认 Bitwarden Secrets Manager 侧已就绪**。以下操作在 Bitwarden Web Vault 网页端完成：

1. **创建 Machine Account**（只读）
   - 路径: Secrets Manager → Machine Accounts → 创建
   - 权限: **Read**（只读，bw-sync 只拉不写）
   - 名称: 建议按用途命名，如 `my-app-sync`

2. **生成并保存 Access Token**（**只出示一次！**）
   - 生成后立即复制保存，丢失需重新生成
   - 写入 Token 文件（install.sh 自动处理，权限 600）

3. **创建密钥**（要同步的内容）
   - 路径: Secrets Manager → Secrets → 创建
   - 创建你需要的所有密钥（key = 密钥名，value = 密钥值）

4. **创建项目 (Project) 并将密钥分配进去**
   - 路径: Secrets Manager → Projects → 创建
   - 记下 **Project ID**（项目页 URL 中可找到，格式为 UUID）
   - 把 Machine Account 授权到该项目（Read 权限）

> 💡 **缺什么就问用户要什么**：如果用户没有 Bitwarden 账号/项目/token，引导按上述 4 步完成后再继续。token 是网页端生成的（只显示一次），无法由脚本代劳。

### 一键安装（推荐）

```bash
cd skills/bw-sync/scripts
bash install.sh --token "<BWS_ACCESS_TOKEN>"
```

install.sh 自动完成：装/查 bws CLI → 装 bw-sync 主脚本 → 写 token 文件 `~/.bw/env`（chmod 600）→ 生成配置模板 `/etc/bw-sync/config.yaml` → **部署到收口目录**（脚本 → `<a_work>/scripts/bw-sync`，配置 → `<a_work>/configs/bw-sync.yaml`）。

- 收口目录自动探测：`$HOME/a_work` → `$(pwd)/Yon-w` → `$(pwd)/a_work`，也可显式指定 `--deploy-dir`

### 手动安装（可选，不用 install.sh 时）

```bash
# 1. 安装 bws CLI
curl -fsSL https://bws.bitwarden.com/install | sh

# 2. 下载同步脚本
#    从仓库或本方案目录拷贝到 /usr/local/bin/
cp bw-sync /usr/local/bin/bw-sync
chmod +x /usr/local/bin/bw-sync

# 3. 验证
bw-sync --version
```

### 初始化（手动方式，install.sh 已自动完成）

```bash
# 1. 在 Bitwarden Web Vault 中创建 Machine Account
#    路径: Secrets Manager → Machine Accounts → 创建
#    权限: Read（只读）
#    名称: 建议按用途命名，如 my-app-sync

# 2. 保存 Access Token（只出示一次！）
#    写入 Token 文件（权限 600）
mkdir -p ~/.bw && chmod 700 ~/.bw
cat > ~/.bw/env << 'EOF'
export BWS_ACCESS_TOKEN="0.xxxx..."
EOF
chmod 600 ~/.bw/env

# 3. 在 Bitwarden 中创建密钥
#    路径: Secrets Manager → Secrets → 创建
#    创建你需要的所有密钥

# 4. 创建项目 (Project) 或将密钥分配到项目
#    Secrets Manager → Projects → 创建
#    记下 Project ID（URL 中可找到）
```

### 配置文件

创建 `bw-sync.yaml`：

```yaml
# bw-sync.yaml
bitwarden:
  project_id: "206d7fbd-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  # 或使用 Organization ID:
  # organization_id: "962510f9-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  bws_path: "/usr/local/bin/bws"
  token:
    source: "file"
    file_path: "~/.bw/env"

output:
  mode: "env_file"          # 输出模式
  env_file_path: ".env"     # 写入 .env 文件
  env_file_append: false    # false=覆盖, true=追加

secrets:
  # 手动映射：环境变量名 → Bitwarden Secret Key
  MAP:
    DEEPSEEK_API_KEY: DEEPSEEK_API_KEY
    GITHUB_TOKEN: GITHUB_TOKEN
  # 或开启透传模式（Bitwarden key 直接作为环境变量名）:
  # pass_through: true
```

### 首次同步

```bash
# 预览（不实际写入）
bw-sync --config bw-sync.yaml --dry-run

# 执行同步
bw-sync --config bw-sync.yaml
```

---

## 配置详解

### 完整的配置文件结构

```yaml
bitwarden:
  project_id: ""              # Project ID（与 org_id 二选一）
  organization_id: ""         # Organization ID（与 project_id 二选一）
  bws_path: "bws"             # bws CLI 路径
  token:
    source: "file"            # file / env / arg
    env_var: "BWS_ACCESS_TOKEN"
    file_path: "~/.bw/env"

output:
  mode: "env_file"            # 输出模式（见下方详解）
  # --- env_set 模式参数 ---
  target_command: "qwenpaw env set"
  # --- env_file 模式参数 ---
  env_file_path: ".env"
  env_file_append: false
  # --- 过滤 ---
  only_keys: []               # 仅同步这些 key
  exclude_keys: []            # 排除这些 key

secrets:
  pass_through: false          # 透传模式
  MAP: {}                      # 键值映射（pass_through=false 时生效）
```

### 输出模式详解

| 模式 | 描述 | 适用场景 |
|------|------|----------|
| `env_set` | 调用目标命令写入环境变量 | QwenPaw (`qwenpaw env set`)、或其他 Agent 的配置命令 |
| `env_file` | 写入 `.env` 格式文件 | Hermes、Docker Compose、各种框架 |
| `stdout` | 输出 JSON 到标准输出 | CI/CD 管道、脚本链式调用 |
| `shell` | 输出 `export` 语句 | `eval "$(bw-sync ...)"` 注入当前 Shell |

### Token 来源

| source | 说明 | 示例 |
|--------|------|------|
| `file` | 从文件读取（推荐） | `~/.bw/env`（`chmod 600`） |
| `env` | 从环境变量读取 | 配合 CI/CD 或容器注入使用 |
| `arg` | 命令行 `--token` 传入 | 临时使用或脚本包装 |

---

## 密钥映射策略

### 策略 A：手动映射（推荐）

```yaml
secrets:
  MAP:
    QWENPAW_GITHUB_TOKEN: GITHUB_TOKEN     # 环境变量名 → Bitwarden key
    MY_APP_API_KEY: PRODUCTION_API_KEY
```

**适合场景**：不同系统对同一密钥有不同的命名规范。

### 策略 B：透传模式

```yaml
secrets:
  pass_through: true
```

Bitwarden 中的 **Secret Key 直接作为环境变量名**，同步所有密钥（或通过 `only_keys`/`exclude_keys` 过滤）。

**适合场景**：命名规范统一，不需要重命名。

---

## 触发方式

> 📁 **收口目录工作链**：install.sh 已部署收口目录副本（脚本 `<a_work>/scripts/bw-sync` + 配置 `<a_work>/configs/bw-sync.yaml`）时，**日常同步/定时任务优先使用收口目录路径**；未部署时回退到系统级路径（`/usr/local/bin/bw-sync` + `/etc/bw-sync/config.yaml`）。以下示例均可用 `<a_work>/scripts/bw-sync -c <a_work>/configs/bw-sync.yaml` 替换。

### 方式 A：Supervisor Wrapper（容器环境，当前方案）

```ini
[program:sync-bw]
command=bw-sync --config /etc/bw-sync/config.yaml -q
autostart=true
autorestart=false
startsecs=0
priority=50

[program:app]
command=/path/to/start-my-app.sh
autostart=true
autorestart=unexpected
priority=100          # 大于 sync-bw 的 priority，保证后启动
```

或合并为一条命令：

```
command=/bin/sh -c "bw-sync --config /etc/bw-sync/config.yaml -q && exec my-app"
```

### 方式 B：系统 Cron（服务器环境）

```bash
# crontab -e
# 每 5 分钟同步一次（比默认 30 分钟更及时）
*/5 * * * * /usr/local/bin/bw-sync --config /etc/bw-sync/config.yaml -q

# 或系统级 cron（root）
cat > /etc/cron.d/bw-sync << 'EOF'
*/5 * * * * root /usr/local/bin/bw-sync --config /etc/bw-sync/config.yaml -q
EOF
```

### 方式 C：Systemd Timer（推荐 Linux 服务器）

```ini
# /etc/systemd/system/bw-sync.service
[Unit]
Description=Sync secrets from Bitwarden
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bw-sync --config /etc/bw-sync/config.yaml -q
User=root

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/bw-sync.timer
[Unit]
Description=Sync secrets every 5 minutes

[Timer]
OnBootSec=30s         # 启动后 30 秒首次同步
OnUnitActiveSec=5min   # 之后每 5 分钟
Persistent=true        # 错过的时间补执行

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now bw-sync.timer
```

### 方式 D：QwenPaw Cron（纯 QwenPaw 环境）

```bash
qwenpaw cron create \
  --agent-id <agent-id> \
  --type agent \
  --schedule-type cron \
  --name "bw-sync" \
  --cron "*/5 * * * *" \
  --channel console \
  --target-user "default" \
  --target-session "cron-bw-sync" \
  --text "请执行 Bitwarden 密钥同步：运行 /usr/local/bin/bw-sync --config /etc/bw-sync/config.yaml -q" \
  --timeout 30 \
  --silent
```

---

## 场景示例

### 场景 1：QwenPaw 用（当前方案）

配置文件 `/etc/bw-sync/qwenpaw.yaml`：

```yaml
bitwarden:
  project_id: "206d7fbd-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  bws_path: "/root/.local/bin/bws"
  token:
    source: "file"
    file_path: "~/.bw/env"

output:
  mode: "env_set"
  target_command: "qwenpaw env set"

secrets:
  pass_through: false
  MAP:
    DEEPSEEK_API_KEY: DEEPSEEK_API_KEY
    GITHUB_TOKEN: GITHUB_TOKEN
    CCH_API_KEY: CCH_API_KEY
    ANYSEARCH_API_KEY: ANYSEARCH_API_KEY
```

Supervisor wrapper 启动：

```bash
#!/bin/bash
# /usr/local/bin/start-qwenpaw.sh
source ~/.bw/env 2>/dev/null
timeout 15 bw-sync --config /etc/bw-sync/qwenpaw.yaml -q
exec /app/venv/bin/qwenpaw app --host 0.0.0.0 --port 8088
```

### 场景 2：Hermes Agent 用

Hermes 原生支持 Bitwarden，但也可用本方案做额外控制：

```yaml
bitwarden:
  organization_id: "962510f9-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

output:
  mode: "env_file"
  env_file_path: "~/.hermes/.env"
  env_file_append: false

secrets:
  pass_through: true
  exclude_keys:
    - WECHAT_APP_ID       # Hermes 不需要的可以排除
    - DINGTALK_APP_SECRET
```

### 场景 3：OpenAI Codex CLI 用

```yaml
bitwarden:
  project_id: "xxx"

output:
  mode: "env_file"
  env_file_path: "~/.codex/.env"
  env_file_append: false

secrets:
  MAP:
    CCH_API_KEY: CCH_API_KEY
    GITHUB_TOKEN: GITHUB_TOKEN
```

### 场景 4：GitHub Actions CI 用

```yaml
bitwarden:
  organization_id: "xxx"

output:
  mode: "stdout"

secrets:
  pass_through: true
  only_keys:
    - DOCKER_REGISTRY_TOKEN
    - NPM_TOKEN
```

```yaml
# .github/workflows/sync-secrets.yml
- name: Sync secrets from Bitwarden
  run: |
    bw-sync --config .github/bw-sync.yaml > secrets.json
    # 解析 JSON 注入环境
    for key in $(jq -r 'keys[]' secrets.json); do
      echo "$key=$(jq -r ".[\"$key\"]" secrets.json)" >> $GITHUB_ENV
    done
  env:
    BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
```

### 场景 5：Docker Compose 用

```yaml
bitwarden:
  project_id: "xxx"

output:
  mode: "env_file"
  env_file_path: "./.env.production"
```

在 `docker-compose.yml` 中使用：

```yaml
services:
  app:
    image: my-app:latest
    env_file:
      - .env.production
```

---

## 错误处理与安全

### 错误处理策略

| 错误场景 | 行为 | 影响 |
|----------|------|------|
| Bitwarden 服务不可用 | 脚本退出（非零），不删除本地缓存 | 无，使用旧密钥 |
| bws CLI 未安装 | 脚本退出，报错路径 | 需要先安装 |
| Access Token 过期 | bws 返回 401，脚本退出 | 需要在 Bitwarden 重新生成 |
| 映射表中部分密钥缺失 | 仅跳过缺失项，不影响其他密钥 | 部分密钥未更新 |
| 网络超时 | 由 `timeout` 命令控制（推荐 15s） | 无，使用旧密钥 |

### 安全建议

| 措施 | 说明 |
|------|------|
| **Token 文件权限** | `chmod 600 ~/.bw/env`，只有 root 可读 |
| **Machine Account 权限** | 只给 **Read** 权限，不给 Write/Admin |
| **最小同步原则** | 只同步目标系统真正需要的密钥 |
| **配置文件不存 Token** | token 从独立文件/env 读取，不写在配置 YAML 里 |
| **定期轮换 Access Token** | 建议每 90 天重新生成一次 |

---

## 迁移指南

### 从旧版 sync-bw.py 迁移

旧版（v1）是硬编码的 QwenPaw 专用脚本。迁移到通用版 bw-sync：

```bash
# 1. 创建通用配置文件
cat > /etc/bw-sync/qwenpaw.yaml << 'EOF'
bitwarden:
  project_id: "你的 Project ID"
  bws_path: "/root/.local/bin/bws"
  token:
    source: "file"
    file_path: "~/.bw/env"
output:
  mode: "env_set"
  target_command: "qwenpaw env set"
secrets:
  MAP:
    DEEPSEEK_API_KEY: DEEPSEEK_API_KEY
    GITHUB_TOKEN: GITHUB_TOKEN
    CCH_API_KEY: CCH_API_KEY
    ANYSEARCH_API_KEY: ANYSEARCH_API_KEY
EOF

# 2. 测试
bw-sync --config /etc/bw-sync/qwenpaw.yaml --dry-run

# 3. 旧版脚本仍可用，建议逐步切换到通用版
#    新版 bw-sync 与旧 sync-bw.py 不冲突，可共存
```
