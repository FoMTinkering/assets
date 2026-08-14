#macro MAXIMUM_REACHED_DUNGEON_LEVEL global.__maximum_reached_dungeon_levels
global.__maximum_reached_dungeon_levels = 0

//
//
function DungeonRunner(itinerary, start_floor) constructor {
    self.itinerary = itinerary;
    self.last_floor = undefined;
    self.current_floor = start_floor;
    self.ladder_score_needed = 0;
    self.ladder_score = 0;
    self.finished_enemy_floor = EnemyFloorState.None;
    self.ladder_choice_options = [undefined, undefined];
    self.blocking_music = false;
    self.side_levels = array_create(DUNGEON_FLOOR_COUNT, undefined);
    self.previous_floors = array_bool(DUNGEON_FLOOR_COUNT);
    self.exit_mines_stats_condition = undefined;

    if !ARI.has_seen_treasure_level_today && ARI.perk_active(Perk.TreasureHunter) {
        var level = try_create_side_room(
            DungeonImpl.Treasure,
            start_floor,
            fiddle_get("dungeons/misc/treasure_range"),
        );
        if level != undefined {
            self.side_levels[level.index] = level;
        }
    }

    if !ARI.has_seen_ritual_level_today && ARI.perk_active(Perk.LostToHistory) {
        var level = try_create_side_room(
            DungeonImpl.Ritual,
            start_floor,
            fiddle_get("dungeons/misc/ritual_range") * ARI.perk_value(Perk.LostToHistoryTwo),
        );
        if level != undefined {
            self.side_levels[level.index] = level;
        }
    }

    //
    function current_level() {
        return self.level(self.current_floor);
    }

    //
    function level(value) {
        if self.side_levels[value] != undefined && !self.previous_floors[value] {
            return self.side_levels[value];
        } else {
            return self.itinerary.get(value);
        }
    }

    //
    //
    function proceed(end_floor_kind, skip_transition=false) {
        var level = self.current_level();

        var next_level = undefined;
        if level[$ "is_side_room"] == true {
            next_level = self.itinerary.get(self.current_floor);
        } else {
            //
            //
            if self.current_floor + 1 >= self.itinerary.count() {
                return;
            }

            next_level = self.level(self.current_floor + 1);
        }

        var itin = goto_gm_room(next_level.gm_room, TEST_SUITE || skip_transition);
        itin.mines = end_floor_kind;
    }

    //
    function post_proceed(end_floor_kind) {
        self.last_floor = self.current_floor;
        self.previous_floors[self.current_floor] = true;
        game_stats_end_mines_floor(end_floor_kind);

        //
        if self.side_levels[self.current_floor] != undefined {
            self.side_levels[self.current_floor] = undefined;
        } else {
            self.current_floor += 1;
        }
    }

    //
    function jump_to(index) {
        self.last_floor = self.current_floor;
        self.current_floor = index;
        goto_gm_room(self.current_level().gm_room);
    }

    //
    function on_room_start() {
        GS_MINES_FLOOR.room_name = asset_to_string(self.current_level().gm_room);
        GS_MINES_FLOOR.current_floor = self.current_floor + 1;
        GS_MINES_FLOOR.health_on_floor_enter = ARI.get_health();
        GS_MINES_FLOOR.stamina_on_floor_enter = ARI.get_stamina();
        GS_MINES_FLOOR_WRITTEN = false;

        DUNGEON_RUNNER.blocking_music = false; //

        var tutorial_chain = new_chain().append(LinkId.Timer, 30);

        if !ARI.tutorials_seen[Tutorial.Mines] && !MIST.is_running() {
            await_popup(spawn_tutorial, [Tutorial.Mines], tutorial_chain);
        }

        if !ARI.tutorials_seen[Tutorial.LavaCaves] && is_between_inclusive(self.current_floor, 60, 78) {
            await_popup(spawn_tutorial, [Tutorial.LavaCaves], tutorial_chain);
        }

        if !ARI.tutorials_seen[Tutorial.DarkMines] && !MIST.is_running() && in_dark_mines() {
            await_popup(spawn_tutorial, [Tutorial.DarkMines], tutorial_chain);
        }

        if self.current_floor == 9 && self.current_floor > MAXIMUM_REACHED_DUNGEON_LEVEL {
            play_conversation_from_path(NpcId.Seridia, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.MinesFloorTen]);
            self.blocking_music = true;
            MUSIC_PLAYER.refresh();
            TANGO.play("SoundEffects/SpecialEvents/CaldarusAppear");
            new_chain()
                .append(LinkId.Await, function() {
                    return ANCHOR.get_menu(Menu.Textbox) == undefined;
                })
                .append(LinkId.Timer, 30)
                .append(LinkId.Function, function() {
                    self.blocking_music = false;
                    MUSIC_PLAYER.refresh();
                })
        }

        MAXIMUM_REACHED_DUNGEON_LEVEL = max(
            MAXIMUM_REACHED_DUNGEON_LEVEL,
            self.current_floor,
        );

        switch self.current_level().impl {
            case DungeonImpl.Treasure:
                ARI.has_seen_treasure_level_today = true;
                break;
            case DungeonImpl.Ritual:
                ARI.has_seen_ritual_level_today = true;
                break;
            case DungeonImpl.Enemy:
                ARI.has_seen_arena_level_today = true;
                break;
            default: break;
        }

        if is_special_dungeon_room(room()) {
            return;
        }

        static MONSTER_POINTS = fiddle_get("misc/dungeon_monster_element_points");
        static OBJECT_POINTS = fiddle_get("misc/dungeon_object_element_points");

        var total_monsters = instance_number(par_monster);
        var total_objects = 0;
        if self.current_level().impl != DungeonImpl.Enemy {
            with obj_node_renderer {
                //
                total_objects += self.node[$ "ladder_candidate"] ?? 0;
            }
        }
        var total_possible_score = (total_monsters * DUNGEON.biomes[DUNGEON_BIOME].monster_element_points)
            + (total_objects * DUNGEON.biomes[DUNGEON_BIOME].object_element_points);
        var chance_range = DUNGEON.biomes[DUNGEON_BIOME].ladder_chance_range;

        if self.current_level().impl == DungeonImpl.Enemy {
            self.ladder_score_needed = total_possible_score;
            self.finished_enemy_floor = EnemyFloorState.OnGoing;
            self.blocking_music = true;

            //
            //
            var chest = GRID.write_node((obj_dungeon_ladder_down.x div 8) + 4, obj_dungeon_ladder_down.y div 8, choose(ObjectId.TreasureChestGold, ObjectId.TreasureChestSilver));
            chest.renderer.sprite_index = chest.prototype.chest.opening_sprite;
            chest.renderer.image_index = sprite_get_number(chest.renderer.sprite_index) - 1;
            chest.renderer.image_speed = 0;

            chest.is_locked = true;
            obj_dungeon_ladder_down.linked_chest = chest;
            obj_dungeon_ladder_down.image_index = obj_dungeon_ladder_down.image_number - 1;

            if !TEST_SUITE {
                MIST.place_on_runtime_blackboard("ladder_x", obj_dungeon_ladder_down.x);
                MIST.place_on_runtime_blackboard("ladder_y", obj_dungeon_ladder_down.y);
                MIST.run_scene("arena");
            }
        } else {
            self.finished_enemy_floor = EnemyFloorState.None;
            self.ladder_score_needed = ceil(total_possible_score * random_range(chance_range[0], chance_range[1]));
        }
        self.ladder_score = 0;

        //
        if DEBUG_ASSERTIONS {
            assert_neq(self.ladder_score_needed, 0, "There are no instances or enemies in mines room {}; ensure there are spawnable locations", asset_to_string(room()));
        }

        if self.current_level().impl == DungeonImpl.LadderChoice {
            var next_level = self.itinerary.get(self.current_floor + 1);
            var room_data = DUNGEON_ROOMS.get(next_level.gm_room);
            self.ladder_choice_options = [
                room_data.impls.choose_random(),
                room_data.impls.choose_random(),
            ];
        }
    }

    //
    function on_monster_destroy(xx, yy) {
        self.ladder_score += DUNGEON.biomes[DUNGEON_BIOME].monster_element_points;
        self.check_ladder_score(xx, yy);
    }

    //
    function on_object_destroy(xx, yy) {
        self.ladder_score += DUNGEON.biomes[DUNGEON_BIOME].object_element_points;
        self.check_ladder_score(xx, yy);
    }

    //
    function check_ladder_score(x_pos, y_pos) {
        if instance_exists(obj_dungeon_ladder_down) {
            return;
        }

        if self.ladder_score >= self.ladder_score_needed {
            self.spawn_ladder(x_pos, y_pos);
        }
    }

    //
    function spawn_ladder(x_pos, y_pos) {
        TANGO.play("SoundEffects/Entrances/ExitReveal", x_pos * 8, y_pos * 8);
        var pos = find_free_position_spiral(x_pos, y_pos, function(x_pos, y_pos) {
            for (var i = 0; i < 2; i++) {
                for (var j = 0; j < 2; j++) {
                    var ni = GRID.try_node_index_for_cell(x_pos + i, y_pos + j);
                    if ni == undefined
                        || GRID.node_object_id[ni] != undefined
                        || GRID.node_collideable[ni]
                        || GRID.node_terrain_kind[ni] != TerrainKind.Ground
                    {
                        return false;
                    }
                }
            }
            return true;
        });
        assert_neq(pos, undefined, "Failed to spawn a ladder in the dungeon!");
        var ladder = instance_create_depth(pos.x * 8, pos.y * 8, 0, obj_dungeon_ladder_down);
        ladder.state = LadderState.TrapdoorOpening;
        ladder.dungeon_init();
        static BUNDLE = new ParticleDustBundle().set_gravity_increase(0);
        repeat BUNDLE.get_instances() {
            create_debris(
                (pos.x * 8) + BUNDLE.get_x_offset(),
                (pos.y * 8) + BUNDLE.get_y_offset(),
                ladder.depth - 1,
                spr_part_rundirt,
                BUNDLE
            );
        }
    }
}

function try_create_side_room(impl, start_floor, range) {
    var floor = irandom_range(start_floor, start_floor + range);
    if floor >= 100 {
        return undefined;
    }

    var rm = get_room_for_dungeon_floor(floor, impl);
    if rm != undefined {
        return {
            index: floor,
            gm_room: rm,
            biome: floor_to_dungeon_biome(floor),
            impl: impl,
            is_side_room: true,
        };
    }
}

function in_dark_mines() {
    if room() == rm_priestess_quarters {
        return true;
    }

    return is_dungeon_room(room())
        && !is_special_dungeon_room(room())
        && DUNGEON_RUNNER != undefined
        && DUNGEON_RUNNER.current_floor >= 80;
}

enum EnemyFloorState {
    None,
    OnGoing,
    Finished,
}
