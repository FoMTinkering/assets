#macro DUNGEON_ROOMS global.__dungeon_rooms
DUNGEON_ROOMS = undefined;

function load_dungeon_rooms() {
    var out = Map();
    var room_ids = asset_get_ids(asset_room);
    for (var i = 0; i < array_length(room_ids); i++) {
        if !is_dungeon_room(room_ids[i]) || is_special_dungeon_room(room_ids[i]) {
            continue;
        }
        var data = parse_dungeon_room(room_ids[i]);
        data.impls = ListFromArray(data.impls);
        out.insert(room_ids[i], data);
    }
    return out;
}

function create_dungeon_grid(room_id) {
    var data = DUNGEON_ROOMS.get(room_id);
    var dims = room_dimensions(room_id);
    var dims = Vec2(dims[0], dims[1]).div_by(8);
    var output = new Grid(dims.x, dims.y, LocationId.Dungeon);

    for (var xx = 0; xx < dims.x; xx++) {
        for (var yy = 0; yy < dims.y; yy++) {
            var ni = output.node_index_for_cell(xx, yy);
            output.node_collideable[ni] = data.collideable[ni];
            output.node_can_jump_over[ni] = data.can_jump_over[ni];

            var terrain_kind = data.terrain_kind[ni];
            switch terrain_kind {
                case TerrainKind.Ground:
                    var ground_kind = data.ground_kind[ni];
                    output.write_ground(xx, yy, ground_kind);
                    break;
                case TerrainKind.Water:
                    output.write_water(xx, yy);
                    break;
                case TerrainKind.Lava:
                    output.write_lava(xx, yy);
                    break;
            }
        }
    }

    output.is_setup = true;

    return output;
}
