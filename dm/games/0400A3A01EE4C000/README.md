# Pokémon Pokopia (`0400A3A01EE4C000`)

A Switch 2 game: update v655360 (the title screen says Ver. 2.0.1), SDK 20.5.25 built for the Switch 2 (`Ounce`). Koei Tecmo's KTGL engine on NVN2, modules `main`, `subsdk0` (WebM movies) and `sdk`. **Plays on the Mac**: the opening, the character choice and the first area's tutorial at about 60 fps, including 31 minutes of the user's playtest with no GPU error and no crash. A save from an earlier run loads and continues. No IPA has been built.

## What it needs

| Setting | Where | Why |
|---|---|---|
| `mem_reserve 0x270000000`, `app_pool 0x240000000` | [`game.tsv`](game.tsv) | Donkey Kong Bananza's 9 GB layout, not measured here. The NPDM declares no system resource |
| `mem_used 0x5600000` | `game.tsv` | the rewritten modules take 82 MB, more than the default 64 MB that `SetHeapSize` checks the game's request against |
| `pad_layout full` | `game.tsv` | |
| `res_levels 76a489f3… 0x2849658 34 …` | `game.tsv` | the dynamic resolution's size table and its nine level lists in update v655360's main: the host lowers the lists to fit `DM_WINDOW_SIZE` (the Android launcher's Game resolution) at load ([Render size](#render-size)) |

## Files

- A dump folder whose `updates/<version>/` holds the whole RomFS; [`pack_dump.py`](../../../scripts/pack_dump.py) packs it without a base RomFS. RomFS: the newer RDB (as ROMANCE OF THE THREE KINGDOMS 8 REMAKE's) under `motor_asset_re/KIDS_PLATFORM_OUNCE`, and a `LD_C0_R.BIN` / `LI_C0_R.IDX` LINKDATA pair.
- Shaders: 131,426 in [`shader_map.tsv`](shader_map.tsv) ([KTGL on NVN2](../../../docs/reference/shaders.md#ktgl-on-nvn2-switch-2-glslc-outputs-and-ld_--li_-linkdata)). The Mac playtest's library held only the 8,157 that its runs asked for (with their pixel shaders), listed in [`shader_seen.tsv`](shader_seen.tsv); [Building selected Mac shaders](../../../docs/development.md#building-selected-mac-shaders) builds those alone. Such a library has no stamp and no `c1_full.tsv`, and each start logs that in red. The NSP script builds all 131,426: an estimated 9 hours on an M4 Pro (from 1,001 shaders) since [the builder stopped keeping the 4.4 GB of packages in memory](../../../docs/reference/shaders.md#a-shader-build-that-keeps-its-packages-in-memory-runs-one-worker-at-a-time) (before, players saw about one shader a second and ETAs of 20 to 200 hours: GitHub issue #1036).
- No `pso_manifest.tsv` yet, so each start also logs a red line for the missing seed list. In the runs here no draw waited on it.

## Shaders

- Resolved: `cc679c7b4d3e703c` did not translate (`LDC with a bindless bank or an address mode`): an indexed read of c1 with the bank in the address register, found on Hyrule Warriors: Age of Imprisonment, which ships the same shader ([LDC with the bank in its address register](../../../docs/reference/shaders.md#ldc-with-the-bank-in-its-address-register-is)); not rerun on this game. The census also lists f55 three times, two more of that LDC and 16 BRX with no target: whether they are the forms since translated ([Barrier moves around warp shuffles](../../../docs/reference/shaders.md#barrier-moves-around-warp-shuffles)) is not checked (open).
- A `3D binding fallback` line fires once at about frame 2100: a 2D 8x8 texture in a 3D slot. The shader is not identified (open).

## Rendering

- Frames take about 16.7 ms. A cold file cache, as after a reboot, keeps the game on the loading icon for over a minute, and a clean run there says nothing: check that `[nvn] frame N: … calls` reached about 3,500.
- The lit HDR target is RG11B10, exposure a 2x1 RGBA32F image, tone map `075fd7285c64b798` with a 32³ LUT, final `ed5f4c6386ca621d`, the luminance histogram compute `2118ab534fac88c6`.
- `texraw` pads rows: an RG11B10 dump has a 16-byte stride with 4-byte pixels at the head of each row. It returns one slice of a 3D texture, and serials shift between runs.

## Render size

KTGL's dynamic resolution, found by disassembly of update v655360's main (2026-11-05):

- **The table:** 34 sizes at `main+0x2849658` (u32 widths, then the heights at `+0x28496e0`), read by the getters at `main+0x1129990` / `+0x11299d0`. Level 0 is 960x540 and each level adds 32x18 up to level 30, 1920x1080; levels 31-33 are 2560x1440, 3840x2160 and 7680x4320. The leaf functions at `main+0x1129980` / `+0x11299c0` return 1920 / 1080, but only as a fallback when the display object at `[main+0x35618d0]` is missing; the window size is that object's `+0x48` / `+0x4c`.
- **The controller:** set up at `main+0x22ca40`, which takes the levels from a two-byte config (the maximum to `+0x29`, so `+0x18` / `+0x1c` hold the maximum size); stepped at `main+0x22cd20`, which moves an index down a level list when its late-frame counter passes 1.25 and up when the other one does. The render size is the level's size times a scale, capped at the maximum size; the per-frame budget is 1/60 s.
- **The lists** (`main+0x22d338`), by `oe::GetCurrentGraphicsScale`, `oe::GetOperationMode` and a flag at `+0x8a`: docked at scale 1 (what the host reports docked) `main+0x2804ff0`, levels 24 down to 17 (1728x972 to 1472x828); docked at scale 0 `+0x28055c0`, 30 down to 23; handheld at scale 0 `+0x2808b69`, 20 down to 11 (`+0x2808b60` with the flag); the others are for scale 1 handheld (`+0x2808b73`, `+0x2805160`) and scale 2 (`+0x2808b7c`, `+0x2805198`, `+0x2805458`), 22 down to 1.
- **On the phone** (Samsung S25 Ultra, Adreno 830, Turnip, 2026-11-05): at the game's own lists, docked, the GPU took 36 ms a frame (23 fps). `DM_OPMODE=0` (handheld, starting at 1600x900) gave 35 ms, and `gpu_timestamps segment` did not lower it either. Lists rewritten to start at level 10 (1280x720) gave 28 ms (31 fps) with a clean picture: this is `res_levels` with the launcher's 720p. The scene follows the level; the rest of the frame does not (nine render targets are created at a constant 1920x1080, `main+0x10f43ec` and others).
- **What breaks:** lowering the table itself (every level above 720p reading 1280x720, so the maximum too) gave 12.8 ms (59 fps), but the ground and objects drew wrongly, and also with the 1920 / 1080 getters and the nine constant render target sizes set to 1280x720 as well. Something else assumes the game's own maximum, not found (open): a frame capture would show which pass.

## Driving it on the Mac

The first boot shows the language list: `A`, `LUp`, `A` picks English. The character choice takes `LLeft` before `A`. From a warm cache, `A A LLeft A A Plus` reaches walking in about 300 s. On later boots, `A` at the title screen a few times continues the save and reaches walking in about 110 s. The work folder has `run/boot.sh`, `run/hdrive.sh` (no window, timed control lines) and `run/spam.sh`.

## Android

- In bring-up: [`readiness.tsv`](readiness.tsv) (status `bring-up`) lets the APK carry the game (`-PnxGames=0400A3A01EE4C000`). A user's run on a Samsung S25 Ultra (12 GB, Adreno 830) with a Turnip driver plays the first area: about 23 fps at the game's own render size, 31 fps at the launcher's 720p ([Render size](#render-size)). The stock Qualcomm driver of that phone has no placed memory maps.
- 160 compute shaders take more shared memory (up to 48,128 bytes) than the tested phone's 32,768, as Mario Kart World's 48 KiB ones (open).
- The memory rows take Donkey Kong Bananza's floor, not measured on this game (open).

## Open

- The picture has not been compared with a Switch 2. The user's playtest found it fine. Sunlit ground matches published iPhone shots of the game. Shaded ground and walls are lavender. The player carries fine contour lines, already present in colour target 5435, which may be the material. In some moving shots far blocks showed through near ones; this has not been rechecked since the fixes below.
- Only the first area has been played on this build. A new save written through the game has not been checked: the 31-minute playtest wrote none.
- An IPA has not been built. A full iOS shader build would be needed first.

## Found on this game

- [KTGL on NVN2: Switch 2 GLSLC outputs and LD_ / LI_ LINKDATA](../../../docs/reference/shaders.md#ktgl-on-nvn2-switch-2-glslc-outputs-and-ld_--li_-linkdata): the split found almost none of its shaders.
- [HADD2 and HMUL2 with an immediate](../../../docs/reference/shaders.md#hadd2-and-hmul2-with-an-immediate): the GPU hang and 88 ms frames.
- [Scaled shared memory addresses](../../../docs/reference/shaders.md#scaled-shared-memory-addresses): stride 3 in use, on accesses of every size.
- [HFMA2 .H0_NH1](../../../docs/reference/shaders.md#hfma2-h0_nh1).
- [Ampere instructions new in Pokémon Pokopia](../../../docs/reference/shaders.md#ampere-instructions-new-in-pokémon-pokopia).
- [A shader build that keeps its packages in memory runs one worker at a time](../../../docs/reference/shaders.md#a-shader-build-that-keeps-its-packages-in-memory-runs-one-worker-at-a-time): the full build at one or two shaders a second (resolved).
- [Integer buffer textures read through float slots](../../../docs/reference/rendering.md#integer-buffer-textures-read-through-float-slots).
- [A luminance histogram's reductions on the Adreno](../../../docs/reference/shaders.md#a-luminance-histograms-reductions-on-the-adreno): the luminance histogram `2118ab534fac88c6` takes 13.6 ms of a 15 ms frame on the S25 Ultra; skipping its zero adds did not lower it (open).
- [The Joy-Con mouse pointer](../../../docs/reference/services.md#the-joy-con-mouse-pointer) and [GameShare guest displays](../../../docs/reference/services.md#gameshare-guest-displays): boot aborts.
