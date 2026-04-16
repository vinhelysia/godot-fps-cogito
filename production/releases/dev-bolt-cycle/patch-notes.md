# Dev Patch — M700 Bolt Cycle Rework
*2026-04-13*

## Highlights
The M700's bolt cycle has been completely rebuilt from the ground up. The rifle now feels
responsive and correct whether you're firing from the hip or scoped in — no more jarring
snaps when transitioning between stances mid-cycle.

---

## Gameplay Changes

### M700 — Bolt Cycle Rework
The bolt cycle animation has been replaced with a tween-driven system. The bolt handle
now moves independently from the rest of the viewmodel, meaning the sight picture stays
stable throughout the entire cycling motion.

- The bolt handle lifts, pulls back, pushes forward, and locks down as a smooth
  multi-step motion — timing matches the original hand-animated cycle (1.2 seconds total)
- The viewmodel body dips slightly as the bolt is pulled open, then settles back into
  position as it closes — giving the action a satisfying weight
- When aiming down sights, the bolt cycles without breaking your sight picture or
  snapping the weapon out of position
- All bolt timing and motion values are now tunable directly in the M700 resource inspector

---

## Bug Fixes

### M700
- **Fixed:** Firing while ADS then releasing aim mid bolt-cycle caused the weapon to
  teleport back to the ADS position when the cycle completed
- **Fixed:** Firing from the hip then pressing ADS mid bolt-cycle caused the weapon to
  snap back to hip position instead of smoothly entering aim
- **Fixed:** Bolt cycling while ADS caused a permanent rotation offset on the viewmodel
  that accumulated with each shot — the weapon would drift further off-axis over time

---

## Known Issues
- The original `bolt_cycle` animation in the M700 scene is no longer played during
  normal gameplay — the tween system takes over when a bolt part node is assigned.
  It remains in the scene as reference data and as a fallback.
- Bolt tween default values are tuned for the M700. Any future bolt-action weapon will
  need its own values configured in the inspector.
