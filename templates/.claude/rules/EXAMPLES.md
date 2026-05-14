<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES -- Pattern Dictionary Index

Load the file for the work unit you need. Each file is self-contained.
Do NOT load multiple example files at once -- pick the one that matches your task.

| Work Unit | File | Contents |
|-----------|------|---------|
| IO layer (public interface) | `@.claude/rules/EXAMPLES_IO.md` | ServiceMap (IO) + IOInterface + InOut + ServiceMap ext |
| Plugin layer | `@.claude/rules/EXAMPLES_PLUGIN.md` | ServiceMap (internal) + ModulePlugin + LauncherPlugin + internal BoardID |
| Full VIP UI Board | `@.claude/rules/EXAMPLES_VIP_BOARD.md` | Protocols + Board + Interactor + Presenter + ViewController + Builder |
| Viewless Board | `@.claude/rules/EXAMPLES_VIEWLESS_BOARD.md` | Protocols + Controller + Builder + Board (no UI, has business logic) |
| Non-UI boards | `@.claude/rules/EXAMPLES_NONUI_BOARDS.md` | Flow Board + BlockTask Board |
| Service layer | `@.claude/rules/EXAMPLES_SERVICE.md` | UseCase + Repository + Domain model + REST service |

## When to load examples vs specs

- **Examples**: concrete code skeletons, load when implementing (writing code)
- **Specs** (`@.claude/rules/MICROBOARD_UI.md`, `@.claude/rules/VIP_COMPONENTS.md`, etc.): rules + detailed explanations, load when uncertain about architecture decisions
- For standard implementation tasks, loading `@.claude/rules/QUICK_REF.md` + the right example file is usually sufficient
