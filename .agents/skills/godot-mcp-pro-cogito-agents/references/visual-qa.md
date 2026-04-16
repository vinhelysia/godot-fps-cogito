# Visual QA specialist

Use this prompt when the user wants the agent to play the game, capture screenshots, spot visible issues, and fix them with Godot MCP Pro.

## Mission

Perform visual QA on a Godot game using MCP Pro tools. Iterate up to three fix cycles and verify what changed.

## Workflow

### Step 1 — capture

- play the relevant scene or the game entry scene
- wait briefly for the scene to stabilize
- capture an initial screenshot
- if movement is possible, move through the space with short keyboard inputs and capture more screenshots from different positions
- gather at least three screenshots when practical, but prioritize relevance over raw count

### Step 2 — analyze

Check every screenshot for:
- invisible or missing objects
- broken transforms, orientation, or hand-held alignment
- missing materials, placeholder surfaces, or broken lighting
- clipping, floating props, or collision mismatches that show visually
- UI overlap, cut-off text, or unreadable prompts
- broken camera distance, clipping, or framing
- NPCs or enemies stuck in obviously wrong poses or locations

### Step 3 — inspect

Do not rely on screenshots alone.

- inspect the live scene tree
- inspect relevant node properties and transforms
- inspect the attached scripts and the source scene files
- confirm whether the problem lives in project code, content wiring, or Cogito addon code

### Step 4 — fix

- stop the running scene before editing files
- patch the smallest responsible scene, script, or resource
- prefer project-local fixes over addon edits
- after patching, replay the scene and capture new screenshots

### Step 5 — iterate

Repeat the loop up to three times if the first pass reveals follow-on issues.

### Step 6 — report

Summarize:
- what looked wrong
- what files or nodes caused it
- what changed
- what was verified visually
- what remains unverified or unfixed

## Input verification rule

Tool simulation limits do not excuse input bugs.

If the issue might involve look, aim, click, interaction, or cursor state:
- inspect `_input`, `_unhandled_input`, `InputEventMouseMotion`, and `InputEventMouseButton` code
- verify `Input.mouse_mode` behavior
- verify input map actions and signal wiring
- never write off mouse problems as “just an MCP limitation” if the repository code is wrong

## Output bias

Return assessment, evidence, patch plan, diff, caveats, and screenshot-backed validation notes.
