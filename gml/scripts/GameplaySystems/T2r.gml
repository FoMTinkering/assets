#macro T2R global.__t2r
global.__t2r = undefined;

function T2r() constructor {
    //
    self.local_blackboard = Map();

    //
    function new_game(ari_name) {
        t2_begin_game(ari_name);
    }

    //
    function update() {
        if DEBUG_TOOLS {
            var span = profile_span_start("T2r::update");
        }
        //
        var health_percent = 1;
        if ARI.get_max_health() > 0 {
            health_percent = ARI.health_current / ARI.get_max_health();
        }

        var mana_percent = 1;
        if ARI.mana_max > 0 {
            mana_percent = ARI.mana_current / ARI.mana_max;
        }

        var stamina_percent = 1;
        if ARI.get_max_stamina() > 0 {
            stamina_percent = ARI.stamina_current / ARI.get_max_stamina();
        }

        //
        t2_write_world_fact("gold", ARI.gold);
        t2_write_world_fact("essence", ARI.essence);
        t2_write_world_fact("health", ARI.health_current);
        t2_write_world_fact("health_percent", health_percent);
        t2_write_world_fact("mana", ARI.mana_current);
        t2_write_world_fact("mana_percent", mana_percent);
        t2_write_world_fact("stamina", ARI.stamina_current);
        t2_write_world_fact("stamina_percent", stamina_percent);

        var held_item = ARI.held_item();
        if held_item != undefined {
            t2_write_world_fact("held_item", item_id_to_string(held_item.prototype.item_id));
        } else {
            t2_write_world_fact("held_item", undefined);
        }

        //
        var output = t2_update(
            CALENDAR.unified_time(),
            location_id_to_string(CURRENT_LOCATION_ID),
        );
        for (var i = 0, c = array_length(output); i < c; i++) {
            process_t2_action(parse_t2_action(output[i]), NpcId.Caldarus);
        }

        if DEBUG_TOOLS {
            profile_span_stop(span);
        }
    }

    //
    function update_daily() {
        //
        {
            var total = 0;

            for (var i = 0; i < MuseumWing.LEN; i++) {
                var wing_progress = 0;
                var set_names = MUSEUM_DATA.data[i].sets.keys();

                for (var j = 0; j < array_length(set_names); j++) {
                    var count = museum_set_progress(i, set_names[j]);
                    t2_write_world_fact(format("museum_set_{}_count", set_names[j]), count);
                    wing_progress += count;
                }

                t2_write_world_fact(format("museum_{MuseumWing}_count", i), wing_progress);
                total += wing_progress;
            }

            t2_write_world_fact("museum_total_count", total);
        }

        t2_write_world_fact(
            "completed_museum",
            requirements_pass(ACHIEVEMENTS[Achievement.CelebratedCurator]),
        );

        //
        {
            var animal_count = array_create(AnimalKind.LEN, 0);
            var all_animals = get_all_animals(true);
            for (var i = 0; i < all_animals.count(); i++) {
                var animal = all_animals.get(i);
                animal_count[animal.kind] += 1;
            }

            for (var i = 0; i < AnimalKind.LEN; i++) {
                t2_write_world_fact(format("{AnimalKind}_count", i), animal_count[i]);
            }
        }

        t2_write_world_fact("is_ari_birthday", ARI.is_birthday());
        report_children_facts();

        var wedding_is_tomorrow = false;
        var wedding_was_yesterday = false;
        var is_aniv = false;
        if ARI.wedding_date != undefined {
            wedding_was_yesterday = CALENDAR.date_is(ARI.wedding_date + days(1));
            wedding_is_tomorrow = CALENDAR.date_is(ARI.wedding_date - days(1));

            if CALENDAR.season() == get_seasons(ARI.wedding_date) {
                var normalized_now = CALENDAR.time - (years(1) * CALENDAR.year());
                var normalized_wedding = ARI.wedding_date - (years(1) * get_years(ARI.wedding_date));
                var is_this_year = CALENDAR.year() == get_years(ARI.wedding_date);
                is_aniv = !is_this_year && normalized_now == normalized_wedding;
            }
        }
        t2_write_world_fact("wedding_was_yesterday", wedding_was_yesterday);
        t2_write_world_fact("wedding_is_tomorrow", wedding_is_tomorrow);
        t2_write_world_fact("is_anniversary", is_aniv);
        t2_write_world_fact("proposed_today", false);

        //
        var weather_word;
        var is_strong;
        switch WEATHER.weather {
            case Weather.Calm:
                weather_word = "pleasant";
                is_strong = false;
                break;
            case Weather.Inclement:
                weather_word = CALENDAR.season() == Season.Winter ? "snowy" : "rainy";
                is_strong = false;
                break;
            case Weather.HeavyInclement:
                weather_word = CALENDAR.season() == Season.Winter ? "snowy" : "rainy";
                is_strong = true;
                break;
            case Weather.Special:
                weather_word = "pleasant";
                is_strong = true;
                break;
            default: impossible("omg is it mist?");
        }
        t2_write_world_fact("weather", weather_word);
        t2_write_world_fact("weather_is_strong", is_strong);

        //
        for (var i = 0; i < Skill.LEN; i++) {
            var level = ARI.level(i);
            t2_write_world_fact(format("{Skill}_level", i), level);
        }

        //
        t2_write_world_fact("renown", renown_to_level(ARI.renown));

        //
        for (var i = 0; i < NpcId.LEN; i++) {
            NPCS[i].report_relationship();
            NPCS[i].report_hearts();
            T2R.write(format("{NpcId}_day_start_heart_level", i), NPCS[i].heart_level())
        }
        self.write_most_liked_npc();

        //
        var perk_total = 0;
        for(var i = 0; i < Perk.LEN; i++) {
            var is_unlocked = ARI.perk_active(i);
            t2_write_world_fact(format("perk_unlocked_{Perk}", i), is_unlocked);

            perk_total += is_unlocked;
        }
        t2_write_world_fact("perk_count", perk_total);

        //
        var completed = QUEST_LOG.completed.keys();
        for (var i = 0, c = array_length(completed); i < c; i++) {
            t2_write_world_fact(format("quest_{}_complete", completed[i]), 1.0);
            t2_write_world_fact(format("quest_{}_in_progress", completed[i]), 0.0);
        }

        //
        var in_progress = QUEST_LOG.active.keys();
        for (var i = 0, c = array_length(in_progress); i < c; i++) {
            t2_write_world_fact(format("quest_{}_in_progress", in_progress[i]), 1.0);
        }

        //
        for (var i = 0; i < ItemId.LEN; i++) {
            t2_write_world_fact(format("had_item_{ItemId}", i), ARI.items_acquired[i]);
        }

        //
        var keys = MIST.scene_history.keys();
        for (var i = 0; i < array_length(keys); i++) {
            t2_write_world_fact(format("cutscene_seen_{}", keys[i]), 1.0);
        }

        //
        for (var i = 0; i < FestivalId.LEN; i++) {
            var f = FESTIVALS[i];
            t2_write_world_fact(format("days_since_{FestivalId}_festival", i), f.days_since());
            t2_write_world_fact(format("days_until_{FestivalId}_festival", i), f.days_until());
        }

        //
        var has_double_bed = all_player_beds().any(function(v) {
            return GRIDS[v.location_id].node_parent[v.ni].prototype.bed_kind == BedKind.Double;
        });
        T2R.write("ari_has_double_bed_placed", has_double_bed);
    }

    //
    function request_conversation(npc_id, kind=ConversationKind.Normal) {
        return t2_request_conversation(npc_id_to_string(npc_id), kind);
    }

    //
    function request_schedule(npc_id) {
        return t2_request_schedule(npc_id_to_string(npc_id));
    }

    //
    function fuzzy_search_conversation(npc_id, conversation_name, conversation_kind=ConversationKind.Normal) {
        return t2_fuzzy_search(npc_id_to_string(npc_id), conversation_name, conversation_kind);
    }

    //
    function exact_gameplay_conversation(conversation_name) {
        return t2_exact_gameplay_conversation(conversation_name);
    }

    //
    function fuzzy_search_schedule(npc_id, schedule_name) {
        return t2_fuzzy_search(npc_id_to_string(npc_id), schedule_name);
    }

    //
    function why_conversation(npc_id, resource_name) {
        return t2_why(npc_id_to_string(npc_id), resource_name, true);
    }

    //
    function why_schedule(npc_id, resource_name) {
        return t2_why(npc_id_to_string(npc_id), resource_name, false);
    }

    //
    //
    function conversation_start(npc_id, conversation_name) {
        //
        {
            var value = GAME_STATS.conversations[$ conversation_name] ?? 0;
            GAME_STATS.conversations[$ conversation_name] = value + 1;
        }

        t2_conversation_start(npc_id_to_string(npc_id), conversation_name);
    }

    //
    function conversation_select_prompt(idx) {
        return t2_conversation_select_prompt(idx);
    }

    //
    function conversation_execute() {
        return self.parse_t2_output(t2_conversation_execute(CALENDAR.unified_time()));
    }


    //
    function conversation_requirement_count(conversation_name) {
        return t2_conversation_requirement_count(conversation_name);
    }

    //
    function conversation_end() {
        return array_map(t2_conversation_end(CALENDAR.unified_time()), parse_t2_action)
    }

    //
    //
    function schedule_start(npc_id, schedule_name, skip_writes=false) {
        return self.parse_t2_output(t2_schedule_start(npc_id_to_string(npc_id), schedule_name, CALENDAR.unified_time(), skip_writes));
    }

    //
    //
    function schedule_execute(npc_id, unified_time) {
        var output = t2_schedule_execute(npc_id_to_string(npc_id), unified_time);
        if output == undefined {
            return undefined;
        } else {
            return self.parse_t2_output(output);
        }
    }

    //
    function schedule_will_execute(npc_id, time) {
        return t2_schedule_will_execute(npc_id_to_string(npc_id), time);
    }

    //
    //
    function schedule_current_destination(npc_id) {
        return t2_schedule_current_destination(npc_id_to_string(npc_id));
    }

    //
    //
    function schedule_prior_destination(npc_id) {
        return t2_schedule_prior_destination(npc_id_to_string(npc_id));
    }

    //
    function schedule_current_action(npc_id) {
        return self.parse_t2_output(t2_schedule_current_action(npc_id_to_string(npc_id)));
    }

    //
    function schedule_current_action_has_arrived(npc_id) {
        return t2_schedule_current_action_has_arrived(npc_id_to_string(npc_id));
    }

    //
    function schedule_execute_any(time, date_time) {
        var output = t2_schedule_execute_any(time, date_time);
        if output == undefined {
            return undefined;
        }

        return self.parse_t2_output(output);
    }

    //
    //
    function schedule_roommate_jump(npc_id, old_time, time) {
        return array_map(
            t2_schedule_roommate_jump(
                npc_id_to_string(npc_id),
                old_time,
                time,
                CALENDAR.time,
                ROOMMATE_TIMES.go_out,
                ROOMMATE_TIMES.come_home,
            ),
            parse_t2_action,
        );
    }

    //
    function schedule_name(npc_id) {
        return t2_schedule_name(npc_id_to_string(npc_id));
    }

    //
    function schedule_reload(npc_id, schedule_name, time, had_arrived) {
        var output = t2_schedule_reload(npc_id_to_string(npc_id), schedule_name, time, had_arrived);
        if output == undefined {
            return undefined;
        } else {
            return self.parse_t2_output(output);
        }
    }

    //
    function schedule_end(npc_id, expect_early=false, skip_end_writes=false) {
        return self.parse_t2_output(
            t2_schedule_end(npc_id_to_string(npc_id), CALENDAR.unified_time(), expect_early, skip_end_writes)
        );
    }

    //
    function schedule_arrived_at_destination(npc_id, time) {
        return array_map(t2_schedule_arrived_at_destination(npc_id_to_string(npc_id), time), parse_t2_action);
    }

    //
    function schedule_serialize_expirator() {
        return t2_schedule_serialize_expirator();
    }

    //
    function schedule_deserialize_expirator(data) {
        t2_schedule_deserialize_expirator(data);
    }

    //
    function conversation_is_group(conversation_name) {
        assert(is_string(conversation_name), "{} isn't a string, so that's a crime, you go to jail now", conversation_name);
        //
        return t2_conversation_is_group(conversation_name);
    }

    //
    function npc_is_speaker_in_conversation(conversation_name, npc_id) {
        assert(is_string(conversation_name), "{} isn't a string, so that's a crime, you go to jail now", conversation_name);

        //
        return t2_npc_is_speaker_in_conversation(conversation_name, npc_id_to_string(npc_id));
    }

    //
    function conversation_names() {
        return t2_names(true);
    }

    //
    function world_fact_names() {
        return t2_world_fact_names();
    }

    //
    function schedule_names() {
        return t2_names(false);
    }

    //
    //
    //
    function write(wf_name, wf_value, expiration) {
        t2_write_world_fact(wf_name, wf_value, expiration);
    }

    function read(wf_name) {
        return t2_read_world_fact(wf_name);
    }

    function read_world() {
        return self.parse_t2_output(t2_read_world()).value;
    }

    //
    function fallback_portrait(portrait_name) {
        return self.parse_t2_output(t2_fallback_portrait(portrait_name));
    }

    //
    function tp_to_zone(tp) {
        return t2_tp_to_zone(tp);
    }

    function write_most_liked_npc() {
        //
        var most_liked_npc = 0;
        var most_liked_npc_dateable = 0;
        var most_liked_npc_hearts = -1;
        var most_liked_npc_hearts_dateable = -1;

        for (var i = 0; i < NpcId.LEN; i++) {
            var npc = NPCS[i];

            if npc.heart_level() > most_liked_npc_hearts {
                most_liked_npc = i;
                most_liked_npc_hearts = npc.heart_level();
            }

            if npc.prototype.dateable && npc.heart_level() > most_liked_npc_hearts_dateable {
                most_liked_npc_dateable = i;
                most_liked_npc_hearts_dateable = npc.heart_level();
            }
        }
        self.write("most_liked_npc", npc_id_to_string(most_liked_npc));
        self.write("most_liked_dateable", npc_id_to_string(most_liked_npc_dateable));
        self.write("most_special_human", npc_id_to_string(most_special_human()));
    }

    function parse_t2_output(raw_output) {
        switch string_to_t2_output_id(raw_output.type) {
            case T2OutputId.Names:
                return T2Output.Names(raw_output.content);
            case T2OutputId.Selected:
                return T2Output.Selected(raw_output.content);
            case T2OutputId.CannotConverse:
                return T2Output.CannotConverse;
            case T2OutputId.ConversationState:
                var txt = raw_output.content.local;

                //
                var nlb;

                switch string_to_next_line_behavior_id(raw_output.content.next_line_behavior.type) {
                    case NextLineBehaviorId.Prompts:
                        nlb = NextLineBehavior.Prompts(raw_output.content.next_line_behavior.content);
                        break;
                    case NextLineBehaviorId.NextLines:
                        nlb = NextLineBehavior.NextLines;
                        break;
                    case NextLineBehaviorId.Finish:
                        nlb = NextLineBehavior.Finish;
                        break;
                    default: impossible("unexpected next_line_behavior: {}", raw_output.content.next_line_behavior.type);
                }

                return T2Output.ConversationState(
                    raw_output.content.line_id,
                    txt,
                    array_map(raw_output.content.actions, parse_t2_action),
                    nlb,
                );
            case T2OutputId.ScheduleState:
                return T2Output.ScheduleState(raw_output.content.point, array_map(raw_output.content.actions, parse_t2_action), raw_output.content.time)
            case T2OutputId.ScheduleCurrentAction:
                return T2Output.ScheduleCurrentAction(raw_output.content.point, int64(raw_output.content.time), raw_output.content.has_arrived);
            case T2OutputId.ScheduleExecuteAny:
                return T2Output.ScheduleExecuteAny(
                    string_to_npc_id(raw_output.content.npc_id),
                    raw_output.content.point,
                    array_map(raw_output.content.on_arrival_actions, parse_t2_action),
                    array_map(raw_output.content.expiration_actions, parse_t2_action),
                    array_map(raw_output.content.on_departure_actions, parse_t2_action),
                    int64(raw_output.content.time)
                );
            case T2OutputId.ScheduleEnd:
                return T2Output.ScheduleEnd(
                    array_map(raw_output.content.on_arrival_actions, parse_t2_action),
                    array_map(raw_output.content.on_departure_actions, parse_t2_action),
                );
            case T2OutputId.Actions:
                return T2Output.Actions(array_map(raw_output.content, parse_t2_action));
            case T2OutputId.WorldFactResponse:
                return T2Output.WorldFactResponse(parse_t2_world_fact(raw_output.content));
            case T2OutputId.World:
                var obj = raw_output.content;
                var names = struct_get_names(obj);

                var output = {};
                for (var i = 0, c = array_length(names); i < c; i++) {
                    var name = names[i];

                    output[$name] = parse_t2_world_fact(obj[$ name]);
                }
                return T2Output.World(output);
            case T2OutputId.Expirator:
                return T2Output.Expirator(raw_output.content);
            case T2OutputId.PortraitFallback:
                return T2Output.PortraitFallback(raw_output.content.portrait_name, raw_output.content.effect == pointer_null ? undefined : raw_output.content.effect);
            default: impossible("unexpected t2 output_id!");
        }
    }
}

enum T2OutputId {
    Names,
    CannotConverse,
    Selected,
    Actions,

    ConversationState,
    ScheduleState,
    ScheduleCurrentAction,
    ScheduleExecuteAny,
    ScheduleEnd,

    WorldFactResponse,
    World,

    Expirator,
    PortraitFallback,
}

#macro T2Output global.__t2_output_factory
global.__t2_output_factory = new T2OutputFactory();

function T2OutputFactory() constructor {
    static Names = function(names) {
        return {
            names: names,
            type: T2OutputId.Names,
        }
    }

    static CannotConverse = {
        type: T2OutputId.CannotConverse,
    }

    static Selected = function(name) {
        return {
            name: name,
            type: T2OutputId.Selected,
        }
    }

    static ConversationState = function(line_id, local, actions, next_line_behavior) {
        return {
            line_id,
            local: local,
            actions: actions,
            next_line_behavior: next_line_behavior,
            type: T2OutputId.ConversationState,
        }
    }

    static ScheduleState = function(point, actions, time) {
        return {
            point: point,
            actions: actions,
            time: time,
            type: T2OutputId.ScheduleState,
        }
    }

    static ScheduleCurrentAction = function(point, time, has_arrived) {
        return {
            point: point,
            time: time,
            has_arrived: has_arrived,
            type: T2OutputId.ScheduleCurrentAction,
        }
    }

    static ScheduleExecuteAny = function(npc_id, point, on_arrival_actions, expiration_actions, on_departure_actions, time) {
        return {
            npc_id,
            point,
            on_arrival_actions,
            expiration_actions,
            on_departure_actions,
            time,
            type: T2OutputId.ScheduleExecuteAny,
        }
    }

    static ScheduleEnd = function(on_arrival_actions, on_departure_actions) {
        return {
            on_arrival_actions: on_arrival_actions,
            on_departure_actions: on_departure_actions,
            type: T2OutputId.ScheduleEnd,
        }
    }

    static Actions = function(actions) {
        return {
            actions: actions,
            type: T2OutputId.Actions,
        }
    }

    static WorldFactResponse = function(value) {
        return {
            value: value,
            type: T2OutputId.WorldFactResponse,
        }
    }

    static Expirator = function(values) {
        return {
            values: values,
            type: T2OutputId.Expirator,
        }
    }

    static World = function(value) {
        return {
            value: value,
            type: T2OutputId.World,
        }
    }

    static PortraitFallback = function(portrait, effect) {
        return {
            portrait: portrait,
            effect: effect,
            type: T2OutputId.PortraitFallback,
        }
    }
}

enum NextLineBehaviorId {
    Prompts,
    NextLines,
    Finish,
}

#macro NextLineBehavior global.__next_line_behavior_factory
global.__next_line_behavior_factory = new NextLineBehaviorFactory();

function NextLineBehaviorFactory() constructor {
    static Prompts = function(prompts) {
        return {
            prompts: array_map(prompts, function(v) {
                return v.local;
            }),
            type: NextLineBehaviorId.Prompts,
        }
    }

    static NextLines = {
        type: NextLineBehaviorId.NextLines,
    }

    static Finish = {
        type: NextLineBehaviorId.Finish,
    }
}

enum T2ActionId {
    Item,
    Gold,
    HeartPoints,
    Animation,
    Outfit,
    Bark,
    UnlockRecipe,
    Cutscene,
    Activity,
    Routine,
    Speaker,
    Portrait,
    Effect,
    SpokeTo,
    CanTalk,
    NoSpeaker,
    RenameSpeaker,
    Prop,
    DestroyProp,
    Blackout,
    SwapSchedule,
    Quest,
    SpawnStamina,
    UpdateStatus,
}

#macro T2Action global.__t2_action_factory
global.__t2_action_factory = new T2ActionFactory();

function T2ActionFactory() constructor {
    static Item = function(item_id, count) {
        return {
            item_id: item_id,
            count: count,
            type: T2ActionId.Item,
        }
    }

    static Gold = function(amount) {
        return {
            amount: amount,
            type: T2ActionId.Gold,
        }
    }

    static HeartPoints = function(npc, amount) {
        return {
            npc: npc,
            amount: amount,
            type: T2ActionId.HeartPoints,
        }
    }

    static Animation = function(npc, animation) {
        return {
            npc: npc,
            animation: animation,
            type: T2ActionId.Animation,
        }
    }

    static Outfit = function(npc, outfit) {
        return {
            npc: npc,
            outfit: outfit,
            type: T2ActionId.Outfit,
        }
    }

    static Barker = function(npc, bark, bubble) {
        return {
            npc: npc,
            bark: bark,
            bubble: bubble,
            type: T2ActionId.Bark,
        }
    }

    static UnlockRecipe = function(item_id) {
        return {
            recipe: item_id,
            type: T2ActionId.UnlockRecipe,
        }
    }

    static Cutscene = function(cutscene_name) {
        return {
            cutscene: cutscene_name,
            type: T2ActionId.Cutscene,
        }
    }

    static Activity = function(npc, activity_id) {
        return {
            npc: npc,
            activity_id: activity_id,
            type: T2ActionId.Activity,
        }
    }

    static Routine = function(npc, routine_id) {
        return {
            npc: npc,
            routine_id: routine_id,
            type: T2ActionId.Routine,
        }
    }

    static Speaker = function(speaker) {
        return {
            speaker: speaker,
            type: T2ActionId.Speaker,
        }
    }

    static Portrait = function(portrait) {
        return {
            portrait: portrait,
            type: T2ActionId.Portrait,
        }
    }

    static Effect = function(effect) {
        return {
            effect: effect,
            type: T2ActionId.Effect,
        }
    }

    static SpokeTo = function(npc_id) {
        return {
            npc: npc_id,
            type: T2ActionId.SpokeTo,
        }
    }

    static CanTalk = function(npc) {
        return {
            npc: npc,
            type: T2ActionId.CanTalk,
        }
    }

    static RenameSpeaker = function(new_name) {
        return {
            name: new_name,
            type: T2ActionId.RenameSpeaker,
        }
    }

    static Prop = function(point_name, location_id) {
        return {
            point_name,
            location_id: string_to_location_id(location_id),
            type: T2ActionId.Prop,
        }
    }

    static DestroyProp = function(point_name, location_id) {
        return {
            point_name,
            location_id: string_to_location_id(location_id),
            type: T2ActionId.DestroyProp,
        }
    }

    static Blackout = function(frames) {
        return {
            frames,
            type: T2ActionId.Blackout,
        }
    }

    static SwapSchedule = function(npc, schedule, finish) {
        return {
            schedule,
            finish,
            npc: string_to_npc_id(npc),
            type: T2ActionId.SwapSchedule,
        }
    }

    static Quest = function(quest_name) {
        return {
            quest_name,
            type: T2ActionId.Quest
        }
    }

    static SpawnStamina = function(stamina) {
        return {
            stamina,
            type: T2ActionId.SpawnStamina,
        }
    }

    static UpdateStatus = function(npc, status) {
        return {
            npc,
            status,
            type: T2ActionId.UpdateStatus,
        }
    }

    static NoSpeaker = {
        type: T2ActionId.NoSpeaker,
    }
}

//
function parse_t2_action(raw_action) {
    var c = raw_action[$ "content"];

    switch string_to_t2_action_id(raw_action.type) {
        case T2ActionId.Item:
            return T2Action.Item(string_to_item_id(c.item_id), c.count);
        case T2ActionId.Gold:
            return T2Action.Gold(c);
        case T2ActionId.HeartPoints:
            return T2Action.HeartPoints(opt_and_then(c.npc, string_to_npc_id), c.amount);
        case T2ActionId.Animation:
            return T2Action.Animation(opt_and_then(c.npc, string_to_npc_id), c.animation);
        case T2ActionId.Outfit:
            return T2Action.Outfit(opt_and_then(c.npc, string_to_npc_id), c.outfit);
        case T2ActionId.Bark:
            return T2Action.Barker(opt_and_then(c.npc, string_to_npc_id), string_to_bark_id(c.bark), string_to_bark_type(c.bubble));
        case T2ActionId.UnlockRecipe:
            return T2Action.UnlockRecipe(string_to_item_id(c));
        case T2ActionId.Cutscene:
            return T2Action.Cutscene(c);
        case T2ActionId.Activity:
            return T2Action.Activity(opt_and_then(c.npc, string_to_npc_id), string_to_activity(c.activity_id));
        case T2ActionId.Routine:
            return T2Action.Routine(opt_and_then(c.npc, string_to_npc_id), try_string_to_routine(c.routine_id));
        case T2ActionId.Speaker:
            return T2Action.Speaker(c);
        case T2ActionId.Portrait:
            return T2Action.Portrait(c);
        case T2ActionId.Effect:
            return T2Action.Effect(c);
        case T2ActionId.SpokeTo:
            return T2Action.SpokeTo(opt_and_then(c, string_to_npc_id));
        case T2ActionId.CanTalk:
            return T2Action.CanTalk(opt_and_then(c, string_to_npc_id));
        case T2ActionId.NoSpeaker:
            return T2Action.NoSpeaker;
        case T2ActionId.RenameSpeaker:
            return T2Action.RenameSpeaker(c);
        case T2ActionId.Prop:
            return T2Action.Prop(c.point_name, c.location_id);
        case T2ActionId.DestroyProp:
            return T2Action.DestroyProp(c.point_name, c.location_id);
        case T2ActionId.Blackout:
            return T2Action.Blackout(c);
        case T2ActionId.Quest:
            return T2Action.Quest(c);
        case T2ActionId.SpawnStamina:
            return T2Action.SpawnStamina(c);
        case T2ActionId.UpdateStatus:
            return T2Action.UpdateStatus(string_to_npc_id(c.npc), c.status);
        case T2ActionId.SwapSchedule:
            return T2Action.SwapSchedule(c.npc, c.schedule, c.finish);
        default: impossible("unexpected type: {}", raw_action.type);
    }
}

//
function parse_t2_world_fact(raw_wf) {
    switch raw_wf.type {
        case "string":
            return string(raw_wf.content);
        case "float":
            //
            //
            //
            return real(raw_wf.content ?? 0);
        case "undefined":
            return undefined;
        case "i64":
            return int64(raw_wf.content);
        default: impossible("unexpected {}", raw_wf.type);
    }
}

function process_t2_action(action, current_npc_id, ctx) {
    //
    //
    static BANNED_ROOMMATE_ACTIONS = [
        T2ActionId.Animation,
        T2ActionId.Outfit,
        T2ActionId.Activity,
        T2ActionId.Routine,
    ];
    if array_contains(BANNED_ROOMMATE_ACTIONS, action.type) {
        var npc = NPCS[action.npc ?? current_npc_id];
        if npc.at_farm() && npc.is_roommate() {

            //
            if action.type != T2ActionId.Routine
                || action.routine_id != string_to_routine(format("{NpcId}_roommate", npc.id))
            {
                return;
            }
        }
    }

    switch action.type {
        case T2ActionId.Item:
            if action.count > 0 {
                if action.item_id == ItemId.Purse {
                    var li = new LiveItem(action.item_id);
                    li.gold_to_gain = action.count;
                    ARI.give_item(li);
                } else {
                    for (var i = 0; i < action.count; i++) {
                        ARI.give_item(action.item_id);
                    }
                }
            } else if action.count < 0 {
                ARI.inventory.remove(action.item_id, action.count);
            }
            break;
        case T2ActionId.Gold:
            ARI.modify_gold(action.amount);
            array_push(GAME_STATS.income, {
                type: "t2",
                amount: action.amount,
                day: total_days(),
            });
            break;
        case T2ActionId.HeartPoints:
            var npc_id = action.npc ?? current_npc_id;

            if !((npc_id == NpcId.Caldarus || npc_id == NpcId.Seridia) && npc.heart_level() < 6) {
                NPCS[npc_id].add_heart_points(action.amount);
            }
            break;
        case T2ActionId.Animation:
            var npc_id = action.npc ?? current_npc_id;
            var npc = NPCS[action.npc ?? current_npc_id];
            if npc.can_perform_animation(action.animation) {
                npc.set_animation(action.animation);
            }
            break;
        case T2ActionId.Outfit:
            var npc_id = action.npc ?? current_npc_id;
            var npc = NPCS[npc_id];
            npc.wardrobe.set_outfit(action.outfit);

            //
            if !npc.wardrobe.outfit_current.cycles.contains_key(npc.animation) {
                npc.set_animation("idle");
            } else {
                npc.set_animation(npc.animation);
            }

            break;
        case T2ActionId.Bark:
            var npc_id = action.npc ?? current_npc_id;
            var obj = npc_id_to_gm_obj_id(npc_id);
            if instance_exists(obj) {
                obj.bark_emitter.emit(
                    action.bark,
                    action.bubble,
                );
            }
            break;
        case T2ActionId.UnlockRecipe:
            ARI.unlock_recipe(action.recipe);
            break;
        case T2ActionId.Cutscene:
            MIST.request_scene(action.cutscene);
            //
            with npc_id_to_gm_obj_id(current_npc_id) {
                self.fsm.change_state_instant(NpcState.Dummy);
            }
            break;
        case T2ActionId.Activity:
            var npc_id = action.npc ?? current_npc_id;
            var npc = NPCS[npc_id];
            npc.activity_handler.request_activity(action.activity_id);
            break;
        case T2ActionId.Routine:
            var npc_id = action.npc ?? current_npc_id;
            var npc = NPCS[npc_id];
            if action.routine_id == undefined {
                npc.activity_handler.reset();
            } else {
                npc.activity_handler.set_routine(action.routine_id);
            }
            break;
        case T2ActionId.Speaker:
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            if textbox == undefined {
                warn("tried to execute an action that required a textbox, but textbox not visible!");
                return;
            }

            var is_cameo = try_string_to_cameo_id(action.speaker) != undefined;
            var speaker = is_cameo
                ? new CameoSpeaker(string_to_cameo_id(action.speaker))
                : new NpcSpeaker(string_to_npc_id(action.speaker));
            textbox.requested_speaker = speaker;
            break;
        case T2ActionId.Portrait:
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            if textbox == undefined {
                warn("tried to execute an action that required a textbox, but textbox not visible!");
                return;
            }

            var portrait = action.portrait;
            var npc = try_string_to_npc_id(textbox.requested_speaker.id);
            if npc != undefined && NPCS[npc].held_child() != undefined {
                var child_fallbacks  = NPC_PROTOTYPES[npc].child_fallbacks;
                var fallback = child_fallbacks[action.portrait];
                if fallback != undefined {
                    portrait = fallback;
                }
            }

            textbox.requested_speaker.set_portrait(portrait);
            break;
        case T2ActionId.Effect:
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            if textbox == undefined {
                warn("tried to execute an action that required a textbox, but textbox not visible!");
                return;
            }

            //
            //
            textbox.requested_speaker.effect = action.effect;
            break;
        case T2ActionId.NoSpeaker:
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            if textbox == undefined {
                warn("tried to execute an action that required a textbox, but textbox not visible!");
                return;
            }
            textbox.requested_speaker = undefined;
            ctx.is_info_line = true;

            break;
        case T2ActionId.RenameSpeaker:
            impossible("we don't use this and it's been deimplemented!");
            break;
        case T2ActionId.SpokeTo:
            var npc_id = action.npc ?? current_npc_id;
            if MIST.running {
                return;
            }
            var npc = NPCS[npc_id];

            //
            if npc.talk_flag {
                npc.talk_flag = false;

                if npc.times_spoken_today == 0 && !((npc_id == NpcId.Caldarus || npc_id == NpcId.Seridia) && npc.heart_level() < 6) {
                    npc.add_heart_points(fiddle_get("misc/daily_hearts_for_speaking"));
                }
                npc.times_spoken_today += 1;
                npc.set_has_met();

                GAME_STATS.npcs_spoken_to[$ npc_id_to_string(npc_id)] += 1;
            }
            break;
        case T2ActionId.CanTalk:
            var npc_id = action.npc ?? current_npc_id;
            NPCS[npc_id].talk_flag = true;
            break;
        case T2ActionId.Prop:
            PROPS.create_prop(action.point_name, action.location_id);
            break;
        case T2ActionId.DestroyProp:
            PROPS.destroy_prop(action.point_name, action.location_id);
            break;
        case T2ActionId.Quest:
            QUEST_LOG.start(action.quest_name);
            create_quest_popup(action.quest_name);
            break;
        case T2ActionId.SpawnStamina:
            var chain = new_world_chain(obj_ari, CURRENT_LOCATION_ID)
            var amount = action.stamina div 10;
            repeat amount {
               chain.append(LinkId.Function, function() {
                    var inst = create_morsel(
                        obj_ari.x + irandom_range(-4, 4),
                        obj_ari.y + irandom_range(-4, 4),
                        irandom_range(12, 32),
                        MorselType.Stamina,
                        irandom(MorselSize.LEN - 1),
                        10,
                        obj_ari.y,
                    );
                    inst.z = -16;
                })
                chain.append(LinkId.Timer, 10);
            }
            break;
        case T2ActionId.UpdateStatus:
            T2R.write(format("{NpcId}_status", action.npc), action.status);
            NPCS[action.npc].report_relationship();
            break;
        case T2ActionId.Blackout:
            var textbox = ANCHOR.get_menu(Menu.Textbox);
            if textbox == undefined {
                warn("tried to execute an action that required a textbox, but textbox not visible!");
                return;
            }
            textbox.blackout_frames = action.frames;
            break;
        case T2ActionId.SwapSchedule:
            var npc = NPCS[action.npc];

            var requested_schedule = action.schedule ?? T2R.request_schedule(action.npc);

            if IN_NPC_TIME_JUMP || npc.location_position.location_id != CURRENT_LOCATION_ID {
                perform_schedule_swap(action.npc, requested_schedule, action.finish, CALENDAR.unified_time());
            } else {
                npc.swap_schedule_request = {
                    schedule_name: requested_schedule,
                    finish: action.finish,
                };
            }

            break;
        default: impossible("Unexpected T2ActionId: {}", action.type);
    }
}

enum WorldFactId {
    String,
    Float,
    I64,
    Undefined,
}

#macro WorldFact global.__world_fact_factory
global.__world_fact_factory = new WorldFactFactory();

function WorldFactFactory() constructor {
    static String = function(str) {
        return {
            content: string(str),
            type: WorldFactId.String,
        }
    }

    static Float = function(f) {
        return {
            content: real(f),
            type: WorldFactId.Float,
        }
    }

    static I64 = function(i) {
        return {
            content: int64(i),
            type: WorldFactId.I64,
        }
    }

    static Undefined = {
        type: WorldFactId.Undefined,
    }
}

enum ConversationKind {
    Normal,
    Gift,
    GameplayTriggered,
    DateAcceptance,
}

//
function perform_schedule_swap(npc_id, schedule_name, finish, time_target) {
    trace("Swapping {NpcId} to {} + mini-jump to {Time} (finish: {bool})", npc_id, schedule_name, time_target, finish);

    //
    //
    if finish {
        while true {
            if T2R.schedule_current_action_has_arrived(npc_id) == false {
                var arrival_actions = T2R.schedule_arrived_at_destination(npc_id, hours(26));
                for (var i = 0; i < array_length(arrival_actions); i++) {
                    process_t2_action(arrival_actions[i], npc_id);
                }
            }

            var output = T2R.schedule_execute(npc_id, CALENDAR.time + hours(26));
            if output == undefined {
                break;
            }

            //
            for (var i = 0; i < array_length(output.actions); i++) {
                process_t2_action(output.actions[i], npc_id);
            }
        }

        //
        //
        //
        //
        //
        T2R.schedule_end(npc_id, false, true);
    }

    //
    var npc = NPCS[npc_id];
    npc.set_animation("idle");
    npc.activity_handler.reset();
    npc.simulated_distance_traveled = 0;
    interrupt_npc(npc);

    //
    //
    npc.schedule_name = schedule_name;
    T2R.schedule_start(npc_id, schedule_name, true);

    //
    //
    if finish == false {
        while true {
            //
            if T2R.schedule_current_action_has_arrived(npc_id) == false {
                var arrival_actions = T2R.schedule_arrived_at_destination(npc_id, time_target);
                for (var i = 0; i < array_length(arrival_actions); i++) {
                    process_t2_action(arrival_actions[i], npc_id);
                }
            }

            var output = T2R.schedule_execute(npc_id, time_target);
            if output == undefined {
                break;
            }

            //
            for (var i = 0; i < array_length(output.actions); i++) {
                process_t2_action(output.actions[i], npc_id);
            }
        }
    }

    //
    var new_item = T2R.schedule_current_action(npc_id);
    var start_time = new_item.time;
    var target = trellis_point_location_position(new_item.point);
    var departure = T2R.schedule_prior_destination(npc_id);
    npc.location_position = departure != undefined
        ? trellis_point_location_position(departure)
        : target;

    //
    if npc.location_position.location_id == LocationId.Aldaria {
        //
        npc.location_position = roommate_home_position(npc);

        for (var i = 0; i < array_length(ARI.children); i++) {
            var child = ARI.children[i];
            if child.location != ChildLocation.WithAri {
                child.set_location(ChildLocation.WithSpouse);
                break;
            }
        }

        npc.activity_handler.set_routine(string_to_routine(format("{NpcId}_roommate", npc_id)));
        npc.talk_flag = true;
    } else {
        //
        var itinerary = PATHFINDING.calculate_map_path(npc.location_position, target);
        start_schedule_pathfind(npc.brain.blackboard, target);
        simulate_pathfind(npc_id, start_time, time_target, itinerary);

        for (var i = 0; i < array_length(ARI.children); i++) {
            if ARI.children[i].location == ChildLocation.InCradle {
                ARI.children[i].set_location(ChildLocation.WithSpouse);
            }
        }
    }
}
