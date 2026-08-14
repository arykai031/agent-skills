#!/bin/bash
# Install or verify exact copies of a curated skill.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  echo "Usage: $0 <install|check> <skill-name> <skills-root> [skills-root ...]" >&2
  exit 2
}

[ "$#" -ge 3 ] || usage

action="$1"
skill_name="$2"
shift 2

case "$skill_name" in
  ""|.*|*/*) echo "Invalid skill name: $skill_name" >&2; exit 2 ;;
esac

source_dir="$REPO_DIR/curated/$skill_name"
[ -f "$source_dir/SKILL.md" ] || {
  echo "Curated skill not found: $source_dir" >&2
  exit 1
}

check_one() {
  local skills_root="$1"
  local target="$skills_root/$skill_name"

  [ -d "$target" ] && [ ! -L "$target" ] || {
    echo "Missing or unsafe deployment: $target" >&2
    return 1
  }

  if diff -qr "$source_dir" "$target" >/dev/null; then
    echo "ok: $target"
  else
    echo "drift: $target" >&2
    diff -qr "$source_dir" "$target" >&2 || true
    return 1
  fi
}

install_one() {
  local skills_root="$1"
  local target="$skills_root/$skill_name"
  local stage backup

  mkdir -p "$skills_root"
  [ ! -L "$skills_root" ] || {
    echo "Refusing symlinked skills root: $skills_root" >&2
    return 1
  }
  [ ! -L "$target" ] || {
    echo "Refusing symlinked deployment: $target" >&2
    return 1
  }

  stage="$(mktemp -d "$skills_root/.${skill_name}.stage.XXXXXX")"
  backup=""
  trap 'rm -rf -- "$stage"; if [ -n "$backup" ] && [ -e "$backup" ] && [ ! -e "$target" ]; then mv -- "$backup" "$target"; fi' RETURN
  cp -a "$source_dir/." "$stage/"

  if [ -e "$target" ]; then
    backup="$(mktemp -d "$skills_root/.${skill_name}.backup.XXXXXX")"
    rmdir "$backup"
    mv -- "$target" "$backup"
  fi

  mv -- "$stage" "$target"
  stage=""
  if [ -n "$backup" ]; then
    rm -rf -- "$backup"
    backup=""
  fi
  trap - RETURN
  echo "installed: $target"
}

case "$action" in
  check)
    for skills_root in "$@"; do check_one "$skills_root"; done
    ;;
  install)
    for skills_root in "$@"; do install_one "$skills_root"; done
    ;;
  *) usage ;;
esac
