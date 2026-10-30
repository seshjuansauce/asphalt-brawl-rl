#!/usr/bin/env bash
# asphalt-brawl-rl — Phase 0 scaffold
# Idempotent: safe to run repeatedly; only creates/commits what's missing.
# Usage: ./setup.sh          (scaffold + commit)
#        ./setup.sh --push   (scaffold + commit + push)

set -euo pipefail

PUSH=false
[[ "${1:-}" == "--push" ]] && PUSH=true

info() { printf "\033[1;34m[setup]\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m[ ok ]\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31m[fail]\033[0m %s\n" "$1"; exit 1; }

# --- 0. Sanity checks --------------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Run this from the repo root."
[[ "$(uname -m)" == "arm64" ]] || info "Warning: not running native arm64 (check for Rosetta)."

GIT_NAME="$(git config user.name || true)"
GIT_EMAIL="$(git config user.email || true)"
[[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]] || fail "Set git user.name and user.email first."
info "Committing as: $GIT_NAME <$GIT_EMAIL>"

# --- 1. uv -------------------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 || fail "Homebrew not found; install uv manually."
  info "Installing uv..."
  brew install uv
fi
ok "uv $(uv --version | awk '{print $2}')"

# --- 2. Python project + deps ------------------------------------------------
if [[ ! -f pyproject.toml ]]; then
  info "Initialising Python 3.11 project..."
  uv init --python 3.11 --no-readme
  rm -f main.py hello.py   # remove uv's placeholder file
fi

info "Syncing dependencies..."
uv add numpy gymnasium pygame stable-baselines3 tensorboard pyyaml
uv add --dev pytest ruff
ok "Dependencies installed"

# --- 3. Folder skeleton ------------------------------------------------------
for d in game env render render/sprites train train/configs eval tests; do
  mkdir -p "$d"
done
for pkg in game env render train eval tests; do
  [[ -f "$pkg/__init__.py" ]] || touch "$pkg/__init__.py"
done
touch render/sprites/.gitkeep train/configs/.gitkeep
ok "Folder skeleton ready"

# --- 4. .gitignore -----------------------------------------------------------
if [[ ! -f .gitignore ]]; then
  cat > .gitignore <<'EOF'
# Python
.venv/
__pycache__/
*.pyc
.pytest_cache/
.ruff_cache/

# Training artefacts (use GitHub Releases for the final model)
runs/
mlruns/
checkpoints/
videos/
*.zip
*.pt

# OS
.DS_Store
EOF
  ok ".gitignore created"
else
  ok ".gitignore already exists (left unchanged)"
fi

# --- 5. LICENSE (MIT) --------------------------------------------------------
if [[ ! -f LICENSE ]]; then
  cat > LICENSE <<EOF
MIT License

Copyright (c) $(date +%Y) $GIT_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
  ok "LICENSE (MIT) created"
else
  ok "LICENSE already exists (left unchanged)"
fi

# --- 6. Smoke check ----------------------------------------------------------
uv run python -c "import gymnasium, pygame, stable_baselines3, numpy; print('imports ok')" >/dev/null \
  && ok "Core imports work" || fail "Import check failed"

# --- 7. Commit (only if something changed) -----------------------------------
git add -A
if git diff --cached --quiet; then
  ok "Nothing new to commit"
else
  git commit -m "Scaffold project structure" >/dev/null
  ok "Committed: $(git log -1 --format='%h %s (%an)')"
fi

# --- 8. Push (optional) ------------------------------------------------------
if $PUSH; then
  git push -u origin "$(git branch --show-current)"
  ok "Pushed"
fi

info "Done."
