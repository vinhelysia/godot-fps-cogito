# Output contract

Use these as the default response shapes unless the user asks for another format.

## Bug fix

```markdown
## Assessment
[one-paragraph diagnosis]

## Evidence
- `path/file.gd`: what matters
- `path/scene.tscn`: relevant node or attachment detail
- addon/project boundary: where the bug actually lives

## Patch plan
1. [smallest safe edit]
2. [secondary edit only if required]

## Diff
```diff
[commit-ready diff]
```

## Caveats
- [cogito upgrade-path or integration note]
- [godot lifecycle, signal, node-path, camera, transform, or save/load caveat]

## Validation
- [ ] Reproduce the original issue
- [ ] Verify the failure no longer occurs
- [ ] Check adjacent behavior that could regress
```

## Feature work

```markdown
## Goal
[requested behavior in concrete game terms]

## Existing integration points
- owner scene:
- attached scripts:
- signals:
- exported properties/resources:
- cogito hook or boundary:

## Implementation plan
1. [file to edit and why]
2. [file to add and why]
3. [scene wiring, signal, or resource change]

## Diff or file plan
```diff
[commit-ready diff]
```

## Caveats
- [upgrade-path or ownership note]
- [timing, performance, camera, or editor caveat]

## Validation
- [ ] Happy path
- [ ] Edge case
- [ ] Save/load or reload path if relevant
```

## Architecture review

```markdown
## Current structure
[short summary of tree, scripts, system ownership, and addon boundaries]

## Findings
1. [fragile dependency or coupling]
2. [state, signal, or ownership issue]
3. [upgrade, performance, or maintainability issue]

## Recommended sequence
1. [lowest-risk refactor]
2. [next safe step]
3. [optional deeper cleanup]

## Risks and tradeoffs
- [what improves]
- [what could break]

## Validation
- [ ] Existing scenes still load
- [ ] Signal flow still works
- [ ] Save/load or state transitions remain valid
```
