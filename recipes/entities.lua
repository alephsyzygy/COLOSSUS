/c
local out = ""

function write(...)
  local arg = {...}
  for i, v in ipairs(arg) do
    out = out .. tostring(v)
  end
end

function item_count(node)
  local count = 0
  for k, v in pairs(node) do
    count = count + 1
  end
  return count
end

function traverse_table(node)
  write("{")
  local i = 1
  local count = item_count(node)
  for k, v in pairs(node) do
    write("\"", tostring(k), "\": ")
    traverse(v)
    if i < count then
      write(",")
    end
    i = i + 1
  end
  write("}")
end

function traverse_array(node)
  local count = item_count(node)
  write("[")
  for k, v in ipairs(node) do
    traverse(v)
    if k < count then
      write(",")
    end
  end
  write("]")
end

function traverse(node)
  if type(node) == "table" then
    if type(next(node)) == "number" then
      traverse_array(node)
    else
      traverse_table(node)
    end
  elseif type(node) == "string" then
    write("\"", node, "\"")
  else
    write(node)
  end
end

function inspect_entity(node)
  local fluidbox = {}
  local related_underground_belt = nil
  for k, v in pairs(node.fluidbox_prototypes) do
    table.insert(fluidbox, {pipe_connections=v.pipe_connections, production_type=v.production_type, height=v.height, index=v.index})
  end
  if node.related_underground_belt ~= nil then
    related_underground_belt = node.related_underground_belt.name
  end

  return {
    name=node.name,
    tile_height=node.tile_height,
    tile_width=node.tile_width,
    type=node.type,
    crafting_categories=node.crafting_categories,
    crafting_speed=node.crafting_speed,
    energy_usage=node.energy_usage,
    module_inventory_size=node.module_inventory_size,
    max_circuit_wire_distance=node.max_circuit_wire_distance,
    max_energy_production=node.max_energy_production,
    is_building=node.is_building,
    max_energy_usage=node.max_energy_usage,
    max_wire_distance=node.max_wire_distance,
    supports_direction=node.supports_direction,
    valid=node.valid,
    fluid_capacity=node.fluid_capacity,
    max_underground_distance=node.max_underground_distance,
    related_underground_belt=related_underground_belt,
    fluidbox_prototypes=fluidbox
  }
end


function inspect_all(entities)
  local r = {}
  for k, v in pairs(entities) do
    r[k] = inspect_entity(v)
  end
  traverse(r)
end

inspect_all(game.entity_prototypes)

game.write_file("entities", out)