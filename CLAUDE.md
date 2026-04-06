# Context Shelf

This project provides a context management system for long Claude Code sessions. It replaces lossy compaction with structured, non-lossy history shelving.

## Shelving Process

When triggered (by PreCompact hook or `/shelf` command), do the following:

### Step 1: Write the History Chunk

Create a file at `.claude/history/<timestamp>.md` (e.g. `2026-04-04T01-15-00.md`).

This is NOT a raw transcript. It is a curated, distilled record organized by topic. Rules:

- **Dedup**: Same question asked multiple times → store once with final answer
- **Collapse noise**: Rambling, false starts, corrections → store the conclusion
- **Preserve signal**: Decisions, rationale, discoveries, code changes, errors and fixes
- **Structure by topic**, not by time — group related exchanges even if interleaved
- **Tag provenance** on facts and decisions:
  - `[read: path]` — learned by reading code/files
  - `[user]` — user stated this
  - `[corrected]` — initially wrong, corrected during conversation
  - `[inferred]` — derived from other facts
  - `[tested]` — verified by running code/tests
  - `[narrative]` — the journey of discovery matters, keep it as a mini-narrative

Example chunk format:

```markdown
# History: 2026-04-04T01:15

## Auth Middleware Refactor
- Uses JWT tokens for session management [read: src/middleware/auth.ts]
- Switching to HttpOnly cookies for compliance [user: legal requirement]
- Originally assumed Redis sessions, corrected by user [corrected]
- Tried passport.js and custom middleware before settling on express-jwt [narrative]

## Database Schema Changes
- Added user_preferences table with JSONB column [tested]
- Migration file: src/migrations/003_user_preferences.sql
- Foreign key to users.id, cascading deletes [read: migration file]

## Unresolved
- Rate limiting strategy still TBD — discussed but no decision made
```

### Step 2: Update the In-Context TOC

After writing the chunk, output a TOC block in your response. This stays in the conversation context. Format:

```
## Session History TOC
- [2026-04-04T01:15](.claude/history/2026-04-04T01-15-00.md) — Auth middleware refactor, DB schema changes, rate limiting discussion
```

If there's already a TOC from a previous shelf, append to it.

### Step 3: Write TOC Backup to Disk

Write the full current TOC to `.claude/history/toc.md` as a backup. This can be loaded by future sessions.

### Step 4: Continue Working

After shelving, continue with whatever the user was asking. The shelved context is now on disk — if you need it, scan the TOC and read the relevant chunk file.

## Retrieving Shelved Context

When you need information from earlier in the session:

1. Scan the in-context TOC for relevant chunks
2. Read the specific chunk file from `.claude/history/`
3. Use the detail you need
4. Let the chunk content naturally fall out of context — don't try to retain it all

## Session Start

If `.claude/history/toc.md` exists, read it at the start of a new session to inherit prior context.

## Plan Completion

When triggered by `/complete <plan-name>`, archive a finished plan:

1. **Find the plan** in `.claude/plans/` — fuzzy-match the argument against filenames
2. **Sanity check** — warn the user if there are unchecked boxes, TODOs, or unresolved items
3. **Move** the file to `.claude/completed/`
4. **Update TOC** — append a one-liner to `.claude/plans/COMPLETED.md`

The `COMPLETED.md` file lives in `plans/` so Claude reads it at session start. It provides lightweight awareness of past work — if something in `COMPLETED.md` looks relevant to the current task, read the full plan from `.claude/completed/`.

Rule: read everything in `.claude/plans/`, ignore `.claude/completed/` unless a `COMPLETED.md` entry is relevant.
