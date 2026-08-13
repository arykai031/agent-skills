#!/bin/bash
# ============================================================
# bw-sync 一键安装脚本
#
# 功能：自动完成以下步骤
#   1. 安装/检查 bws CLI（Bitwarden Secrets Manager 命令行工具）
#   2. 安装 bw-sync 主脚本到用户级目录（默认 0out 收口目录）
#   3. 初始化 Token 文件 ~/.bw/env（chmod 600）
#   4. 生成配置文件（与脚本同一收口目录）
#
# 安装目标（按优先级）：
#   1. --deploy-dir <dir>    显式指定收口目录（脚本→<dir>/scripts/，配置→<dir>/configs/）
#   2. 自动探测 $HOME/0out → $(pwd)/0out（收口目录，存在即用）
#   3. 兜底用户级 $HOME/.local/bin + $HOME/.config/bw-sync
#
# 用法:
#   # 方式1：token 通过环境变量传入（推荐给 agent 调用）
#   BWS_ACCESS_TOKEN="0.xxx" bash install.sh
#
#   # 方式2：--token 参数传入
#   bash install.sh --token "0.xxx"
#
#   # 方式3：交互式输入（人工使用）
#   bash install.sh
#
#   # 指定收口目录（推荐，脚本→<dir>/scripts/，配置→<dir>/configs/）
#   bash install.sh --deploy-dir "$HOME/0out"
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR=""
CONFIG_DIR=""
DEPLOY_DIR=""

# ---------- 解析参数 ----------
TOKEN=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --token)
            TOKEN="$2"; shift 2 ;;
        --bin-dir)
            BIN_DIR="$2"; shift 2 ;;
        --config-dir)
            CONFIG_DIR="$2"; shift 2 ;;
        --deploy-dir)
            DEPLOY_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "用法: bash install.sh [--token <token>] [--deploy-dir <dir>] [--bin-dir <dir>] [--config-dir <dir>]"
            exit 0 ;;
        *)
            echo "未知参数: $1"; exit 1 ;;
    esac
done

# ---------- 确定安装目标（用户级，优先收口目录） ----------
if [ -z "$BIN_DIR" ] && [ -z "$CONFIG_DIR" ]; then
    if [ -n "$DEPLOY_DIR" ]; then
        # 显式指定收口目录
        BIN_DIR="$DEPLOY_DIR/scripts"
        CONFIG_DIR="$DEPLOY_DIR/configs"
    else
        # 自动探测收口目录（通用 0out 概念）
        for candidate in "$HOME/0out" "$(pwd)/0out"; do
            if [ -d "$candidate" ]; then
                DEPLOY_DIR="$candidate"
                BIN_DIR="$candidate/scripts"
                CONFIG_DIR="$candidate/configs"
                break
            fi
        done
        if [ -z "$BIN_DIR" ]; then
            # 兜底：标准用户级位置
            BIN_DIR="$HOME/.local/bin"
            CONFIG_DIR="$HOME/.config/bw-sync"
        fi
    fi
elif [ -n "$DEPLOY_DIR" ]; then
    echo "[WARN] --deploy-dir 与 --bin-dir/--config-dir 同时指定，以后者为准" >&2
fi

# 环境变量优先
TOKEN="${BWS_ACCESS_TOKEN:-$TOKEN}"

echo "==> bw-sync 安装开始"
echo "    安装目标: 脚本 $BIN_DIR/bw-sync"
echo "              配置 $CONFIG_DIR/bw-sync.yaml"

# ---------- 1. bws CLI ----------
echo "[1/4] 检查 bws CLI..."
# 常见安装位置：PATH 中 / ~/.local/bin / ~/bin
BWS_BIN="$(command -v bws 2>/dev/null || true)"
if [ -z "$BWS_BIN" ] && [ -x "$HOME/.local/bin/bws" ]; then
    BWS_BIN="$HOME/.local/bin/bws"
fi
if [ -z "$BWS_BIN" ] && [ -x "$HOME/bin/bws" ]; then
    BWS_BIN="$HOME/bin/bws"
fi

if [ -n "$BWS_BIN" ]; then
    echo "    已存在: $BWS_BIN ($("$BWS_BIN" --version 2>/dev/null || echo unknown))"
else
    echo "    未安装，开始安装..."
    curl -fsSL https://bws.bitwarden.com/install | sh || {
        echo "[ERROR] bws 安装失败，请手动安装: curl -fsSL https://bws.bitwarden.com/install | sh" >&2
        exit 1
    }
    # bws 默认装到 ~/.local/bin
    if command -v bws &>/dev/null; then
        BWS_BIN="$(command -v bws)"
    elif [ -x "$HOME/.local/bin/bws" ]; then
        BWS_BIN="$HOME/.local/bin/bws"
    else
        echo "[ERROR] 找不到 bws，请手动安装后重试" >&2
        exit 1
    fi
fi

# ---------- 2. bw-sync 主脚本 ----------
echo "[2/4] 安装 bw-sync 到 $BIN_DIR/..."
mkdir -p "$BIN_DIR"
install -m 755 "$SCRIPT_DIR/bw-sync" "$BIN_DIR/bw-sync"
echo "    已安装: $BIN_DIR/bw-sync ($("$BIN_DIR/bw-sync" --version))"

# ---------- 3. Token 文件 ----------
echo "[3/4] 初始化 Token 文件..."
BW_DIR="$HOME/.bw"
mkdir -p "$BW_DIR" && chmod 700 "$BW_DIR"

if [ -f "$BW_DIR/env" ] && [ -z "$TOKEN" ]; then
    echo "    ~/.bw/env 已存在，保留现有 token"
elif [ -n "$TOKEN" ]; then
    printf 'export BWS_ACCESS_TOKEN="%s"\n' "$TOKEN" > "$BW_DIR/env"
    chmod 600 "$BW_DIR/env"
    echo "    token 已写入 ~/.bw/env (chmod 600)"
else
    # 交互式输入
    read -rsp "    请输入 Bitwarden Machine Account Access Token: " TOKEN
    echo
    if [ -z "$TOKEN" ]; then
        echo "[ERROR] token 为空，中止" >&2
        exit 1
    fi
    printf 'export BWS_ACCESS_TOKEN="%s"\n' "$TOKEN" > "$BW_DIR/env"
    chmod 600 "$BW_DIR/env"
    echo "    token 已写入 ~/.bw/env (chmod 600)"
fi

# ---------- 4. 配置文件 ----------
echo "[4/4] 生成配置文件 $CONFIG_DIR/bw-sync.yaml..."
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_DIR/bw-sync.yaml" ]; then
    echo "    配置文件已存在，保留: $CONFIG_DIR/bw-sync.yaml"
else
    cp "$SCRIPT_DIR/config.example.yaml" "$CONFIG_DIR/bw-sync.yaml"
    echo "    已生成模板: $CONFIG_DIR/bw-sync.yaml"
fi

echo
echo "=================================================="
echo "✅ bw-sync 安装完成！"
echo "   - bws CLI:    ${BWS_BIN:-自动查找}"
echo "   - 主脚本:     $BIN_DIR/bw-sync"
echo "   - Token 文件: $BW_DIR/env"
echo "   - 配置模板:   $CONFIG_DIR/bw-sync.yaml"
echo ""
echo "下一步："
echo "   1. 编辑 $CONFIG_DIR/bw-sync.yaml，填入："
echo "      - project_id 或 organization_id"
echo "      - output.mode（env_set / env_file / stdout / shell）"
echo "      - secrets.MAP（环境变量名 → Bitwarden key）"
echo "   2. 预览:  $BIN_DIR/bw-sync -c $CONFIG_DIR/bw-sync.yaml --dry-run"
echo "   3. 执行:  $BIN_DIR/bw-sync -c $CONFIG_DIR/bw-sync.yaml"
echo "=================================================="
