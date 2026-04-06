# Context Shelf

Non-lossy context management for long [Claude Code](https://docs.anthropic.com/en/docs/claude-code) sessions.

## The Problem

When Claude Code's context window fills up, it compacts conversation history — lossy compression that discards details you might need later. The longer your session, the more you lose.

## The Solution

Context Shelf intercepts compaction and instead writes curated, structured history chunks to disk. Nothing is lost. Claude can retrieve any detail on demand by reading the shelved files.

**Before:** Context fills up → compaction → details gone forever

**After:** Context fills up → shelf triggered → history written to `.claude/history/` → context freed → full detail preserved on disk

## How It Works

1. A **SessionStart hook** injects the TOC from prior sessions so Claude knows what's on the shelf
2. A **PreCompact hook** fires before Claude Code compacts context
2. Claude writes a curated history chunk to `.claude/history/<timestamp>.md` — organized by topic, deduplicated, with provenance tags
3. A **table of contents** stays in context so Claude knows what's on the shelf
4. Claude retrieves shelved context on demand when it needs earlier details

History chunks aren't raw transcripts. They're distilled records that preserve decisions, rationale, discoveries, code changes, and errors — tagged with how each fact was learned:

| Tag | Meaning |
|-----|---------|
| `[read: path]` | Learned by reading a file |
| `[user]` | User stated this |
| `[corrected]` | Initially wrong, later corrected |
| `[inferred]` | Derived from other facts |
| `[tested]` | Verified by running code/tests |
| `[narrative]` | Journey of discovery worth preserving |

## Install

Run this from your project root:

```bash
curl -fsSL https://raw.githubusercontent.com/Pinnacle-Solutions-Group/context-shelf/main/install.sh | bash
```

This will:
- Create `.claude/hooks/context-shelf-session-start.sh` (SessionStart hook — loads TOC)
- Create `.claude/hooks/context-shelf-trigger.sh` (PreCompact hook)
- Create `.claude/skills/shelf/SKILL.md` (`/shelf` command)
- Add the PreCompact hook to `.claude/settings.json` (safely merges if file exists)
- Append shelving instructions to your `CLAUDE.md`

### Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- `jq` (recommended, for safe settings.json merging — install with `brew install jq` or `apt install jq`)

## Usage

### Automatic

Just work normally. When your context window is about to compact, Context Shelf intercepts and shelves the history first. No action needed.

### Manual

Type `/shelf` in Claude Code to trigger shelving at any time — useful before switching topics or when you want a checkpoint.

### Complete a plan

Type `/complete <plan-name>` to archive a finished plan. This:

1. Fuzzy-matches the name against files in `.claude/plans/`
2. Sanity-checks for unchecked boxes or unresolved items
3. Moves the plan to `.claude/completed/`
4. Appends a one-liner to `.claude/plans/COMPLETED.md`

Claude reads `COMPLETED.md` at session start for lightweight awareness of past work, but only digs into `.claude/completed/` when it's relevant to the current task.

### Cross-session

Shelved history persists in `.claude/history/`. When you start a new Claude Code session in the same project, it reads the TOC and can access everything from prior sessions.

## What Gets Installed

```
your-project/
├── .claude/
│   ├── hooks/
│   │   ├── context-shelf-session-start.sh  # SessionStart hook
│   │   └── context-shelf-trigger.sh        # PreCompact hook
│   ├── skills/
│   │   ├── shelf/
│   │   │   └── SKILL.md               # /shelf command
│   │   └── complete/
│   │       └── SKILL.md               # /complete command
│   ├── settings.json                   # Hook configuration
│   ├── history/                        # Shelved chunks (created at runtime)
│   │   ├── 2026-04-04T01-15-00.md
│   │   ├── 2026-04-04T02-30-00.md
│   │   └── toc.md
│   └── completed/                     # Archived plans (created at runtime)
└── CLAUDE.md                           # Shelving instructions appended
```

## Uninstall

Remove the installed files and the Context Shelf section from your CLAUDE.md:

```bash
rm -rf .claude/hooks/context-shelf-trigger.sh .claude/skills/shelf .claude/skills/complete .claude/history .claude/completed
# Then remove the "# Context Shelf" section from CLAUDE.md
# And remove the PreCompact hook from .claude/settings.json
```

## License

MIT
