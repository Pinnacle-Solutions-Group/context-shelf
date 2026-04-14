#!/bin/bash
# Context Shelf installer
# Usage:
#   Project install (default):
#     curl -fsSL https://raw.githubusercontent.com/Pinnacle-Solutions-Group/context-shelf/main/install.sh | bash
#   Global install (applies to every repo on this machine):
#     curl -fsSL https://raw.githubusercontent.com/Pinnacle-Solutions-Group/context-shelf/main/install.sh | bash -s -- --global

set -e

REPO_RAW="https://raw.githubusercontent.com/Pinnacle-Solutions-Group/context-shelf/main"

MODE="project"
for arg in "$@"; do
  case "$arg" in
    --global|-g) MODE="global" ;;
    --project)   MODE="project" ;;
    --help|-h)
      echo "Usage: install.sh [--global|--project]"
      echo "  --project  Install into ./.claude (default)"
      echo "  --global   Install into ~/.claude so it applies to every repo"
      exit 0
      ;;
  esac
done

if [ "$MODE" = "global" ]; then
  BASE="$HOME/.claude"
  echo "Installing Context Shelf (global) into $BASE..."
else
  BASE=".claude"
  echo "Installing Context Shelf (project) into ./$BASE..."
fi

# Create directories
mkdir -p "$BASE/hooks"
mkdir -p "$BASE/skills/shelf"
mkdir -p "$BASE/skills/complete"
mkdir -p "$BASE/skills/cancel"
mkdir -p "$BASE/skills/dependencies"

# Per-repo state dirs only make sense for project installs.
# For global installs, the hook/skill scripts create these lazily in $CLAUDE_PROJECT_DIR on first use.
if [ "$MODE" = "project" ]; then
  mkdir -p "$BASE/history"
  mkdir -p "$BASE/completed"
  mkdir -p "$BASE/cancelled"
  mkdir -p "$BASE/private"
fi

# Download hooks
curl -fsSL "$REPO_RAW/.claude/hooks/context-shelf-trigger.sh" -o "$BASE/hooks/context-shelf-trigger.sh"
curl -fsSL "$REPO_RAW/.claude/hooks/context-shelf-session-start.sh" -o "$BASE/hooks/context-shelf-session-start.sh"
chmod +x "$BASE/hooks/context-shelf-trigger.sh" "$BASE/hooks/context-shelf-session-start.sh"

# Download skills
curl -fsSL "$REPO_RAW/.claude/skills/shelf/SKILL.md" -o "$BASE/skills/shelf/SKILL.md"
curl -fsSL "$REPO_RAW/.claude/skills/complete/SKILL.md" -o "$BASE/skills/complete/SKILL.md"
curl -fsSL "$REPO_RAW/.claude/skills/cancel/SKILL.md" -o "$BASE/skills/cancel/SKILL.md"
curl -fsSL "$REPO_RAW/.claude/skills/dependencies/SKILL.md" -o "$BASE/skills/dependencies/SKILL.md"

# Merge or create settings.json
SETTINGS_FILE="$BASE/settings.json"

# Hook command paths: absolute for global install (so they work from any cwd),
# repo-relative for project install (so they travel with the repo).
if [ "$MODE" = "global" ]; then
  SESSION_START_CMD="$BASE/hooks/context-shelf-session-start.sh"
  PRECOMPACT_CMD="$BASE/hooks/context-shelf-trigger.sh"
else
  SESSION_START_CMD=".claude/hooks/context-shelf-session-start.sh"
  PRECOMPACT_CMD=".claude/hooks/context-shelf-trigger.sh"
fi

SESSION_START_HOOK="{\"type\":\"command\",\"command\":\"${SESSION_START_CMD}\"}"
PRECOMPACT_HOOK="{\"type\":\"command\",\"command\":\"${PRECOMPACT_CMD}\"}"

add_hook() {
  local EVENT="$1"
  local HOOK_ENTRY="$2"
  local COMMAND="$3"
  local EXISTING=$(cat "$SETTINGS_FILE")

  # Check if this specific command is already registered
  if echo "$EXISTING" | jq -e ".hooks.${EVENT}[]?.hooks[]? | select(.command == \"${COMMAND}\")" &> /dev/null; then
    echo "  $EVENT: context-shelf hook already present — skipping."
    return
  fi

  # If the event exists, append our hook entry to the first matcher's hooks array
  if echo "$EXISTING" | jq -e ".hooks.${EVENT}" &> /dev/null; then
    echo "$EXISTING" | jq ".hooks.${EVENT}[0].hooks += [${HOOK_ENTRY}]" > "$SETTINGS_FILE"
    echo "  $EVENT: appended context-shelf hook to existing hooks."
  else
    # Event doesn't exist — add it
    echo "$EXISTING" | jq ".hooks.${EVENT} = [{\"matcher\":\"\",\"hooks\":[${HOOK_ENTRY}]}]" > "$SETTINGS_FILE"
    echo "  $EVENT: added context-shelf hook."
  fi
}

if [ -f "$SETTINGS_FILE" ]; then
  if command -v jq &> /dev/null; then
    # Ensure .hooks exists
    if ! jq -e '.hooks' "$SETTINGS_FILE" &> /dev/null; then
      jq '. + {"hooks":{}}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
    add_hook "SessionStart" "$SESSION_START_HOOK" "$SESSION_START_CMD"
    add_hook "PreCompact"   "$PRECOMPACT_HOOK"   "$PRECOMPACT_CMD"
  else
    echo "Warning: jq not found. Cannot safely merge into existing $SETTINGS_FILE."
    echo "Please manually add the hooks. See README for details."
  fi
else
  if command -v jq &> /dev/null; then
    echo '{"hooks":{"SessionStart":[{"matcher":"","hooks":['"$SESSION_START_HOOK"']}],"PreCompact":[{"matcher":"","hooks":['"$PRECOMPACT_HOOK"']}]}}' | jq . > "$SETTINGS_FILE"
  else
    echo '{"hooks":{"SessionStart":[{"matcher":"","hooks":['"$SESSION_START_HOOK"']}],"PreCompact":[{"matcher":"","hooks":['"$PRECOMPACT_HOOK"']}]}}' > "$SETTINGS_FILE"
  fi
  echo "  Created $SETTINGS_FILE with context-shelf hooks."
fi

# --- Project-only: gitignore + CLAUDE.md ---
# For global installs, .gitignore belongs to each repo (not touched here),
# and instructions go into ~/.claude/CLAUDE.md instead of a project CLAUDE.md.
if [ "$MODE" = "project" ]; then
  GITIGNORE=".gitignore"
  PRIVATE_PATTERN=".claude/private/"

  if [ -f "$GITIGNORE" ]; then
    if grep -qF "$PRIVATE_PATTERN" "$GITIGNORE"; then
      echo "  .gitignore already excludes $PRIVATE_PATTERN — skipping."
    else
      echo "" >> "$GITIGNORE"
      echo "# Context Shelf — private conversation notes (never commit)" >> "$GITIGNORE"
      echo "$PRIVATE_PATTERN" >> "$GITIGNORE"
      echo "  Added $PRIVATE_PATTERN to .gitignore"
    fi
  else
    echo "# Context Shelf — private conversation notes (never commit)" > "$GITIGNORE"
    echo "$PRIVATE_PATTERN" >> "$GITIGNORE"
    echo "  Created .gitignore with $PRIVATE_PATTERN"
  fi

  CLAUDE_MD="CLAUDE.md"
else
  CLAUDE_MD="$BASE/CLAUDE.md"
fi

# Append shelving instructions to CLAUDE.md (project or ~/.claude/CLAUDE.md)
MARKER="# Context Shelf"

if [ -f "$CLAUDE_MD" ] && grep -q "$MARKER" "$CLAUDE_MD"; then
  echo "$CLAUDE_MD already contains Context Shelf instructions — skipping."
else
  [ -f "$CLAUDE_MD" ] && echo "" >> "$CLAUDE_MD"
  curl -fsSL "$REPO_RAW/CLAUDE.md" >> "$CLAUDE_MD"
  echo "Appended shelving instructions to $CLAUDE_MD"
fi

echo ""
echo "Context Shelf installed successfully!"
echo ""
echo "  - Hooks:   $BASE/hooks/context-shelf-session-start.sh"
echo "             $BASE/hooks/context-shelf-trigger.sh"
echo "  - Skills:  $BASE/skills/shelf/SKILL.md"
echo "             $BASE/skills/complete/SKILL.md"
echo "             $BASE/skills/cancel/SKILL.md"
echo "             $BASE/skills/dependencies/SKILL.md"
echo "  - Config:  $SETTINGS_FILE"
if [ "$MODE" = "project" ]; then
  echo "  - Private: $BASE/private/ (gitignored)"
fi
echo "  - Docs:    $CLAUDE_MD"
echo ""
echo "Usage:"
echo "  - Automatic: shelving triggers before context compaction"
echo "  - Manual:    type /shelf in Claude Code"
echo "  - Complete:  type /complete <plan-name> to archive a finished plan"
echo "  - Cancel:    type /cancel <plan-name> to archive an abandoned plan"
echo "  - Deps:      type /dependencies to build a plan dependency graph"
echo ""
if [ "$MODE" = "global" ]; then
  echo "Global install: skills, hooks, and instructions now apply to every repo."
  echo "Per-repo state (.claude/history, .claude/private, .claude/plans, ...) is"
  echo "created automatically in each project as you use it. Remember to add"
  echo ".claude/private/ to each repo's .gitignore — global install cannot do"
  echo "that for you."
else
  echo "Private content: /shelf and /complete will scan for sensitive content"
  echo "and offer to write it to .claude/private/ (gitignored) instead of"
  echo "committed directories."
fi
