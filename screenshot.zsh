#!/usr/bin/env zsh
# Open a disposable demo shell for taking README screenshots, and capture it.
#
#   ./screenshot.zsh                 # dev@macbook
#   ./screenshot.zsh alice thinkpad  # alice@thinkpad
#
# Everything shown is throwaway: a fake user and host, a fake home directory, and
# a fake git repo. Your real ~/.zshrc still loads, so node/conda versions and the
# git integration are genuine — only the identity and the working tree are staged.
#
# The image lands in ~/Downloads. The temp tree is removed on exit; your own shell
# and config are never modified.
#
# macOS needs Screen Recording permission for your terminal
# (System Settings -> Privacy & Security -> Screen Recording).

emulate -L zsh
set -u

export PICKAXE_SHOT_USER="${1:-dev}"
export PICKAXE_SHOT_HOST="${2:-macbook}"

dir=$(mktemp -d) || exit 1
[[ -n "$dir" && -d "$dir" ]] || exit 1
trap 'rm -rf "$dir"' EXIT INT TERM

export PICKAXE_SHOT_HOME="$dir/home"

outdir="$HOME/Downloads"
[[ -d "$outdir" ]] || outdir="$HOME"
out="$outdir/pickaxe-$(date +%Y%m%d-%H%M%S).png"

# --- fake project ---------------------------------------------------------
# A real git repo so the theme's branch and dirty markers are truthful, just
# not yours. Deep enough that the path truncation is visible.
proj="$dir/home/Projects/awesome-app"
mkdir -p "$proj/src/components/ui"
print 'console.log("hi")' > "$proj/src/index.js"
print '# awesome-app' > "$proj/README.md"
print '{ "name": "awesome-app" }' > "$proj/package.json"

git -C "$proj" -c init.defaultBranch=main init -q
git -C "$proj" add -A
git -C "$proj" -c user.name=dev -c user.email=dev@example.com commit -qm "initial commit"
print 'work in progress' >> "$proj/src/index.js"   # dirty, so the ! marker shows

# --- disposable shell config ----------------------------------------------
cat > "$dir/.zshrc" <<'EOF'
source "$HOME/.zshrc"

# Substituted after the real config loads. The theme uses %n and %m exactly once
# each, so this cannot clip other prompt escapes.
PROMPT="${PROMPT//\%n/$PICKAXE_SHOT_USER}"
PROMPT="${PROMPT//\%m/$PICKAXE_SHOT_HOST}"

# The terminal title leaks user@host a second time.
DISABLE_AUTO_TITLE=true
print -n "\e]0;awesome-app\a"

# Swap in the fake home last, so %~ abbreviates the demo path to ~ while the real
# config above still resolved against the real home.
export HOME="$PICKAXE_SHOT_HOME"
cd "$HOME/Projects/awesome-app"
clear
EOF

# --- run ------------------------------------------------------------------
print
print "  Demo shell: ${PICKAXE_SHOT_USER}@${PICKAXE_SHOT_HOST} in ~/Projects/awesome-app"
print "  Suggested:  ls · cat missing.yml (shows FAIL) · cd src/components/ui (shows truncation)"
print
print "  A camera cursor appears shortly — click this window to capture."
print "  Esc cancels the capture. Ctrl-D exits and cleans up."
print
print -n "  Press Enter to start: "
read -r _

( sleep 1; screencapture -w -o -x "$out" 2>/dev/null ) &
capture_pid=$!

ZDOTDIR="$dir" zsh -i

# If the demo shell is gone there is nothing left worth capturing, so drop a
# still-pending camera cursor rather than leaving the script apparently frozen
# waiting for a click.
kill $capture_pid 2>/dev/null
pkill -P $capture_pid screencapture 2>/dev/null
wait $capture_pid 2>/dev/null

print
if [[ -f "$out" ]]; then
  print "  Saved: $out"
else
  print "  No image captured (cancelled, or Screen Recording permission is missing)."
fi
