# Codex router for Godot MCP Pro + Cogito

Use this file as the root agent instruction set for Codex on Godot 4.6.1 + Cogito 1.1.5 repositories.

## Working stance

- repository first
- runtime verification second
- narrow patches
- project-local ownership before addon edits

## Choose one specialist prompt

- `references/visual-qa.md`
- `references/scene-debugger.md`
- `references/gameplay-fixer.md`
- `references/level-integrator.md`
- `references/regression-tester.md`

Pick the closest fit, then keep the rest unloaded unless needed.

## Required checks

- read `project.godot`
- inspect `addons/cogito` boundaries
- inspect the target `.tscn` and attached `.gd` files together
- verify node ownership, signals, transforms, input actions, and resources before editing
- use Godot MCP Pro to re-test after changes

## Boundary rule

Avoid editing `addons/cogito` unless:
- the request explicitly targets Cogito internals
- the bug clearly lives in addon-owned code
- no robust project-local path exists

If addon edits are necessary, explain why.

## Default output

1. Assessment
2. Evidence
3. Patch plan
4. Diff or file plan
5. Caveats
6. Validation
