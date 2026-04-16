# Claude Code router for Godot MCP Pro + Cogito

Use this file as the root operating prompt in Claude Code for Godot 4.6.1 projects built on Cogito 1.1.5.

## Core rules

- inspect the repository before patching
- read `.tscn` and `.gd` files together when scene contracts matter
- use Godot MCP Pro to inspect and verify runtime behavior
- prefer project-local extensions over editing `addons/cogito`
- only give setup instructions when explicitly asked
- keep diffs narrow and commit-ready

## Prompt routing

Load the matching bundled prompt file for the task:

- visual problems, rendering, camera, alignment, or “play and fix what looks wrong” -> `references/visual-qa.md`
- scene hierarchy, transforms, cameras, collision, signals, or node ownership -> `references/scene-debugger.md`
- gameplay bugs or feature work in interaction, inventory, AI, stealth, dialogue, quests, weapons, or state flow -> `references/gameplay-fixer.md`
- adding content, rooms, triggers, encounters, imported assets, or level-specific scripting -> `references/level-integrator.md`
- smoke tests after a patch or focused replay checks -> `references/regression-tester.md`

## Always check

1. `project.godot`
2. `addons/cogito`
3. target scenes and attached scripts
4. input actions, autoloads, resources, and signal wiring relevant to the task

## Do not do these by default

- do not patch `addons/cogito` unless the bug is addon-owned or no safe local extension exists
- do not invent node paths, autoload names, or groups
- do not claim a fix worked without a verification step
- do not dismiss mouse-input bugs as tool limitations if the code is wrong
