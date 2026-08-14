#macro NPC_PROTOTYPES global.__npc_prototypes
NPC_PROTOTYPES = undefined;

function load_npc_prototypes() {
    var npcs = array_create(NpcId.LEN, undefined);

    for (var i = 0; i < NpcId.LEN; i++) {
        var npc_string = npc_id_to_string(i);
        var data = fiddle_get("npcs/" + npc_string);

        //
        var outfit_selector;
        switch i {
            case NpcId.Caldarus:
                outfit_selector = function(wardrobe, time) {
                    if npc_is_unlocked(NpcId.Caldarus) {
                        return default_npc_outfit_selector(wardrobe, time);
                    } else {
                        return "dragon_statue";
                    }
                };
                break;
            case NpcId.Seridia:
                outfit_selector = function(wardrobe, time) {
                    if npc_is_unlocked(NpcId.Seridia) {
                        return default_npc_outfit_selector(wardrobe, time);
                    } else {
                        return "priestess";
                    }
                }
                break;
            default: outfit_selector = default_npc_outfit_selector;
        }

        var wardrobe_outfits = parse_wardrobe(data, npc_string);

        //
        var loved_gifts = ListFromArray(data.loved_gifts).map_to(string_to_item_id);
        var liked_gifts = ListFromArray(data.liked_gifts).map_to(string_to_item_id);
        for (var j = 0; j < liked_gifts.count(); j++) {
            for (var k = 0; k < loved_gifts.count(); k++) {
                assert(loved_gifts.get(k) != liked_gifts.get(j), format("Dupe gift found in {NpcId}.toml under liked/loved gifts.  Dupe liked/loved gift is {ItemId}", i, liked_gifts.get(j)));
            }
        }

        data.gossip.line = T2R.exact_gameplay_conversation(data.gossip.line);

        npcs[i] = {
            id: i,
            name: data.name,
            aldarian_name: data.aldarian_name,
            job: data.job,
            loved_gifts,
            liked_gifts,
            disliked_gift_tags: ListFromArray(data.disliked_gift_tags),
            hated_gift: string_to_item_id(data.hated_gift),
            banned_gift_tags: ListFromArray(data[$ "banned_gift_tags"] ?? []),
            birthday: {
                day: data.birthday.day,
                season: string_to_season(data.birthday.season),
            },
            music: data[$ "music"],
            fallback_outfit: data[$ "fallback_outfit"] ?? "spring",
            offsets: data.offsets,
            portrait_sound_overrides: data[$ "portrait_sound_overrides"] ?? {},
            journal_portrait_offset: data.journal_portrait_offset,
            journal_background_color: data.journal_background_color,
            date_photo_offset: data.date_photo_offset,
            wardrobe_outfits,
            get_suitable_outfit_key: outfit_selector,
            dateable: data.dateable,
            small_outlined_icon_sprite: string_to_asset(data.small_outlined_icon_sprite),
            small_icon_sprite: string_to_asset(data.small_icon_sprite),
            icon_sprite: string_to_asset(data.icon_sprite),
            gossip: data.gossip,
            tags: data.tags,
            roommate_routine: opt_and_then(data[$ "roommate_routine"], string_to_routine),
            children: apply_func(data[$ "children"] ?? [], string_to_child_id),
            proposal_cutscene: opt_and_then(data[$ "proposal_cutscene"], CONTENT_REGISTRY.validate_cutscene),
            can_carry_child: data[$ "can_carry_child"] ?? false,
            child_fallbacks: data[$ "child_portrait_fallbacks"] ?? {},
        };
    }

    return npcs;
}

function parse_wardrobe(data, npc_string) {
    var wardrobe_outfits = Map();
    var outfits = is_array(data.outfits) ? data.outfits : [data.outfits];
    for (var j = 0; j < array_length(data.outfits); j++) {
        wardrobe_outfits.set(data.outfits[j], {
            cycles: Map(),
            portraits: Map(),
        });
    }
    var cycle_keys = struct_get_names(data.cycles);
    for (var j = 0; j < array_length(cycle_keys); j++) {
        var cycle = data.cycles[$ cycle_keys[j]];
        var outfits = is_array(cycle.outfits) ? cycle.outfits : [cycle.outfits];
        for (var k = 0; k < array_length(outfits); k++) {
            var cycle_name = cycle_keys[j];
            var collection;
            switch cycle.type {
                case "linear":
                    var north_sprite = undefined;
                    var south_sprite = undefined;
                    var east_sprite = undefined;
                    var default_sprite = undefined;
                    var directions = is_array(cycle.directions) ? cycle.directions : [cycle.directions];
                    for (var h = 0; h < array_length(directions); h++) {
                        //
                        var name = fmt(
                            "spr_npc_{}_{}_{}_{}",
                            npc_string,
                            outfits[k],
                            cycle_name,
                            directions[h],
                        );
                        var sprite = try_string_to_asset(name);
                        if sprite == undefined {
                            var name = fmt(
                                "spr_npc_{}_specialanimation_{}_{}_{}",
                                npc_string,
                                outfits[k],
                                cycle_name,
                                directions[h],
                            );
                            var sprite = try_string_to_asset(name);
                            if sprite == undefined {
                                warn("{} could not be found! Falling back to spr_nothing...", name);
                                sprite = spr_nothing;
                            }
                        }
                        switch directions[h] {
                            case "north":
                                north_sprite = sprite;
                                break;
                            case "south":
                                south_sprite = sprite;
                                break;
                            case "east":
                                east_sprite = sprite;
                                break;
                            default: impossible("Unexpected direction: {}", directions[h]);
                        }
                        assert_neq(sprite, -1, "Sprite does not exist: {}", name);
                        if directions[h] == cycle.default_direction {
                            default_sprite = sprite;
                        }
                    }
                    assert_neq(
                        default_sprite,
                        undefined,
                        "Default sprite does not exist in {} for {}!",
                        outfits[k],
                        npc_string
                    );
                    north_sprite = north_sprite ?? default_sprite;
                    south_sprite = south_sprite ?? default_sprite;
                    east_sprite = east_sprite ?? default_sprite;
                    collection = SpritePackCollection.Multi(
                        SpritePack.Linear(north_sprite),
                        SpritePack.Linear(south_sprite),
                        SpritePack.Linear(east_sprite),
                    );
                    break;
                case "complex":
                    //
                    var parse_pack = function(npc_string, outfit, cycle_name, direction) {
                        var start_sprite_name = fmt(
                            "spr_npc_{}_specialanimation_{}_{}_start_{}",
                            npc_string,
                            outfit,
                            cycle_name,
                            direction,
                        );
                        var loop_sprite_name = fmt(
                            "spr_npc_{}_specialanimation_{}_{}_loop_{}",
                            npc_string,
                            outfit,
                            cycle_name,
                            direction,
                        );
                        var end_sprite_name = fmt(
                            "spr_npc_{}_specialanimation_{}_{}_end_{}",
                            npc_string,
                            outfit,
                            cycle_name,
                            direction,
                        );
                        var start_sprite = try_string_to_asset(start_sprite_name);
                        if start_sprite == undefined {
                            var name = fmt(
                                "spr_npc_{}_{}_{}_start_{}",
                                npc_string,
                                outfit,
                                cycle_name,
                                direction,
                            );
                            var start_sprite = try_string_to_asset(name);
                            if start_sprite == undefined {
                                return undefined;
                            }
                        }
                        var loop_sprite = try_string_to_asset(loop_sprite_name);
                        if loop_sprite == undefined {
                            var name = fmt(
                                "spr_npc_{}_{}_{}_loop_{}",
                                npc_string,
                                outfit,
                                cycle_name,
                                direction,
                            );
                            var loop_sprite = try_string_to_asset(name);
                            if loop_sprite == undefined {
                                return undefined;
                            }
                        }
                        var end_sprite = try_string_to_asset(end_sprite_name);
                        if end_sprite == undefined {
                            var name = fmt(
                                "spr_npc_{}_{}_{}_end_{}",
                                npc_string,
                                outfit,
                                cycle_name,
                                direction,
                            );
                            var end_sprite = try_string_to_asset(name);
                            if end_sprite == undefined {
                                return undefined;
                            }
                        }

                        return SpritePack.Complex(start_sprite, loop_sprite, end_sprite);
                    }

                    var default_pack = parse_pack(npc_string, outfits[k], cycle_name, cycle.default_direction);
                    assert_neq(default_pack, undefined, "Could not find assets for {} {} in {}", npc_string, cycle_name, outfits[k]);

                    collection = SpritePackCollection.Multi(
                        parse_pack(npc_string, outfits[k], cycle_name, "north") ?? default_pack,
                        parse_pack(npc_string, outfits[k], cycle_name, "south") ?? default_pack,
                        parse_pack(npc_string, outfits[k], cycle_name, "east") ?? default_pack,
                    );
                    break;
                default: impossible("Unexpected cycle type: {}", cycle.type);
            }

            //
            if cycle[$ "is_seated"] != undefined {
                collection.is_seated = cycle.is_seated;
            }

            //
            //
            if cycle[$ "last_frame_hold"] != undefined {
                collection.last_frame_hold = cycle.last_frame_hold;
            }

            //
            //
            if cycle[$ "can_talk"] != undefined {
                collection.can_talk = cycle.can_talk;
            }

            //
            if cycle[$ "sound"] != undefined {
                collection.sound = cycle.sound;
                collection.detach_sound = cycle[$ "sound"] ?? false;
            }

            collection.on_pause_speaking_turn = cycle[$ "on_pause_speaking_turn"] ?? false;
            collection.on_pause_speaking = cycle[$ "on_pause_speaking"];
            if collection.on_pause_speaking != undefined {
                assert_neq(data.cycles[$ collection.on_pause_speaking], undefined, "{} in {} animation wants to use {} on_pause_speaking, but it does not exist!", npc_string, cycle_name, collection.on_pause_speaking);
            }
            collection.on_pause_background = cycle[$ "on_pause_background"];
            if collection.on_pause_background != undefined {
                assert_neq(data.cycles[$ collection.on_pause_background], undefined, "{} in {} animation wants to use {} on_pause_background, but it does not exist!", npc_string, cycle_name, collection.on_pause_background);
            }

            wardrobe_outfits
                .get_unwrap(outfits[k])
                .cycles
                .set(cycle_name, collection);
        }
    }
    var portrait_keys = struct_get_names(data.portraits);
    for (var j = 0; j < array_length(portrait_keys); j++) {
        var portrait_name = portrait_keys[j];
        var portrait_outfits = data.portraits[$ portrait_name];
        portrait_outfits = is_array(portrait_outfits) ? portrait_outfits : [portrait_outfits];
        for (var k = 0; k < array_length(portrait_outfits); k++) {
            var sprite_name = fmt(
                "spr_portrait_{}_{}_{}",
                npc_string,
                portrait_outfits[k],
                portrait_name,
            );
            var sprite = string_to_asset(sprite_name);
            wardrobe_outfits
                .get_unwrap(portrait_outfits[k])
                .portraits
                .set(portrait_name, sprite);
        }
    }

    return wardrobe_outfits;
}

function Npc(idx, brain) constructor {
    self.id = idx;
    self.brain = brain;
    self.brain.blackboard.set("me", self);
    self.prototype = NPC_PROTOTYPES[idx];
    self.location_position = undefined;
    self.brain_dead = true;
    self.activity_handler = undefined;
    self.gift_flag = true;
    self.gifts_given = HashSet();
    self.known_gift_preferences = HashSet();
    self.animation = "idle";
    self.cardinality = Cardinal.South;
    self.itinerary = undefined;
    self.simulated_distance_traveled = 0;
    self.times_spoken_today = 0;
    self.talk_flag = true;
    self.heart_points = 0;
    self.swap_schedule_request = undefined;
    self.activity_handler = new ActivityHandler(self);
    self.wardrobe = new Wardrobe(self.prototype.wardrobe_outfits, format("{NpcId}_outfit", self.id));
    self.wardrobe.set_outfit(self.prototype.get_suitable_outfit_key(self.wardrobe, CALENDAR.time));

    function set_animation(animation_name) {
        self.animation = animation_name;
        with npc_id_to_gm_obj_id(self.id) {
            self.update_animation();
            //
            self.reset_cycle_name = undefined;
            self.reset_cycle_cardinality = undefined;
        }
        T2R.write(format("{NpcId}_animation", self.id), self.animation);
    }

    function try_set_animation(animation_name) {
        var anim = self
            .wardrobe
            .outfit_current
            .cycles
            .get(animation_name);

        if anim == undefined {
            return false;
        }

        self.set_animation(animation_name);

        return true;
    }

    //
    //
    //
    //
    //
    //
    function can_perform_animation(animation_name, required_cardinal, ignore_child=false) {
        var in_current = self.wardrobe
            .outfit_current
            .cycles
            .contains_key(animation_name);

        var in_fallback = self.wardrobe
            .outfits
            .get(self.prototype.fallback_outfit)
            .cycles
            .contains_key(animation_name);

        var child = self.held_child();
        if !ignore_child && child != undefined && child.try_get_parent_sprite(animation_name, self.cardinality) == undefined {
            return false;
        }

        if !in_current && !in_fallback {
            return false;
        }

        //
        if required_cardinal != undefined {
            required_cardinal = required_cardinal == Cardinal.West ? Cardinal.East : required_cardinal;
            var dirs = fiddle_get(format("npcs/{NpcId}/cycles/{}/directions", self.id, animation_name));
            if !array_has(dirs, cardinal_to_string(required_cardinal)) {
                return false;
            }
        }

        return true;
    }

    function set_cardinality(cardinal) {
        self.cardinality = cardinal;
        with npc_id_to_gm_obj_id(self.id) {
            self.update_cardinality();
        }
    }

    function add_heart_points(amount) {
        var old = self.heart_level();
        if old >= 10 {
            return;
        }
        self.heart_points += max(amount, 0);

        if old < self.heart_level() {
            ANCHOR.get_menu(Menu.Dingaling).create_heart_dingaling(self.id, old);
            TANGO.play("SoundEffects/Ari/LevelUp");

            var obj = npc_id_to_gm_obj_id(self.id);
            if instance_exists(obj) {
                repeat irandom_range(3, 5) {
                    create_debris(
                        obj.x + obj.heart_particle_bundle.get_x_offset() + random_range(-2, 2),
                        obj.y + obj.heart_particle_bundle.get_y_offset() + random_range(-2, 2) - 25,
                        obj.depth - 1,
                        spr_part_heart,
                        obj.heart_particle_bundle,
                    );
                }
            }
            refresh_achievements([Requirement.ReachedHeartLevel]);
        }

        self.report_hearts();
        T2R.write_most_liked_npc();
    }

    //
    //
    //
    function set_heart_level(level) {
        self.heart_points = npc_heart_level_to_points(level);
        self.report_hearts();
        T2R.write_most_liked_npc();
    }

    function heart_level() {
        static TABLE = fiddle_get("misc/npc_heart_point_table");
        for (var i = 0; i < array_length(TABLE); i++) {
            if heart_points < TABLE[i] {
                return i;
            }
        }
        return array_length(TABLE);
    }

    function report_hearts() {
        //
        T2R.write(format("{NpcId}_heart_level", self.id), self.heart_level())
    }

    function report_relationship() {
        var status = T2R.read(format("{NpcId}_status", self.id));
        T2R.write(format("{NpcId}_is_best_friend", self.id), status == "best_friend");
        T2R.write(format("{NpcId}_is_dating", self.id), status == "dating");
        T2R.write(format("{NpcId}_is_fiance", self.id), status == "fiance");
        T2R.write(format("{NpcId}_is_spouse", self.id), status == "spouse");
        T2R.write(format("{NpcId}_is_partner", self.id), matches(status, "dating", "fiance", "spouse"));
        T2R.write("has_spouse", ARI.spouse() != undefined);
        T2R.write("has_fiance", ARI.fiance() != undefined);

        refresh_achievements([
            Requirement.HasSpouse,
            Requirement.HasBestFriend,
            Requirement.HasPartner,
            Requirement.IsDating,
        ]);
    }

    function give_gift(item) {
        self.gifts_given.insert(item.item_id);
        self.known_gift_preferences.insert(item.item_id);

        var treat_as_birthday = self.is_birthday();
        var hearts = undefined;
        var multip = 1;
        switch item.item_id {
            case ItemId.VoidNewt:
                if self.id == NpcId.Juniper {
                    desire = Desire.Loved;
                    treat_as_birthday = true;
                    multip = 2.0;
                } else {
                    desire = Desire.Disliked;
                }
                break;
            case ItemId.VoidCake:
                if self.id == NpcId.Eiland {
                    desire = Desire.Loved;
                    treat_as_birthday = true;
                    multip = 2.0;
                } else {
                    desire = Desire.Disliked;
                }
                break;
            default:
                if item.infusion == Infusion.Loveable || self.prototype.loved_gifts.contains(item.item_id) {
                    desire = Desire.Loved;
                } else if item.infusion == Infusion.Likeable || self.prototype.liked_gifts.contains(item.item_id){
                    desire = Desire.Liked;
                } else if item.item_id == self.prototype.hated_gift {
                    desire = Desire.Hated;
                } else if item.prototype.tags.contains_any_value_from(self.prototype.disliked_gift_tags) {
                    desire = Desire.Disliked;
                } else {
                    desire = Desire.Neutral;
                }
                break;
        }


        array_push(GAME_STATS.gifts_given, {
            npc: npc_id_to_string(self.id),
            gift: item.pretty_print(),
            desire: desire_to_string(desire),
            day: total_days(),
        });

        var hearts = fiddle_get(format("misc/gift_giving/hearts/{Desire}", desire));
        if treat_as_birthday {
            hearts += fiddle_get("misc/gift_giving/hearts/birthday_boost");
        }

        if ARI.perk_active(Perk.AwardWinning)
            && desire == Desire.Liked
            && ITEM_PROTOTYPES[item.item_id].recipe != undefined
            && ITEM_PROTOTYPES[item.item_id].edible
        {
            hearts += hearts * ARI.perk_value(Perk.AwardWinning);
            GAME_STATS.perks[$ perk_to_string(Perk.AwardWinning)] += 1;
        }

        if ARI.perk_active(Perk.AWayToTheHeart)
            && desire == Desire.Loved
            && ITEM_PROTOTYPES[item.item_id].recipe != undefined
            && ITEM_PROTOTYPES[item.item_id].edible
        {
            hearts += hearts * ARI.perk_value(Perk.AWayToTheHeart);
            GAME_STATS.perks[$ perk_to_string(Perk.AWayToTheHeart)] += 1;
        }

        hearts *= multip;

        self.add_heart_points(hearts);

        self.gift_flag = false;

        T2R.write("gift_given", item_id_to_string(item.item_id));
        T2R.write("gift_desire", desire_to_string(desire));

        var gift_convo = T2R.request_conversation(self.id, ConversationKind.Gift);

        //
        T2R.write("gift_given", undefined);
        T2R.write("gift_desire", undefined);

        if desire == Desire.Hated {
            T2R.write("has_given_any_hated_gift", true);
        }

        if self.is_birthday() && matches(desire, Desire.Liked, Desire.Loved) {
            T2R.write(format("gave_{NpcId}_good_birthday_gift", self.id), true);
        }

        refresh_achievements([Requirement.AllNpcGiftsDiscovered, Requirement.GoodGiftsGiven]);

        return {
            convo: gift_convo,
            bark: string_to_bark_id(fiddle_get(format("misc/gift_giving/barks/{Desire}", desire))),
        }
    }

    function is_birthday() {
        return (CALENDAR.day() == (self.prototype.birthday.day - 1)) && CALENDAR.season() == self.prototype.birthday.season;
    }

    function set_has_met() {
        T2R.write(format("{NpcId}_has_met", self.id), true);
    }

    function has_met() {
        return T2R.read(format("{NpcId}_has_met", self.id));
    }

    function can_go_on_dates() {
        //
        //
        if array_contains(self.prototype.tags, "child") {
            return false;
        }
        for (var i = 0; i < array_length(ELIGIBLE_DATE_STATUSES); i++) {
            if T2R.read(format("{NpcId}_status", self.id)) == ELIGIBLE_DATE_STATUSES[i] {
                return true;
            }
        }
        return false;
    }

    function is_spouse() {
        return T2R.read(format("{NpcId}_status", self.id)) == "spouse";
    }

    function is_dating() {
        return T2R.read(format("{NpcId}_status", self.id)) == "dating";
    }

    function is_fiance() {
        return T2R.read(format("{NpcId}_status", self.id)) == "fiance";
    }

    function is_partner() {
        return self.is_dating() || self.is_spouse() || self.is_fiance();
    }

    function is_best_friend() {
        return T2R.read(format("{NpcId}_status", self.id)) == "best_friend";
    }

    function is_roommate() {
        return self.is_spouse()
            || (self.id == NpcId.Dozy && NPCS[NpcId.Juniper].is_spouse())
            || (self.id == NpcId.Henrietta && NPCS[NpcId.Hayden].is_spouse());
    }

    function is_animal() {
        return self.id == NpcId.Dozy || self.id == NpcId.Henrietta;
    }

    function at_farm() {
        return self.location_position != undefined
            && (self.location_position.location_id == LocationId.Farm
                || is_home_location(self.location_position.location_id)
            );
    }

    function held_child() {
        if !self.is_spouse() {
            return undefined;
        }

        if MIST.blackboard.get("no_held_child") == true {
            return undefined;
        }

        var child = undefined;
        for (var i = 0; i < array_length(ARI.children); i++) {
            if ARI.children[i].location == ChildLocation.WithSpouse {
                assert_neq(child, "Spouse cannot hold more than one child!");
                child = ARI.children[i];
            }
        }

        return child;
    }

    function is_seated() {
        var pack = self.wardrobe.outfit_current.cycles.get(self.animation);
        if pack == undefined {
            return false;
        }
        return self.wardrobe.outfit_current.cycles.get(self.animation).is_seated;
    }

    function complete_pathfind() {
        var output = self.brain.blackboard.try_take("on_arrived_at_next_location");
        if output != undefined {
            output(self.brain.blackboard);
        }

        if self.activity_handler.activity != undefined {
            var trellis_point = trellis_point_by_location_position(self.location_position);

            var zone = undefined;
            if trellis_point != undefined {
                zone = T2R.tp_to_zone(trellis_point.name);
            }

            if zone == undefined {
                zone = format("personal/{NpcId}", self.id);
            }

            T2R.write(format("{NpcId}_zone", self.id), zone);
        }

        self.itinerary = undefined;
        self.simulated_distance_traveled = 0;

        if self.brain.blackboard.try_take("set_can_talk_on_arrival") == true {
            self.talk_flag = true;
        }
    }

    function serialize() {
        var routine = self.activity_handler.routine;
        var activity = undefined;

        var has_arrived = T2R.schedule_current_action_has_arrived(self.id);

        if routine == undefined {
            if self.activity_handler.activity != undefined {
                activity = activity_to_string(self.activity_handler.activity.id);
            }
        } else {
            routine = routine_to_string(routine.id);
        }

        return {
            animation: self.animation,
            cardinality: cardinal_to_string(self.cardinality),
            outfit: self.wardrobe.outfit_name,
            current_activity: activity,
            current_routine: routine,
            location_position: serialize_location_position(self.location_position),
            schedule_name: T2R.schedule_name(self.id),
            had_arrived: has_arrived,
            known_gift_preferences: array_map(self.known_gift_preferences.keys(), function(v) { return item_id_to_string(real(v)); }),
            gifts_given: array_map(self.gifts_given.keys(), function(v) { return item_id_to_string(real(v)); }),

            gift_flag: self.gift_flag,
            talk_flag: self.talk_flag,
            times_spoken_today: self.times_spoken_today,
            heart_points: self.heart_points,
            simulated_distance_traveled: self.simulated_distance_traveled,
            swap_schedule_request: self.swap_schedule_request,
        }
    }

    function deserialize(value) {
        self.heart_points = value.heart_points;

        self.wardrobe.set_outfit(value.outfit);
        self.set_animation(value.animation);
        self.talk_flag = value.talk_flag;
        self.times_spoken_today = value.times_spoken_today;
        self.gift_flag = value.gift_flag;
        self.location_position = deserialize_location_position(value.location_position);
        self.cardinality = string_to_cardinal(value.cardinality);
        self.known_gift_preferences = HashSetFromArray(array_map(value.known_gift_preferences, string_to_item_id_or_unknown));
        self.gifts_given = HashSetFromArray(array_map(value.gifts_given, string_to_item_id_or_unknown));
        self.simulated_distance_traveled = value.simulated_distance_traveled;
        self.swap_schedule_request = value[$ "swap_schedule_request"];

        var routine_id = try_string_to_routine(value.current_routine);
        if routine_id == undefined {
            var activity_id = try_string_to_activity(value.current_activity);
            if activity_id != undefined {
                self.activity_handler.request_activity(activity_id);
            }
        } else {
            self.activity_handler.set_routine(routine_id);
        }

        //
        var schedule_name = value.schedule_name;
        if schedule_name == "Schedules/Dragon Town Schedules/FNATI/fnati_0_dragon" {
            schedule_name = "Schedules/Dragon Town Schedules/FNATI/fnati_5_dragon";
        }
        var output = T2R.schedule_reload(self.id, schedule_name, CLOCK.time, value.had_arrived);
        if output == undefined {
            tattletale_report_error_without_panic(
                "Failed to deserialize schedule",
                format("Couldn't find a schedule of the given name `{}`! Defaulting back to basement schedule...find them in Aldaria", schedule_name),
            );
            T2R.schedule_start(self.id, "Schedules/basement_schedule");
            var pt = trellis_point_find_by_name(rm_aldaria, "default");
            self.location_position = new LocationPosition(LocationId.Aldaria, Vec2(pt.x, pt.y));
        }
    }

}

function default_npc_outfit_selector(wardrobe, time) {
    switch get_seasons(time) {
        case Season.Spring: return wardrobe.outfits.contains_key("spring") ? "spring" : "spring";
        case Season.Summer: return wardrobe.outfits.contains_key("summer") ? "summer" : "spring";
        case Season.Fall: return wardrobe.outfits.contains_key("autumn") ? "autumn" : "spring";
        case Season.Winter: return wardrobe.outfits.contains_key("winter") ? "winter" : "spring";
    }
}

//
function some_romantic_npc() {
    for (var i = 0; i < NpcId.LEN; i++) {
        if NPCS[i].is_partner() {
            return i;
        }
    }
    return undefined;
}

enum Desire {
    Loved,
    Liked,
    Neutral,
    Disliked,
    Hated,
    LEN,
}

function Wardrobe(_outfits, t2_key) constructor {
    self.outfits = _outfits;
    self.outfit_name = undefined;
    self.outfit_current = undefined;
    self.t2_key = t2_key;

    static set_outfit = function(name) {
        var outfit = self.outfits.get(name);
        assert_neq(outfit, undefined, "Outfit {} does not exist!", name);
        self.outfit_current = outfit;
        self.outfit_name = name;

        if self.t2_key != undefined {
            T2R.write(self.t2_key, self.outfit_name);
        }
    }
}

//
function test_gift_dialogue() {
    for (var i = 0; i < NpcId.LEN; i++) {
        var npc = NPCS[i];

        //
        if npc.is_birthday() {
            T2R.write(format("is_{NpcId}_birthday", i), false);
        }

        for (var j = 0; j < ItemId.LEN; j++) {
            var ret = npc.give_gift(new LiveItem(j));
            if string_pos("temporary_gift_lines", ret.convo) != 0 {
                crash("{NpcId} got a basement gift line for {ItemId}: {}", i, j, ret.convo);
            }
        }

        if npc.is_birthday() {
            T2R.write(format("is_{NpcId}_birthday", i), true);
        }

        var date = npc.prototype.birthday;
        var season = CALENDAR.season();
        var day = CALENDAR.day();
        var since_year = CALENDAR.year() - 1;
        var until_year = CALENDAR.year();
        if date.season < season || (date.season == season && (date.day - 1) < day) {
            since_year += 1;
            until_year += 1;
        }
        var unt = day_delta(date.season, date.day - 1, until_year);
        var since = abs(day_delta(date.season, date.day - 1, since_year));
        t2_write_world_fact(format("days_since_{NpcId}_birthday", i), since);
        t2_write_world_fact(format("days_until_{NpcId}_birthday", i), unt);
    }
}

//
//
function npc_heart_level_to_points(level) {
    static TABLE = fiddle_get("misc/npc_heart_point_table");
    if level == 0 {
        return 0;
    }

    return TABLE[level - 1];
}

//
//
function npc_is_unlocked(npc_id) {
    switch npc_id {
        case NpcId.Merri:
        case NpcId.Darcy:
        case NpcId.Louis:
        case NpcId.Vera:
            return requirements_pass(Requirement.SaturdayMarketUnlocked)
        case NpcId.Wheedle:
        case NpcId.Taliferro:
            return QUEST_LOG.completed.contains("upgrade_the_saturday_market");
        case NpcId.Stillwell:
        case NpcId.Zorel:
            return QUEST_LOG.completed.contains("upgrade_the_saturday_market_plaza");
        case NpcId.Caldarus: return requirements_pass(Requirement.BrokeFireSeal)
        case NpcId.Seridia: return requirements_pass(Requirement.SeridiaTransformed);
        //
        default: return true;
    }
}

function caldarus_is_sleeping() {
    return NPCS[NpcId.Caldarus].animation == "eyes_closed";
}
