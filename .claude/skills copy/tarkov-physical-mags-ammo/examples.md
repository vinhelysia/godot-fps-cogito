# Examples

## Load ammo into mag

Drag 5.56 ammo stack onto 5.56 mag:

- Mag becomes X/30
- Ammo stack decreases by X

## Wrong caliber reject

Drag 9x19 ammo onto 5.56 mag:

- Reject with "Wrong caliber"

## Insert mag into weapon

Drag mag item onto weapon mag slot:

- Weapon stores insertedMagInstanceId
- Mag is now equipped (removed from stash grid or moved to equipment slot container)

## Fire

Press Fire:

- If no mag: fail NO_MAG
- If mag empty: fail EMPTY_MAG
- Else mag.loadedCount -= 1

## Reload

Press Reload:

- Picks compatible mag with highest loadedCount (tie: lowest instanceId)
- Swaps old mag back into inventory if space; else fails
