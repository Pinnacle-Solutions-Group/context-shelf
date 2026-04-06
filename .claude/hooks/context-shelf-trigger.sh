#!/bin/bash
# Context Shelf Trigger — fires on PreCompact
# Returns additionalContext telling Claude to shelf its history before compaction happens.

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "CONTEXT SHELF TRIGGER: Your context is about to be compacted. Instead of losing history to compaction, you MUST run the shelving process NOW before responding to anything else. IMPORTANT: Before writing anything, scan the conversation for private/sensitive content (client names, financial data, pricing, business strategy, personal info). If found, alert the user and offer to write sensitive content to .claude/private/ (gitignored) instead of .claude/history/. Follow the full shelving and private content instructions in CLAUDE.md. Do this immediately."
  }
}
EOF
