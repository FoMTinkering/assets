#macro MAP_HUBS global.__map_hubs
MAP_HUBS = undefined;

function load_map_hubs() {
    var out = array_create(LocationId.LEN, undefined);
    for (var i = 0; i < LocationId.LEN; i++) {
        if i == LocationId.Dungeon {
            continue;
        }

        var room_id = location_id_to_gm_room(i);
        var raw_hubs = map_hubs_in(room_id);
        var these_hubs = [];
        for (var j = 0; j < array_length(raw_hubs); j++) {
            var raw_hub = raw_hubs[j];
            var locations = [];
            for (var k = 0; k < array_length(raw_hub.locations); k++) {
                array_push(locations, string_to_location_id(raw_hub.locations[k]));
            }

            array_push(these_hubs, {
                type: array_is_empty(locations) ? MapHub.Position : MapHub.Locations,
                x: raw_hub.x,
                y: raw_hub.y,
                asset_x: raw_hub.asset_x,
                asset_y: raw_hub.asset_y,
                locations,
            });
        }

        out[i] = these_hubs;
    }

    return out;
}

#macro ARI_MAP_SIGNUM 99999
#macro PET_MAP_SIGNUM 11111
#macro CHILD_0_MAP_SIGNUM 22222
#macro CHILD_1_MAP_SIGNUM 33333

function MapMenu() : AnchorMenu(Menu.Map) constructor {
    //
    //
    function select_location(location_id) {
        //
        if self.selected_location_id != undefined {
            var node = self.tab_nodes.get(self.selected_location_id);
            node.set_z(JournalDepth.MapUnselectedTab);
            node.set_y(-3);
            var icon = node.board_get("icon");
            icon.set_alpha(0.5);
            icon.set_z(node.get_z() - 1);
        }
        ANCHOR.free_children(self.map);

        //
        location_id = LOCATIONS[location_id].map_location;
        var true_location = LOCATIONS[location_id];
        self.selected_location_id = location_id;

        //
        var node = self.tab_nodes.get(location_id);
        node.set_z(JournalDepth.SelectedTab);
        node.set_y(-8);
        var icon = node.board_get("icon");
        icon.set_z(node.get_z() - 1);
        icon.set_alpha(1);

        var map_sprite = string_to_asset(fmt("spr_ui_map_{LocationId}", location_id));

        if location_id == LocationId.Farm && FARM_EXPANDED {
            map_sprite = spr_ui_map_farm_expansion;
        }

        if location_id == LocationId.DeepWoods && !world_mod_enabled(WorldMod.ThornyStairs) {
            self.map.set_sprite(spr_ui_map_locked);
        } else {
            self.map.set_sprite(map_sprite);
        }


        var loc_name = location_id == LocationId.Farm ? ARI.farm_name : local_get(true_location.name);
        draw_set_font(ANCHOR.get_text_font());
        var width = string_width(loc_name);
        width += 8;

        self.name_backplate.set_width(width);
        self.name.set_text(loc_name);

        var hubs = MAP_HUBS[location_id];
        for (var i = 0; i < array_length(hubs); i++) {
            var hub = hubs[i];
            hub.node = ANCHOR.positional(self.map)
                .set_xy(hub.asset_x, hub.asset_y)
        }

        //
        var sorting_prio_queue = ds_priority_create();
        var npc_to_hub = Map();
        for (var i = 0; i < NpcId.LEN; i++) {
            if !npc_is_unlocked(i) {
                continue;
            }

            var npc = NPCS[i];
            var winning_hub = self.find_hub_for(hubs, npc.location_position, sorting_prio_queue, location_id);
            if winning_hub != 0 {
                npc_to_hub.set(i, winning_hub);
            }
        }

        var winning_hub = self.find_hub_for(
            hubs,
            new LocationPosition(CURRENT_LOCATION_ID, Vec2(obj_ari.x, obj_ari.y), CURRENT_DYN_INDEX),
            sorting_prio_queue,
            location_id,
        );
        if winning_hub != 0 {
            npc_to_hub.set(ARI_MAP_SIGNUM, winning_hub);
        }

        if PET.unlocked() {
            var position = Vec2Zero();
            if PET.job_active && PET.job != PetJob.None {
                var job_setup_data = PET_PROTOTYPE.job_setup_data[PET.job];
                position.x = job_setup_data.pet_position.x;
                position.y = job_setup_data.pet_position.y;
            } else if PET.location_id == LocationId.Farm {
                //
                //
                //
                //
                position.x = 600;
                position.y = 400;
            } else if instance_exists(obj_pet) {
                position.x = obj_pet.x;
                position.y = obj_pet.y;
            }

            var winning_hub = self.find_hub_for(
                hubs,
                new LocationPosition(PET.location_id, position),
                sorting_prio_queue,
                location_id,
            );
            if winning_hub != 0 {
                npc_to_hub.set(PET_MAP_SIGNUM, winning_hub);
            }
        }

        var child_sigs = [CHILD_0_MAP_SIGNUM, CHILD_1_MAP_SIGNUM];
        for (var i = 0; i < array_length(ARI.children); i++) {
            var child = ARI.children[i];
            if child != undefined {
                var loc_pos = undefined;
                switch child.location {
                    case ChildLocation.WithAri:
                        loc_pos = new LocationPosition(CURRENT_LOCATION_ID, Vec2(obj_ari.x, obj_ari.y), CURRENT_DYN_INDEX);
                        break;
                    case ChildLocation.InCradle:
                        var cradle = find_cradle();
                        loc_pos = new LocationPosition(cradle.location_id, Vec2Zero());
                        break;
                    case ChildLocation.WithSpouse:
                        loc_pos = NPCS[ARI.spouse()].location_position;
                        break;
                }

                var winning_hub = self.find_hub_for(
                    hubs,
                    loc_pos,
                    sorting_prio_queue,
                    location_id,
                );
                if winning_hub != 0 {
                    npc_to_hub.set(child_sigs[i], winning_hub);
                }
            }
        }

        ds_priority_destroy(sorting_prio_queue);

        //
        //
        //
        //
        for (var i = 0; i < array_length(hubs); i++) {
            var hub = hubs[i];
            var residents = [];
            var ids = npc_to_hub.keys();
            for (var j = 0; j < array_length(ids); j++) {
                if npc_to_hub.get(ids[j]) == hub {
                    array_push(residents, real(ids[j]));
                }
            }

            var count = array_length(residents);
            var box_size = ceil(sqrt(count));
            var slot_width = 11;
            var slot_height = 11;
            var xx = -((slot_width / 2) * box_size);
            var yy = -((slot_height / 2) * ceil(count / box_size));
            var iter = 0;
            for (var j = 0; j < box_size && iter < count; j++) {
                for (var k = 0; k < box_size && iter < count; k++) {
                    var resident = real(residents[iter]);
                    var node = ANCHOR.sprite(hub.node)
                    var unknown_icon = matches(resident, NpcId.Dozy, NpcId.Henrietta)
                        ? spr_ui_generic_animal_name_icon
                        : spr_ui_generic_icon_npc_small_unknown;
                    var icon;
                    if resident == ARI_MAP_SIGNUM {
                        icon = spr_ui_generic_icon_npc_small_player;
                    } else if resident == PET_MAP_SIGNUM {
                        icon = PET_PROTOTYPE.variants.get(PET.variant).map_icon;
                    } else if resident == CHILD_0_MAP_SIGNUM {
                        icon = ARI.children[0].get_small_icon();
                    } else if resident == CHILD_1_MAP_SIGNUM {
                        icon = ARI.children[1].get_small_icon();
                    } else {
                        icon = NPCS[resident].has_met()
                            ? get_small_npc_icon(resident)
                            : unknown_icon;
                    }
                    node
                        .set_sprite(icon)
                        .set_xy(xx, yy)
                        .set_speed(1)
                    xx += slot_width;
                    iter += 1;
                }
                xx = -((slot_width / 2) * min(box_size, count - iter));
                yy += slot_height;
            }
        }
    }

    function find_hub_for(hubs, location_position, sorting_prio_queue, location_id) {
        for (var j = 0; j < array_length(hubs); j++) {
            var hub = hubs[j];
            switch hub.type {
                case MapHub.Position:
                    if location_position.location_id == location_id {
                        var prox = point_distance(
                            hub.x,
                            hub.y,
                            location_position.pos.x,
                            location_position.pos.y,
                        );
                        ds_priority_add(sorting_prio_queue, hub, -prox);
                    }
                    break;
                case MapHub.Locations:
                    for (var k = 0; k < array_length(hub.locations); k++) {
                        if location_position.location_id == hub.locations[k] {
                            ds_priority_add(sorting_prio_queue, hub, 0);
                            break;
                        }
                    }
                    break;
                default: impossible("Unexpected MapHub: {}", hub.type);
            }
        }
        var val = ds_priority_delete_max(sorting_prio_queue);
        ds_priority_clear(sorting_prio_queue);
        return val;
    }

    self.journal = ANCHOR.get_menu(Menu.Journal);
    self.selected_location_id = undefined;
    self.tab_nodes = Map();
    self.location_neighbors = Map();
    self.location_neighbors.insert(LocationId.Farm, {
        north: LocationId.Town,
        south: undefined,
        west: LocationId.HaydensFarm,
        east: undefined,
    });
    self.location_neighbors.insert(LocationId.Town, {
        north: undefined,
        south: LocationId.Farm,
        west: LocationId.Narrows,
        east: LocationId.EasternRoad,
    });
    self.location_neighbors.insert(LocationId.Narrows, {
        north:LocationId.Summit,
        south: LocationId.HaydensFarm,
        west: LocationId.WesternRuins,
        east: LocationId.Town,
    });
    self.location_neighbors.insert(LocationId.HaydensFarm, {
        north: LocationId.Narrows,
        south: LocationId.Beach,
        west: undefined,
        east: LocationId.Farm,
    });
    self.location_neighbors.insert(LocationId.Beach, {
        north: LocationId.HaydensFarm,
        south: undefined,
        west: undefined,
        east: undefined,
    });
    self.location_neighbors.insert(LocationId.WesternRuins, {
        north: undefined,
        south: undefined,
        west: undefined,
        east: LocationId.Narrows,
    });
    self.location_neighbors.insert(LocationId.Summit, {
        north: undefined,
        south: LocationId.Narrows,
        west: undefined,
        east: undefined,
    });
    self.location_neighbors.insert(LocationId.EasternRoad, {
        north: LocationId.DeepWoods,
        south: undefined,
        west: LocationId.Town,
        east: undefined,
    });

    var has_glade = world_mod_enabled(WorldMod.DragonswornGlade);

    self.location_neighbors.insert(LocationId.DeepWoods, {
        north: has_glade ? LocationId.DragonswornGlade : undefined,
        south: LocationId.EasternRoad,
        west: undefined,
        east: undefined,
    });

    if has_glade {
        self.location_neighbors.insert(LocationId.DragonswornGlade, {
            north: undefined,
            south: LocationId.DeepWoods,
            west: undefined,
            east: undefined,
        });
    }

    var xx = 20;
    var tabs = array_map(self.data.tab_order, string_to_location_id);
    for (var i = 0; i < array_length(tabs); i++) {
        var location_id = tabs[i];

        if location_id == LocationId.DragonswornGlade && !world_mod_enabled(WorldMod.DragonswornGlade) {
            continue;
        }

        var sprite = string_to_asset(fmt("spr_ui_map_tab_icon_{LocationId}", location_id));
        var tab = ANCHOR.sprite(self.journal.left_page)
            .set_position(xx, -3, JournalDepth.MapUnselectedTab)
            .set_sprites_from_key("spr_ui_map_tab")
            .set_tap_callback(function(location_id) {
                self.select_location(location_id);
            }, [location_id])
            .set_selected_getter(function(location_id) {
                return self.selected_location_id == location_id;
            }, [location_id]);


        self.tab_nodes.insert(location_id, tab);

        var icon = ANCHOR.sprite(tab, JournalDepth.MapUnselectedTab - 1)
            .set_sprite(sprite)
            .set_align(Align.Center, Align.Middle)
            .set_alpha(0.5)

        tab.board_set("icon", icon);
        xx += sprite_get_width(spr_ui_map_tab_disabled) - 1;
    }

    self.grid = ANCHOR.sprite(self.journal.left_page)
        .set_sprite(spr_ui_map_grid)
        .set_position(8, 8, JournalDepth.MapGrid)

    self.map = ANCHOR.sprite(self.grid)
        .set_xy(12, 12)

    self.north_arrow = ANCHOR.sprite(self.grid)
        .set_y(14)
        .set_z(JournalDepth.MapArrows)
        .set_align(Align.Center, Align.TopIn)
        .set_sprites_from_key("spr_ui_map_arrow_up")
        .set_tap_callback(function() {
            var target = self.location_neighbors.get(self.selected_location_id).north;
            if target != undefined {
                self.select_location(target);
            }
        })
        .set_think_callback(function() {
            if !self.journal.canvas.is_unlocked() {
                return;
            }
            var unlocked = self.location_neighbors.get(self.selected_location_id).north != undefined;
            self.north_arrow.set_unlocked(unlocked);
            self.north_arrow.set_alpha(unlocked ? 1 : 0);
            if unlocked {
                self.north_arrow.set_y(14 + sin(current_time() / 150))
                if INPUT.take_press(InputId.Up) {
                    ANCHOR.tap_node(self.north_arrow);
                }
            }
        })

    self.south_arrow = ANCHOR.sprite(self.grid)
        .set_y(-14)
        .set_z(JournalDepth.MapArrows)
        .set_align(Align.Center, Align.BottomIn)
        .set_sprites_from_key("spr_ui_map_arrow_down")
        .set_tap_callback(function() {
            var target = self.location_neighbors.get(self.selected_location_id).south;
            if target != undefined {
                self.select_location(target);
            }
        })
        .set_think_callback(function() {
            if !self.journal.canvas.is_unlocked() {
                return;
            }
            var unlocked = self.location_neighbors.get(self.selected_location_id).south != undefined;
            self.south_arrow.set_unlocked(unlocked);
            self.south_arrow.set_alpha(unlocked ? 1 : 0);
            if unlocked {
                self.south_arrow.set_y(-14 + -sin(current_time() / 150))
                if INPUT.take_press(InputId.Down) {
                    ANCHOR.tap_node(self.south_arrow);
                }
            }
        })

    self.west_arrow = ANCHOR.sprite(self.grid)
        .set_x(14)
        .set_z(JournalDepth.MapArrows)
        .set_align(Align.LeftIn, Align.Middle)
        .set_sprites_from_key("spr_ui_map_arrow_left")
        .set_tap_callback(function() {
            var target = self.location_neighbors.get(self.selected_location_id).west;
            if target != undefined {
                self.select_location(target);
            }
        })
        .set_think_callback(function() {
            if !self.journal.canvas.is_unlocked() {
                return;
            }
            var unlocked = self.location_neighbors.get(self.selected_location_id).west != undefined;
            self.west_arrow.set_unlocked(unlocked);
            self.west_arrow.set_alpha(unlocked ? 1 : 0);
            if unlocked {
                self.west_arrow.set_x(14 + -sin(current_time() / 150));
                if INPUT.take_press(InputId.Left) {
                    ANCHOR.tap_node(self.west_arrow);
                }
            }
        })

    self.east_arrow = ANCHOR.sprite(self.grid)
        .set_x(-14)
        .set_z(JournalDepth.MapArrows)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprites_from_key("spr_ui_map_arrow_right")
        .set_tap_callback(function() {
            var target = self.location_neighbors.get(self.selected_location_id).east;
            if target != undefined {
                self.select_location(target);
            }
        })
        .set_think_callback(function() {
            if !self.journal.canvas.is_unlocked() {
                return;
            }
            var unlocked = self.location_neighbors.get(self.selected_location_id).east != undefined;
            self.east_arrow.set_unlocked(unlocked);
            self.east_arrow.set_alpha(unlocked ? 1 : 0);
            if unlocked {
                self.east_arrow.set_x(-14 + sin(current_time() / 150))
                if INPUT.take_press(InputId.Right) {
                    ANCHOR.tap_node(self.east_arrow);
                }
            }
        })

    self.name_backplate = ANCHOR.positional(self.grid)
        .set_height(17)
        .set_xy(12, 12)
        .set_z(JournalDepth.MapName)

    self.name = ANCHOR.text(self.name_backplate)
        .set_align(Align.Center, Align.Middle)

    self.select_location(TAXI.current_location_id());
}

enum MapHub {
    Position,
    Locations,
}
