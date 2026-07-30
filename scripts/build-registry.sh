#!/bin/bash
# build-registry.sh — 从 SKILL.md 文件自动更新 registry.json
#
# 扫描 curated/ 和 community/ 下的所有 SKILL.md，提取元数据写入 registry.json

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$REPO_DIR/registry.json"

echo "=== 构建 registry.json ==="

# 初始化 registry
cat > "$REGISTRY" <<'REGEOF'
{
  "version": 1,
  "description": "agent-skills 技能注册表 — 机器可读索引",
  "updated": "REGEOF"
date -u '+%Y-%m-%dT%H:%M:%SZ' >> "$REGISTRY"
cat >> "$REGISTRY" <<'REGEOF'
",
  "skills": [
REGEOF

first=true
for skill_dir in "$REPO_DIR/curated"/*/ "$REPO_DIR/community"/*/*/; do
  [ -d "$skill_dir" ] || continue
  skill_md="$skill_dir/SKILL.md"
  [ -f "$skill_md" ] || continue

  name=$(basename "$skill_dir")
  
  # 提取 namespace
  rel_path="${skill_dir#$REPO_DIR/}"
  if [[ "$rel_path" == community/* ]]; then
    namespace=$(echo "$rel_path" | cut -d'/' -f2)
  else
    namespace="curated"
  fi

  # 从 SKILL.md frontmatter 提取 description
  desc=$(head -20 "$skill_md" | grep -E "^description:" | sed 's/^description: *//' | tr -d '"' | tr -d "'" || echo "")

  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$REGISTRY"
  fi

  cat >> "$REGISTRY" <<ITEM
    
    {
      "name": "$name",
      "namespace": "$namespace",
      "description": "$desc",
      "path": "$rel_path"
    }
ITEM
done

echo "" >> "$REGISTRY"
cat >> "$REGISTRY" <<'REGEOF'
  ]
}
REGEOF

echo "✅ registry.json 已更新 — $(grep -c '"name"' "$REGISTRY") 个技能"
