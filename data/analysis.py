import json

# DIRECTORY = "space-exploration"
DIRECTORY = "nullius"

with open(f"{DIRECTORY}/recipes.json", "r") as f:
    recipes = json.load(f)
recipe_categories = set()
for recipe in recipes.values():
    if not recipe["hidden"]:
        recipe_categories.add(recipe["category"])
for category in recipe_categories:
    print(category)
print(len(recipe_categories))

with open(f"{DIRECTORY}/entities.json", "r") as f:
    data = json.load(f)

disabled_categories = [
    "fixed-recipe",
    "delivery-cannon-weapon",
    "creative-mod_free-fluids",
    "creative-mod_energy-absorption",
    "dummy",
    "empty-recipe-category",
    "no-category",
    "equipment-change",  # equipment gantry
    "big-turbine",
    "condenser-turbine",
    "spaceship-rocket-engine",
    "spaceship-ion-engine",
    "spaceship-antimatter-engine",
    "space-elevator",
    "delivery-cannon",  # could be done - TODO
    "character",
]


def fluidbox_string(data):
    out = []
    if "fluidbox_prototypes" in data:
        for fluidbox in data["fluidbox_prototypes"]:
            out.append("[")
            out.append(fluidbox["production_type"])
            out.append(fluidbox["pipe_connections"][0]["type"])
            out.append(str(fluidbox["pipe_connections"][0]["positions"][0]["x"]))
            out.append(",")
            out.append(str(fluidbox["pipe_connections"][0]["positions"][0]["y"]))
            out.append("]")
    return "".join(out)


def fluidbox(data):
    out = []
    if "fluidbox_prototypes" in data:
        for fluidbox in data["fluidbox_prototypes"]:
            out.append(
                (
                    fluidbox["production_type"],
                    fluidbox["pipe_connections"][0]["type"],
                    fluidbox["pipe_connections"][0]["positions"][0]["x"],
                    fluidbox["pipe_connections"][0]["positions"][0]["y"],
                )
            )
    return out


def fluidbox_compatible(data1, data2):
    """
    Can the two fluidboxe data be joined into one.  Return the bigger one
    if so.
    """
    if set(data1) <= set(data2):
        return data2
    if set(data2) <= set(data1):
        return data1
    return None


def max_fluidbox(data):
    max_input = 0
    max_output = 0
    if "fluidbox_prototypes" in data:
        for fluidbox in data["fluidbox_prototypes"]:
            if fluidbox["production_type"] == "input":
                max_input += 1
            elif fluidbox["production_type"] == "output":
                max_output += 1
            else:
                max_input += 1
                max_output += 1
    return max_input, max_output


crafting_categories = dict()
sizes = dict()
sizes_fluidbox = dict()
for entity in data.values():
    if "crafting_categories" in entity:
        if not set(entity["crafting_categories"]).difference(disabled_categories):
            # drop entities with no categories we are interested in
            continue
        if entity["tile_width"] == 0 or entity["tile_height"] == 0:
            continue
        if entity["name"].startswith("character"):
            continue
        print(f"{entity['name']}: {entity['crafting_categories']}")
        print(fluidbox_string(entity))
        for category in entity["crafting_categories"].keys():
            if category not in crafting_categories:
                crafting_categories[category] = set()
            crafting_categories[category].add(entity["name"])
        size = (entity["tile_width"], entity["tile_height"])
        if size not in sizes:
            sizes[size] = set()
        sizes[size].add(entity["name"])
        if size not in sizes_fluidbox:
            sizes_fluidbox[size] = dict()
        if fluidbox_string(entity) not in sizes_fluidbox[size]:
            sizes_fluidbox[size][fluidbox_string(entity)] = []
        sizes_fluidbox[size][fluidbox_string(entity)].append(entity["name"])

print("================")
for category, assemblers in crafting_categories.items():
    print(f"{category}: {assemblers}")

print("================")
for size, assemblers in sizes.items():
    print(f"{size}: {assemblers}")

print("================")
for size, fluidbox_string in sizes_fluidbox.items():
    print(f"{size}: {len(fluidbox_string)}")
    for s, vals in fluidbox_string.items():
        print(f"   ({s}) {vals} ")

loops = dict()

catalysts = []
output_loops = []
fluid_loops = dict()
item_idx_loops = dict()

recipe_crafting_category = dict()


def process_recipe(recipe):
    num_item_inputs = 0
    num_item_outputs = 0
    num_fluid_inputs = 0
    num_fluid_outputs = 0
    num_item_loops = 0
    num_fluid_loops = 0
    item_names = dict()
    fluid_names = dict()
    # fluid loop fluidboxes?
    # fluidbox index? - very rare, only basic-oil-processing for se
    output_fluid_idx = 1
    output_item_idx = 1
    input_fluid_idx = 1
    input_item_idx = 1
    fluid_idxs = dict()
    item_idxs = dict()
    for product in recipe["products"]:
        amount = product.get("amount", None)
        if amount is None:
            amount = (product["amount_min"] + product["amount_max"]) / 2
        if product["type"] == "fluid":
            num_fluid_outputs += 1
            fluid_names[product["name"]] = amount * product.get("probability", 1)
            fluid_idxs[product["name"]] = output_fluid_idx
            output_fluid_idx += 1
        else:
            num_item_outputs += 1
            item_idxs[product["name"]] = output_item_idx
            output_item_idx += 1
            item_names[product["name"]] = amount * product.get("probability", 1)
    for ingredient in recipe["ingredients"]:
        if ingredient["type"] == "fluid":
            num_fluid_inputs += 1
            if ingredient["name"] in fluid_names:
                num_fluid_loops += 1
                idx = (input_fluid_idx, fluid_idxs[ingredient["name"]])
                if idx not in fluid_loops:
                    fluid_loops[idx] = []
                fluid_loops[idx].append(f"{recipe['name']}-{ingredient['name']}")
                if ingredient["amount"] <= fluid_names[ingredient["name"]]:
                    print(f"{recipe['name']} fluid output")
                    catalysts.append(f"{recipe['name']}:fluid:{ingredient['name']}")
                else:
                    print(f"{recipe['name']} fluid input")
                    output_loops.append(f"{recipe['name']}:fluid:{ingredient['name']}")
            input_fluid_idx += 1

        else:
            num_item_inputs += 1
            if ingredient["name"] in item_names:
                num_item_loops += 1
                idx = (input_item_idx, item_idxs[ingredient["name"]])
                if idx not in item_idx_loops:
                    item_idx_loops[idx] = []
                item_idx_loops[idx].append(f"{recipe['name']}-{ingredient['name']}")
                if ingredient["amount"] <= item_names[ingredient["name"]]:
                    print(f"{recipe['name']} item output")
                    catalysts.append(f"{recipe['name']}:item:{ingredient['name']}")
                else:
                    print(f"{recipe['name']} item input")
                    output_loops.append(f"{recipe['name']}:item:{ingredient['name']}")
            input_item_idx += 1

    if num_item_loops > 0 or num_fluid_loops > 0:
        global loops
        idx = (num_item_loops, num_fluid_loops)
        if idx not in loops:
            loops[idx] = set()
        loops[idx].add(recipe["name"])
        print(
            f"{recipe['name']} {num_item_inputs} {num_item_outputs} {num_item_loops} | {num_fluid_inputs} {num_fluid_outputs} {num_fluid_loops}"
        )
    category = recipe["category"]
    if category not in recipe_crafting_category:
        recipe_crafting_category[category] = []
    recipe_crafting_category[category].append(
        (
            recipe["name"],
            num_item_inputs,
            num_item_outputs,
            num_item_loops,
            num_fluid_inputs,
            num_fluid_outputs,
            num_fluid_loops,
        )
    )


# recipe research
count = 0
for recipe in recipes.values():
    if recipe["hidden"]:
        continue
    if recipe["category"] in disabled_categories:
        # drop entities with no categories we are interested in
        continue
    if recipe["name"].startswith("creative"):
        continue
    process_recipe(recipe)
    count += 1

print(f"There are {count} recipes")
for k, v in loops.items():
    print(f"{k}: {v}")

print(f"===== Catalyst recipes: {len(catalysts)}")
for x in catalysts:
    print(x)

print(f"====== Output loops: {len(output_loops)}")
for x in output_loops:
    print(x)

print(f"====== Fluid box loops : {len(fluid_loops)}")
for k, v in fluid_loops.items():
    print(f"{k}: {v}")

print(f"====== Item index loops : {len(item_idx_loops)}")
for k, v in item_idx_loops.items():
    print(f"{k}: {v}")


# now for every potential template, find all the recipes
# and get max input/output item/fluid
# item/fluid loops

print(f"====== Recipe categories : {len(recipe_crafting_category)}")
for k, v in recipe_crafting_category.items():
    print(f"{k}: {v}")

disabled_recipes = [
    "se-thruster-suit",
    "power-armor-mk2",
    "energy-shield-mk2-equipment",
    "se-thruster-suit-3",
    "se-thruster-suit-4",
    # "spidertron",
    "se-rtg-equpment-2",
]

disabled_assemblers = [
    # "se-space-astrometrics-laboratory",
    # "se-space-gravimetrics-laboratory",
    # "se-space-thermodynamics-laboratory",
    "burner-assembling-machine",
    "assembling-machine-1",
    "centrifuge",
    "character",
    "nullius-android-2",
    "yarm-remote-viewer",
]

print(f"====== Templates ")
for size, fluidbox_string in sizes_fluidbox.items():
    for s, assemblers in fluidbox_string.items():
        # print(f"{size} {s}")
        max_input_items = 0
        max_output_items = 0
        max_loop_items = 0
        max_input_fluids = 0
        max_output_fluids = 0
        max_loop_fluids = 0
        for assembler_name in assemblers:
            entity_max_fluid_input, entity_max_fluid_output = max_fluidbox(
                data[assembler_name]
            )
            if assembler_name in disabled_assemblers:
                continue

            ingredient_count = data[assembler_name].get("ingredient_count", None)
            if ingredient_count is None:
                print(f"    {assembler_name}")
                exit(1)
            for category in data[assembler_name]["crafting_categories"]:
                if category in disabled_categories:
                    continue
                category_max_input_items = 0
                category_max_output_items = 0
                category_max_loop_items = 0
                category_max_input_fluids = 0
                category_max_output_fluids = 0
                category_max_loop_fluids = 0
                for v in recipe_crafting_category.get(category, []):
                    if v[0] in disabled_recipes:
                        continue
                    if v[4] > entity_max_fluid_input or v[5] > entity_max_fluid_output:
                        continue
                    if v[1] > ingredient_count:
                        continue
                    # if v[1] > 8 or v[2] > 5 or v[4] > 5 or v[5] > 5:
                    #     print(v)
                    # if v[4] >= 4 or v[3] >= 3:
                    #     print(v)
                    if v[1] >= 7:
                        print(v)
                        # skip these
                        continue
                    # if v[1] >= 6:
                    # print(v)
                    max_input_items = max(max_input_items, v[1])
                    max_output_items = max(max_output_items, v[2])
                    max_loop_items = max(max_loop_items, v[3])
                    max_input_fluids = max(max_input_fluids, v[4])
                    max_output_fluids = max(max_output_fluids, v[5])
                    max_loop_fluids = max(max_loop_fluids, v[6])
                    category_max_input_items = max(category_max_input_items, v[1])
                    category_max_output_items = max(category_max_output_items, v[2])
                    category_max_loop_items = max(category_max_loop_items, v[3])
                    category_max_input_fluids = max(category_max_input_fluids, v[4])
                    category_max_output_fluids = max(category_max_output_fluids, v[5])
                    category_max_loop_fluids = max(category_max_loop_fluids, v[6])
        #         print(
        #             f"        {category} : {category_max_input_items} {category_max_output_items} {category_max_loop_items} | {category_max_input_fluids} {category_max_output_fluids} {category_max_loop_fluids}"
        #         )
        print(
            f"{size} : {max_input_items} {max_output_items} {max_loop_items} | {max_input_fluids} {max_output_fluids} {max_loop_fluids} | {s} {assemblers}"
        )

print("============")
# print(data["se-pulveriser"]["crafting_categories"])
# for v in recipe_crafting_category.get("core-fragment-processing", []):  # 1,5,0,1,3,0
#     print(v)
# print(" ")
# for v in recipe_crafting_category.get("pulverising", []):  # 2,3,1,0,1,0
#     print(v)

# vs 5,5,2,1,3,0
