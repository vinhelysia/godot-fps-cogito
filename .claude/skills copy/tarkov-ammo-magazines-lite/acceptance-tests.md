# Acceptance Tests

## Manual (Demo Scene)

1. Load correct ammo into correct mag
   - Expect: mag count increases, ammo stack decreases, totals conserved
2. Try wrong-caliber load
   - Expect: reject with reason, no changes
3. Unload mag into existing stack
   - Expect: stack merges up to max, leftover handled (new stack if needed)
4. Fire weapon
   - Expect: mag loadedCount decrements per shot
5. Reload weapon
   - Expect: chooses correct mag deterministically
6. Save/Load
   - Expect: magazine loadedCount persists after restart

## Headless (Required)

- Wrong caliber load fails
- Capacity respected
- No mixing inside mag
- Unload merge works
- Split preserves totals
- Reload deterministic selection
