# game/

The Godot 4 project lives here. This folder is **owned by Claude Code sessions** — the design chat does not modify anything inside it.

When the project is initialized (in the first Tier 0 Claude Code session), the standard Godot layout will appear:

```
game/
├── project.godot          # Godot project file
├── CLAUDE.md              # (optional) implementation-specific Claude Code notes
├── scenes/                # .tscn scene files
├── scripts/               # GDScript files
│   └── constants.gd       # ALL gameplay constants live here (per CLAUDE.md convention)
├── assets/                # placeholder art, audio, fonts
├── shaders/               # GLSL-style shader files
└── tests/                 # GUT test files (if/when we add unit tests)
```

Until then, this folder is empty.

See the project root `CLAUDE.md` for the operating model, conventions, and escalation rules.
