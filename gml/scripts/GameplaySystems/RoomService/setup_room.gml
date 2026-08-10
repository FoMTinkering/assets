//
function setup_room() {
    //
    //
    if LOCATIONS[CURRENT_LOCATION_ID].outdoor == false
        && instance_exists(obj_windowshader_interior)
        && instance_exists(obj_exterior_window_interior) == false
    {
        var largest_y = 0;
        var new_exterior_window_interior = instance_create_depth(
            0,
            0,
            0,
            obj_exterior_window_interior
        );

        with obj_windowshader_interior {
            if (self.y + self.image_yscale) > largest_y {
                largest_y = self.y + self.image_yscale;
            }

            var xx_dist = self.image_xscale / 8;
            if frac(xx_dist) != 0 {
                warn("Window Shader Interior in {LocationId} has width that isn't cleanly divisible by 8!", CURRENT_LOCATION_ID);
                xx_dist = ceil(xx_dist);
            }

            var yy_dist = self.image_yscale / 8;
            if frac(yy_dist) != 0 {
                warn("Window Shader Interior in {LocationId} has height that isn't cleanly divisible by 8!", CURRENT_LOCATION_ID);
                yy_dist = ceil(yy_dist);
            }

            var x_root = self.x div 8;
            var y_root = self.y div 8;

            for (var xx = 0; xx < xx_dist; xx++) {
                for (var yy = 0; yy < yy_dist; yy++) {
                    new_exterior_window_interior.windows[# xx + x_root, yy + y_root] = true;
                }
            }
        }
        instance_destroy(obj_windowshader_interior);

        new_exterior_window_interior.horizon_line = largest_y div 8;
    }

    static GET_INVISIBLE_LAYERS = function() {
        var out = HashSetFromArray([
            "Tiles_bridge_fixed",
            "Tiles_bridge_destroyed",
            "Tiles_Collision",
            "Tiles_Collision_Zero",
            "Tiles_Collision_One",
            "Tiles_Collision_Two",
            "Tiles_Collision_Three",
            "Tiles_Collision_Four",
            "Tiles_Collision_Player_House_Adobe",
            "Tiles_Collision_Player_House_Leafy_Cottage",
            "Tiles_Collision_Player_House_Leafy_Timbered",
            "Tiles_Collision_Player_House_Leafy_Victorian",
            "Tiles_Collision_Player_House_Upgrade",
            "Tiles_Rules",
            "Tiles_Rules_Post_Init",
            "Tiles_Forces",
            "Tiles_Critter_Points",
            "Pathfinding",
            "FootstepTiles",
            "PriorityObjects",
            "PriorityObjectsSpring",
            "PriorityObjectsSummer",
            "PriorityObjectsFall",
            "PriorityObjectsWinter",
            "Level_0_Shadows",
            "Level_0_Shadows_Fixed",
            "Level_1_Shadows",
            "Level_2_Shadows",
            "Level_0_BasicShadows",
            "Level_0_UpgradedShadows",
            "Level_0_UpgradedShadowsNorthern",
            "Level_0_Assets_Saturday_Market",
            "Tiles_Collision_Saturday_Market",
            "Level_0_FloorSprites_Saturday_Market",
            "Tiles_Fish_Size",
            "Tiles_WindowBacking",
            "Level_0_Assets_Wedding",
            "Level_0_FloorSprites_Wedding",
            "Level_0_Assets_Wedding_Flowers_blue",
            "Level_0_Assets_Wedding_Flowers_ebony",
            "Level_0_Assets_Wedding_Flowers_multicolor",
            "Level_0_Assets_Wedding_Flowers_pink",
            "Level_0_Assets_Wedding_Flowers_purple",
            "Level_0_Assets_Wedding_Flowers_red",
            "Level_0_Assets_Wedding_Flowers_white",
            "Level_0_Assets_Wedding_Flowers_yellow",
            "Level_0_Assets_Wedding_Cake_chocolate",
            "Level_0_Assets_Wedding_Cake_golden_cheesecake",
            "Level_0_Assets_Wedding_Cake_lemon",
            "Level_0_Assets_Wedding_Cake_mont_blanc",
            "Level_0_Assets_Wedding_Cake_moon_fruit",
            "Level_0_Assets_Wedding_Cake_pumpkin_pie",
            "Level_0_Assets_Wedding_Cake_rose",
            "Level_0_Assets_Wedding_Cake_rose_hip",
            "Level_0_Assets_Wedding_Cake_spellfruit",
            "Level_0_Assets_Wedding_Cake_triple_chocolate",
            "Level_0_Assets_Wedding_Cake_vanilla",
            "Level_0_Assets_Wedding_Cake_wildberry",
        ]);

        for (var i = 0; i < NpcId.LEN; i++) {
            var name = capitalize(npc_id_to_string(i));
            out.insert(format("Level_0_Assets_Stall_{}", name));
            out.insert(format("Tiles_Collision_Stall_{}", name));
            out.insert(format("Level_0_FloorSprites_Stall_{}", name));
        }

        for (var i = 0; i < WorldMod.LEN; i++) {
            var wm = WORLD_MODS[i];
            if wm.collision_edit != undefined {
                out.insert(format("Tiles_Collision_{}", wm.collision_edit.name));
            }
        }

        for (var i = 0; i < FestivalId.LEN; i++) {
            var f = FESTIVALS[i];
            for (var j = 0; j < array_length(f.prototype.challenges); j++) {
                var challenge = f.prototype.challenges[j];
                for (var k = 0; k < array_length(challenge.tier_results); k++) {
                    var tier = challenge.tier_results[k];
                    if tier[$ "asset_layer"] != undefined {
                        out.insert(tier.asset_layer);
                    }
                    if tier[$ "collision_layer"] != undefined {
                        out.insert(tier.collision_layer);
                    }
                }
            }

            for (var j = 0; j < array_length(f.prototype.decor); j++) {
                var decor = f.prototype.decor[j];
                if decor == undefined {
                    continue;
                }

                for (var k = 0; k < array_length(decor.asset_layers); k++) {
                    out.insert(decor.asset_layers[k]);
                }

                for (var k = 0; k < array_length(decor.collision_layers); k++) {
                    out.insert(decor.collision_layers[k]);
                }
            }
        }

        return out;
    }
    static INVISIBLE_LAYERS = GET_INVISIBLE_LAYERS();

    var season = CALENDAR.season();

    switch CURRENT_LOCATION_ID {
        case LocationId.Dungeon:
            break;
        case LocationId.Aldaria:
            //
            return;
        case LocationId.SmallGreenhouse:
        case LocationId.LargeGreenhouse:
            //
            season = Season.Spring;
            break;
    }

    //
    //
    instance_activate_object(obj_assetobject);

    with obj_assetobject {
        if self.from_room_service {
            instance_destroy();
        }
    }

    with obj_door {
        if self.from_room_service {
            instance_destroy();
        }
    }

    with obj_shadow_level {
        instance_destroy();
    }

    var removals = [];
    for (var i = 0; i < WorldMod.LEN; i++) {
        var world_mod = WORLD_MODS[i];
        if world_mod.location_id != CURRENT_LOCATION_ID {
            continue;
        }
        var enabled = world_mod_enabled(i);

        if world_mod.collision_edit != undefined {
            var room_id = location_id_to_gm_room(CURRENT_LOCATION_ID);
            var other_collision_layer_name = format("Tiles_Collision_{}", world_mod.collision_edit.name);

            var replace_mode = world_mod.collision_edit[$ "replacement_area"] != undefined;
            var grid = GRIDS[CURRENT_LOCATION_ID];
            var bounds = replace_mode
                ? Vec4(
                    world_mod.collision_edit.replacement_area[0],
                    world_mod.collision_edit.replacement_area[1],
                    world_mod.collision_edit.replacement_area[2],
                    world_mod.collision_edit.replacement_area[3],
                )
                : Vec4(0, 0, grid.dims.x - 1, grid.dims.y - 1);

            for (var xx = bounds.x1; xx <= bounds.x2; xx++) {
                for (var yy = bounds.y1; yy <= bounds.y2; yy++) {
                    var ni = grid.node_index_for_cell(xx, yy);

                    //
                    var edit_value = room_data_read_tile(room_id, other_collision_layer_name, xx, yy);
                    if edit_value == 2 {
                        edit_value = 1;
                    } else if edit_value == 3 {
                        edit_value = 0;
                    } else {
                        edit_value = undefined;
                    }

                    var og_has_collision = room_data_read_cell(room_id, xx, yy, CellDataRequest.Collideable);
                    var og_jumpable = room_data_read_cell(room_id, xx, yy, CellDataRequest.CanJumpOver);
                    var og_pathable = room_data_read_cell(room_id, xx, yy, CellDataRequest.PathfindingSitting);

                    var write_collision = enabled ? edit_value != undefined : og_has_collision;
                    var write_jumpable = enabled ? edit_value == 1 : og_jumpable;
                    if replace_mode {
                        //
                        //
                        if enabled && og_has_collision == (edit_value != undefined) {
                            continue;
                        }
                    } else if edit_value == undefined {
                        //
                        continue;
                    }

                    var should_evil = matches(
                        grid.node_is_room_editor_collision[ni],
                        RoomEditorCollision.Active,
                        RoomEditorCollision.Inactive,
                    );
                    if should_evil {
                        grid.node_is_room_editor_collision[ni] = RoomEditorCollision.None;
                    }

                    var col_flag = -1;
                    if write_collision {
                        if write_jumpable {
                            col_flag = og_pathable ? 3 : 1;
                        } else {
                            col_flag = og_pathable ? 4 : 2;
                        }
                    }

                    set_collision_grid_flag_on_node(grid, col_flag, xx, yy);

                    if should_evil {
                        grid.node_is_room_editor_collision[ni] = RoomEditorCollision.Inactive;
                    }
                }
            }

            with obj_door {
                set_collision();
            }
        }

        removals = array_concat(
            removals,
            enabled ? world_mod.layer_removals : world_mod.layer_additions
        );
    }

    //
    //
    if CURRENT_LOCATION_ID == LocationId.Farm {
        switch CALENDAR.season() {
            case Season.Spring:
                background_set_color(make_color_rgb(80, 207, 143), 1.0);
                break;
            case Season.Summer:
                background_set_color(make_color_rgb(109, 194, 95), 1.0);
                break;
            case Season.Winter:
                background_set_color(make_color_rgb(240, 252, 255), 1.0);
                break;
            case Season.Fall:
                background_set_color(make_color_rgb(217, 79, 100), 1.0);
                break;
        }

        for (var i = 0; i < HomeVariant.LEN; i++) {
            var layers = layers_for_home_variant(i);

            if DECOR.variant != i {
                for (var j = 0; j < array_length(layers); j++) {
                    var nom_deletion = layers[j];
                    if nom_deletion != home_variant_window_layer_tag(DECOR.variant)
                        && array_contains(removals, nom_deletion) == false
                    {
                        array_push(removals, layers[j]);
                    }
                }
                continue;
            }

            if i == HomeVariant.StoneCottage {
                if DECOR.size_upgrade != HomeUpgrade.Small {
                    array_push(removals, "Level_0_Assets_Player_House");
                    array_push(removals, "Level_0_Windows");
                }
                if DECOR.size_upgrade != HomeUpgrade.Large {
                    array_push(removals, "Level_0_Assets_Player_House_Upgrade_1");
                    array_push(removals, "Level_0_Windows_Player_House_Upgrade_1");
                }
                if DECOR.size_upgrade != HomeUpgrade.LargeWest {
                    array_push(removals, "Level_0_Assets_Player_House_Upgrade_2");
                    array_push(removals, "Level_0_Windows_Player_House_Upgrade_2");
                }
                if DECOR.size_upgrade != HomeUpgrade.LargeWestEast || DECOR.upper_floor {
                    array_push(removals, "Level_0_Assets_Player_House_Upgrade_3");
                    array_push(removals, "Level_0_Windows_Player_House_Upgrade_3");
                }
                if !DECOR.upper_floor {
                    array_push(removals, "Level_0_Assets_Player_House_Upgrade_4");
                    array_push(removals, "Level_0_Windows_Player_House_Upgrade_4");
                }
            }
        }

        if DECOR.variant != undefined {
            try {
                var output = array_pos(removals, home_variant_window_layer_tag(DECOR.variant));
                array_delete(removals, output);
            } catch(_) {
                //
            }
        }
    }

    if !instance_exists(obj_void_background) && matches(CURRENT_LOCATION_ID, LocationId.VoidSeal, LocationId.SeridiasHouseBack) {
        instance_create_depth(0, 0, 2000, obj_void_background);
    }

    var layers = layer_get_all();
    for (var i = 0, c = array_length(layers); i < c; i++) {
        var layer_name = layer_get_name(layers[i]);
        var should_be_removed = array_contains(removals, layer_name);

        //
        if string_pos("TrellisPoints", layer_name) != 0 {
            //
            continue;
        }

        //
        if string_copy(layer_name, 1, 6) == "Level_" {
            var output = DUNGEON_FLOOR_DEPTH;
            if CURRENT_LOCATION_ID != LocationId.Dungeon {
                output = room_data_layer_depth(location_id_to_gm_room(CURRENT_LOCATION_ID), layer_name);
            }

            assert_defined(output, "undefined layer_depth `{}` in `{LocationId}`", layer_name, CURRENT_LOCATION_ID);
            strict_layer_depth(layers[i], output);
        }

        //
        if CURRENT_LOCATION_ID != LocationId.PlayerHome
            && string_pos("_Shadows", layer_name) != 0
            && !should_be_removed
        {
            var shadow_map_id = strict_layer_tilemap_get_id(layers[i]);

            var on_level_zero = string_pos("Level_0_Shadows", layer_name) != 0;
            var shadow_level = instance_create_depth(0, 0, layer_get_depth(layers[i]), obj_shadow_level, {
                target_shadow_grid: on_level_zero ? SHADOW_GRID : undefined,
                shadow_maps: [shadow_map_id],
                shadow_map_offsets: [
                    Vec2(tilemap_get_x(shadow_map_id), tilemap_get_y(shadow_map_id)),
                ],
                render_outlines: on_level_zero,
                image_alpha: layer_name == "Level_2_Shadows" ? 0.5 : 1.0,
            });
            if DEBUG_TOOLS {
                shadow_level.name = layer_name;
            }

            should_be_removed = true;
        }

        //
        if INVISIBLE_LAYERS.contains(layer_name) || should_be_removed {
            strict_layer_set_visible(layers[i], false);
            layer_activate(layers[i], false);
            continue;
        }

        //
        //
        strict_layer_set_visible(layers[i], true);
        layer_activate(layers[i], true);

        //
        //
        if season != Season.Spring
            && layer_contains_tilemap(layers[i])
            && LOCATIONS[CURRENT_LOCATION_ID].replace_tilemaps
        {
            var tilemap = strict_layer_tilemap_get_id(layers[i]);
            var tileset = tilemap_get_tileset(tilemap);

            var seasonal_tileset = get_seasonal_tileset(tileset, season);
            if seasonal_tileset != tileset {
                tilemap_tileset(tilemap, seasonal_tileset);
            }
        }

        //
        //
        if string_pos("_Assets", layer_name) != 0 {
            process_asset_layer(layers[i]);
        } else if string_pos("_FloorSprites", layer_name) != 0 {
            process_asset_layer(layers[i], true);
        } else if string_pos("River", layer_name) != 0 {
            var tile_height = room_height() div 16;
            var tile_width = room_width() div 16;
            var tilemap = strict_layer_tilemap_get_id(layers[i]);

            //
            //
            var _width = 21;

            for (var yy = 0; yy < tile_height; yy++) {
                for (var xx = 0; xx < tile_width; xx++) {
                    var _tile = tilemap_get(tilemap, xx, yy);
                    //
                    if
                        //
                        (_tile >= 4 && _tile <= 8)
                        || (_tile >= 25 && _tile <= 29)
                        || (_tile >= 46 && _tile <= 50)

                        //
                        ||(_tile >= 9 && _tile <= 20)
                        ||(_tile >= 30 && _tile <= 41)
                        ||(_tile >= 61 && _tile <= 62)

                        //
                        ||(_tile == 21)

                        //
                        ||(_tile >= 263 && _tile <= 268)
                        ||(_tile >= 284 && _tile <= 289)

                        //
                        ||(_tile >= 256 && _tile <= 261)
                        ||(_tile >= 277 && _tile <= 282)
                    {
                        //
                        var index = ((yy * tile_width) + xx) mod 4;
                        tilemap_set_extra_data(tilemap, index, xx, yy);
                    }
                }
            }
        }
    }

    if MIST.is_running() && MIST.active_cutscene.id == "wedding" {
        var flower_fact = T2R.read("wedding_flower_color") ?? "white";
        var flower_lay = format("Level_0_Assets_Wedding_Flowers_{}", flower_fact);

        if CURRENT_LOCATION_ID == LocationId.Inn {
            var food_fact = T2R.read("wedding_dinner_dish");
            var food_item = try_string_to_item_id(food_fact);
            if food_item == undefined {
                warn("Invalid food item: {}", food_fact);
                food_item = ItemId.HarvestPlate;
            }
            var food_sprite = ITEM_PROTOTYPES[food_item].icon_sprite;

            process_asset_layer(layer_get_id("Level_0_Assets_Wedding"));

            with obj_assetobject {
                if self.sprite_index == spr_npc_food_empty_plate_eat_south {
                    instance_create_layer(
                        self.x,
                        self.y,
                        "Instances",
                        obj_assetobject,
                        {
                            sprite_index: food_sprite,
                            z: -8,
                        }
                    );

                    if !ITEM_PROTOTYPES[food_item].tags.contains("inn_plate") {
                        instance_destroy();
                    }
                }
            }

            if !layer_exists(flower_lay) {
                warn("Invalid flower choice: {}", flower_fact);
                flower_lay = "Level_0_Assets_Wedding_Flowers_white";
            }
            process_asset_layer(layer_get_id(flower_lay));

            var cake_fact = T2R.read("wedding_cake_flavor") ?? "vanilla";
            var lay = format("Level_0_Assets_Wedding_Cake_{}", cake_fact);
            if !layer_exists(lay) {
                warn("Invalid cake choice: {}", cake_fact);
                lay = "Level_0_Assets_Wedding_Cake_vanilla";
            }
            process_asset_layer(layer_get_id(lay));
        } else if CURRENT_LOCATION_ID == LocationId.Town {
            process_asset_layer(layer_get_id("Level_0_Assets_Wedding"));
            process_asset_layer(layer_get_id("Level_0_FloorSprites_Wedding"), true);

            if !layer_exists(flower_lay) {
                warn("Invalid flower choice: {}", flower_fact);
                flower_lay = "Level_0_Assets_Wedding_Flowers_white";
            }
            process_asset_layer(layer_get_id(flower_lay));
        }
    }

    if CURRENT_LOCATION_ID == LocationId.HaydensFarm && QUEST_LOG.active.contains_key("find_the_weathervane") {
        toggle_asset_visibility("spr_haydens_farm_barn_weathervane_spring", false);
    }

    festival_build_layers();
    SATURDAY_MARKET.on_room_start();
}

//
//
function tilemap_update(tilemap, _tile, _x, _y) {
    var val = tilemap_set(tilemap, _tile, _x, _y);
    return val;
}

function get_seasonal_tileset(spring_tileset, season) {
    switch spring_tileset {
        case tile_grassautotile_spring:
            switch season {
                case Season.Summer: return tile_grassautotile_summer;
                case Season.Fall: return tile_grassautotile_autumn;
                case Season.Winter: return tile_grassautotile_winter;
            }
            break;

        case tile_main_exteriors_spring:
            switch season {
                case Season.Summer: return tile_main_exteriors_summer;
                case Season.Fall: return tile_main_exteriors_fall;
                case Season.Winter: return tile_main_exteriors_winter;
            }
            break;

        case tile_soil_spring:
            switch season {
                case Season.Summer: return tile_soil_summer;
                case Season.Fall: return tile_soil_autumn;
                case Season.Winter: return tile_soil_winter;
            }
            break;

        case tile_soil_wet_spring:
            switch season {
                case Season.Summer: return tile_soil_wet_summer;
                case Season.Fall: return tile_soil_wet_autumn;
                case Season.Winter: return tile_soil_wet_winter;
            }
            break;
    }

    return spring_tileset;
}

function process_asset_layer(layer_id, on_floor=false) {
    static LEN = string_length("Level_X");

    var layer_name = layer_get_name(layer_id);
    var elements = layer_get_all_assets(layer_id);
    var level_snip = string_copy(layer_name, 1, LEN);
    var level = real(string_digits(level_snip));
    var instances = List();
    for (var i = 0; i < array_length(elements); i++) {
        var element = elements[i];

        //
        var obj = obj_assetobject;
        var element_sprite = layer_asset_get(element, LayerAssetProperty.Sprite);

        //
        if CALENDAR.season() == Season.Winter && array_contains(ILLEGAL_WINTER_SPRITES, element_sprite) {
            layer_asset_destroy(element);
            continue;
        }

        //
        var spr_name = asset_to_string(element_sprite);
        var stripped = string_strip_digits(spr_name);
        if string_pos("door_spring_closed", stripped) != 0 {
            obj = obj_door;
        }

        //
        var inst = instance_create_layer(
            layer_asset_get(element, LayerAssetProperty.XPos),
            layer_asset_get(element, LayerAssetProperty.YPos),
            "Instances",
            obj,
            {
                sprite_index: element_sprite,
                image_xscale: layer_asset_get(element, LayerAssetProperty.XScale),
                image_yscale: layer_asset_get(element, LayerAssetProperty.YScale),
                image_speed:  layer_asset_get(element, LayerAssetProperty.ImageSpeed),
                image_angle: layer_asset_get(element, LayerAssetProperty.ImageAngle),
                depth_offset: layer_asset_get(element, LayerAssetProperty.DepthOffset),
                z: -level * room_height() * 2,
                original_blend: layer_asset_get(element, LayerAssetProperty.ImageBlend),
                on_floor,
            }
        );

        inst.from_room_service = true;

        instances.push(inst);

        //
        if inst.sprite_index == spr_beach_barn_door_spring_closed {
            inst.door_hides_on_open = false;
        }

        //
        if matches(element_sprite, spr_town_water_rock_1_spring, spr_town_water_rock_2_spring) {
            inst.image_index = random(sprite_get_number(element_sprite));
        } else {
            inst.image_index = layer_asset_get(element, LayerAssetProperty.ImageIndex);
        }

        //
        if obj == obj_door {
            inst.setup_floor_shadow();
        }

        if inst.sprite_index == spr_doorway_light_bottom || inst.sprite_index == spr_doorway_light_top {
            inst.image_alpha = .5;
            inst.image_blend = c_black;
        }
    }

    layer_set_visible(layer_id, false);

    return instances;
}

//
function process_other_collision_layer(location_id, name, boo=true) {
    var grid = GRIDS[location_id];

    var raw_tiles = room_data_read_tilemap(location_id_to_gm_room(location_id), format("Tiles_Collision_{}", name));
    for (var j = 0; j < array_length(raw_tiles); j++) {
        var val = ((raw_tiles[j] >> 32) & U32_MAX) == 2;
        var cell = raw_tiles[j] & U32_MAX;

        if boo {
            set_collision_on_node(
                grid,
                cell % grid.dims.x,
                cell div grid.dims.x,
                val,
            );
        } else {
            remove_collision_on_node(
                grid,
                cell % grid.dims.x,
                cell div grid.dims.x,
            );
        }
    }
}
