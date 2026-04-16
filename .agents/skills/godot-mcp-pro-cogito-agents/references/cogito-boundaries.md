# Cogito boundaries

Use this file to decide where code should live.

## Default rule

Prefer project-local scripts, scenes, resources, wrappers, adapters, and controllers before editing `addons/cogito`.

Edit addon code only when at least one of these is true:
- the user explicitly asked to adjust Cogito itself
- the needed hook does not exist and cannot be added project-side without brittle duplication
- the bug is clearly inside addon-owned code rather than project wiring or content

When editing addon code, explain:
1. why a project-local extension path was insufficient
2. which addon files are touched
3. what upgrade or merge risk remains

## Ownership matrix

### Usually project-local

- custom interactables and pickups
- custom items, weapons, ammo, and loadout rules
- quest state and dialogue progression
- AI suspicion, faction, patrol logic, and alert rules
- level triggers, encounter scripting, mission beats, and scripted sequences
- game-specific UI, prompts, audio, and feedback
- content data resources and balancing values

### Sometimes addon-owned, but inspect first

- generic player controller behavior
- shared inventory framework behavior
- reusable interaction framework behavior
- common weapon base behavior
- save/load serialization hooks
- generic AI utility functions or reusable base states

### Strong signal that addon edits are probably wrong

- the requested behavior is specific to one map, mission, faction, or weapon
- the change depends on game-specific content or story state
- the patch would hard-code project node paths into addon scripts
- the patch would couple addon code to one project-specific autoload or UI scene

## Extension patterns to prefer

- inherited scenes instead of direct addon scene edits
- child component nodes for optional behavior
- project-side adapter scripts that translate Cogito signals into local systems
- exported resources for content variation and balancing
- groups or explicit node references rather than hard-coded deep node paths
- autoloads only for truly global game state, not convenience shortcuts

## Inspection checklist before any addon edit

- Is there already a signal, exported variable, or overridable method that solves this?
- Can the behavior live in a project-local child node or wrapper scene?
- Is the issue actually scene wiring, input setup, or project data rather than addon logic?
- Would the addon edit make future Cogito updates harder?
- Can the same outcome be achieved with an adapter between Cogito and project systems?
