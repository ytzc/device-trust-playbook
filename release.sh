#!/usr/bin/env bash
# release.sh — bump patch version, auto-commit if dirty, tag and push
#
# Usage:
#   ./release.sh          # patch bump: v0.1.0 → v0.1.1
#   ./release.sh minor    # minor bump: v0.1.0 → v0.2.0
#   ./release.sh major    # major bump: v0.1.0 → v1.0.0
#   ./release.sh v1.2.3   # explicit version

set -euo pipefail

BUMP=${1:-patch}

# ── 1. 確保在 repo 根目錄 ────────────────────────────────────────────────────
cd "$(git rev-parse --show-toplevel)"

# ── 2. 如果有未 commit 的變更，自動補 commit ─────────────────────────────────
if ! git diff --quiet || ! git diff --cached --quiet || \
   [ -n "$(git ls-files --others --exclude-standard)" ]; then

  echo "→ Uncommitted changes detected, staging and committing..."

  # stage 所有已追蹤的修改 + 新增檔案（不包含 .gitignore 中排除的）
  git add -A

  git commit -m "chore: update"
  echo "  Committed: chore: update"
fi

# ── 3. 取得最新 tag ──────────────────────────────────────────────────────────
LATEST=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

if [ -z "$LATEST" ]; then
  LATEST="v0.0.0"
  echo "→ No existing semver tag found, starting from v0.0.0"
fi

echo "→ Current version: $LATEST"

# ── 4. 計算下一個版本號 ──────────────────────────────────────────────────────
# 去掉前綴 v
VER="${LATEST#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VER"

if [[ "$BUMP" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  # 使用者直接指定版本號
  NEXT_TAG="$BUMP"
elif [ "$BUMP" = "major" ]; then
  NEXT_TAG="v$((MAJOR + 1)).0.0"
elif [ "$BUMP" = "minor" ]; then
  NEXT_TAG="v${MAJOR}.$((MINOR + 1)).0"
else
  # default: patch
  NEXT_TAG="v${MAJOR}.${MINOR}.$((PATCH + 1))"
fi

echo "→ Next version:    $NEXT_TAG"

# ── 5. 確認不重複 ────────────────────────────────────────────────────────────
if git tag | grep -qx "$NEXT_TAG"; then
  echo "✗ Tag $NEXT_TAG already exists. Aborting."
  exit 1
fi

# ── 6. 建立 tag 並 push ──────────────────────────────────────────────────────
git tag "$NEXT_TAG"
echo "→ Tagged: $NEXT_TAG"

git push origin HEAD
git push origin "$NEXT_TAG"
echo "✓ Pushed branch + tag $NEXT_TAG"
echo ""
echo "  GitHub Actions will now deploy to GitHub Pages with version: $NEXT_TAG"
