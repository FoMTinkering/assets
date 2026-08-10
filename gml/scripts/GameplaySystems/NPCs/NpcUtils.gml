//
//
function find_npc_at_or_approaching(location_position, npc_to_ignore) {
    for (var i = 0; i < NpcId.LEN; i++) {
        if DEBUG_TOOLS && !NPC_WHITELIST[i] {
            continue;
        }

        if npc_to_ignore == i {
            continue;
        }
        var npc = NPCS[i];
        var currently_present = npc.location_position.eq(location_position);
        var approaching =
            npc.itinerary != undefined
            && npc.itinerary.items.last().target_location.eq(location_position);
        var brain_order =
            npc.brain.blackboard.get("next_location") != undefined
            && npc.brain.blackboard.get("next_location").eq(location_position);
        if currently_present || approaching || brain_order {
            return i;
        }
    }
    return undefined;
}

//
//
function npcs_enter_pause_animations(conversation) {
    //
    with par_NPC {
        //
        self.restore_animation = undefined;
        self.restore_cardinality = undefined;

        if conversation != undefined && T2R.npc_is_speaker_in_conversation(conversation, self.npc_id) {
            //
            if self.animator.sprite_pack_collection.on_pause_speaking != undefined {
                self.restore_animation = self.me.animation;
                self.me.set_animation(self.animator.sprite_pack_collection.on_pause_speaking);
            }

            //
            if self.animator.sprite_pack_collection.on_pause_speaking_turn
                && T2R.conversation_is_group(conversation) == false
            {
                //
                self.restore_cardinality = self.animator.cardinality;
                self.me.set_cardinality(angle_to_cardinal(point_direction(self.x, self.y, obj_ari.x, obj_ari.y)));
            }
        } else if self.animator.sprite_pack_collection.on_pause_background != undefined {
            self.restore_animation = self.me.animation;
            self.me.set_animation(self.animator.sprite_pack_collection.on_pause_background);
        }

        self.animate();
    }
}

function npcs_exit_pause_animations() {
    with par_NPC {
        if self.restore_animation != undefined {
            self.me.set_animation(self.restore_animation);
        }

        if self.restore_cardinality != undefined {
            self.me.set_cardinality(self.restore_cardinality);
        }

        self.restore_cardinality = undefined;
        self.restore_animation = undefined;

        self.animate();
    }
}

function get_small_npc_icon(npc_id) {
    if npc_id == NpcId.Seridia {
        return npc_is_unlocked(npc_id)
            ? spr_ui_generic_icon_npc_small_seridia
            : spr_ui_generic_icon_npc_small_priestess;
    } else {
        return NPC_PROTOTYPES[npc_id].small_icon_sprite;
    }
}

function get_small_outlined_npc_icon(npc_id) {
    if npc_id == NpcId.Seridia {
        return npc_is_unlocked(npc_id)
            ? spr_ui_generic_icon_npc_small_outline_seridia
            : spr_ui_generic_icon_npc_small_outline_priestess;
    } else {
        return NPC_PROTOTYPES[npc_id].small_outlined_icon_sprite;
    }
}

function get_npc_icon(npc_id) {
    if npc_id == NpcId.Seridia {
        return npc_is_unlocked(npc_id)
            ? spr_ui_generic_icon_npc_seridia
            : spr_ui_generic_icon_npc_priestess;
    } else {
        return NPC_PROTOTYPES[npc_id].icon_sprite;
    }
}

function most_special_human() {
    return ListFromArray([
            NpcId.Adeline,
            NpcId.Celine,
            NpcId.Balor,
            NpcId.Eiland,
            NpcId.Hayden,
            NpcId.March,
            NpcId.Juniper,
            NpcId.Reina,
            NpcId.Ryis,
            NpcId.Valen,
        ])
        .sort_with(function(a, b) {
            var ap = NPCS[a];
            var bp = NPCS[b];

            if ap.is_spouse() != bp.is_spouse() {
                return ap.is_spouse() ? -1 : 1;
            }

            if ap.is_fiance() != bp.is_fiance() {
                return ap.is_fiance() ? -1 : 1;
            }

            if ap.is_dating() != bp.is_dating() {
                return ap.is_dating() ? -1 : 1;
            }

            if ap.is_best_friend() != bp.is_best_friend() {
                return ap.is_best_friend() ? -1 : 1;
            }

            if ap.heart_points == bp.heart_points {
                return 0;
            } else {
                return ap.heart_points > bp.heart_points ? -1 : 1;
            }

        })
        .first();
}

//
//
function spouse_wake_position() {
    var p_bed = player_bed();

    if p_bed != undefined {
        var node = GRIDS[p_bed.location_id].node_parent[p_bed.ni];
        var offset = bed_sleep_offset(node.object_id, true);
        return new LocationPosition(
            p_bed.location_id,
            Vec2(node.top_left_x * 8 + offset.x, node.top_left_y * 8 + offset.y),
        );
    }

    warn("Couldn't find any bed for spouse! Using a random position...");
    return new LocationPosition(
        LocationId.PlayerHome,
        player_home_random_position(LocationId.PlayerHome),
    );
}

//
//
function roommate_home_position(npc) {
    var player_wake = player_wake_position();
    return LocationPosition(
        player_wake.location_id,
        player_home_random_position(player_wake.location_id),
    );
}

//
function roommate_to_sleep(npc) {
    npc.talk_flag = false;

    if npc.is_spouse() {
        npc.location_position = spouse_wake_position();
    } else {
        npc.location_position = roommate_home_position();
    }

    if npc.is_spouse() {
        npc.set_animation("sleep");
        npc.set_cardinality(Cardinal.West);
        return;
    }

    //
    var animation = undefined;
    switch npc.id {
        case NpcId.Dozy:
            animation = choose("sleep_1", "sleep_2");
            break;
        case NpcId.Henrietta:
            animation = "sleep";
            break;
        default: impossible("Unexpected NpcId: {NpcId}", npc.id);
    }
    npc.set_animation(animation);
}

//
function test_most_special_human() {
    var original = array_create_ext(NpcId.LEN, function(i) {
        return [NPCS[i].heart_points, T2R.read(format("{NpcId}_status", i))];
    });

    static RESET = function() {
        for (var i = 0; i < NpcId.LEN; i++) {
            T2R.write(format("{NpcId}_status", i), undefined);
            NPCS[i].heart_points = 0;
        }
    }

    static SET = function(npc, hearts, status) {
        NPCS[npc].heart_points = hearts;
        T2R.write(format("{NpcId}_status", npc), status ?? "undefined");
    }

    RESET();
    SET(NpcId.Adeline, 10);
    SET(NpcId.Eiland, 0, "best_friend");
    assert_eq(most_special_human(), NpcId.Eiland);

    RESET();
    SET(NpcId.Adeline, 10, "best_friend");
    SET(NpcId.Eiland, 0, "best_friend");
    assert_eq(most_special_human(), NpcId.Adeline);

    RESET();
    SET(NpcId.Adeline, 0, "best_friend");
    SET(NpcId.Eiland, 0, "dating");
    assert_eq(most_special_human(), NpcId.Eiland);

    RESET();
    SET(NpcId.Adeline, 5, "dating");
    SET(NpcId.Eiland, 8, "best_friend");
    SET(NpcId.Valen, 10);
    SET(NpcId.Juniper, 6, "dating");
    assert_eq(most_special_human(), NpcId.Juniper);

    RESET();
    SET(NpcId.Caldarus, 10, "dating");
    SET(NpcId.Adeline, 1);
    assert_eq(most_special_human(), NpcId.Adeline);

    RESET();
    SET(NpcId.Adeline, 5, "dating");
    SET(NpcId.Eiland, 1, "spouse");
    assert_eq(most_special_human(), NpcId.Eiland);

    for (var i = 0; i < NpcId.LEN; i++) {
        T2R.write(format("{NpcId}_status", i), original[i][1]);
        NPCS[i].heart_points = original[i][0];
    }
}

function fade_value(obj, value, start, target, len) {
    obj[$ value] = start;
    new_chain().append(LinkId.Ease, new Ease(EaseId.Linear, start, target, len), function(_, a, inst, value) {
        var early_exit = is_struct(inst) ? false : !instance_exists(inst);
        if early_exit {
            return;
        }
        inst[$ value] = a;
    }, [obj, value])
}

function wedding_party_for(spouse) {
    var designated = fiddle_get(format("spouse/wedding_parties/{NpcId}", spouse));

    var all_npcs = ListFromArray(array_create_ext(NpcId.LEN, identity))
        .retain(function(npc, spouse) {
            if matches(npc, spouse, NpcId.Elsie, NpcId.Dozy, NpcId.Henrietta) {
                return false;
            }

            if array_has(NPC_PROTOTYPES[npc].tags, "vendor") {
                return false;
            }
            if !npc_is_unlocked(npc) {
                return false;
            }

            if npc == NpcId.Caldarus && T2R.read("caldarus_seridia_town") != true {
                return false;
            }

            return true;
        }, spouse)
        .map(npc_id_to_string);

        all_npcs.sort_with(function(a, b) {
            var ap = NPCS[string_to_npc_id(a)];
            var bp = NPCS[string_to_npc_id(b)];

            if ap.is_best_friend() != bp.is_best_friend() {
                return ap.is_best_friend() ? -1 : 1;
            }

        if ap.heart_points == bp.heart_points {
            return 0;
        } else {
            return ap.heart_points > bp.heart_points ? -1 : 1;
        }
    });
    all_npcs.set_reverse(); //

    var ceremony_available = all_npcs.clone();
    var reception_available = all_npcs.clone();

    var spouse = npc_id_to_string(spouse);
    var ceremony = { spouse };
    var reception = { spouse };

    //
    ceremony.spouse_party_0 = designated.spouse_party_0;
    var index = ceremony_available.find_lazy(ceremony.spouse_party_0);
    if index != undefined {
        ceremony_available.remove(index);
    }
    ceremony.spouse_party_1 = designated.spouse_party_1;
    var index = ceremony_available.find_lazy(ceremony.spouse_party_1);
    if index != undefined {
        ceremony_available.remove(index);
    }

    //
    ceremony.ari_party_0 = ceremony_available.pop();
    ceremony.ari_party_1 = ceremony_available.pop();

    static CEREMONY_SEATS_TO_FILL = [
        "priority_0",
        "priority_1",
        "priority_2",
        "priority_3",
        "priority_4",
        "priority_5",
        "priority_6",
        "priority_7",
        "standard_0",
        "standard_1",
        "standard_2",
        "standard_3",
        "standard_4",
        "standard_5",
        "standard_6",
        "standard_7",
        "standard_8",
        "standard_9",
        "extra_0",
        "extra_1",
    ];

    //
    for (var i = 0; i < array_length(CEREMONY_SEATS_TO_FILL); i++) {
        var key = CEREMONY_SEATS_TO_FILL[i];
        var selection = undefined;
        if i == 0 && designated[$ "spouse_guest_0"] != undefined {
            selection = designated.spouse_guest_0;
        } else if i == 1 && designated[$ "spouse_guest_1"] != undefined {
            selection = designated.spouse_guest_1;
        } else {
            selection = ceremony_available.last();
        }

        var index = ceremony_available.find_lazy(selection);
        if index != undefined {
            ceremony_available.remove(index);
        }

        ceremony[$ key] = selection;
    }

    static POTENTIAL_SPEAKERS = [
        "standing_speaker_0",
        "standing_speaker_1",
        "standing_speaker_2",
        "standing_speaker_3",
        "standing_speaker_4",
    ];

    //
    //
    reception_available.remove(reception_available.find_lazy("dell"));
    reception_available.remove(reception_available.find_lazy("maple"));
    reception_available.remove(reception_available.find_lazy("luc"));

    for (var i = 0; i < array_length(POTENTIAL_SPEAKERS); i++) {
        var key = POTENTIAL_SPEAKERS[i];
        reception[$ key] = designated[$ key];
        if reception[$ key] != undefined {
            var index = reception_available.find_lazy(reception[$ key]);
            if index != undefined {
                reception_available.remove(index);
            }
        }
    }
    //
    static VALID_BARTENDERS = [
        "hemlock",
        "josephine",
        "reina",
        "olric",
    ];
    reception.bartender = undefined;
    for (var i = 0; i < array_length(VALID_BARTENDERS); i++) {
        var this = VALID_BARTENDERS[i];
        var index = reception_available.find_lazy(this);
        if index != undefined {
            reception_available.remove(index);
            reception.bartender = this;
            break;
        }
    }
    assert_defined(reception.bartender, "we couldn't find a bartender!");

    //
    reception.north_table_0 = spouse;
    reception.north_table_1 = "ari";
    reception.south_table_0 = "maple";
    reception.south_table_6 = "dell";
    reception.south_table_7 = "luc";

    //
    reception.north_table_5 = spouse == "juniper" ? reception_available.pop() : "elsie";
    reception.north_table_6 = spouse == "juniper"
        ? "elsie"
        : reception.standing_speaker_1 ?? reception_available.pop();
    reception.north_table_7 = reception.standing_speaker_0 ?? reception_available.pop();

    static RECEPTION_SEATS_TO_FILL = [
        "north_table_2",
        "north_table_3",
        "north_table_4",
        "south_table_1",
        "south_table_2",
        "south_table_3",
        "south_table_4",
        "south_table_5",
        "bar_1",
        "bar_2",
        "bar_3",
        "bar_4",
        "bar_5",
        "bar_6",
        "bar_0", //
        "bar_7",
        "reception_extra_0",
        "reception_extra_1",
    ];
    for (var i = 0; i < array_length(RECEPTION_SEATS_TO_FILL); i++) {
        reception[$ RECEPTION_SEATS_TO_FILL[i]] = reception_available.pop();
    }
    assert(ceremony_available.is_empty(), "Not all NPCs made it to the ceremony: {}", ceremony_available.join(", "));
    assert(reception_available.is_empty(), "Not all NPCs made it to the reception: {}", reception_available.join(", "));


    return {
        ceremony,
        reception,
    };
}
