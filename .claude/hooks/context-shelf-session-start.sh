#!/bin/bash
# Context Shelf — SessionStart hook
# Injects the shelved history TOC and private notes TOC into context.

HISTORY_TOC=".claude/history/toc.md"
PRIVATE_TOC=".claude/private/toc.md"

CONTEXT=""

if [ -f "$HISTORY_TOC" ]; then
  HISTORY_CONTENT=$(cat "$HISTORY_TOC")
  CONTEXT="CONTEXT SHELF: Prior session history is available on disk. Here is the table of contents:\n\n${HISTORY_CONTENT}\n\nWhen you need details from a prior session, read the relevant chunk file from .claude/history/. You do NOT need to read them all now — just be aware they exist."
fi

if [ -f "$PRIVATE_TOC" ]; then
  PRIVATE_CONTENT=$(cat "$PRIVATE_TOC")
  if [ -n "$CONTEXT" ]; then
    CONTEXT="${CONTEXT}\n\n"
  fi
  CONTEXT="${CONTEXT}PRIVATE NOTES: Private conversation notes exist on disk from prior sessions. These contain sensitive content that is gitignored and must NOT be referenced in committed files.\n\n${PRIVATE_CONTENT}\n\nRead specific files from .claude/private/ when you need private context. Do NOT copy private content into .claude/history/ or any tracked file."
fi

if [ -n "$CONTEXT" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${CONTEXT}"
  }
}
EOF
else
  echo '{}'
fi
