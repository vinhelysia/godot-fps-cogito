# Acceptance Tests

## Manual (Demo Scene)

1. Load correct ammo into correct mag (totals conserved)
2. Wrong caliber load rejected (no state change)
3. Unload mag creates/merges stacks correctly
4. Insert mag into weapon slot
5. Fire decrements mag count
6. Fire fails with no mag and with empty mag
7. Reload swaps to a loaded compatible mag deterministically
8. Save/Load preserves mag counts and inserted mag

## Headless

- Wrong caliber load fails
- Capacity respected
- No mixing
- Unload merges then creates stacks
- Split preserves totals
- Reload deterministic + space failure handled
- Fire state transitions correct
