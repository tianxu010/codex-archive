#!/usr/bin/env bash
# 一键把 GitHub 上的能力档案同步到本机。
#
#   tools/sync.sh            拉取 + 安装缺失的技能
#   tools/sync.sh --rebuild  拉取 + 重装全部第三方技能
#
# 做三件事：
#   1. git pull 档案仓库
#   2. 把 skills/codex/ 里的自研技能装到 ~/.codex/skills/
#   3. 按 skills.agents.json 索引还原第三方技能（tools/restore-skills.py）
#
# 配置不自动覆盖：config/config.redacted.toml 里含密钥占位符与 Windows 路径，
# 差异用 tools/sync.sh --diff-config 自己看。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_SKILLS="${CODEX_HOME:-$HOME/.codex}/skills"
MODE="${1:-}"

command -v git >/dev/null || { echo "需要 git" >&2; exit 1; }
command -v python3 >/dev/null || { echo "需要 python3" >&2; exit 1; }

echo "==> 拉取档案"
git -C "$REPO_DIR" pull --ff-only

echo "==> 安装自研技能（skills/codex -> $CODEX_SKILLS）"
mkdir -p "$CODEX_SKILLS"
for src in "$REPO_DIR"/skills/codex/*/; do
  name="$(basename "$src")"
  [ "$name" = "_shared" ] && continue
  if [ -d "$CODEX_SKILLS/$name" ] && diff -rq "$src" "$CODEX_SKILLS/$name" >/dev/null 2>&1; then
    echo "    = $name（已是最新）"
    continue
  fi
  mkdir -p "$CODEX_SKILLS/$name"
  cp -r "$src." "$CODEX_SKILLS/$name/"
  echo "    + $name"
done

if [ "$MODE" = "--rebuild" ]; then
  echo "==> 重装第三方技能"
  python3 "$REPO_DIR/tools/restore-skills.py" --refresh
else
  echo "==> 还原第三方技能（只补缺失）"
  python3 "$REPO_DIR/tools/restore-skills.py"
fi

echo
echo "==> 当前技能清单"
ls -1 "$CODEX_SKILLS" | grep -v '^\.system$' | wc -l | xargs echo "技能总数:"
