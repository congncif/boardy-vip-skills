# PROJECT_STRUCTURE — Project Topology Contract

> **Update rule**: Update this file in the same change set whenever code, podspecs, Xcode schemes,
> module boundaries, or PRD scope changes project structure.
>
> **Boundary**: global configuration values live in `PROJECT_CONFIG.md`; topology/inventory lives here.

---

## 1. Scheme Inventory

| Scheme | Purpose | Structure owner |
|--------|---------|-----------------|
| `{ProjectName}` | Main app target | App shell |
| `{FirstModule}` | {FirstModule} interface module | `{ModuleRoot}/{FirstModule}/IO/` |
| `{FirstModule}Plugins` | {FirstModule} implementation module | `{ModuleRoot}/{FirstModule}/Sources/` |

> **FILL**: Replace example rows above with actual schemes.
> Refresh inventory: `xcodebuild -workspace {Workspace} -list`

---

## 2. Module Inventory

| Module | Role | Interface target | Implementation target |
|--------|------|------------------|------------------------|
| `{FirstModule}` | **FILL: describe purpose** | `{FirstModule}` | `{FirstModule}Plugins` |

> **FILL**: Add one row per module.

---

## 3. Synchronization Rules

Update this file when:

- New module added or removed
- Module renamed
- Module responsibility changes
- Interface/implementation target names change
- Xcode scheme added, removed, or renamed
- Shared component target added or removed
- Module folder moved

Do NOT update for temporary branches, local experiments, or implementation details.

---

## 4. Verification Commands

```bash
# List schemes
xcodebuild -workspace {Workspace} -list

# Check module folders
find {ModuleRoot} -maxdepth 2 -name "*.podspec" -print

# Check interface/implementation split
find {ModuleRoot} -maxdepth 3 \( -path "*/IO" -o -path "*/Sources" \) -print
```
