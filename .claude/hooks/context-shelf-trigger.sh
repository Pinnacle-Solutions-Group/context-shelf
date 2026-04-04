#!/bin/bash
# Context Shelf Trigger — fires on PreCompact
# Returns additionalContext telling Claude to shelf its history before compaction happens.

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "CONTEXT SHELF TRIGGER: Your context is about to be compacted. Instead of losing history to compaction, you MUST run the shelving process NOW before responding to anything else. Follow the shelving instructions in CLAUDE.md to write a curated history chunk to .claude/history/ and update the in-context TOC. This preserves full detail on disk while freeing context space. Do this immediately."
  }
}
EOF
