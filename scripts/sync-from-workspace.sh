#!/bin/bash
# sync-from-workspace.sh — 将 QwenPaw workspace 中的技能同步到 agent-skills 仓库
#
# 用法: ./scripts/sync-from-workspace.sh <workspace-skills-dir>
#
# 示例: ./scripts/sync-from-workspace.sh /app/working/workspaces/Yon-Agent/skills

set -euo pipefail

WORKSPACE_SKILLS="${1:-}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$WORKSPACE_SKILLS" ]; then
  echo "用法: $0 <workspace-skills-dir>"
  echo "示例: $0 /app/working/workspaces/Yon-Agent/skills"
  exit 1
fi

if [ ! -d "$WORKSPACE_SKILLS" ]; then
  echo "错误: 目录不存在 — $WORKSPACE_SKILLS"
  exit 1
fi

echo "=== 同步技能到 agent-skills ==="
echo "来源: $WORKSPACE_SKILLS"
echo "目标: $REPO_DIR"

# 同步 curated — 只同步非 @ 开头的自定义技能
echo ""
echo "--- 精选技能 (curated/) ---"
for skill in "$WORKSPACE_SKILLS"/*/; do
  name=$(basename "$skill")
  # 跳过 @ 开头的社区技能
  if [[ "$name" != @* ]]; then
    target="$REPO_DIR/curated/$name"
    if [ -d "$target" ]; then
      echo "  ⚠️  已存在，跳过: $name"
    else
      cp -r "$skill" "$target"
      echo "  ✅ 已同步: $name"
    fi
  fi
done

# 同步 community — 只同步 @ 开头的社区技能
echo ""
echo "--- 社区技能快照 (community/) ---"
for skill in "$WORKSPACE_SKILLS"/*/; do
  name=$(basename "$skill")
  if [[ "$name" == @* ]]; then
    ns_dir="$REPO_DIR/community/${name%%/*}"
    mkdir -p "$ns_dir"
    target="$REPO_DIR/community/$name"
    if [ -d "$target" ]; then
      echo "  ⚠️  已存在，跳过: $name"
    else
      cp -r "$skill" "$target"
      echo "  ✅ 已同步: $name"
    fi
  fi
done

echo ""
echo "=== 同步完成 ==="
echo "请 review 后提交:"
echo "  cd $REPO_DIR && git add . && git status"
