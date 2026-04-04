#!/bin/bash
# Context Shelf installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Pinnacle-Solutions-Group/context-shelf/main/install.sh | bash

set -e

REPO_RAW="https://raw.githubusercontent.com/Pinnacle-Solutions-Group/context-shelf/main"

echo "Installing Context Shelf..."

# Create directories
mkdir -p .claude/hooks
mkdir -p .claude/skills/shelf
mkdir -p .claude/history

# Download hooks
curl -fsSL "$REPO_RAW/.claude/hooks/context-shelf-trigger.sh" -o .claude/hooks/context-shelf-trigger.sh
curl -fsSL "$REPO_RAW/.claude/hooks/context-shelf-session-start.sh" -o .claude/hooks/context-shelf-session-start.sh
chmod +x .claude/hooks/context-shelf-trigger.sh .claude/hooks/context-shelf-session-start.sh

# Download skill
curl -fsSL "$REPO_RAW/.claude/skills/shelf/SKILL.md" -o .claude/skills/shelf/SKILL.md

# Merge or create settings.json
SETTINGS_FILE=".claude/settings.json"

SESSION_START_HOOK='{"type":"command","command":".claude/hooks/context-shelf-session-start.sh"}'
PRECOMPACT_HOOK='{"type":"command","command":".claude/hooks/context-shelf-trigger.sh"}'

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
    add_hook "SessionStart" "$SESSION_START_HOOK" ".claude/hooks/context-shelf-session-start.sh"
    add_hook "PreCompact" "$PRECOMPACT_HOOK" ".claude/hooks/context-shelf-trigger.sh"
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

# Append shelving instructions to CLAUDE.md
CLAUDE_MD="CLAUDE.md"
MARKER="# Context Shelf"

if [ -f "$CLAUDE_MD" ] && grep -q "$MARKER" "$CLAUDE_MD"; then
  echo "CLAUDE.md already contains Context Shelf instructions — skipping."
else
  echo "" >> "$CLAUDE_MD"
  curl -fsSL "$REPO_RAW/CLAUDE.md" >> "$CLAUDE_MD"
  echo "Appended shelving instructions to $CLAUDE_MD"
fi

echo ""
echo "Context Shelf installed successfully!"
echo ""
echo "  - Hook:    .claude/hooks/context-shelf-trigger.sh"
echo "  - Skill:   .claude/skills/shelf/SKILL.md"
echo "  - Config:  .claude/settings.json"
echo "  - Docs:    CLAUDE.md"
echo ""
echo "Usage:"
echo "  - Automatic: shelving triggers before context compaction"
echo "  - Manual:    type /shelf in Claude Code"
