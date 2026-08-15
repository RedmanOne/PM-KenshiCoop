# KenshiLib_deps pin + patches

`third_party/KenshiLib_deps/` (git-ignored, see `docs/BUILD_SETUP.md`) is a clone of
[KenshiLib_Examples_deps](https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps).
That repo's `master` moves independently of this project - its headers get
reorganized and occasionally ship bugs, and KenshiCoop's plugin source only
compiles against a specific snapshot. This folder pins that snapshot and
patches the two bugs found in it.

## The pin

Commit **`e75769b`** ("Fixed missing boost environment variable"). Newer
commits break the build for KenshiCoop specifically:

- `b566d74` ("Update KenshiLib to 0.4.0") moves `kenshi/CombatClass.h` to
  `kenshi/combat/CombatClass.h`, which KenshiCoop's source doesn't expect
  (`#include <kenshi/CombatClass.h>` in `src/plugin/game/EngineInternal.h`).

Older commits are missing headers KenshiCoop needs (`kenshi/CameraClass.h`,
`kenshi/ZoneManager.h`, `kenshi/gui/TitleScreen.h` were added between
`a63131d` and `960a7c0`), so `e75769b` (or its parent `960a7c0`, same
content for our purposes) is the newest commit that has everything without
the 0.4.0 reorg.

## The patches

Both fix genuine bugs in the vendor headers at this pin - not something
KenshiCoop's own source did wrong. Apply from the **KenshiCoop repo root**
(not from inside `KenshiLib_deps`):

```bash
git apply third_party/KenshiLib_patches/0001-fix-duplicate-buildingdesignation-enum.patch
git apply third_party/KenshiLib_patches/0002-add-craftingitem-stub-definition.patch
```

1. **`0001-fix-duplicate-buildingdesignation-enum.patch`** - `enum
   BuildingDesignation` is defined identically in both
   `kenshi/Building/Building.h` and `kenshi/Platoon.h` (a vendor copy-paste
   bug - `Platoon.h`'s copy even has a `// TODO move?` comment above it).
   Any translation unit that includes both hits MSVC error C2011
   (`'BuildingDesignation': 'enum' type redefinition`), which KenshiCoop's
   plugin does. Fix: drop the duplicate from `Platoon.h`, `#include
   "Building/Building.h"` there instead.

2. **`0002-add-craftingitem-stub-definition.patch`** - `CraftingItem` is
   only ever forward-declared in `kenshi/Building/CraftingBuilding.h`,
   never given a real definition anywhere in this vendor snapshot. That
   same header declares a `std::deque<CraftingItem>` member, which needs a
   *complete* type under MSVC10's STL, so any translation unit pulling this
   header in hits error C2027 (`'CraftingItem': use of undefined type`).
   Fix: give `CraftingItem` a minimal empty-class stand-in. Nothing in
   KenshiCoop touches its members.

`scripts/setup_toolchain.ps1` does the clone, pin checkout, and patch
application automatically - see that script rather than doing this by hand
unless you're debugging the pin itself.
