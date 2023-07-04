# About COLOSSUS

COLOSSUS is a mod that automatically generate blueprints from planner mods.  This mod is still in pre-release and may have many bugs.

Currently supports the following planner mods:
- Helmod
- Factory Planner (with some source code changes)

Overhaul mod supports:
- No overhaul mods are supported at this time.  This mod may or may not work with overhauls.

This mod has only been tested in single player.  It may cause desyncs in multiplayer.

This mod make take anywhere from 1 second to minutes to generate a blueprint.  Small plans are generated in less that a second.  If you try to build a 1000spm blueprint expect it to take a few minutes.  It will freeze the game while generating.

This mod will have support for an external CLI program to generate blueprints offline.  The CLI is not currently supported.

# Usage

Create a plan in either Helmod or Factory Planner (if you have connected Factory Planner to the mod, see below for instructions).

Load the COLOSSUS interface by pressing the compass icon in the shortcut bar.  Alternatively press the keyboard shortcut (`Ctrl-I` by default).

Choose your type of blueprint and various config options on the Config screen.

Then choose the tab corresponding to your planner mod.  It should list the available plans.  Select the plan and press "Create Blueprint".

## Config Options

TODO

## Template Editor

TODO

## Connecting Factory Planner

COLOSSUS can connect to Factory Planner via gvv.  To enable this connection follow gvv's Helper commands (Ctrl-Shift-v in game).

You can add the following to Factory Planner's `control.lua` to enable gvv and COLOSSUS integration:

```
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
```

Alternatively there is a console command to enable gvv for the session.  See gvv's Helper > Console Commands > "factoryplanner" > copy and paste into the console.

# Other Mods

The following mods automatically generate blueprints and complement this mod:

- Mining patch planner https://mods.factorio.com/mod/mining-patch-planner
- P.U.M.P https://mods.factorio.com/mod/pump
- Well Planner https://mods.factorio.com/mod/WellPlanner

# CLI Usage

TODO

# Licensing

All non-third party code is licensed under the MIT license, see `LICENSE.txt`.

All files in the `lib/` directory are third-party libs and are under various licenses.  See the individual files for details.

Some code is based on the following mods:
- `Factory Planner` by Therenas, under the MIT license
- `Helmod` by Helfima, https://github.com/Helfima/helmod, under the MIT license.

The files `graphics/compass-drafiting-solid*` is from FontAwesome https://fontawesome.com/icons/compass-drafting?f=classic&s=solid see LICENSE.txt in that directory.

The file `thumbnail.jpg` is from [Wikipedia](https://en.wikipedia.org/wiki/File:GB-ENG_-_Bletchley_-_Computers_-_Buckinghamshire_-_Milton_Keynes_-_Bletchly_-_Bletchley_Park_(4890148011).jpg):


> This file is licensed under the Creative Commons Attribution 2.0 Generic license.
> 
> Attribution: http://www.cgpgrey.com

>You are free:

>to share – to copy, distribute and transmit the work

>to remix – to adapt the work

>Under the following conditions:

>attribution – You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.