global.__buildings = undefined;

//
//
function get_buildings() {
    if global.__buildings == undefined {
        global.__buildings = List();
        var grid = GRIDS[LocationId.Farm];
        for (var i = 0; i < grid.dims.x; i++) {
            for (var j = 0; j < grid.dims.y; j++) {
                var ni = grid.node_index_for_cell(i, j);
                if
                    grid.node_object_id[ni] != undefined
                    && object_id_to_object_category(grid.node_object_id[ni]) == ObjectCategory.Building
                    && !global.__buildings.contains(grid.node_parent[ni])
                {
                    global.__buildings.push(grid.node_parent[ni]);
                }
            }
        }

    }
    return global.__buildings.clone();
}

//
function find_building(dyn_index) {
    var buildings = get_buildings();
    for (var i = 0; i < buildings.count(); i++) {
        var building = buildings.get(i);
        if building.dyn_index == dyn_index {
            return building;
        }
    }
    crash("Failed to find a building with dyn index {}", dyn_index);
}

//
function random_free_building_position(dyn_index) {
    var grid = DYNAMIC_GRIDS.get(dyn_index);
    var open_positions = List();
    for (var xx = 0; xx < grid.dims.x; xx += 2) {
        for (var yy = 0; yy < grid.dims.y; yy += 2) {
            if !grid.node_collideable[grid.node_index_for_cell(xx, yy)] {
                open_positions.push(Vec2(xx * 8, yy * 8));
            }
        }
    }

    var pos = open_positions.choose_random();
    assert_neq(pos, undefined, "We couldn't find an open position!");

    return new LocationPosition(grid.location_id, pos, dyn_index);
}

//
//
function availability_for_animal(kind) {
    var availability = {
        empty: 0,
        total: 0,
    };
    get_buildings().for_each(function(building, kind, availability) {
        if building.prototype.player_building_kind == PlayerBuildingKind.Stable
            && building.prototype.permitted_animal_size == ANIMAL_PROTOTYPES[kind].core.size
        {
            availability.empty += building.stable.availability();
            availability.total += building.prototype.max_occupants;
        }
    }, [kind, availability]);

    return availability;
}
