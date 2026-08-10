//
#macro GRID global.__grid
global.__grid = undefined;

//
#macro GRIDS global.__grids
global.__grids = undefined;

//
#macro DYNAMIC_GRIDS global.__dynamic_grids
global.__dynamic_grids = undefined;

//
function Grid(cell_width, cell_height, location_id, dyn_index=undefined) constructor {
    self.dims = Vec2(cell_width, cell_height);

    self.node_len = cell_width * cell_height;
    self.node_object_id = array_create(self.node_len, undefined);
    self.node_parent = array_create(self.node_len, undefined);
    self.node_rug_id = array_create(self.node_len, undefined);
    self.node_rug_parent = array_create(self.node_len, undefined);
    self.node_terrain_kind = array_create(self.node_len, undefined);
    self.node_terrain_ground_kind = array_create(self.node_len, undefined);
    self.node_terrain_is_watered = array_create(self.node_len, false);
    self.node_terrain_variant = array_create(self.node_len, 0);
    self.node_terrain_tile = array_create(self.node_len, 0);
    self.node_footstep_kind = array_create(self.node_len, 0);
    self.node_force = array_create(self.node_len, undefined);
    self.node_is_room_editor_collision = array_create(self.node_len, RoomEditorCollision.None);
    self.node_collideable = array_create(self.node_len, false);
    self.node_can_jump_over = array_create(self.node_len, false);
    self.node_pathfinding_cost = array_create(self.node_len, 0);
    self.node_pathfinding_sitting = array_create(self.node_len, 0);
    self.node_flags = array_create(self.node_len, 0);
    self.node_top_left_x = array_create(self.node_len, undefined);
    self.node_top_left_y = array_create(self.node_len, undefined);
    self.node_furniture_footstep = ds_map_create();
    self.node_restrict_tree_growth = ds_map_create();
    self.node_spawn_colliders_timer = ds_map_create();
    self.node_colliders_count = ds_map_create();
    self.node_spawn_grass_timer = ds_map_create();
    self.node_grass_count = ds_map_create();
    self.node_animal_claimed = ds_map_create();

    self.location_id = location_id;
    self.dyn_index = dyn_index;
    self.lost_items = List();
    self.node_counter = 0;
    self.parent_node = undefined;
    self.is_setup = false;
    self.sprinklers = [];
    self.pet_beds = [];
    self.pet_dishes = [];
    self.activity_nodes = List();
    self.terrain_editors = [];
    self.ocarina = undefined;
    self.auto_feeder = undefined;

    self.soil_tilemap_id = undefined;
    self.water_tilemap_id = undefined;
    self.grass_autotile_tilemap_id = undefined;
    self.grass_variant_tilemap_id = undefined;

    function remove_as_current_grid() {
        self.soil_tilemap_id = undefined;
        self.water_tilemap_id = undefined;
        self.grass_autotile_tilemap_id = undefined;
        self.grass_variant_tilemap_id = undefined;


        for (var ni = 0; ni < self.node_len; ni++) {
            if self.node_object_id[ni] != undefined {
                self.node_parent[ni].last_update = NODE_ROOM_START;
            }
        }
    }
    //
    function node_index_for_cell(_x, _y) {
        assert(_x >= 0 && _x < self.dims.x && _y >= 0 && _y < self.dims.y, "{}x{} out of range of grid dimensions {}", _x, _y, self.dims);

        return _y * self.dims.x + _x;
    }

    //
    function try_node_index_for_cell(_x, _y) {
        if _x < 0 || _x >= self.dims.x || _y < 0 || _y >= self.dims.y {
            return undefined;
        }

        return _y * self.dims.x + _x;
    }

    //
    function node_index_for_room_position(_x, _y) {
        return self.node_index_for_cell(_x div 8, _y div 8);
    }

    //
    //
    function try_node_index_for_room_position(_x, _y) {
        return self.try_node_index_for_cell(_x div 8, _y div 8);
    }

    function item_effects_node_at_cell(xx, yy, item_prototype) {
        //
        //
        //
        var ni = self.try_node_index_for_cell(xx, yy);
        if ni == undefined {
            return false;
        }

        switch item_prototype.use {
            case ItemUse.Bait:
                if item_prototype.attract.bug {
                    if LOCATIONS[CURRENT_LOCATION_ID].outdoor == false
                        && CURRENT_LOCATION_ID != LocationId.Dungeon
                    {
                        return false;
                    }


                    for (var x_addr = 0; x_addr < 2; x_addr++) {
                        for (var y_addr = 0; y_addr < 2; y_addr++) {
                            var other_ni = self.try_node_index_for_cell(xx + x_addr, yy + y_addr);
                            if other_ni == undefined
                                || self.node_terrain_kind[other_ni] != TerrainKind.Ground
                                || self.node_terrain_ground_kind[other_ni] == GroundKind.RiverBank
                                || self.node_collideable[other_ni]
                            {
                                return false;
                            }
                        }
                    }

                    return true;
                } else {
                    var left = self.try_node_index_for_cell(xx + 1, yy);
                    var bottom = self.try_node_index_for_cell(xx, yy + 1);
                    var bottom_right = self.try_node_index_for_cell(xx + 1, yy + 1);

                    //
                    //
                    if left == undefined || bottom == undefined || bottom_right == undefined {
                        return false;
                    }

                    return self.node_terrain_kind[ni] == TerrainKind.Water
                        || self.node_terrain_kind[left] == TerrainKind.Water
                        || self.node_terrain_kind[bottom] == TerrainKind.Water
                        || self.node_terrain_kind[bottom_right] == TerrainKind.Water;
                }
            case ItemUse.PlantSeed:
                return can_plant_seed(xx, yy, item_prototype.crop_object);
            case ItemUse.PlantSapling:
                return can_plant_sapling(self, xx, yy, item_prototype.sapling);
            case ItemUse.PlantGrass:
                return can_plant_grass(self, xx, yy);
            case ItemUse.PlaceTile:
                var base_success = self.location_id == LocationId.Farm
                    && self.node_terrain_kind[ni] == TerrainKind.Ground
                    && self.node_terrain_ground_kind[ni] == item_prototype.tile_placement.ground_kind;

                if base_success {
                    if CURRENT_LOCATION_ID == self.location_id
                        && self.is_setup
                        && self.parent_node == undefined
                    {
                        return tilemap_get(self.grass_autotile_tilemap_id, xx div 2, yy div 2) == AUTOTILE_FULLGRASS_CELL || item_prototype.tile_placement.ground_kind == GroundKind.Dirt;
                    } else {
                        //
                        return true;
                    }
                } else {
                    return false;
                }
            case ItemUse.UseTool:
                if ARI.get_stamina() <= 0 {
                    return false;
                }

                switch item_prototype.tool_type {
                    case ToolType.Hoe: return can_hoe_node(self, ni);
                    case ToolType.Axe: return can_chop_node(self, ni, item_prototype, xx, yy);
                    case ToolType.PickAxe: return can_pick_node(self, ni, item_prototype.quality);
                    case ToolType.WateringCan: return can_water_node(self, ni);
                    case ToolType.Shovel: return can_shovel_node(xx,yy);
                    case ToolType.Net: return net_target_in_tile(xx, yy);
                }
                return false;
            case ItemUse.Blueprint:
            case ItemUse.PlaceObject:
                //
                //
                return false;
            case ItemUse.Wallpaper:
            case ItemUse.Flooring:
                return false;
            default:
                return false;
        }
    }

    //
    //
    //
    //
    function write_node(_x, _y, _object_id, ctx) {
        var output = self.write_node_without_initializing(_x, _y, _object_id, ctx);
        if output != undefined && self.is_setup && self.location_id == CURRENT_LOCATION_ID {
            self.initialize_node_renderer(output);
        }

        return output;
    }

    //
    //
    //
    //
    //
    //
    function write_node_without_initializing(_x, _y, _object_id, ctx) {
        var output = undefined;
        var category = object_id_to_object_category(_object_id);

        switch category {
            case ObjectCategory.DigSite:
                output = write_dig_site_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id], ctx);
                break;
            case ObjectCategory.Tree:
                output = write_tree_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id]);
                break;
            case ObjectCategory.Rock:
                output = write_rock_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id]);
                break;
            case ObjectCategory.Breakable:
                output = write_breakable_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id]);
                break;
            case ObjectCategory.Stump:
                output = write_stump_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id]);
                break;
            case ObjectCategory.Crop:
                output = write_crop_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id], ctx);
                break;
            case ObjectCategory.Bush:
                //
                output = write_bush_to_location(self, _x, _y, NODE_PROTOTYPES[_object_id], ctx);
                break;
            case ObjectCategory.Grass:
                output = write_grass_to_location(self, _x, _y, NODE_PROTOTYPES[_object_id]);
                break;
            case ObjectCategory.Building:
                output = write_building_to_location(self, (_x div 2) * 2, (_y div 2) * 2, NODE_PROTOTYPES[_object_id], ctx);
                break;
            case ObjectCategory.Furniture:
                //
                output = write_furniture_to_location(self, _x, _y, NODE_PROTOTYPES[_object_id], 0, ctx);
                break;
            default: impossible("we don't know how to construct {ObjectId} -- it was not made @ {}x{}", _object_id, _x, _y);
        }

        if output != undefined
            && self.location_id == LocationId.Farm
            && self.parent_node == undefined
            && (GROW_BACK.elligible_objects[_object_id] || category == ObjectCategory.Grass)
        {
            var parent_boy = self.node_index_for_cell(
                (_x div GROW_BACK.cell_size) * GROW_BACK.cell_size,
                (_y div GROW_BACK.cell_size) * GROW_BACK.cell_size
            );
            if category == ObjectCategory.Grass {
                self.node_grass_count[? parent_boy] += 1;
            } else {
                self.node_colliders_count[? parent_boy] += 1;
            }
        }

        return output;
    }

    function write_ground(_x, _y, _ground_kind, _node_callback, _node_callback_args) {
        var top_left_x = (_x div 2) * 2;
        var top_left_y = (_y div 2) * 2;

        var written = write_ground_to_location(self, top_left_x, top_left_y, _ground_kind, _node_callback, _node_callback_args);

        if self.is_setup && self.location_id == CURRENT_LOCATION_ID && written != undefined {
            //
            if self.grass_autotile_tilemap_id != undefined {
                tilemap_set(grass_variant_tilemap_id, 0, top_left_x div 2, top_left_y div 2);
            }
            update_tilemap_for_node(top_left_x, top_left_y);
        }

        return written;
    }

    function write_water(_x, _y, _node_callback, _node_callback_args) {
        var top_left_x = (_x div 2) * 2;
        var top_left_y = (_y div 2) * 2;

        var written = write_water_to_location(self, (_x div 2) * 2, (_y div 2) * 2, _node_callback, _node_callback_args);

        if self.is_setup && self.location_id == CURRENT_LOCATION_ID && written != undefined {
            //
            for (var xx = max(top_left_x - 2, 0); xx <= min(top_left_x + 2, self.dims.x - 2); xx += 2) {
                for (var yy = max(top_left_y - 2, 0); yy <= min(top_left_y + 2, self.dims.y - 2); yy += 2) {
                    self.auto_tile_tile(xx, yy);
                }
            }
        }

        return written;
    }

    function write_lava(_x, _y, _node_callback, _node_callback_args) {
        return write_lava_to_location(self, (_x div 2) * 2, (_y div 2) * 2, _node_callback, _node_callback_args);
    }

    //
    //
    function new_day() {
        static NODE_TICK = 0;
        //
        NODE_TICK++;

        //
        var ni;
        var watered;
        var npc_crop;
        var on_twos;

        var xx_dims = self.dims.x;
        var yy_dims = self.dims.y;

        if self.location_id == LocationId.Farm
            && self.parent_node == undefined
        {
            yy_dims = NORMAL_FARM_EDGE_Y;
            if FARM_EXPANDED == false {
                xx_dims = NORMAL_FARM_EDGE_X;
            }
        }


        for (var xx = 0; xx < xx_dims; xx++) {
            for (var yy = 0; yy < yy_dims; yy++) {
                ni = self.node_index_for_cell(xx, yy);

                if self.node_terrain_kind[ni] == undefined {
                    continue;
                }
                on_twos = xx % 2 == 0 && yy % 2 == 0;

                if self.node_terrain_kind[ni] == TerrainKind.Ground {
                    watered = self.node_terrain_is_watered[ni];
                    //
                    //
                    if on_twos  {
                        water_chunk(self, xx, yy, false);
                    }
                } else {
                    watered = false;
                }

                //
                if self.node_object_id[ni] != undefined && self.node_parent[ni].last_update != NODE_TICK {
                    self.node_parent[ni].last_update = NODE_TICK;

                    switch object_id_to_object_category(self.node_object_id[ni]) {
                        case ObjectCategory.Tree:
                            tree_node_new_day(self, self.node_parent[ni]);
                            break;
                        case ObjectCategory.Crop:
                            npc_crop = has_flag(self.node_flags[ni], TileFlag.NpcFarm);
                            if watered
                                || has_flag(self.node_parent[ni].ctx, CropFlag.MANAGED)
                                || npc_crop
                            {
                                crop_node_new_day(self, self.node_parent[ni]);

                                if chance_percent(ARI.perk_value(Perk.WellWatered)) && on_twos {
                                    water_chunk(self, xx, yy);
                                    GAME_STATS.perks[$ perk_to_string(Perk.WellWatered)] += 1;
                                }
                            }

                            if npc_crop && on_twos {
                                water_chunk(self, xx, yy);
                            }
                            break;
                        case ObjectCategory.Bush:
                            bush_node_new_day(self.node_parent[ni]);
                            break;
                        case ObjectCategory.Grass:
                            if self.location_id == LocationId.Farm {
                                if self.node_object_id[ni] != ObjectId.GrassMedium || self.node_parent[ni].stunt_growth == false {
                                    self.node_parent[ni].day_count += 1;
                                }
                                var grass_size = self.node_parent[ni].prototype.day_to_stage.try_get(self.node_parent[ni].day_count) ?? ObjectId.GrassLarge;

                                if grass_size != self.node_object_id[ni] {
                                    erase_object_node(self, ni);
                                    self.write_node(xx, yy, grass_size);
                                }
                            }

                            break;
                        case ObjectCategory.DigSite:
                            self.node_parent[ni].day_count++;

                            if self.node_object_id[ni] == ObjectId.DigSiteDestroyed || self.node_parent[ni].day_count >= 14  {
                                erase_object_node(self, ni);
                            }
                            break;
                        case ObjectCategory.Furniture:
                            if self.node_parent[ni].prototype.soup_pot != undefined {
                                self.node_parent[ni].status = PerpetualSoupStatus.NoItem;
                            }

                            if self.node_object_id[ni] == ObjectId.TesseraeTree {
                                self.node_parent[ni].day_count += 1;
                            }
                            break;
                    }
                }
            }
        }


        if LOCATIONS[self.location_id].reset_every_night {
            var room_id = location_id_to_gm_room(self.location_id);

            spawn_prios_on_map(self, room_id, "PriorityObjects", spawn_priority_object, true);
            spawn_prios_on_map(self, room_id, priority_tileset_season(CALENDAR.season()), spawn_priority_object, true);
            spawn_prios_on_map(self, room_id, "PriorityGrass", spawn_priority_grass, true);
            spawn_prios_on_map(self, room_id, priority_grass_tileset_season(CALENDAR.season()), spawn_priority_grass, true);
        }
    }

    //
    //
    function initialize_on_room_start() {
        self.node_counter++;

        //
        var location = LOCATIONS[self.location_id];
        if location.farm || location.npc_farm {
            static CREATE_OR_FIND_TILEMAP = function(name, d, tileset, dims) {
                if layer_exists(name) {
                    return strict_layer_tilemap_get_id(layer_get_id(name));
                } else {
                    return layer_create_with_tilemap(
                        name,
                        d,
                        tileset
                    );
                }
            }

            var d = layer_get_depth(layer_get_id("Level_0_Floor_A"));

            self.water_tilemap_id = CREATE_OR_FIND_TILEMAP("Level_0_Water", d + 100, tile_soil_wet_spring, self.dims);
            self.soil_tilemap_id = CREATE_OR_FIND_TILEMAP("Level_0_Soil", d + 200, tile_soil_spring, self.dims);
            self.grass_variant_tilemap_id = CREATE_OR_FIND_TILEMAP("Level_0_Ground", d + 300, tile_main_exteriors_spring, self.dims);
            self.grass_autotile_tilemap_id = CREATE_OR_FIND_TILEMAP("Level_0_Grassautotile", d + 400, tile_grassautotile_spring, self.dims);
        } else {
            self.soil_tilemap_id = undefined;
            self.water_tilemap_id = undefined;
            self.grass_autotile_tilemap_id = undefined;
            self.grass_variant_tilemap_id = undefined;
        }


        var xx_dims = self.dims.x;
        var yy_dims = self.dims.y;

        if self.location_id == LocationId.Farm
            && self.parent_node == undefined
        {
            //
            if !FARM_EXPANDED {
                xx_dims = 188;
            }

            yy_dims = 144;
        }

        for (var xx = 0; xx < xx_dims; xx++) {
            for (var yy = 0; yy < yy_dims; yy++) {
                var ni = self.node_index_for_cell(xx, yy);

                if self.node_object_id[ni] != undefined && self.node_parent[ni].last_update != self.node_counter {
                    self.node_parent[ni].last_update = self.node_counter;
                    self.initialize_node_renderer(self.node_parent[ni]);
                }

                if self.node_rug_id[ni] != undefined && self.node_rug_parent[ni].last_update != self.node_counter {
                    self.node_rug_parent[ni].last_update = self.node_counter;

                    self.initialize_node_renderer(self.node_rug_parent[ni]);
                }

                //
                if LOCATIONS[self.location_id].farm && (xx % 2 == 0) && (yy % 2 == 0) {
                    auto_tile_tile(xx, yy);
                }

                if location.npc_farm && has_flag(self.node_flags[ni], TileFlag.NpcFarm) {
                    GRID.update_tilemap_for_node(xx, yy);
                }
            }
        }

        if MIST.running == false && self.parent_node == undefined {
            restore_lost_items(self.lost_items);

            //
            if self.location_id == LocationId.PlayerHome {
                var g = self;
                with obj_item {
                    var maybe_ni = g.try_node_index_for_room_position(x, y);
                    var triggered = false;

                    while maybe_ni == undefined || (has_flag(g.node_flags[maybe_ni], TileFlag.Placeable) == false) {
                        x = approach(x, room_width() / 2, 8);
                        y = approach(y, room_height() / 2, 8);

                        triggered = true;

                        if abs(x - (room_width() / 2)) < 1
                            && abs(y - (room_height() / 2)) < 1
                        {
                            break;
                        }
                        maybe_ni = g.try_node_index_for_room_position(x, y);
                    }

                    if triggered {
                        x = approach(x, room_width() / 2, 16);
                        y = approach(y, room_height() / 2, 16);

                        self.final_x = x;
                        self.final_y = y;
                    }
                }
            }
        }
    }

    function initialize_node_renderer(node) {
        switch object_id_to_object_category(node.object_id) {
            case ObjectCategory.DigSite:
                create_dig_site_renderer(node);
                break;
            case ObjectCategory.Tree:
                create_tree_renderer(node);
                break;
            case ObjectCategory.Rock:
                create_rock_renderer(node);
                break;
            case ObjectCategory.Breakable:
                create_breakable_renderer(node);
                break;
            case ObjectCategory.Stump:
                create_stump_renderer(node);
                break;
            case ObjectCategory.Crop:
                create_crop_renderer(node);
                break;
            case ObjectCategory.Bush:
                create_bush_renderer(node);
                break;
            case ObjectCategory.Grass:
                create_grass_renderer(node);
                break;
            case ObjectCategory.Furniture:
                create_furniture_renderer(node);
                break;
            case ObjectCategory.Building:
                create_building_renderer(node);
                break;
            default: impossible("unknown object category for object id: {}", object_id_to_string(node.object_id));
        }
    }

    //
    function tile_flag_satisfies_region(_x1, _y1, _x2, _y2, _tile_flag) {
        for(var yy = _y1; yy <= _y2; yy++) {
            for(var xx = _x1; xx <= _x2; xx++) {
                if tile_flag_satisfies(xx, yy, _tile_flag) == false {
                    return false;
                }
            }
        }
        return true;
    }

    //
    function tile_flag_satisfies(_x, _y, _tile_flag) {
        var ni = self.node_index_for_cell(_x, _y);
        return self.tile_flag_satisfies_node(ni, _tile_flag);
    }

    function tile_flag_satisfies_node(ni, _tile_flag) {
        //
        if has_flag(_tile_flag, TileFlag.FreeOfCollisions) && self.node_collideable[ni] {
            return false;
        }

        //
        if has_flag(_tile_flag, TileFlag.FreeOfAnyObject) && self.node_object_id[ni] != undefined {
            return false;
        }

        //
        if (has_flag(_tile_flag, TileFlag.Soil) && self.node_terrain_kind[ni] == TerrainKind.Ground && self.node_terrain_ground_kind[ni] != GroundKind.Soil) {
            return false;
        }

        //
        if (has_flag(_tile_flag, TileFlag.Grass) && self.node_terrain_kind[ni] == TerrainKind.Ground && self.node_terrain_ground_kind[ni] != GroundKind.Grass) {
            return false;
        }

        var _tile_flag_at_cell = self.node_flags[ni] ?? 0;

        //
        if has_flag(_tile_flag, TileFlag.Placeable) && has_flag(_tile_flag_at_cell, TileFlag.Placeable) == false {
            return false;
        }

        //
        if has_flag(_tile_flag, TileFlag.Wilderness) && has_flag(_tile_flag_at_cell, TileFlag.Wilderness) == false {
            return false;
        }

        //
        if has_flag(_tile_flag, TileFlag.Forageable) && has_flag(_tile_flag_at_cell, TileFlag.Forageable) == false {
            return false;
        }
        //
        if has_flag(_tile_flag, TileFlag.DigSite) && has_flag(_tile_flag_at_cell, TileFlag.DigSite) == false {
            return false;
        }
        //
        if has_flag(_tile_flag, TileFlag.DigSiteSpecial) && has_flag(_tile_flag_at_cell, TileFlag.DigSiteSpecial) == false {
            return false;
        }
        //
        if has_flag(_tile_flag, TileFlag.PlaceableWall) && has_flag(_tile_flag_at_cell, TileFlag.PlaceableWall) == false {
            return false;
        }

        //
        return true;
    }

    //
    //
    //
    //
    //
    function update_tilemap_for_node(_x, _y) {
        for (var xx = max(_x - 2, 0); xx <= min(_x + 2, self.dims.x - 2); xx += 2) {
            for (var yy = max(_y - 2, 0); yy <= min(_y + 2, self.dims.y - 2); yy += 2) {

                self.auto_tile_tile(xx, yy, true);
            }
        }
    }

    function auto_tile_tile(xx, yy, force=false) {
        //
        xx = (xx div 2) * 2;
        yy = (yy div 2) * 2;

        static SOIL_BITMASK = [
            2, 8, 10, 11, 16,
            18, 22, 24, 26, 27,
            30, 31, 64, 66, 72,
            74, 75, 80, 82, 86,
            88, 90, 91, 94, 95,
            104, 106, 107, 120, 122,
            123, 126, 127, 208, 210,
            214, 216, 218, 219, 222,
            223, 248, 250, 251, 254,
            255, 0
        ];

        static GRASS_BITMASK = [
            1, 2, 4, 16,        128, 64, 32, 8,
            5, 132, 160, 33,    18, 80, 72, 10,
            26, 82, 88, 74,     50, 81, 76, 138,
            34, 17, 68, 136,    130, 48, 65, 12,
            162, 49, 69, 140,   66, 24, 129, 36,
            37, 133, 164, 161,  165, 0, 90
        ];

        //
        var ni = self.node_index_for_cell(xx, yy);
        if self.node_terrain_kind[ni] != TerrainKind.Ground {
            return;
        }

        switch self.node_terrain_ground_kind[ni] {
            case GroundKind.Grass:
                if self.node_terrain_tile[ni] == undefined || force {
                    var n = is_not_grass(self, xx, yy - 2);
                    var w = is_not_grass(self, xx - 2, yy);
                    var e = is_not_grass(self, xx + 2, yy);
                    var s = is_not_grass(self, xx, yy + 2);

                    var sw;
                    var se;
                    var ne;
                    var nw;

                    if e || n {
                        ne = 0;
                    } else {
                        ne = is_not_grass(self, xx + 2, yy - 2);
                    }

                    if e || s {
                        se = 0;
                    } else {
                        se = is_not_grass(self, xx + 2, yy + 2);
                    }

                    if w || n {
                        nw = 0;
                    } else {
                        nw = is_not_grass(self, xx - 2, yy - 2);
                    }

                    if w || s {
                        sw = 0;
                    } else {
                        sw = is_not_grass(self, xx - 2, yy + 2);
                    }

                    var bitty = (1 * nw) + (2 * n) + (4 * ne) + (8 * w) + (16 * e) + (32 * sw) + (64 * s) + (128 * se);
                    self.node_terrain_tile[ni] = array_pos(GRASS_BITMASK, bitty) + 1;
                }

                tilemap_update(self.grass_autotile_tilemap_id, self.node_terrain_tile[ni], xx div 2, yy div 2);

                //
                tilemap_update(self.soil_tilemap_id, 0, xx div 2, yy div 2);
                tilemap_update(self.water_tilemap_id, 0, xx div 2, yy div 2);
                break;
            case GroundKind.Dirt:
                //
                tilemap_update(self.grass_autotile_tilemap_id, 0, xx div 2, yy div 2);
                tilemap_update(self.soil_tilemap_id, 0, xx div 2, yy div 2);
                tilemap_update(self.water_tilemap_id, 0, xx div 2, yy div 2);
                break;
            case GroundKind.Soil:
                //
                tilemap_update(self.grass_autotile_tilemap_id, 0, xx div 2, yy div 2);

                //
                if self.node_terrain_tile[ni] == undefined || force {
                    var n = soil_data_value(self, xx, yy - 2);
                    var w = soil_data_value(self, xx - 2, yy);
                    var e = soil_data_value(self, xx + 2, yy);
                    var s = soil_data_value(self, xx, yy + 2);

                    var nw;
                    var ne;
                    var sw;
                    var se;

                    if w == false || n == false {
                        nw = false;
                    } else {
                        nw = soil_data_value(self, xx - 2, yy - 2);
                    }

                    if e == false || n == false {
                        ne = false;
                    } else {
                        ne = soil_data_value(self, xx + 2, yy - 2);
                    }
                    if w == false || s == false {
                        sw = false;
                    } else {
                        sw = soil_data_value(self, xx - 2, yy + 2);
                    }
                    if e == false || s == false {
                        se = false;
                    } else {
                        se = soil_data_value(self, xx + 2, yy + 2);
                    }

                    var bitty = (1 * nw) + (2 * n) + (4 * ne) + (8 * w) + (16 * e) + (32 * sw) + (64 * s) + (128 * se);
                    self.node_terrain_tile[ni] = array_pos(SOIL_BITMASK, bitty) + 1;
                }

                tilemap_update(self.soil_tilemap_id, self.node_terrain_tile[ni], xx div 2, yy div 2);

                //
                if is_place_watered(self, xx, yy) {
                    var n = is_place_watered(self, xx, yy - 2);
                    var w = is_place_watered(self, xx - 2, yy);
                    var e = is_place_watered(self, xx + 2, yy);
                    var s = is_place_watered(self, xx, yy + 2);

                    var nw;
                    var ne;
                    var sw;
                    var se;

                    if w == false || n == false {
                        nw = false;
                    } else {
                        nw = is_place_watered(self, xx - 2, yy - 2);
                    }

                    if e == false || n == false {
                        ne = false;
                    } else {
                        ne = is_place_watered(self, xx + 2, yy - 2);
                    }
                    if w == false || s == false {
                        sw = false;
                    } else {
                        sw = is_place_watered(self, xx - 2, yy + 2);
                    }
                    if e == false || s == false {
                        se = false;
                    } else {
                        se = is_place_watered(self, xx + 2, yy + 2);
                    }

                    var bitty = (1 * nw) + (2 * n) + (4 * ne) + (8 * w) + (16 * e) + (32 * sw) + (64 * s) + (128 * se);
                    var tile = array_pos(SOIL_BITMASK, bitty) + 1;

                    tilemap_update(self.water_tilemap_id, tile, xx div 2, yy div 2);
                }
                break;
        }

        //
        if self.node_terrain_variant[ni] != undefined {
            if write_terrain_tile_to_tilemap(self, xx, yy) == false {
                tilemap_set(self.grass_variant_tilemap_id, 0, xx div 2, yy div 2);
            }
        } else {
            tilemap_set(self.grass_variant_tilemap_id, 0, xx div 2, yy div 2);
        }
    }

    function wilt_crops(season) {
        for (var xx = 0; xx < self.dims.x; xx += 2) {
            for (var yy = 0; yy < self.dims.y; yy += 2) {
                var ni = self.node_index_for_cell(xx,yy);

                //
                if object_id_to_object_category(self.node_object_id[ni]) != ObjectCategory.Crop
                    || self.node_parent[ni].prototype.seasons[season]
                {
                    continue;
                }

                //
                //
                if can_interact(self.node_parent[ni]) {
                    var output_array = array_create(self.node_parent[ni].prototype.count, undefined);
                    for (var i = 0; i < self.node_parent[ni].prototype.count; i++) {
                        output_array[i] = new LiveItem(self.node_parent[ni].prototype.harvest);
                    }

                    //
                    if CURRENT_LOCATION_ID == self.location_id {
                        drop_item(output_array, xx * 8, yy * 8);
                    } else {
                        self.lost_items.push({
                            x: xx * 8 + irandom(8),
                            y: yy * 8 + irandom(8),
                            items: ListFromArray(output_array),
                        });
                    }
                }

                //
                var stage = self.node_parent[ni].stage;
                var proto = self.node_parent[ni].prototype;
                erase_object_node(self, ni);

                if proto.stage_zero_is_seed == false || stage != 0 {
                    self.write_node(xx, yy, ObjectId.WiltedPlant);
                }
            }
        }
    }

    //
    function wilt_trees_and_forageables(season, old_season) {
        var tag = irandom(I32_MAX);

        for (var xx = 0; xx < self.dims.x; xx += 2) {
            for (var yy = 0; yy < self.dims.y; yy += 2) {
                var ni = self.node_index_for_cell(xx,yy);
                if self.node_object_id[ni] == undefined || self.node_parent[ni].last_update == tag {
                    continue;
                }

                //
                self.node_parent[ni].last_update = tag;

                switch object_id_to_object_category(self.node_object_id[ni]) {
                    case ObjectCategory.Tree:
                        if self.node_parent[ni].has_fruit
                            && self.node_parent[ni].prototype.fruit_data.seasons.contains(season) == false
                        {
                            self.node_parent[ni].fruiting_days = 0;
                            self.node_parent[ni].has_fruit = false;

                            //
                            if self.node_parent[ni].renderer != undefined && instance_exists(self.node_parent[ni].renderer) {
                                self.node_parent[ni].renderer.fruit_sprite = undefined;
                                self.node_parent[ni].renderer.fruit_sprite_positions = undefined;
                            }
                        }

                        //
                        if self.location_id != LocationId.Farm
                            && self.node_parent[ni].prototype.fruit_data != undefined
                            && self.node_parent[ni].prototype.fruit_data.seasons.contains(old_season) == false
                            && self.node_parent[ni].prototype.fruit_data.seasons.contains(season)
                        {
                            self.node_parent[ni].fruiting_days = 0;
                            self.node_parent[ni].has_fruit = true;
                        }
                        break;
                    case ObjectCategory.Crop:
                        if has_flag(self.node_parent[ni].ctx, CropFlag.FORAGEABLE)
                            || self.node_parent[ni].prototype.seasons[season] == false
                        {
                            erase_object_node(self, ni);
                        }
                        break;
                    case ObjectCategory.Bush:
                        if self.node_parent[ni].prototype.seasons[season] {
                            //
                            if self.node_parent[ni].prototype.seasons[old_season] == false {
                                self.node_parent[ni].day_count = self.node_parent[ni].prototype.regrow_days + 1;
                            }
                        } else {
                            switch self.node_parent[ni].prototype.off_season {
                                case OffSeason.Regress:
                                    self.node_parent[ni].day_count = 0;
                                    break;
                                case OffSeason.Destroy:
                                    erase_object_node(self, ni);
                                    break;
                                default: impossible("unexpected off_season: {}", self.node_parent[ni].prototype.off_season);
                            }
                        }
                        break;
                    default:
                        break;
                }
            }
        }
    }

    function save(saver) {
        var data_blob = create_grid_serialization_data(self);

        var file_name;
        if self.dyn_index == undefined {
            file_name = data_blob.location_id;
        } else {
            file_name = create_dynamic_grid_file_name(self.dyn_index);
        }

        if data_blob[$ "terrain_buffer"] != undefined {
            saver.save_farm_buffer(data_blob.terrain_buffer);
        }

        //
        saver.save_file(
            file_name,
            {
                object_list: data_blob.object_list,
                inventories: data_blob.inventories,
                size_x: data_blob.size_x,
                size_y: data_blob.size_y,
                location_id: data_blob.location_id,
                dyn_index: data_blob.dyn_index,
            }
        );
    }

    //
    function load(data, terrain_buffer) {
        //
        var c = array_length(data.inventories);
        for(var i = 0; i < c; i++) {
            var internal_inventory = data.inventories[i];
            var inventory = Inventory(array_length(internal_inventory));
            //
            inventory.deserialize(internal_inventory);
            data.inventories[i] = inventory;
        }

        //
        if terrain_buffer != undefined {
            //
            buffer_seek(terrain_buffer, buffer_seek_start, 0);
            var position = Vec2(0, -2);

            for (var i = 0, c = buffer_get_size(terrain_buffer); i < c; i++) {
                position.y += 2;
                if position.y >= self.dims.y {
                    position.y = 0;
                    position.x += 2;
                }
                //
                if position.x >= self.dims.x {
                    break;
                }
                var terrain_kind = serialized_to_terrain_kind(buffer_read(terrain_buffer, buffer_u8));

                switch terrain_kind {
                    case TerrainKind.Ground:
                        //
                        i+= 3;

                        var gkind = serialized_to_ground_kind(buffer_read(terrain_buffer, buffer_u8));

                        //
                        var is_watered = buffer_read(terrain_buffer, buffer_u8) == 1;

                        var variant = serialized_to_main_exterior_tile_indexes(buffer_read(terrain_buffer, buffer_u8));

                        self.write_ground(position.x, position.y, gkind, function(grid, ni, gkind, is_watered, variant) {
                            grid.node_terrain_is_watered[ni] = gkind == GroundKind.Soil && is_watered;
                            grid.node_terrain_variant[ni] = variant;
                        }, [gkind, is_watered, variant]);
                        break;

                    case TerrainKind.Water:
                        self.write_water(position.x, position.y);
                        break;

                    case undefined:
                        //
                        break;

                    //
                    default: impossible("unknown terrain_kind found = {} @ {}", terrain_kind, position);
                }
            }
        }

        //
        load_objects(data.object_list, data.inventories);

        //
        //
        if self.ocarina != undefined {
            self.ocarina.sound_idx = undefined;
        }
    }

    function load_objects(objects, inventories) {
        for (var i = 0, c = array_length(objects); i < c; i++) {
            var obj = objects[i];
            //
            var object_id = try_string_to_object_id(obj.object_id);
            if object_id == undefined {
                if !DEBUG_ASSERTIONS {
                    error("Unexpected object name: `{}`. ignoring...", obj.object_id);
                    continue;
                } else {
                    crash("Unexpected ObjectId name `{}`, did not match any ids", obj.object_id)
                }
            }
            var category = object_id_to_object_category(object_id);

            var node;
            switch category {
                case ObjectCategory.Crop:
                    node = self.write_node(obj.top_left_x, obj.top_left_y, object_id, obj.ctx);
                    break;
                case ObjectCategory.Building:
                    node = self.write_node(obj.top_left_x, obj.top_left_y, object_id, { variant: obj.variant, dyn_index: obj.dyn_index });
                    break;
                case ObjectCategory.Furniture:
                    var input_rotation = 0;

                    for (var j = 0, l = array_length(NODE_PROTOTYPES[object_id].cardinals); j < l; j++) {
                        var rot = NODE_PROTOTYPES[object_id].cardinals[j];
                        if rot == obj.cardinal_index {
                            input_rotation = j;
                            break;
                        }
                    }

                    node = self.write_node(obj.top_left_x, obj.top_left_y, object_id, input_rotation);
                    if TEST_SUITE && node == undefined {
                        test_suite_grid_load_failure(object_id, self.location_id, obj.top_left_x, obj.top_left_y, obj);
                    }
                    if node != undefined &&  node.child_grid != undefined && obj[$ "sub_grid_blob"] != undefined {
                        node.child_grid.load(obj.sub_grid_blob);
                    }
                    break;
                default:
                    node = self.write_node(obj.top_left_x, obj.top_left_y, object_id);
                    break;
            }

            if node == undefined {
                if TEST_SUITE {
                    test_suite_grid_load_failure(object_id, self.location_id, obj.top_left_x, obj.top_left_y, obj);
                } else {
                    error("failed to make {ObjectId} @ {}x{}", object_id, obj.top_left_x, obj.top_left_y);
                }
                continue;
            }

            if category == ObjectCategory.Furniture {
                if node.prototype.factory != undefined {
                    node.inventory = inventories[obj.inventory];
                    for (var j = 0, ic = node.inventory.size(); j < ic; j++) {
                        node.inventory.slot(j).one_slot = true;
                    }
                    node.production_request = opt_and_then(obj.production_request, try_string_to_item_id);
                    node.production_tier = opt_and_then(obj.production_tier, string_to_factory_tier);
                }

                if node.prototype.interaction_chest != undefined {
                    //
                    node.inventory = inventories[obj.inventory];

                    //
                    //
                    //
                    assert(node.inventory.size() <= node.prototype.interaction_chest.inventory_size);
                    node.inventory.resize(node.prototype.interaction_chest.inventory_size);

                    node.chest_icon = opt_and_then(obj[$ "chest_icon"], string_to_chest_icon);

                    if node.prototype.interaction_chest.allow_soulbound == false {
                        node.inventory.slots.for_each(function(slot) {
                            slot.allow_soulbound = false;
                        });
                    };
                }

                if object_id == ObjectId.AutoFeeder {
                    node.inventory = inventories[obj.inventory];
                }
            }

            if category == ObjectCategory.Tree && obj.stage != 0 {
                //
                for (var xx = 2; xx < 4; xx++) {
                    for (var yy = 2; yy < 4; yy++) {
                        set_collision_on_node(
                            self,
                            node.top_left_x + xx,
                            node.top_left_y + yy,
                        );
                    }
                }
            }

            //
            var names = struct_get_names(obj);
            for (var j = 0, cj = array_length(names); j < cj; j++) {
                var name = names[j];

                //
                //
                //
                if name == "object_id" || name == "write_size_x" || name == "write_size_y" {
                    continue;
                }

                //
                if name == "active_toy_sfx" {
                    continue;
                }

                if name == "blueprint_id" {
                    node.blueprint_id = string_to_blueprint(obj[$ name]);
                    continue;
                }

                switch category {
                    case ObjectCategory.Furniture:
                        if name == "inventory" || name == "chest_icon" || name == "production_request" || name == "production_tier" {
                            continue;
                        }
                        if name == "blueprint_fingerprint"
                            && node.prototype.fence
                        {
                            node.blueprint_fingerprint = int64(obj[$ name]);
                            autotile_furniture_fence_node(self, node);
                            continue;
                        }

                        if name == "cardinal_index" {
                            var cardinal_index = obj.cardinal_index;
                            var cardinal_data = node.prototype.cardinal_data[cardinal_index];
                            repeat 4 {
                                if cardinal_data == undefined {
                                    cardinal_index = wrap(cardinal_index + 1, Cardinal.LEN);
                                    cardinal_data = node.prototype.cardinal_data[cardinal_index];
                                }
                            }
                            node.cardinal_index = cardinal_index;
                            if cardinal_data == undefined {
                                error("Failed to deserialize cardinal_index for {ObjectId}, there will likely be a crash in the future!", node.object_id);
                            }

                            continue;
                        }
                        break;
                    case ObjectCategory.Crop:
                        if name == "ctx" {
                            continue;
                        }
                        break;
                    case ObjectCategory.Building:
                        if name == "stable" {
                            node.stable.deserialize(obj.stable);
                            continue;
                        } else if name == "dyn_index" {
                            node.dyn_index = obj.dyn_index;
                            if DYNAMIC_GRIDS.get(node.dyn_index) == undefined {
                                error("Dyn_index requested: {}", node.dyn_index);
                                crash("no dynamic_index found matching stable index");
                            }
                            continue;
                        } else if name == "greenhouse_watered_positions" {
                            //
                            //
                            if node.prototype["crop_area_end"] == undefined {
                                continue;
                            }
                            apply_greenhouse_watered_positions(node, obj.greenhouse_watered_positions);
                            continue;
                        }
                        break;
                }

                //
                node[$ name] = obj[$ name] == pointer_null ? undefined : obj[$ name];
            }
        }
    }
}

//
function create_dynamic_grid_file_name(dyn_index) {
    return fmt("DynamicGrid_{int}", dyn_index);
}

function create_grid_serialization_data(grid) {
    var save_counter = irandom(I32_MAX);

    var object_list = List();

    var terrain_buffer = undefined;

    if grid.location_id == LocationId.Farm && grid.parent_node == undefined {
        terrain_buffer = buffer_create(grid.dims.x * grid.dims.y * 2, buffer_grow, 1);
        buffer_seek(terrain_buffer, buffer_seek_start, 0);

        //
        for (var i = 0; i < array_length(grid.terrain_editors); i++) {
            var node = grid.terrain_editors[i];

            furniture_write_old_terrain(grid, node.top_left_x, node.top_left_y, node.prototype.size.x, node.prototype.size.y, node.old_terrain);
        }
    }

    var inventories = List();

    for (var xx = 0; xx < grid.dims.x; xx++) {
        for (var yy = 0; yy < grid.dims.y; yy++) {
            var ni = grid.node_index_for_cell(xx, yy);

            //
            if grid.node_object_id[ni] != undefined && grid.node_parent[ni].last_update != save_counter {
                object_list.push(create_grid_object_serialization_data(grid.node_parent[ni], inventories));
                grid.node_parent[ni].last_update = save_counter;
            }

            //
            if grid.node_rug_id[ni] != undefined && grid.node_rug_parent[ni].last_update != save_counter {
                object_list.push(create_grid_object_serialization_data(grid.node_rug_parent[ni], inventories));
                grid.node_rug_parent[ni].last_update = save_counter;
            }

            //
            if grid.location_id == LocationId.Farm
                && grid.parent_node == undefined
                && (xx mod 2 == 0) && (yy mod 2 == 0)
            {
                if grid.node_terrain_kind[ni] == undefined {
                    buffer_write(terrain_buffer, buffer_u8, SerializedTerrainKind.NoTerrain);
                } else {
                    buffer_write(terrain_buffer, buffer_u8, terrain_kind_to_serialized(grid.node_terrain_kind[ni]));

                    if grid.node_terrain_kind[ni] == TerrainKind.Ground {
                        buffer_write(terrain_buffer, buffer_u8, ground_kind_to_serialized(grid.node_terrain_ground_kind[ni]));
                        buffer_write(terrain_buffer, buffer_u8, grid.node_terrain_is_watered[ni]);

                        if grid.node_terrain_variant[ni] == undefined {
                            buffer_write(terrain_buffer, buffer_u8, SerializedMainExteriorTileIndices.NoVariant);
                        } else {
                            buffer_write(terrain_buffer, buffer_u8, main_exterior_tile_indexes_to_serialized(grid.node_terrain_variant[ni]));
                        }
                    }
                }
            }
        }
    }

    var output = {
        object_list: object_list.to_array(),
        inventories: inventories.to_array(),
        size_x: grid.dims.x,
        size_y: grid.dims.y,
        location_id: location_id_to_string(grid.location_id),
        dyn_index: grid.dyn_index == undefined ? -1 : grid.dyn_index,
    };

    //
    //
    if terrain_buffer != undefined {
        output.terrain_buffer = terrain_buffer;

        //
        //
        for (var i = 0; i < array_length(grid.terrain_editors); i++) {
            var node = grid.terrain_editors[i];

            for (var j = 0; j < node.prototype.size.x * node.prototype.size.y; j++) {
                var obj_x = j % node.prototype.size.x;
                var obj_y = j div node.prototype.size.x;

                var new_terrain_kind = node.prototype.output_terrain[# obj_x, obj_y];
                if new_terrain_kind != undefined {
                    //
                    var posx = node.top_left_x + obj_x;
                    var posy = node.top_left_y + obj_y;
                    var ni = grid.node_index_for_cell(posx, posy);

                    node.old_terrain[j] = furniture_write_new_terrain(grid, ni, new_terrain_kind);
                }
            }
        }
    }

    return output;
}

function create_grid_object_serialization_data(parent, inventories) {
    var parent_names = struct_get_names(parent);

    var o = {};

    for (var i = 0, c = array_length(parent_names); i < c; i++) {
        var n = parent_names[i];

        switch object_id_to_object_category(parent.object_id) {
            case ObjectCategory.Building:
                if n == "stable" {
                    if parent.prototype.player_building_kind == PlayerBuildingKind.Stable {
                        o[$ n] = parent.stable.serialize();
                    }
                    continue;
                }

                if n == "greenhouse_watered_positions" && parent.prototype.player_building_kind == PlayerBuildingKind.Greenhouse
                {
                    o[$ n] = record_greenhouse_watered_positions(parent);
                    continue;
                }
                break;

            case ObjectCategory.Furniture:
                if n == "production_request" {
                    o[$ n] = opt_and_then(parent[$ n], item_id_to_string);
                    continue;
                }

                if n == "production_tier" {
                    o[$ n] = opt_and_then(parent[$ n], factory_tier_to_string);
                    continue;
                }
                if n == "day_count" {
                    o[$ n] = parent[$ n];
                    continue;
                }
                if n == "inventory" {
                    o[$ n] = inventories.count();
                    var val = parent[$ n].serialize();
                    inventories.push(val);
                    continue;
                }
                break;
            case ObjectCategory.Breakable:
                if n == "items" {
                    continue;
                }
                break;
        }

        switch n {
            case "prototype":
            case "last_update":
            case "renderer":
            case "sub_grid_blob":
            case "parent_grid":
            case "write_size_x":
            case "write_size_y":
            case "active_toy_sfx":
                continue;
            case "object_id":
                o[$ n] = object_id_to_string(parent[$ n]);
                break;
            case "blueprint_id":
                o[$ n] = blueprint_to_string(parent[$ n]);
                break;
            case "chest_icon":
                o[$ n] = parent[$ n] != undefined ? chest_icon_to_string(parent[$ n]) : undefined;
                break;
            case "child_grid":
                //
                if parent[$ n] != undefined {
                    o.sub_grid_blob = create_grid_serialization_data(parent.child_grid);
                }
                break;
            default:
                o[$ n] = parent[$ n];

                if is_struct(parent[$ n]) {
                    warn("variable {} is a struct! we can't serialize it", n);
                }
        }
    }

    return o;
}

enum SerializedTerrainKind {
    Ground,
    Water,
    Lava,
    NoTerrain,
}

function terrain_kind_to_serialized(t) {
    switch t {
        case TerrainKind.Ground:
            return SerializedTerrainKind.Ground;
        case TerrainKind.Water:
            return SerializedTerrainKind.Water;
        case TerrainKind.Lava:
            return SerializedTerrainKind.Lava;
        default: impossible("unexpected terrain_kind {}", t);
    }
}

function serialized_to_terrain_kind(t) {
    switch t {
        case SerializedTerrainKind.Ground:
            return TerrainKind.Ground;
        case SerializedTerrainKind.Water:
            return TerrainKind.Water;
        case SerializedTerrainKind.Lava:
            return TerrainKind.Lava;
        case SerializedTerrainKind.NoTerrain:
            return undefined;
        default: impossible("unexpected serialized terrain kind {}", t);
    }
}

enum SerializedGroundKind {
    Grass,
    Dirt,
    Soil,
    RiverBank,
}

function ground_kind_to_serialized(t) {
    switch t {
        case GroundKind.Grass:
            return SerializedGroundKind.Grass;
        case GroundKind.Dirt:
            return SerializedGroundKind.Dirt;
        case GroundKind.Soil:
            return SerializedGroundKind.Soil;
        case GroundKind.RiverBank:
            return SerializedGroundKind.RiverBank;
        default: impossible("unexpected ground_kind {}", t);
    }
}

function serialized_to_ground_kind(t) {
    switch t {
        case SerializedGroundKind.Grass:
            return GroundKind.Grass;
        case SerializedGroundKind.Dirt:
            return GroundKind.Dirt;
        case SerializedGroundKind.Soil:
            return GroundKind.Soil;
        case SerializedGroundKind.RiverBank:
            return GroundKind.RiverBank;
        default: impossible("unexpected serialized ground kind {}", t);
    }
}

enum SerializedMainExteriorTileIndices {
    DirtNormal,
    DirtVariantOne,
    DirtVariantTwo,
    DirtVariantThree,
    FlowerVariantOne,
    FlowerVariantTwo,
    GrassNormal,
    GrassVariantOne,
    GrassVariantTwo,

    NoVariant
}

function main_exterior_tile_indexes_to_serialized(t) {
    switch t {
        case MainExteriorTileIndexes.DirtNormal:
            return SerializedMainExteriorTileIndices.DirtNormal;
        case MainExteriorTileIndexes.DirtVariantOne:
            return SerializedMainExteriorTileIndices.DirtVariantOne;
        case MainExteriorTileIndexes.DirtVariantTwo:
            return SerializedMainExteriorTileIndices.DirtVariantTwo;
        case MainExteriorTileIndexes.DirtVariantThree:
            return SerializedMainExteriorTileIndices.DirtVariantThree;
        case MainExteriorTileIndexes.FlowerVariantOne:
            return SerializedMainExteriorTileIndices.FlowerVariantOne;
        case MainExteriorTileIndexes.FlowerVariantTwo:
            return SerializedMainExteriorTileIndices.FlowerVariantTwo;
        case MainExteriorTileIndexes.GrassNormal:
            return SerializedMainExteriorTileIndices.GrassNormal;
        case MainExteriorTileIndexes.GrassVariantOne:
            return SerializedMainExteriorTileIndices.GrassVariantOne;
        case MainExteriorTileIndexes.GrassVariantTwo:
            return SerializedMainExteriorTileIndices.GrassVariantTwo;
        default: impossible("unexpected main exterior tile index {}", t);
    }
}

function serialized_to_main_exterior_tile_indexes(t) {
    switch t {
        case SerializedMainExteriorTileIndices.DirtNormal:
            return MainExteriorTileIndexes.DirtNormal;
        case SerializedMainExteriorTileIndices.DirtVariantOne:
            return MainExteriorTileIndexes.DirtVariantOne;
        case SerializedMainExteriorTileIndices.DirtVariantTwo:
            return MainExteriorTileIndexes.DirtVariantTwo;
        case SerializedMainExteriorTileIndices.DirtVariantThree:
            return MainExteriorTileIndexes.DirtVariantThree;
        case SerializedMainExteriorTileIndices.FlowerVariantOne:
            return MainExteriorTileIndexes.FlowerVariantOne;
        case SerializedMainExteriorTileIndices.FlowerVariantTwo:
            return MainExteriorTileIndexes.FlowerVariantTwo;
        case SerializedMainExteriorTileIndices.GrassNormal:
            return MainExteriorTileIndexes.GrassNormal;
        case SerializedMainExteriorTileIndices.GrassVariantOne:
            return MainExteriorTileIndexes.GrassVariantOne;
        case SerializedMainExteriorTileIndices.GrassVariantTwo:
            return MainExteriorTileIndexes.GrassVariantTwo;
        case SerializedMainExteriorTileIndices.NoVariant:
            return undefined;
        default: impossible("unexpected serialized main exterior tile index {}", t);
    }
}


function is_not_grass(grid, xx, yy) {
    if xx < 0
        || xx > grid.dims.x - 1
        || yy < 0
        || yy > grid.dims.y - 1
    {
        return false;
    }

    var ni = grid.node_index_for_cell(xx, yy);

    if grid.node_terrain_kind[ni] == undefined || grid.node_terrain_kind[ni] == TerrainKind.Water {
        return false; //
    }

    switch (grid.node_terrain_ground_kind[ni]) {
        case GroundKind.Grass:
        case GroundKind.RiverBank:
            //
            return false;
        case GroundKind.Dirt:
        case GroundKind.Soil:
            return true;
        default: impossible("unknown ground_kind {}", grid.node_terrain_ground_kind[ni]);
    }
}

function soil_data_value(grid, xx, yy) {
    if xx < 0
        || xx > self.dims.x - 1
        || yy < 0
        || yy > self.dims.y - 1
    {
        return false;
    }

    var ni = grid.node_index_for_cell(xx, yy);

    if grid.node_terrain_kind[ni] == undefined || grid.node_terrain_kind[ni] == TerrainKind.Water {
        return false; //
    }

    switch (grid.node_terrain_ground_kind[ni]) {
        case GroundKind.Grass:
        case GroundKind.Dirt:
        case GroundKind.RiverBank:
            return false;
        case GroundKind.Soil:
            return true;
        default: impossible("unknown ground_kind {} @ {} ({}x{})", grid.node_terrain_ground_kind[ni], ni, xx, yy);
    }
};

function is_place_watered(grid, xx, yy) {
    if xx < 0
        || xx > self.dims.x - 1
        || yy < 0
        || yy > self.dims.y - 1
    {
        return false;
    }

    var ni = grid.node_index_for_cell(xx, yy);

    if grid.node_terrain_kind[ni] == undefined || grid.node_terrain_kind[ni] == TerrainKind.Water {
        return false; //
    }

    switch (grid.node_terrain_ground_kind[ni]) {
        case GroundKind.Grass:
        case GroundKind.Dirt:
        case GroundKind.RiverBank:
            return false;
        case GroundKind.Soil:
            return grid.node_terrain_is_watered[ni];
        default: impossible("unknown ground_kind {}", grid.node_terrain_ground_kind[ni]);
    }
};


function remake_room_renderers() {
    //
    with obj_node_renderer {
        instance_destroy(self, true);
    }

    //
    var c = irandom(I32_MAX);
    for (var xx = 0; xx < GRID.dims.x; xx++) {
        for (var yy = 0; yy < GRID.dims.y; yy++) {
            var ni = GRID.node_index_for_cell(xx, yy);

            if GRID.node_object_id[ni] == undefined || GRID.node_parent[ni].last_update == c {
                continue;
            }

            //
            GRID.node_parent[ni].last_update = c;
            GRID.initialize_node_renderer(GRID.node_parent[ni]);
        }
    }
}
