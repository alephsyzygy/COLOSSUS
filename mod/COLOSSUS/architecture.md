# Directory Structure

Here is an overview of the directory structure of COLOSSUS:

- `cli` - CLI specific code
- `common` - code common to both the Factorio mod and the CLI
- `common/bus` - bus specific code
- `common/config` - configuration and access to game data
- `common/data_structures` - code for various data structures
- `common/factorio_objects` - objects representing factorio objecys
- `common/factory_components` - components that make up a factory
- `common/logistic` - logistic network specific code
- `common/planners` - code for integration with planners
- `common/schematic` - code for schematic diagrams and grid related functions
- `common/utils` - utility code, objects, loggers, serdes
- `data` - data required by the mod.  Templates and blueprints are used by the mod, the JSON data is used by the CLI
- `factorio` - code specific to the Factorio mod
- `lib` - LUA libraries
- `locale` - other language support
- `test` - unit and integration tests

# Schematic Engine

`diagram.lua`, reference the `monoid-pearl.pdf`

## Coordinate System

## Internal Blueprints

mention that everything is done with relative co-ords, we don't have entity ids.

## Templates

Tags

# Bus Workflow

From reading a factory recipe, generating the bus, and outputting a blueprint.

# Other

The difference between optimizations and post-processing is that optimizations are optional and do
not change the functionality, whereas post-processing must be done and changes the functionality
of the factory.