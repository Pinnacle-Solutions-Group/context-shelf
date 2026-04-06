---
name: complete
description: Mark a plan as completed — move it from .claude/plans/ to .claude/completed/ and add a TOC entry so Claude retains lightweight awareness without loading the full plan.
---

The user wants to mark a plan as completed. Follow these steps:

### Step 1: Identify the plan

Look at the argument the user passed (e.g. `/complete signatures`). Fuzzy-match it against files in `.claude/plans/` (exclude `COMPLETED.md`).

- If exactly one match: proceed.
- If multiple matches: list them and ask which one.
- If no match: list available plans and ask the user to clarify.

### Step 2: Sanity check

Read the plan file. Look for signs it may not actually be complete:

- Unchecked checkboxes (`- [ ]`)
- Sections marked as TODO, TBD, or "Unresolved"
- Status frontmatter that isn't "completed" or "done"

If any are found, tell the user what you found and ask: "This plan has [N unchecked items / unresolved sections]. Shelve it anyway?"

If the plan looks clean, or the user confirms, proceed.

### Step 3: Move the file

- Create `.claude/completed/` if it doesn't exist
- Move the plan file: `.claude/plans/<name>.md` → `.claude/completed/<name>.md`

### Step 4: Update COMPLETED.md

Append a one-liner to `.claude/plans/COMPLETED.md` (create it if it doesn't exist).

Format:

```markdown
# Completed Plans

- [plan-name](../completed/plan-name.md) — One-line summary of what this plan covered
```

Infer the summary from the plan's title, description, or content. Keep it under 120 characters — this is what Claude reads at session start to stay aware of past work without loading the full plans.

### Step 5: Confirm

Tell the user:

"Shelved **plan-name** to `.claude/completed/`. TOC entry added to `.claude/plans/COMPLETED.md`."
