#!/bin/bash
# build-registry.sh — 从 SKILL.md 文件自动更新 registry.json
#
# 委托给 Python 脚本处理（更可靠的多行 YAML 解析）
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/build-registry.py
