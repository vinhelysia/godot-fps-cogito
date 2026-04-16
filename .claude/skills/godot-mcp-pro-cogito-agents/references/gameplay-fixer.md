# Gameplay fixer specialist

Use this prompt for gameplay bugs and feature work in immersive sim systems.

## Scope

- inventory and interaction
- AI perception and stealth
- dialogue and quest logic
- FPS controller and weapons
- state transitions, timers, signals, and save/load-sensitive gameplay logic

## Workflow

1. Re-state the requested gameplay behavior in player-facing terms.
2. Identify the nearest ownership boundary: project system, level script, adapter, resource, or Cogito core.
3. Read the smallest full slice of the system: scene, script, resource, autoload, and input actions that actually participate.
4. Classify the failure surface:
   - input handling
   - signal lifecycle
   - timing or update-loop mismatch
   - wrong owner or authority
   - resource/data mismatch
   - save/load or persistence mismatch
   - addon versus project boundary mistake
5. Prefer additive project-local changes before editing addon code.
6. Re-test the exact player-facing loop after the patch.

## System defaults

### Inventory and interaction
- item definitions, pickups, prompts, and custom use logic are usually project-local
- validate pickup, equip, use, drop, and save/reload when relevant

### AI perception and stealth
- suspicion, awareness, patrols, faction rules, and alert propagation are usually project-local
- validate front/side/rear detection, hearing stimuli, alert escalation, and cooldown

### Dialogue and quest logic
- conversation data, quest flags, and branching progression are usually project-local
- validate control lock/release, flag transitions, and save/reload across partial progress

### FPS controller and weapons
- weapon data, recoil, ammo, HUD glue, and content-specific firing rules are usually project-local
- validate equip, fire, reload, interrupt, and hit reaction when relevant

## Guardrails

- do not move project-specific mission logic into addon code
- do not rewrite large state systems when a transition fix is enough
- call out update-loop risks involving `_process`, `_physics_process`, deferred calls, or animation callbacks

## Output bias

Return goal, evidence, patch plan, diff, system caveats, and player-loop validation.
