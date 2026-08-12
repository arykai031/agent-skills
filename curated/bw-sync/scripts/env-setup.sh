#!/bin/sh
# env-setup.sh — 把收口目录的密钥文件接入 shell（幂等，可反复执行）
# 用法: sh env-setup.sh [secrets.env 路径]
# 默认探测: <a_work>/configs/secrets.env（即脚本上级目录的 configs/）
#
# 设计原则（2026-08-12）:
#   - 密钥文件放收口目录（NAS/持久盘），不依赖 ~/.bashrc 存活
#   - ~/.bashrc 只放一行 source（消费入口）；容器重建后 .bashrc 会还原，
#     重跑本脚本即可恢复，密钥文件本身不会丢
#   - 幂等：重复执行不叠加 source 行；权限非 600 自动修复
#
# 功能:
#   1. 校验密钥文件存在
#   2. 校验并修复权限为 600
#   3. 幂等追加 source 行到 ~/.bashrc

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
A_WORK="$(dirname "$SCRIPT_DIR")"

SECRETS_FILE="${1:-$A_WORK/configs/secrets.env}"
BASHRC="${HOME}/.bashrc"

# 1. 校验密钥文件
if [ ! -f "$SECRETS_FILE" ]; then
    echo "❌ 密钥文件不存在: $SECRETS_FILE"
    echo "   请先用 bw-sync（env_file 模式）同步生成，例如:"
    echo "   python3 $A_WORK/scripts/bw-sync -c $A_WORK/configs/bw-sync.yaml"
    exit 1
fi

# 2. 权限校验（600）
PERM="$(stat -c '%a' "$SECRETS_FILE" 2>/dev/null || stat -f '%Lp' "$SECRETS_FILE" 2>/dev/null)"
if [ "$PERM" != "600" ]; then
    echo "⚠️  密钥文件权限为 $PERM，应为 600，正在修复..."
    chmod 600 "$SECRETS_FILE"
    echo "   已修复为 600"
else
    echo "✅ 密钥文件权限 600"
fi

# 3. 幂等追加 source 行
if [ -f "$BASHRC" ] && grep -qF "source \"$SECRETS_FILE\"" "$BASHRC" 2>/dev/null; then
    echo "✅ ~/.bashrc 已包含 source 行，跳过（幂等）"
else
    mkdir -p "$(dirname "$BASHRC")"
    # shellcheck disable=SC1090
    printf '\n# bw-sync 密钥加载（env-setup.sh 托管，幂等）\n[ -f "%s" ] && source "%s"\n' "$SECRETS_FILE" "$SECRETS_FILE" >> "$BASHRC"
    echo "✅ 已追加 source 行到 ~/.bashrc"
fi

echo ""
echo "完成。新 shell 会话将自动加载 $SECRETS_FILE 中的密钥"
echo "立即生效: source ~/.bashrc"
