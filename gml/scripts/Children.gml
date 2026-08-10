#macro CHILDREN global.__children
CHILDREN = undefined;

enum ChildSkinTone {
    Lighter,
    Darker,
    LEN,
}

enum ChildLocation {
    InCradle,
    WithSpouse,
    WithAri,
    LEN,
}

//
enum ChildStage {
    Infant,
    Toddler,
    LEN,
}

function load_children_prototypes() {
    var f_children = fiddle_get("children");
    var o = array_create(ChildId.LEN, undefined);
    for (var i = 0; i < ChildId.LEN; i++) {
        var f_child = f_children[$ child_id_to_string(i)];
        var parent = undefined;
        for (var j = 0; j < NpcId.LEN; j++) {
            if array_has(NPC_PROTOTYPES[j].children, i) {
                parent = j;
                break;
            }
        }
        o[i] = {
            parent,
            name: f_child.name,
            tone_threshold: f_child.tone_threshold,
            sex: string_to_sex(f_child.sex),
        };
    }

    return o;
}

function Child(idx, birthday, skin_tone) constructor {
    self.id = idx;
    self.prototype = CHILDREN[self.id];
    self.name = local_get(self.prototype.name);
    self.skin_tone = skin_tone;
    self.location = undefined;
    self.birthday = birthday;
    self.stage = ChildStage.Infant;

    function set_location(location) {
        var spouse = NPCS[ARI.spouse()];
        var held_by_ari = ARI.held_child();
        var held_by_spouse = spouse.held_child();
        switch location {
            case ChildLocation.WithSpouse:
                self.location = location;
                if !spouse.can_perform_animation(spouse.animation) {
                    spouse.set_animation("idle");
                }
                break;
            case ChildLocation.WithAri:
                self.location = location;
                break;
            case ChildLocation.InCradle:
                self.location = location;
                break;
        }
        build_obj_ari_par_from(ARI.animation_assets());
        report_children_facts();
    }

    function try_get_parent_sprite(animation, cardinality) {
        return try_string_to_asset(format(
            "spr_npc_{NpcId}_baby_{ChildId}_{ChildSkinTone}_{}_{Cardinal}",
            self.prototype.parent,
            self.id,
            self.skin_tone,
            animation,
            cardinality == Cardinal.West ? Cardinal.East : cardinality,
        ));
    }

    function get_sprite(animation) {
        return string_to_asset(format(
            "spr_npc_{ChildId}_baby_{ChildSkinTone}_{}",
            self.id,
            self.skin_tone,
            animation,
        ));
    }

    function get_player_asset() {
        return format(
            "baby_back_{ChildId}_{ChildSkinTone}",
            self.id,
            self.skin_tone,
        );
    }

    function get_icon() {
        return string_to_asset(format(
            "spr_ui_item_wearable_baby_back_{ChildId}_{ChildSkinTone}",
            self.id,
            self.skin_tone,
        ));
    }

    function get_small_icon() {
        return string_to_asset(format(
            "spr_ui_generic_icon_baby_small_{ChildId}_{ChildSkinTone}",
            self.id,
            self.skin_tone,
        ));
    }

    function toString() {
        return format("Child({ChildId})", self.id);
    }
}

function report_children_facts() {
    var child_birthday = [false, false];
    var child_status = [undefined, undefined];
    var child_location = [undefined, undefined];
    var child_default_name = [false, false];
    var ari_holding = false;
    var spouse_holding = false;
    var has_infant = false;
    var has_toddler = false;
    var ari_utero = false;
    var spouse_utero = false;
    var stork_utero = false;

    for (var i = 0; i < array_length(ARI.children); i++) {
        var child = ARI.children[i];
        child_birthday[i] = get_days(child.birthday) == CALENDAR.day()
            && get_seasons(child.birthday) == CALENDAR.season()
            && get_years(child.birthday) < CALENDAR.year();
        child_status[i] = child_stage_to_string(child.stage);
        child_location[i] = child_location_to_string(child.location);
        child_default_name[i] = child.name == local_get(child.prototype.name);
        ari_holding |= child.location == ChildLocation.WithAri;
        spouse_holding |= child.location == ChildLocation.WithSpouse;
        has_infant |= child.stage == ChildStage.Infant;
        has_toddler |= child.stage == ChildStage.Toddler;
    }

    var child_born_today = array_any(ARI.children, function(v) {
        return v.birthday == CALENDAR.time;
    });

    if ARI.pending_child != undefined {
        var i = array_length(ARI.children);
        T2R.write(format("child_{}_status", i), "utero");
        ari_utero = ARI.pending_child.utero == Utero.Ari;
        spouse_utero =  ARI.pending_child.utero == Utero.Spouse;
        stork_utero = ARI.pending_child.utero == Utero.Stork;
    }

    var spouse = ARI.spouse();
    if spouse != undefined {
        T2R.write("spouse_can_carry_child", NPC_PROTOTYPES[spouse].can_carry_child);
        T2R.write(format("{NpcId}_can_drink", spouse), spouse_utero == false);
    }

    for (var i = 0; i < NpcId.LEN; i++) {
        var any = false;
        var c = NPC_PROTOTYPES[i].children;
        for (var j = 0; j < array_length(c); j++) {
            for (var k = 0; k < array_length(ARI.children); k++) {
                any |= ARI.children[k].id == c[j];
            }
        }
        T2R.write(format("{NpcId}_has_child", i), any);
    }

    T2R.write("child_0_status", child_status[0]);
    T2R.write("child_1_status", child_status[1]);
    T2R.write("child_0_location", child_location[0]);
    T2R.write("child_1_location", child_location[1]);
    T2R.write("child_0_has_default_name", child_default_name[0]);
    T2R.write("child_1_has_default_name", child_default_name[1]);
    T2R.write("child_0_birthday", child_birthday[0]);
    T2R.write("child_1_birthday", child_birthday[1]);
    T2R.write("ari_holding_child", ari_holding);
    T2R.write("spouse_holding_child", spouse_holding);
    T2R.write("child_is_held", ari_holding || spouse_holding);
    T2R.write("ari_has_child", has_infant || has_toddler);
    T2R.write("ari_has_infant", has_infant);
    T2R.write("ari_has_toddler", has_toddler);
    T2R.write("child_in_utero", ari_utero || spouse_utero || stork_utero);
    T2R.write("ari_utero", ari_utero);
    T2R.write("spouse_utero", spouse_utero);
    T2R.write("stork_utero", stork_utero);
    T2R.write("child_born_today", child_born_today);
}

function trigger_birth(child_id) {
    var proto = CHILDREN[child_id];
    var tone = ARI.animation_assets().skin_tone >= proto.tone_threshold
        ? ChildSkinTone.Darker
        : ChildSkinTone.Lighter;

    var child = new Child(child_id, CALENDAR.time, tone);
    //
    //
    child.set_location(ChildLocation.WithSpouse);

    array_push(ARI.children, child);
    ARI.pending_child = undefined;

    report_children_facts();

    return create_child_naming_popup(child);
}

//
function potential_child() {
    var spouse = ARI.spouse();
    var child_id = NPC_PROTOTYPES[spouse].children[array_length(ARI.children)];
    var proto = CHILDREN[child_id];
    var tone = ARI.animation_assets().skin_tone >= proto.tone_threshold
        ? ChildSkinTone.Darker
        : ChildSkinTone.Lighter;

    return new Child(child_id, CALENDAR.time, tone);
}

function create_child_naming_popup(child) {
    var popup = create_naming_popup();
    popup.child = ANCHOR.sprite(popup.image_background)
        .set_sprite(child.get_sprite("idle_south"))
        .set_y(-6)
        .set_align(Align.Center, Align.Middle)
    popup.name_input.set_text(child.name);

    popup.random_button.set_tap_callback(function(popup, child) {
        var name = popup.name_input.get_text();
        var new_name = name;
        while new_name == name {
            new_name = random_child_name(child.prototype.sex);
        }
        popup.name_input.set_text(new_name);
    }, [popup, child])

    popup.create_button("misc_local/confirm", function(popup, child) {
        child.name = popup.name_input.get_text();
        MIST.blackboard.insert("naming_done", true);
        report_children_facts();
    }, [popup, child], undefined, InputId.Interact);

    return popup.spawn();
}

//
function find_cradle() {
    var output = List();

    for (var i = 0; i < LocationId.LEN; i++) {
        var grid = GRIDS[i];
        if !is_home_location(i) || grid == undefined {
            continue;
        }

        var node_tick = irandom(I32_MAX);
        for (var xx = 0; xx < grid.dims.x; xx++) {
            for (var yy = 0; yy < grid.dims.y; yy++) {
                var ni = grid.node_index_for_cell(xx, yy);
                if grid.node_object_id[ni] != ObjectId.BabyCradle {
                    continue;
                }
                return {
                    location_id: i,
                    ni,
                }
            }
        }
    }

    return output;
}

//
enum Utero {
    Ari,
    Spouse,
    Stork,
    LEN,
}
