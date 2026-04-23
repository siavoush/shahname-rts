# Claude Code Kickoff Template

Copy the block below into the first message of every new Claude Code session for this project. Fill in the bracketed sections per task.

The template is short on purpose — `CLAUDE.md` (auto-loaded by Claude Code on session start) carries the persistent context. This is just per-session orientation.

---

## Template (copy from here)

```
We're working on the Shahnameh RTS — a real-time strategy game based on Ferdowsi's epic. This Claude Code session is for IMPLEMENTATION ONLY. Design lives in a separate Cowork chat; you build against the specs.

Before doing anything else:
1. Read CLAUDE.md in this folder (project orientation, your responsibilities, escalation rules).
2. Read DECISIONS.md (settled design decisions).
3. Read 01_CORE_MECHANICS.md (the MVP spec you build against).
4. [Add any task-specific docs here]

Today's task: [DESCRIBE ONE FOCUSED THING — e.g., "Set up the basic Godot project structure with placeholder Iran worker unit (Kargar) that can be selected and moved to a target location" — be specific about what 'done' means]

Constraints (also in CLAUDE.md, repeated for emphasis):
- Implementation only. Gameplay/feel/balance questions go to QUESTIONS_FOR_DESIGN.md (append, do not invent answers).
- Build against the spec. If the spec is silent on a *non-design* detail (e.g., a data structure choice), pick the simplest option and document briefly.
- Placeholder graphics only — colored shapes, text labels, no real art.
- Externalize all gameplay constants in game/scripts/constants.gd.
- All Farr changes flow through apply_farr_change().
- Comment any Shahnameh-rooted mechanic with its source reference.

When you're done (or you've done as much as fits this session):
- Append a one-paragraph entry to BUILD_LOG.md: what shipped, what didn't, what the next session needs to know.
- If there are open questions, list them in QUESTIONS_FOR_DESIGN.md and mention them in the build log.
- Commit your work to git on a feature branch (feat/* or proto/*).

Confirm you've read CLAUDE.md, DECISIONS.md, and 01_CORE_MECHANICS.md before starting work. If anything in those docs conflicts with this prompt, follow the docs and flag the conflict.
```

---

## Notes for Siavoush

- The "Today's task" line is the single most important field. Specific tasks produce focused work; vague tasks produce sprawl. Examples of good task framings: *"Implement the Khaneh building — placement, build time, population +5, no other effects yet"* or *"Build the Kaveh Event trigger logic per spec §9, with placeholder VFX (red screen flash + console log)"*. Bad framings: *"Work on the economy"*, *"Make some progress on Iran"*.
- For the very first session (Tier 0 prototype kickoff), the task should be: *"Initialize the Godot 4 project in the game/ folder with a basic scene structure (main menu placeholder → match scene), one selectable unit, and the constants.gd file. Goal: end of session, I can run the project and click a colored cube to select it."*
- For sessions that follow design changes, paste the relevant `DECISIONS.md` line into the kickoff so Claude Code doesn't have to find it.
- If a session is *continuing* prior work rather than starting fresh, replace the "Today's task" with: *"Read the most recent BUILD_LOG.md entries to understand state, then continue with: [next thing]"*.
