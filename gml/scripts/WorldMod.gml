#macro WORLD_MODS global.__world_mods
WORLD_MODS = undefined;

function load_world_mods() {
    var output = array_create(WorldMod.LEN, undefined);
    var data = fiddle_get("world_mod");
    for (var i = 0; i < WorldMod.LEN; i++) {
        var entry = clone_value(data[$ world_mod_to_string(i)]);
        output[i] = {
            location_id: string_to_location_id(entry.location_id),
            requirements: parse_requirements(entry.requirements),
            collision_edit: entry[$ "collision_edit"],
            layer_additions: entry[$ "layer_additions"] ?? [],
            layer_removals: entry[$ "layer_removals"] ?? [],
        }
    }

    return output;
}

function world_mod_enabled(world_mod) {
    return requirements_pass(WORLD_MODS[world_mod].requirements);
}
