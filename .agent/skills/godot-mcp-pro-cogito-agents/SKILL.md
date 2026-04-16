---
name: godot-mcp-pro-cogito-agents
description: repository-first godot 4.6.1 work for projects built on cogito 1.1.5 with godot mcp pro available. use when chatgpt or codex should inspect a full godot project folder, route work to a specialist agent prompt, diagnose bugs, review scene trees, run visual qa, integrate new content, re-test fixes, or produce patch-ready diffs for immersive sim and 3d fps systems while preferring project-local extensions over editing addons/cogito.
---

# Godot MCP Pro Cogito Agents

## Overview

Use this skill as a router for Godot 4.6.1 + Cogito 1.1.5 projects when Godot MCP Pro is available.

Treat Cogito as a protected gameplay template. Prefer project-local scripts, scenes, resources, wrappers, child nodes, adapters, and inherited scenes before editing `addons/cogito`. Only give setup or install instructions when the user explicitly asks for them.

## Routing workflow

1. Inspect the repository first.
2. Confirm the request type.
3. Load the most relevant specialist prompt from the references below.
4. Use MCP Pro for inspection, runtime validation, and iteration.
5. Return narrow diffs, file plans, or validation findings.

## Initial inspection order

Always do these checks before choosing a specialist prompt:

1. Read `project.godot`.
2. Inspect `addons/cogito` to understand framework boundaries.
3. Inspect target scenes, scripts, resources, autoloads, input actions, and any scene currently mentioned by the user.
4. Read relevant `.tscn` and `.gd` files together.
5. Confirm which nodes own the behavior, which scripts are attached, and which boundaries are addon-owned versus project-owned.

Never invent node paths, autoload names, input actions, scene structure, or upgrade hooks.

## Decision tree

### Visual breakage, rendering issues, camera issues, alignment problems, or “play the scene and fix what looks wrong”
Load `references/visual-qa.md`.

### Broken scene hierarchy, transforms, signals, collision, cameras, or node ownership assumptions
Load `references/scene-debugger.md`.

### Gameplay bugs or feature work in input, interaction, inventory, AI, stealth, dialogue, quests, weapons, or state flow
Load `references/gameplay-fixer.md`.

### Adding assets, rooms, props, encounters, triggers, navigation, interactables, mission scripting, or Cogito-compatible content wiring
Load `references/level-integrator.md`.

### Re-running checks after a patch, smoke testing multiple scenes, or building a focused regression loop
Load `references/regression-tester.md`.

If a task spans multiple categories, start with the prompt that best matches the failure surface, then pull in another reference only if needed.

## MCP Pro rules

Use Godot MCP Pro as an inspection and verification layer, not as a replacement for repository reading.

- Read repository files before changing them.
- Use runtime scene tools to confirm actual node ownership, transforms, and state.
- Use play/stop/screenshot workflows to verify visual and interaction fixes.
- Reproduce issues before patching whenever practical.
- After edits, re-run the narrowest test loop that proves the fix.

Use `references/mcp-pro-rules.md` for tool-usage boundaries.

## Cogito boundary rule

Do not edit `addons/cogito` by default.

Only edit addon code when at least one of these is true:
- the user explicitly asked to modify Cogito internals
- the bug is clearly in addon-owned code
- no safe project-local extension path exists

Use `references/cogito-boundaries.md` whenever ownership is ambiguous.

## Output rules

Use `references/output-contract.md` unless the user explicitly wants another format.

Default structure:
1. Assessment
2. Evidence
3. Patch plan or implementation plan
4. Diff or file plan
5. Caveats
6. Validation

## Companion files

For external agent environments, also use:
- `assets/CLAUDE.md` for Claude Code
- `assets/AGENTS.md` for Codex

These companion files mirror the routing and guardrails from this skill.
