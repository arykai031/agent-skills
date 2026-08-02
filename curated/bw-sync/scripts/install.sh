#!/bin/bash
# ============================================================
# bw-sync 一键安装脚本
#
# 功能：自动完成以下步骤
#   1. 安装/检查 bws CLI（Bitwarden Secrets Manager 命令行工具）
#   2. 安装 bw-sync 主脚本到 /usr/local/bin
#   3. 初始化 Token 文件 ~/.bw/env（chmod 600）
#   4. 生成配置文件 /etc/bw-sync/config.yaml（模板）
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
#   # 指定安装路径（默认 /usr/local/bin）
#   bash install.sh --bin-dir "$HOME/.local/bin"
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/bw-sync"

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
        -h|--help)
            echo "用法: bash install.sh [--token <token>] [--bin-dir <dir>] [--config-dir <dir>]"
            exit 0 ;;
        *)
            echo "未知参数: $1"; exit 1 ;;
    esac
done

# 环境变量优先
TOKEN="${BWS_ACCESS_TOKEN:-$TOKEN}"

echo "==> bw-sync 安装开始"

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
echo "[4/4] 生成配置文件 $CONFIG_DIR/config.yaml..."
mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_DIR/config.yaml" ]; then
    echo "    配置文件已存在，保留: $CONFIG_DIR/config.yaml"
else
    cp "$SCRIPT_DIR/config.example.yaml" "$CONFIG_DIR/config.yaml"
    echo "    已生成模板: $CONFIG_DIR/config.yaml"
fi

echo
echo "=================================================="
echo "✅ bw-sync 安装完成！"
echo "   - bws CLI:    ${BWS_BIN:-自动查找}"
echo "   - 主脚本:     $BIN_DIR/bw-sync"
echo "   - Token 文件: $BW_DIR/env"
echo "   - 配置模板:   $CONFIG_DIR/config.yaml"
echo ""
echo "下一步："
echo "   1. 编辑 $CONFIG_DIR/config.yaml，填入："
echo "      - project_id 或 organization_id"
echo "      - output.mode（env_set / env_file / stdout / shell）"
echo "      - secrets.MAP（环境变量名 → Bitwarden key）"
echo "   2. 预览:  bw-sync -c $CONFIG_DIR/config.yaml --dry-run"
echo "   3. 执行:  bw-sync -c $CONFIG_DIR/config.yaml"
echo "=================================================="
