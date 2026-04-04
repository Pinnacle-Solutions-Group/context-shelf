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
HOOK_CONFIG='{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":".claude/hooks/context-shelf-session-start.sh"}]}],"PreCompact":[{"matcher":"","hooks":[{"type":"command","command":".claude/hooks/context-shelf-trigger.sh"}]}]}}'

if [ -f "$SETTINGS_FILE" ]; then
  # Check if jq is available for safe merge
  if command -v jq &> /dev/null; then
    EXISTING=$(cat "$SETTINGS_FILE")
    # Check if PreCompact hook already exists
    if echo "$EXISTING" | jq -e '.hooks.PreCompact' &> /dev/null; then
      echo "Warning: PreCompact hook already exists in $SETTINGS_FILE — skipping settings merge."
      echo "You may need to manually add the context-shelf hook."
    else
      echo "$EXISTING" | jq '. * '"$HOOK_CONFIG" > "$SETTINGS_FILE"
    fi
  else
    echo "Warning: jq not found. Cannot safely merge into existing $SETTINGS_FILE."
    echo "Please manually add the PreCompact hook. See README for details."
  fi
else
  echo "$HOOK_CONFIG" | if command -v jq &> /dev/null; then jq .; else cat; fi > "$SETTINGS_FILE"
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
