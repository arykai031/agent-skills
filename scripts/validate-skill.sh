#!/bin/bash
# validate-skill.sh — 校验 SKILL.md 格式是否合规
#
# 用法: ./scripts/validate-skill.sh [skill-dir]
# 不带参数时校验全部技能

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

validate_one() {
  local dir="$1"
  local name=$(basename "$dir")
  local skill_md="$dir/SKILL.md"
  local ok=true

  if [ ! -f "$skill_md" ]; then
    echo "  ❌ 缺少 SKILL.md"
    return 1
  fi

  # 检查 frontmatter
  if ! head -1 "$skill_md" | grep -q "^---$"; then
    echo "  ❌ 缺少 frontmatter 起始 ---"
    ok=false
  fi

  if ! grep -q "^name:" "$skill_md"; then
    echo "  ❌ 缺少 frontmatter name 字段"
    ok=false
  fi

  if ! grep -q "^description:" "$skill_md"; then
    echo "  ❌ 缺少 frontmatter description 字段"
    ok=false
  fi

  if [ "$ok" = true ]; then
    echo "  ✅ $name"
    return 0
  else
    return 1
  fi
}

if [ $# -ge 1 ]; then
  echo "校验技能: $1"
  validate_one "$1" || errors=$((errors + 1))
else
  echo "=== 校验 curated/ ==="
  for dir in "$REPO_DIR/curated"/*/; do
    [ -d "$dir" ] || continue
    validate_one "$dir" || errors=$((errors + 1))
  done

  echo ""
  echo "=== 校验 community/ ==="
  for dir in "$REPO_DIR/community"/*/*/; do
    [ -d "$dir" ] || continue
    validate_one "$dir" || errors=$((errors + 1))
  done
fi

echo ""
if [ "$errors" -eq 0 ]; then
  echo "✅ 全部校验通过"
else
  echo "❌ $errors 个技能校验失败"
fi
exit "$errors"
