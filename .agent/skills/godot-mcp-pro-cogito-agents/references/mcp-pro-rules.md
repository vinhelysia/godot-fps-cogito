# MCP Pro rules

Use Godot MCP Pro aggressively for inspection and verification, but not as a substitute for reading the repo.

## Core stance

- inspect the repository before patching
- use runtime tools to confirm scene-tree assumptions
- use screenshots and live scene inspection to verify visual fixes
- stop the running scene before changing project files
- after patching, re-run the smallest proof that demonstrates success

## Typical tool usage

These names may vary by environment. Use the closest available tool names.

### Runtime inspection
- play the scene or project
- capture one or more screenshots
- query the live scene tree
- inspect live node properties and transforms
- simulate keyboard input when needed for movement or traversal
- stop the scene before editing files

### Repository inspection
- read `.gd`, `.tscn`, `.tres`, `.res`, and `project.godot`
- inspect input actions, autoloads, groups, and exported resources
- read both the scene and the attached script before changing node paths or signal logic

## Guardrails

- do not claim a fix worked unless a verification step actually ran
- do not dismiss mouse-input problems merely because tool simulation is incomplete
- do not trust screenshots alone for logic bugs that require code inspection
- do not use runtime state as proof of repository ownership; confirm both
- do not rewrite broad systems when a local patch and a re-test are enough

## Test loop

1. reproduce or inspect the problem
2. identify the smallest responsible files and nodes
3. stop the running scene
4. patch the repo
5. re-run the narrowest test that proves the change
6. note any unverified edge cases explicitly
