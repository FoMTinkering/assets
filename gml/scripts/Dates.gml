#macro DATES global.__dates
DATES = undefined;

#macro DATE_PHOTOS global.__date_photos
DATE_PHOTOS = undefined;

#macro DATE_PHOTO_REQUEST global.__date_photo_request
DATE_PHOTO_REQUEST = undefined;

#macro DATE_PHOTO_ASSET global.__date_photo_asset
DATE_PHOTO_ASSET = -1;

#macro ELIGIBLE_DATE_DAYS global.__eligible_date_days
ELIGIBLE_DATE_DAYS = undefined;

#macro ELIGIBLE_DATE_STATUSES global.__eligible_date_statuses
ELIGIBLE_DATE_STATUSES = undefined;

function load_dates() {
    var output = array_create(Date.LEN, undefined);
    var f_data = filter_toml_nulls(clone_value(fiddle_get("dates")));
    var def = f_data[$ "default"];
    for (var i = 0; i < Date.LEN; i++) {
        var date = clone_value(def);
        patch_object(f_data[$ date_to_string(i)], date);

        date.icon = try_string_to_asset(date.icon);
        date.unlock_sprite = try_string_to_asset(date.unlock_sprite);
        date.photo_item = string_to_item_id(date.photo_item);
        date.random_item_reward = apply_func(date.random_item_reward, string_to_item_id);
        var npc_visuals = date.npc_visuals;
        var keys = struct_get_names(npc_visuals);
        date.npc_visuals = array_create_ext(NpcId.LEN, function(_) {
            return {
                expression: "neutral",
                frame: 0,
                outfit: undefined,
            };
        });
        for (var j = 0; j < array_length(keys); j++) {
            var npc = string_to_npc_id(keys[j]);
            var entry = npc_visuals[$ keys[j]];
            var target = date.npc_visuals[npc];
            target.expression = entry[$ "expression"] ?? target.expression;
            target.frame = entry[$ "frame"] ?? target.frame;
            target.outfit = entry[$ "outfit"] ?? target.outfit;
        }
        CONTENT_REGISTRY.validate_cutscene(date.cutscene);

        output[i] = date;
    }

    return output;
}

function clear_loaded_date_photos() {
    for (var i = 0; i < array_length(DATE_PHOTOS);  i++) {
        var photo = DATE_PHOTOS[i];
        if photo.photo_decompressed != undefined
            && photo.photo_decompressed != spr_nothing
        {
            try {
                animation_remove(photo.photo_decompressed);
            } catch(e) {
                error("Failed to remove date photo from VRAM: {}", e);
            }

            photo.photo_decompressed = undefined;
        }
    }
}

function date_selection_ui(npc_id) {
    var popup = popup_creator("misc_local/select_a_date");
    popup.backplate.set_height(190);
    popup.backplate.add_width(70);

    var scroller = create_scroller(
        popup.backplate,
        Vec2(10, 36),
        Vec2(217, 140),
    );
    scroller.outline.enable();
    scroller.subscribe_to_pilot(popup.pilot);

    var order = ListFromArray(array_create_ext(Date.LEN, function(i) {
        return i;
    }));

    order.sort_with(function(a, b) {
        var a_unlocked = ARI.date_unlocks[a];
        var b_unlocked = ARI.date_unlocks[b];
        if a_unlocked && b_unlocked {
            return string_alphanumeric_comparison(local_get(DATES[a].name), local_get(DATES[b].name));
        } else if a_unlocked {
            return -1;
        } else {
            return 1;
        }
    });

    for (var i = 0; i < order.count(); i++) {
        var date = order.get(i);
        var data = DATES[date];
        if data.unlisted {
            continue;
        }
        var element = scroller.new_element(26)
            .add_to_pilot(popup.pilot, true)
            .set_label(date_to_string(date))
            .set_tap_callback(function(npc_id, date, popup) {
                popup.close();

                await_popup(run_date, [date, npc_id]);
            }, [npc_id, date, popup])
        var icon = ANCHOR.sprite(element)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(3)
            .set_sprite(data.icon)
        var text = ANCHOR.text(icon)
            .set_lut(COMMON_LUT)
            .set_align(Align.RightOut, Align.Middle)
            .set_x(2)
            text.set_key(data.name)

        if !ARI.date_unlocks[date] {
            icon.set_color(c_black);
            text.set_text("???");
            element.set_soft_locked();
        }
    }

    popup.spawn();

    ANCHOR.set_active_pilot(popup.pilot);

    return popup;
}

//
function new_date_popup(date_id) {
    var date = DATES[date_id];
    var ribbon_key = "misc_local/new_date";
    var popup = popup_creator();

    popup.add_title(date.name);

    popup.backplate.set_size(211, 213);

    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 36)

    popup.image = ANCHOR.sprite(popup.header)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(6)
        .set_sprite(date.unlock_sprite)

    popup.text = ANCHOR.text(popup.image)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(3)
        .set_lut(COMMON_LUT)
        .allow_line_breaks()
        .set_text_align(TextAlign.Center)
        .set_key(date.description)

    popup.create_button("misc_local/close");

    var ribbon = ANCHOR.nine_slice(popup.header)
        .set_sprite(spr_ui_tooltip_new_item_ribbon_box)
        .set_size(30, 20)
        .set_y(-14)

    ANCHOR.sprite(ribbon)
        .set_sprite(spr_ui_tooltip_new_item_ribbon_left)
        .set_align(Align.LeftOut, Align.Middle)

    var new_text = wavy_text(ribbon, ribbon_key, COMMON_LUT, CommonLutIndex.BlackOnYellow, 1)
        .set_align(Align.LeftIn, Align.Middle)

    ribbon.set_width(new_text.get_width() + 4)

    TANGO.play("SoundEffects/NPCs/DialogSparkle");

    popup.spawn();
}

function run_date(date, npc) {
    T2R.write("date", date_to_string(date));
    var date_convo = T2R.request_conversation(npc, ConversationKind.DateAcceptance);
    T2R.write("date", undefined);

    with npc_id_to_gm_obj_id(npc) {
        self.fsm.change_state_instant(NpcState.Dummy);

        //
        obj_ari.face_dir(point_direction(obj_ari.x, obj_ari.y, self.x, self.y));
        obj_ari.set_idle_simple();
    }

    play_conversation(npc, date_convo, function(_, npc, date) {
        start_date_cutscene(npc, date);
    }, [npc, date]);
}

function start_date_cutscene(npc, date) {
    var data = DATES[date];
    MIST.blackboard.set("date_partner", npc_id_to_string(npc));
    MIST.blackboard.set("date", date);
    MIST.blackboard.set("outfit", outfit_for_date(npc, date, CALENDAR.time));

    //
    var item = undefined;
    var prop_sprite = undefined;
    if date == Date.Park {
        //
        var items = List();
            for (var i = 0; i < ObjectId.LEN; i++) {
                if object_id_to_object_category(i) == ObjectCategory.Crop {
                    var proto = NODE_PROTOTYPES[i];
                    if ITEM_PROTOTYPES[proto.harvest].tags.contains("flower")
                        && !ITEM_PROTOTYPES[proto.harvest].tags.contains("mines_forageable")
                        && proto.seasons[CALENDAR.season()]
                    {
                        items.push(proto.harvest);
                    }
                }
            }

            item = items.choose_random();

            prop_sprite = spr_flower_tulip_stage4; //
            for (var i = 0; i < ObjectId.LEN; i++) {
                var proto = NODE_PROTOTYPES[i];
                if proto[$ "harvest"] == item {
                    prop_sprite = proto.sprites[array_length(proto.sprites) - 1];
                    break;
                }
            }

    } else if !array_is_empty(data.random_item_reward) {
        item = ListFromArray(data.random_item_reward).choose_random();
        prop_sprite = ITEM_PROTOTYPES[item].icon_sprite;
    }

    MIST.blackboard.insert("prop_sprite", prop_sprite);
    MIST.run_scene(data.cutscene);

    new_chain().append(LinkId.Await, function(npc, date, item) {
        if MIST.is_running() {
            return false;
        }

        //
        //
        //
        if CUTSCENES.get(DATES[date].cutscene).ends_day && ANCHOR.get_menu(Menu.Eod) == undefined {
            return false;
        }

        NPCS[npc].add_heart_points(fiddle_get("misc/date_heart_points"));
        process_t2_action(T2Action.CanTalk(npc), npc);

        //
        if date == Date.Bathhouse {
            ARI.set_health(ARI.get_max_health());
            ARI.set_stamina(ARI.get_max_stamina());
            ARI.modify_mana(2);
        }

        //
        if DATES[date].unlisted && !NPCS[npc].is_partner() {
            return true;
        }

        var listings = List();
        var photo_card = undefined;
        if !ari_has_photo_for(npc, date) {
            photo_card = new LiveItem(DATES[date].photo_item);
            photo_card.date_photo = array_length(DATE_PHOTOS) - 1;
            listings.push(Listing.Item(photo_card));
            ARI.give_item(photo_card);
        }

        if item != undefined {
            listings.push(Listing.Item(item));
            ARI.give_item(item);
        }

        array_push(ARI.date_history, {
            date,
            npc,
            timestamp: CALENDAR.time,
        });

        var popup = __base_quest_popup(
            DATES[date].name,
            "misc_local/date_completed",
            listings,
            render_quest_reward,
        );

        var button = popup.create_button("misc_local/close");

        popup.pilot.force_select(button);

        popup.spawn();

        if photo_card != undefined {
            await_popup(spawn_date_photo, [photo_card.date_photo]);
        }

        return true;
    }, [npc, date, item]);
}

function outfit_for_date(npc, date, time) {
    if date == Date.Beach && get_seasons(time) == Season.Summer {
        return "beach";
    }
    var visuals = DATES[date].npc_visuals[npc];
    return visuals.outfit ?? NPC_PROTOTYPES[npc].get_suitable_outfit_key(NPCS[npc].wardrobe, time)
}

function ari_eligible_for_date(npc, time_to_check) {
    time_to_check = time_to_check == undefined ? CALENDAR.time : time_to_check;

    for (var i = 0; i < array_length(ARI.date_history); i++) {
        var v = ARI.date_history[i];
        if DATES[v.date].unlisted {
            continue;
        }
        if time_to_check == v.timestamp
            || (v.npc == npc && time_to_check - v.timestamp < days(6))
        {
            return false;
        }
    }

    var festival_today = undefined;
    for (var i = 0; i < FestivalId.LEN; i++) {
        var festival = FESTIVALS[i];
        var is_today = festival.prototype.implemented
            && get_seasons(time_to_check) == festival.prototype.date.season
            && get_days(time_to_check) == festival.prototype.date.day - 1
            && !CANCEL_FESTIVALS;
        if is_today {
            festival_today = i;
            break;
        }
    }

    return array_contains(ARI.date_unlocks, true)
        && array_contains(ELIGIBLE_DATE_DAYS, get_days(time_to_check) % Day.LEN)
        && (festival_today == undefined || FESTIVALS[festival_today].prototype.date == undefined);
}

function npc_date_eligibility(time_to_check) {
    var output = array_create(NpcId.LEN, false);
    for (var i = 0; i < NpcId.LEN; i++) {
        output[i] = NPCS[i].can_go_on_dates() && ari_eligible_for_date(i, time_to_check);
    }
    return output;
}

function ari_has_photo_for(npc, date) {
    for (var i = 0; i < array_length(ARI.date_history); i++) {
        var v = ARI.date_history[i];
        if v.npc == npc && v.date == date {
            return true;
        }
    }
    return false;
}

function spawn_date_photo(index) {
    static SIZE = fiddle_get("misc/date_photo_size");

    if index == undefined || index == -1 || index >= array_length(DATE_PHOTOS) {
        data = {
            date: Date.InnMeal,
            npc: some_romantic_npc(),
            photo: "",
            photo_decompressed: spr_nothing,
            timestamp: CALENDAR.time,
        };
    } else {
        data = DATE_PHOTOS[index];
    }

    //
    if data.photo_decompressed == undefined {
        data.photo_decompressed = animation_decompress(data.photo, SIZE[0], SIZE[1]);
    }

    var popup = popup_creator(ANCHOR.wrap_for_local(format(
        local_get(DATES[data.date].photo_title),
        local_get(NPC_PROTOTYPES[data.npc].name),
    )));

    popup.backplate.set_size(232, 238);
    popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 24);

    var photo = ANCHOR.sprite(popup.header)
        .set_align(Align.Center, Align.BottomOut)
        .set_sprite(data.photo_decompressed)
        .set_color(make_color_rgb(200, 200, 200))
        .set_y(-1);

    var date = DATES[data.date];

    var outfit = NPCS[data.npc].wardrobe.outfits.get(outfit_for_date(data.npc, data.date, data.timestamp));
    var visuals = date.npc_visuals[data.npc];
    var sprite = outfit.portraits.get(visuals.expression);

    var position = NPC_PROTOTYPES[data.npc].date_photo_offset;
    ANCHOR.sprite(photo)
        .set_sprite(sprite)
        .set_align(Align.Center, Align.BottomIn)
        .set_index(visuals.frame)
        .set_x(position[0], position[1])

    ANCHOR.text(photo)
        .set_align(Align.Center, Align.BottomOut)
        .set_y(3)
        .set_lut(COMMON_LUT)
        .set_text(format(
            local_get("misc_local/formatted_date_string"),
            local_get(format("misc_local/{Season}", get_seasons(data.timestamp))),
            get_days(data.timestamp) + 1,
            get_years(data.timestamp) + 1,
        ))

    popup.create_button("misc_local/close");

    popup.spawn();
}

function save_date_photo(npc, date_id, date_sprite) {
    var photo = undefined;
    var photo_decompressed = undefined;
    if date_sprite != undefined {
        photo = animation_compress(date_sprite);
        animation_remove(date_sprite);
    } else {
        photo = "";
        photo_decompressed = spr_nothing;
    }

    array_push(DATE_PHOTOS, {
        photo,
        photo_decompressed,
        npc,
        timestamp: CALENDAR.time,
        date: date_id,
    });
}
