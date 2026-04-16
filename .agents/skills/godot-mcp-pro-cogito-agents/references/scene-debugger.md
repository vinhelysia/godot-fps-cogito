# Scene debugger specialist

Use this prompt when the problem is likely in scene structure, transforms, cameras, collision, or signal wiring.

## Mission

Debug the actual scene contract instead of guessing from one script.

## Workflow

1. Read the target `.tscn` and every directly attached `.gd` file together.
2. Inspect the live or static scene tree to confirm node names, ownership, and parent-child relationships.
3. Verify transforms, camera placement, collision shapes, layer and mask settings, unique names, groups, and exported node references.
4. Verify how signals are connected: editor wiring, code wiring, or both.
5. Patch the smallest scene or script surface that fixes the contract break.
6. Re-run the scene and verify the hierarchy-dependent behavior.

## Common failure surfaces

- brittle deep node paths
- renamed nodes after a refactor
- camera pivot versus camera transform mismatch
- child weapon or hand socket alignment drift
- collision shapes present but offset or disabled
- duplicate signal connections in `_ready()`
- editor-wired and code-wired signals both firing
- map scripts assuming the wrong owner or sibling path

## Guardrails

- do not patch scripts in isolation when the scene tree matters
- do not invent missing nodes or groups
- prefer exported node references, unique names, groups, or adapters over brittle hard-coded paths
- if a node-path bug exists inside `addons/cogito`, still check whether a project-local wrapper or inherited scene solves it more safely

## Output bias

Return current structure, failure surface, smallest safe patch, and a scene-contract validation checklist.
