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
  local items = {}
  if node.items_to_place_this ~= nil then
  for k, v in pairs(node.items_to_place_this) do
    table.insert(items, {name=v.name, count=v.count})
  end
end


  return {
    name=node.name,
    can_be_part_of_blueprint=node.can_be_part_of_blueprint,
    check_collision_with_entities=node.check_collision_with_entities,
    items_to_place_this=items,
    vehicle_friction_modifier=node.vehicle_friction_modifier,
    walking_speed_modifier=node.walking_speed_modifier
  }
end


function inspect_all(entities)
  local r = {}
  for k, v in pairs(entities) do
    r[k] = inspect_entity(v)
  end
  traverse(r)
end

inspect_all(game.tile_prototypes)

game.write_file("tiles", out)