---
name: shelf
description: Shelve conversation history to disk, freeing context space while preserving full detail. Scans for private/sensitive content and offers to write it to .claude/private/ (gitignored) instead.
---

Run the context shelving process now. Follow the shelving instructions in CLAUDE.md exactly.

**Before writing anything**, scan the conversation for private or sensitive content (client names, financial data, pricing, business strategy, personal info, credentials). If found, alert the user with specifics and offer to write sensitive content to `.claude/private/` instead of `.claude/history/`. Wait for their response before proceeding.

Then write a curated history chunk covering the conversation since the last shelf (or the entire conversation if this is the first shelf).

After writing the history chunk (and private notes if applicable) and TOC to disk, tell the user:

"Context shelved. Run `/clear` to free context — your history is safely on disk and the TOC will reload automatically on the fresh session."
