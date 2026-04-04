# Context Shelf

## Problem

Claude Code conversations lose context as they grow long. The built-in compaction is lossy and opaque — you can't see what was dropped or get it back. Claude gets sluggish around ~100k context.

## Solution

At ~100k context, Claude "shelves" the conversation: writes a curated history chunk to disk and keeps only a short TOC line in context. This frees up massive context space while losing nothing — the full detail is on disk, addressable from the TOC.

## Architecture: Two Layers

### In Context: The Master TOC

The TOC lives in the conversation, not on disk. It grows by ~1 line per shelving cycle. This is what Claude actually sees and uses to decide when to pull detail from disk.

```markdown
# Session History
- [2026-04-03T23:50](../.claude/history/2026-04-03T23-50-00.md) — Auth middleware review, JWT→cookie decision, DB schema changes
- [2026-04-04T01:15](../.claude/history/2026-04-04T01-15-00.md) — API rate limiting, test coverage for auth module
- [2026-04-04T02:30](../.claude/history/2026-04-04T02-30-00.md) — CI pipeline fix, deployment config
```

Because shelving replaces ~100k of conversation with one line, this dramatically delays when compaction would ever be needed. You could do 20-30 shelving cycles before the TOC itself becomes a concern — and at that point you could meta-shelf (TOC of TOCs).

### On Disk: History Chunks

```
<project-root>/
└── .claude/
    └── history/
        ├── 2026-04-03T23-50-00.md    # full curated history
        ├── 2026-04-04T01-15-00.md    # next chunk
        └── ...
```

Claude reads these on demand when the TOC tells it something relevant is in a particular chunk. No separate TOC files on disk — that's an unnecessary layer since the TOC is in context and Claude wouldn't know to look for on-disk TOC files anyway.

**Backup**: The master TOC is *also* written to `.claude/history/toc.md` as a safety net. A session-start hook can load it if resuming a session or starting a new one that should inherit prior context.

## Shelving Trigger

Auto-trigger at ~100k context. This preempts the built-in compaction, which is strictly worse:
- Compaction is lossy and opaque
- Shelving is non-lossy — full detail on disk, indexed by TOC in context
- Shelving *dramatically reduces* how often compaction is needed

A manual `/shelf` command should also be available.

## History as Intelligent Compression

History chunks are NOT raw transcripts. They're **curated, distilled records** — like meeting minutes, not a court reporter's log.

- **Dedup**: Same question asked 3 times → stored once with final answer
- **Collapse noise**: Rambling, false starts, corrections → store the conclusion
- **Preserve signal**: Decisions, rationale, discoveries, code changes, errors and fixes
- **Structured by topic**, not by time — group related exchanges even if interleaved

### The Provenance Problem

If you only store *what you learned*, you lose *how you learned it*. The provenance affects confidence:

- A fact read from code is high-confidence
- A fact from an offhand user comment might be wrong
- A fact that was corrected mid-conversation has a specific evolution
- Sometimes the *journey* of discovering something is itself valuable ("we tried 3 approaches, here's why only the third worked")

**Approach**: Lightweight provenance tags on facts/decisions:

```markdown
## Auth Middleware Architecture
- Uses JWT tokens for session management [read: src/middleware/auth.ts]
- Switching to HttpOnly cookies for compliance [user: legal requirement]
- Originally assumed Redis sessions, corrected by user [corrected]
- Tried passport.js and custom middleware before settling on express-jwt [narrative]
```

Tags:
- `[read: path]` — learned by reading code/files
- `[user]` — user stated this
- `[corrected]` — initially wrong, corrected during conversation
- `[inferred]` — derived from other facts
- `[tested]` — verified by running code/tests
- `[narrative]` — the journey matters, not just the conclusion

## Implementation

### Approach: CLAUDE.md Instructions + `/shelf` Skill

CLAUDE.md instructs Claude to self-shelf when context feels heavy (~100k). The `/shelf` skill provides an explicit trigger. A session-start hook loads the backup TOC from disk if one exists.

### Shelving Process

1. Claude reviews conversation since last shelf
2. Writes a curated, topic-organized history chunk to `.claude/history/<timestamp>.md`
3. Appends a one-line summary to the in-context TOC
4. Writes the updated TOC to `.claude/history/toc.md` (backup)
5. Continues working with the freed context space

### Retrieval Process

1. User asks about something, or Claude needs prior context
2. Claude scans the in-context TOC for relevant chunks
3. Reads the specific chunk file(s) from disk
4. Uses the detail, then lets it naturally fall out of context

## Open Questions

1. **How does Claude know its context size?** — Can hooks inject an approximate token count? Or does Claude just estimate based on conversation length?
2. **Format** — Plain markdown with provenance tags seems right. Structured enough to be useful, loose enough to write in-flow.
3. **Cross-session** — History should persist. Session-start hook loads the TOC backup from disk.
4. **Compression quality** — Err on keeping more detail early on, get more aggressive as the approach is validated.
