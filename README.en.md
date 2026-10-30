<img src="docs/images/icon_routeBuilder.png" width="96" align="right">

# AutoDrive Route Builder (`FS25_AutoDriveRouteBuilder`)

[Deutsch](README.md) | **English**

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-0070ba?logo=paypal&logoColor=white)](https://paypal.me/toneslin)

Builds AutoDrive routes from settings and places them with the mouse – instead of setting every waypoint by hand. The points are created with AutoDrive's own functions and sent to everybody in multiplayer.

## Video

Part 1: reverse bay (in German) – click the picture to open the video on YouTube:

[![Video: AutoDrive Route Builder part 1 – reverse bay](https://img.youtube.com/vi/RU473sKUrjU/hqdefault.jpg)](https://youtu.be/RU473sKUrjU)

## What it looks like

Put bays into a bunker silo automatically – mouse into the silo, Num9, done:

![Num9 in a bunker silo](docs/images/silo_fit_en.png)

Approach along a guide line – the radius stays, the point where it joins the bay is computed:

![Approach along a guide line](docs/images/bay_align_en.png)

## Requirements

- Farming Simulator 25
- [FS25_AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive) (developed with AutoDrive 3.0.1.4)
- Multiplayer / dedicated server: install it on the server **and** on all players in the same version.

## Installation

1. Download the zip file from the [releases](../../releases) (do not unpack it).
2. Put it into the mods folder: `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods`
3. Activate it together with AutoDrive when loading the savegame.

## Contents

- [Getting started](#getting-started)
- [Build types](#build-types)
- [Keys while placing](#keys-while-placing)
- [Guide lines](#guide-lines)
- [Along guide lines](#along-guide-lines)
- [Editing AutoDrive points](#editing-autodrive-points)
- [Showing obstacles](#showing-obstacles)
- [Top view and editing AutoDrive](#top-view-and-editing-autodrive)
- [Good to know](#good-to-know)
- [Support](#support)

## Getting started

1. LCtrl + LAlt + B starts the builder – in the top view and with the build type guide line.
2. Num1 opens the build type menu, a number or a click chooses the type.
3. LCtrl + LAlt + B again opens the settings of the build type you are using (explanation on the right, diagram below). "Place" or "Back" returns to the same place.
4. Left click builds. The builder stays active, so you can go on building.
5. End closes the builder.

LCtrl + LAlt + P starts placing directly with the last values. LCtrl + LAlt + Z undoes the last route.

While placing, a panel at the top left shows the current values and all keys of the build type (Num- collapses it).

## Build types

While placing, Num1 opens a menu with all build types – press the number or click it.

Connection types (curve, arc, straight, branch): V = one-way forward, B = both ways, R = reverse.

### 1. Reverse bay

One or more bays side by side (silo, parking, unloading): forward in to the turning piece, reverse into the target, forward out via the exit. With AD targets (target name + running number) and collector roads for several bays.

<img src="docs/images/diagram_en.png" width="100%" alt="Reverse bay">

### 2. Free curve

A curve from the mouse position with side, angle, radius and number of points.

<img src="docs/images/curve_en.png" width="100%" alt="Free curve">

### 3. Guide line / cross

A line with a cross line and a ruler for aligning. Only you see it, nothing is built in AutoDrive.

<img src="docs/images/guide_en.png" width="100%" alt="Guide line / cross">

### 4. Straight on guide line

First click = start, second click = end, both are put onto the guide line. The points are spread evenly (spacing at most "max. point spacing").

<img src="docs/images/line_en.png" width="100%" alt="Straight on guide line">

### 5. Arc

An arc touching the last two guide lines. The mouse chooses corner and size.

<img src="docs/images/arc_en.png" width="100%" alt="Arc">

### 6. Branch

Feed line, branches to the left and/or right (each with its own angle, radius and start), optionally straight on. For merging there is the merge (7).

<img src="docs/images/branch_en.png" width="100%" alt="Branch">

### 7. Merge

The counterpart: lines from behind left and/or right join into one line.

<img src="docs/images/merge_en.png" width="100%" alt="Merge">

### 8. Select / move

Select existing AD points with a box, move, copy, delete them.

<img src="docs/images/connections_en.png" width="100%" alt="Select / move">

### 9. Vehicle gauge

A rough model of a truck (vehicle + trailer or semi-trailer) to check if there is enough room. Nothing is built. With the mouse near an AD route the front stands on it in driving direction and the trailer follows the route backwards, also through curves. Green = fits, red = touches an obstacle. The side that touches (left, right, front or rear) is also filled bright red.

### 10. Field border

Builds a route around a field, as the field is now. Unlike AutoDrive's "generate field points" (which takes the field outline stored in the map), the mod scans the real field area. Fields plowed together, made bigger or smaller are therefore found correctly. In the build type menu it is the key 0.

## Keys while placing

In the game there are two windows: the current values at the top, the keys of the build type on the left. Both can be dragged with the mouse, the position is saved. Num- shows all keys, Num- again hides the help. LCtrl + Num- hides / shows the values.

### All build types

| What you want to do | How |
|---|---|
| Build | left click (the builder stays active) |
| Close the builder | End |
| Rotate | LShift + wheel or `,` / `.` |
| Fine rotate | LShift + LAlt + wheel (with LCtrl even finer) |
| Fine move | Num8 / Num2 / Num4 / Num6 (with LCtrl 0.01 m) |
| Lock position | Num5 |
| Put onto an AD point | Num0 |
| Other build type | Num1, then number or click |
| Top view on / off | Num+ |
| Top view back to you / the vehicle | LCtrl + Num+ |
| Move / rotate the top view | W A S D / hold Space + drag the mouse |
| Camera zoom / look around | wheel / middle mouse button or Num/ |
| Show the AutoDrive network | Num* |
| Edit with AutoDrive yourself | short right click or Num Enter |
| Undo the last route | LCtrl + LAlt + Z |
| Settings of the build type | LCtrl + LAlt + B |
| Help short / all keys / off | Num- (press several times) |
| Helper circles on / off | H |
| Show the real obstacles | LCtrl + H |
| Value window on / off | LCtrl + Num- |
| Move a window | drag it with the left mouse button (the position is saved) |

### 1. Reverse bay

| What you want to do | How |
|---|---|
| Curves bigger / smaller | LCtrl + wheel |
| More / fewer points in the curves | LAlt + wheel |
| Change only the approach or only the exit | mouse on the curve (turns white), then wheel as above |
| Leave out the approach or exit for this bay only | mouse on the curve, Del |
| Always leave out the approach or exit | settings: approach / exit side = none |
| Bring back a removed approach / exit | LShift + Del |
| Put the bays into a bunker silo | mouse into the silo (near the entrance), then Num9 |
| Mouse at the first bay / in the middle | Num3 |
| Approach or exit along a guide line | LCtrl + left click on the curve, then on the line |
| Approach or exit to the other side | LAlt + left click on the curve |

### 2. Free curve and 5. Arc

| What you want to do | How |
|---|---|
| Curve bigger / smaller | LCtrl + wheel |
| More / fewer points | LAlt + wheel |
| Direction: forward / turned / both ways | LCtrl + Num, (or Num,) |
| Main / sub / reverse route | LAlt + Num, |
| Arc: choose corner and size | move the mouse |

### 3. Guide line

| What you want to do | How |
|---|---|
| Set a guide line | left click |
| Line longer / shorter | LCtrl + wheel |
| Move the line sideways | LAlt + wheel |
| Parallel to a line, silo wall or building | LCtrl + left click on it |
| Delete / bring back a line | Del / LShift + Del |
| Delete all guide lines | LCtrl + LAlt + L |

### 4. Straight on guide line

| What you want to do | How |
|---|---|
| Set the start | first left click near the guide line |
| Set the end and build | second left click |
| Spacing of the points | LAlt + wheel |
| Direction: forward / turned / both ways | LCtrl + Num, (or Num,) |
| Main / sub / reverse route | LAlt + Num, |
| Discard the start | Num0 |

### 6. Branch and 7. Merge

| What you want to do | How |
|---|---|
| Curves bigger / smaller | LCtrl + wheel |
| More / fewer points | LAlt + wheel |
| One-way / both ways | Num, |
| Connect to an AD point | Num0 |
| Branch along a guide line | LCtrl + left click on the branch, then on the line |
| Leave out a branch / bring it back | LAlt + left click on the side |

### 9. Vehicle gauge

| What you want to do | How |
|---|---|
| Put the model onto the AD network | mouse near a route |
| Turn it to the other direction | Num3 |
| Length of the vehicle | LCtrl + wheel |
| Length of the trailer (0 = none) | LAlt + wheel |
| Width, height, coupling | in the settings dialog (LCtrl + LAlt + B) |
| Leave the model standing (to compare) | left click |
| Remove the models left standing | Num0 |

Examples: semi-trailer truck 6 m + 13.6 m, coupling 1.5 m in front of the rear, width 2.55 m. Tractor with trailer 6 m + 10 m, coupling -1 (1 m behind the rear). The model is rough on purpose: box shapes, the trailer follows the route approximately.

### 10. Field border

| What you want to do | How |
|---|---|
| Find the field | left click onto the field, wait a moment |
| Build the field border | left click again |
| Discard | Num0 |
| Entry / exit | LCtrl + left click on the start, then on the end: an AD point of the road, the found border or an already built border. The order is the driving direction |
| Build only entries / exits (border exists already) | without finding the field: set the entries / exits, then left click |
| Remove the last entry / exit | LCtrl + Num0 |
| Move the border outwards / inwards | LAlt + wheel (+ = outside, - = inside). Every new LAlt press changes the step: 1 m → 0.5 m → 0.1 m → 0.01 m |
| Curve radius: only the corner at the mouse (marked yellow), else all corners (default 10 m) | LCtrl + wheel |
| Points: in the arc at the mouse, else point spacing on the straight parts | LCtrl + LShift + wheel |
| Corner back to the general values | Del (mouse at the corner) |
| Direction: forward / turned / both ways | LCtrl + Num, (or Num,) |
| Main / sub / reverse route | LAlt + Num, |

The corners are rounded with the set curve radius. If an edge is too short for it, the radius gets smaller there and the value window shows the tightest curve. In the settings dialog: offset, point spacing, curve radius, grid (smaller = more exact but slower, default 2 m) and the biggest area (default 100 ha), so that not a whole meadow is scanned. Fields separated only by a strip of grass stay separate. Entries and exits are smooth curves: at the road in its driving direction, at the border along the border. They are built together with the border.

## Guide lines

Guide lines help you to build exactly. Only you see them, AutoDrive builds nothing from them.

- Set a line: build type 3, left click. The line has a ruler in metres.
- Make it parallel: LCtrl + left click on another guide line, a silo wall or the edge of a building. The new line turns parallel to it.
- See the distance: while the line is parallel, a yellow line shows the distance.
- Move it sideways: LAlt + wheel. Every new LAlt press makes the steps smaller: 1 m, 0.5 m, 0.1 m, 0.01 m.
- Delete: Del deletes the line near the mouse, LShift + Del brings it back, LCtrl + LAlt + L deletes all.
- The lines are saved with the savegame. The arc needs the last two (orange and turquoise).

![Guide line parallel to a silo wall](docs/images/guide_parallel_en.png)

## Along guide lines

Works for the reverse bay (approach and exit), branch and merge:

1. LCtrl + left click on the curve or the branch.
2. LCtrl + left click on the guide line.
3. Done: the curve now starts or ends exactly on the line.

LCtrl + Num0 undoes it. A side mouse button works instead of the left click too.

## Editing AutoDrive points

Build type 8 (select / move), best in the top view:

| What you want to do | How |
|---|---|
| Select points | hold the left mouse button and drag a box |
| Add points / deselect points | box with LShift / with LCtrl |
| Select one point | left click on the point |
| Add all connected points | LCtrl + A (at most the number set in the settings dialog, default 500) |
| Clear the selection | Num0 |
| Move the selection | drag a selected point with the left mouse button |
| Fine move | Num8 / Num2 / Num4 / Num6 (with LCtrl 0.01 m) |
| Move only along / across the guide line | Num3 |
| Put the selection straight on the guide line | Num7 (Num9: and spread evenly) |
| Direction: forward / turned / both ways | LCtrl + Num, (or Num,) |
| Main / sub / reverse route | LAlt + Num, |
| Change the points of a curve | select the curve, LAlt + wheel, then left click |
| Straight line between two points | select 2 points, Num/, then left click |
| Set / rename / delete an AD target | select 1 point, Num5 |
| Copy the selection | LCtrl + C, left click pastes, Num0 = done |
| Delete the selection | Del, then Del again – **cannot be undone** |
| Undo | LCtrl + LAlt + Z |

Tip: for a long route it is enough to select the first and the last point. AD targets are not copied.

## Showing obstacles

LCtrl + H shows around the mouse (25 m) where something is really in the way. Red is the invisible collision of trees, poles, buildings and objects, not the visible model. The mod checks this the same way AutoDrive does while driving.

- Red areas with a yellow border: a collision is here (from 0.3 m to 4 m above the ground). Drawn just above the ground and at 4 m height, plus a red post. Under tree crowns it is best seen with a tilted camera (Space + mouse).
- Red line above the preview: a 3 m wide vehicle would touch something on this section. The value window shows how many sections are affected.
- LCtrl + H again switches it off.

## Top view and editing AutoDrive

- The builder starts in the top view above you or your vehicle.
- Short right click or Num Enter: building pauses and you edit with the normal AutoDrive editor. Num Enter brings you back.
- AutoDrive only edits with the mouse while you sit in a vehicle, the AD HUD is on and the editor is set to "extended" (Num/). The panel shows you what is missing.

## Good to know

- Multiplayer: the mod has to be on the server **and** on all players in the same version. Undo only takes back routes you built yourself.
- New routes are only connected to the AD network where you use Num0. Connect the rest in the AutoDrive editor.
- Reverse bay: no other route may branch off where reversing starts.
- German keyboard: undo works with LCtrl + LAlt + Z or Y.
- Numpad: avoid LShift together with numpad keys. With NumLock on, Windows turns them into other keys (e.g. Num. → Del). That is why the mod uses LCtrl there.
- Texts and pictures in German and English.

## Support

The mod is free. If it saves you time and you want to give something back, I am happy about a small donation – completely voluntary.

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-0070ba?logo=paypal&logoColor=white)](https://paypal.me/toneslin)

## Bugs and wishes

Please report them as an [issue](../../issues), ideally with a screenshot and the `log.txt`.

## License

All rights reserved. Using it for free in the game, also on servers, is allowed. Uploading it elsewhere, selling it or publishing changed versions only with my permission. Please link to this page instead. Details: [LICENSE](LICENSE)

## Author

Toneslin
