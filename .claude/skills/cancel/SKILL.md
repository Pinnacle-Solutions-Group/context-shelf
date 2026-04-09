---
name: cancel
description: Mark a plan as cancelled — move it from .claude/plans/ to .claude/cancelled/ and add a TOC entry so Claude retains lightweight awareness without loading the full plan.
---

The user wants to cancel a plan. Follow these steps:

### Step 1: Identify the plan

Look at the argument the user passed (e.g. `/cancel signatures`). Fuzzy-match it against files in `.claude/plans/` (exclude `COMPLETED.md` and `CANCELLED.md`).

- If exactly one match: proceed.
- If multiple matches: list them and ask which one.
- If no match: list available plans and ask the user to clarify.

### Step 2: Confirm cancellation

Read the plan file. Tell the user what the plan covers and ask: "Cancel this plan? It will be moved to `.claude/cancelled/`."

If the user confirms, proceed.

### Step 3: Move the file

- Create `.claude/cancelled/` if it doesn't exist
- Move the plan file: `.claude/plans/<name>.md` → `.claude/cancelled/<name>.md`

### Step 4: Update CANCELLED.md

Append a one-liner to `.claude/plans/CANCELLED.md` (create it if it doesn't exist).

Format:

```markdown
# Cancelled Plans

- [plan-name](../cancelled/plan-name.md) — One-line summary of what this plan covered
```

Infer the summary from the plan's title, description, or content. Keep it under 120 characters — this is what Claude reads at session start to stay aware of cancelled work without loading the full plans.

### Step 5: Private content check

Before confirming, scan the plan and the conversation around it for private or sensitive content (client names, financial data, pricing, business strategy, personal info). If found, alert the user and offer to write a private summary to `.claude/private/` — the plan in `.claude/cancelled/` may be committed to git.

### Step 6: Confirm

Tell the user:

"Cancelled **plan-name** — moved to `.claude/cancelled/`. TOC entry added to `.claude/plans/CANCELLED.md`."

If private notes were written, also mention: "Private notes saved to `.claude/private/` (gitignored)."
