//
function enter_dungeon(start_floor=0, length=undefined, should_skip=false) {
    var itinerary = create_dungeon_itinerary(length);
    DUNGEON_RUNNER = new DungeonRunner(itinerary, start_floor);
    goto_gm_room(DUNGEON_RUNNER.current_level().gm_room, TEST_SUITE || should_skip);
}

//
function on_dungeon_enter() {
    //
    if GS_MINES_RUN == undefined {
        game_stats_mines_run();

        if ARI.invulnerable_hits > 0 && ARI.perk_active(Perk.GuardiansShield) {
            ARI.status_effects.register(
                StatusEffectId.GuardiansShield,
                undefined,
                CALENDAR.unified_time(),
                I32_MAX,
            );
        }
    }

    //
    GS_MINES_FLOOR = game_stats_current_mines_floor();
    GL_MINES_FLOOR_WRITTEN = false;
    build_dungeon_room(GRID);
    DUNGEON_RUNNER.on_room_start();

    if ARI.perk_active(Perk.MineTime) {
        var time = CALENDAR.unified_time();
        ARI.status_effects.register(
            StatusEffectId.MineTime,
            ARI.perk_value(Perk.MineTime),
            time,
            time + minutes(fiddle_get("perks/mine_time/duration_minutes")),
        );
    }

    tango_set_global_parameter("CaveReverb", 1.0);
}

//
function on_dungeon_exit() {
    game_stats_end_mines_run(DUNGEON_RUNNER.exit_mines_stats_condition ?? "elevator");
    DUNGEON_RUNNER = undefined;

    ARI.status_effects.cancel(StatusEffectId.GuardiansShield);

    var menu = ANCHOR.get_menu(Menu.Vitals);
    if menu != undefined
        && menu.element_visibility[VitalsElement.Health]
        && ARI.get_health() == ARI.get_max_health()
    {
        menu.hide_element(VitalsElement.Health, true);
    }

    tango_set_global_parameter("CaveReverb", 0.0);
}

function get_room_for_dungeon_floor(flr, impl, appearances) {
    var winning_room = undefined;
    var current_minimum = I32_MAX;
    var this_floor_range = ListFromArray(clone_value(DUNGEON.level_ranges[flr]));
    this_floor_range.shuffle();
    var requires_elevator = dungeon_level_contains_elevator(flr);

    for (var i = 0; i < this_floor_range.count(); i++) {
        var this_room = this_floor_range.get(i);
        var this_room_data = DUNGEON_ROOMS.get(this_room);
        var this_room_appearances = appearances == undefined
            ? 0
            : appearances.get_or(this_room, 0);
        if
            this_room_data.impls.contains(impl)
            && requires_elevator == this_room_data.contains_elevator
            && this_room_appearances < current_minimum
        {
            winning_room = this_room;
            current_minimum = this_room_appearances;
        }
    }

    if winning_room != undefined && appearances != undefined {
        appearances.set(winning_room, current_minimum + 1);
    }

    return winning_room;
}

//
function create_dungeon_itinerary(length) {
    length = length == undefined ? DUNGEON_FLOOR_COUNT : length;
    var biome_impl_votes = List();
    for (var i = 0; i < DungeonBiome.LEN; i++) {
        var votes = HistoricalVotes(
            fiddle_get("dungeons/misc/impl_dampening"),
            fiddle_get("dungeons/misc/impl_dampening_decay"),
        );

        for (var j = 0; j < DungeonImpl.LEN; j++) {
            var vote_count = fiddle_get(format("dungeons/level_kinds/{DungeonImpl}/{DungeonBiome}", j, i));
            votes.add_candidate(j, vote_count);
        }

        biome_impl_votes.push(votes);
    }

    var appearances = Map();

    //
    var itin = List();
    var can_select_arena = !ARI.has_seen_arena_level_today;
    for (var i = 0; i < length; i++) {
        var requires_elevator = dungeon_level_contains_elevator(i);
        var visual_index = i + 1; //
        var biome = floor_to_dungeon_biome(i);
        var this_floor_range = ListFromArray(clone_value(DUNGEON.level_ranges[i]));
        this_floor_range.shuffle();

        //
        var impl = undefined;
        if visual_index == 1 || visual_index == MAX_DUNGEON_FLOOR || requires_elevator {
            impl = DungeonImpl.Standard;
        } else {
            //
            impl = biome_impl_votes.get(biome).get_candidate(function(try_impl, this_floor_range, can_select_arena) {
                if try_impl == DungeonImpl.Enemy && !can_select_arena {
                    return false;
                }
                return this_floor_range.any(function(e, try_impl) {
                    return DUNGEON_ROOMS.get(e).impls.contains(try_impl);
                }, try_impl);
            }, [this_floor_range, can_select_arena]);
        }

        //
        //
        if impl == undefined {
            impl = DUNGEON_ROOMS.get(this_floor_range.choose_random()).impls.choose_random();
        }

        //
        //
        //
        var gm_room = get_room_for_dungeon_floor(i, impl, appearances);
        switch visual_index {
            case 20:
                impl = DungeonImpl.Standard;
                gm_room = rm_water_seal;
                biome = DungeonBiome.Upper;
                break;
            case 40:
                impl = DungeonImpl.Standard;
                gm_room = rm_earth_seal;
                biome = DungeonBiome.TideCaverns;
                break;
            case 60:
                impl = DungeonImpl.Standard;
                gm_room = rm_fire_seal;
                biome = DungeonBiome.DeepEarth;
                break;
            case 80:
                impl = DungeonImpl.Standard;
                gm_room = rm_ruins_seal;
                biome = DungeonBiome.Ruins;
                break;
            case 90:
                impl = DungeonImpl.Standard;
                gm_room = rm_priestess_quarters;
                biome = DungeonBiome.Ruins;
                break;
            case 100:
                impl = DungeonImpl.Standard;
                gm_room = rm_seridias_chamber;
                biome = DungeonBiome.Ruins;
                break;
            default: break;
        }
        assert_neq(gm_room, undefined, "Failed to get a room!");

        if impl == DungeonImpl.Enemy {
            can_select_arena = false;
        }

        itin.push({
            impl: impl,
            gm_room: gm_room,
            biome: biome,
        });
    }

    return itin;
}

#macro DUNGEON_TREASURE_CTX global.__dungeon_treasure_ctx
#macro DUNGEON_RITUAL_CTX global.__dungeon_ritual_ctx

//
//
function test_dungeon_itineraries() {
    ARI.has_seen_arena_level_today = false;

    static CHECK = function(itin, expect_them) {
        var treasure_count = itin.sum_with(function(v) {
            return v.impl == DungeonImpl.Treasure;
        });
        assert_eq(treasure_count, 0, "Treasure rooms should not appear directly in an itinerary!");

        var ritual_count = itin.sum_with(function(v) {
            return v.impl == DungeonImpl.Ritual;
        });
        assert_eq(ritual_count, 0, "Ritual rooms should not appear directly in an itinerary!");

        var arena_count = itin.sum_with(function(v) {
            return v.impl == DungeonImpl.Enemy;
        });
        assert(arena_count <= expect_them ? 1 : 0, "There should be a max of {} arena floors but we found {}!", expect_them ? 1 : 0, arena_count);
    }

    CHECK(create_dungeon_itinerary(), true);
    ARI.has_seen_arena_level_today = true;
    repeat 100 {
        CHECK(create_dungeon_itinerary(), false);
    }
}
