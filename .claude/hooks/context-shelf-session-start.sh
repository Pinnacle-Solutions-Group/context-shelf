#!/bin/bash
# Context Shelf — SessionStart hook
# Injects the shelved history TOC into context so Claude knows what's available on disk.

TOC_FILE=".claude/history/toc.md"

if [ -f "$TOC_FILE" ]; then
  TOC_CONTENT=$(cat "$TOC_FILE")
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "CONTEXT SHELF: Prior session history is available on disk. Here is the table of contents:\n\n${TOC_CONTENT}\n\nWhen you need details from a prior session, read the relevant chunk file from .claude/history/. You do NOT need to read them all now — just be aware they exist."
  }
}
EOF
else
  echo '{}'
fi
