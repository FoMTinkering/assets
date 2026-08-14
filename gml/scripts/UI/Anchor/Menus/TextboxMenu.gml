#macro TEXTBOX_Y -5
#macro TEXTBOX_WIDTH 374
#macro TEXTBOX_HEIGHT 60
#macro TEXTBOX_MIN_WIDTH 16
#macro TEXTBOX_MIN_HEIGHT 16
#macro PORTRAIT_X -90
#macro PORTRAIT_Y -65
#macro PORTRAIT_X_OFFSET 30
#macro TEXT_Y 4
#macro EASE_LENGTH 12
#macro TEXTBOX_NAMEBOX_BACK_PADDING 25

enum TextboxDepthLevel {
    PromptTabNumber,
    PromptTab,
    PromptText,
    PromptBox,
    PromptCanvas,
    Heart,
    HeartBackplate,
    NameboxText,
    NameboxFront,
    NameboxBack,
    Blinky,
    Text,
    TextCanvas,
    Textbox,
    PortraitEffect,
    Portrait,
}

enum TextboxState {
    //
    Hidden,
    //
    Ready,
    //
    Say,
    //
    Ask,
    //
    Info,
    //
    Blackout,
    //
    Translating,
}

function filter_text_for_textbox(input_text) {
    //
    var tags = find_info_tags(input_text);
    for (var i = 0; i < array_length(tags); i++) {
        var tag = tags[i];
        var str = undefined;

        //
        //
        //
        switch string_lower(tag) {
            case "ari":
                str = ARI.name;
                break;
            case "bathhouse_cost":
                str = num_display(ARI.get_bathhouse_cost());
                break;
            case "inn_soup_of_the_day":
                str = string(soup_of_the_day());
                break;
            case "farm_name":
                str = ARI.farm_name;
                break;
            case "animal_name":
                assert_neq(BREEDING_ANIMAL_CTX.animal_name, undefined, "line needed `ANIMAL_NAME` but it wasn't defined!");
                str = BREEDING_ANIMAL_CTX.animal_name;
                break;
            case "animal_pair":
                assert_neq(BREEDING_ANIMAL_CTX.animal_pair, undefined, "line needed `ANIMAL_PAIR` but it wasn't defined!");
                str = BREEDING_ANIMAL_CTX.animal_pair;
                break;
            case "breeding_partner":
                assert_neq(BREEDING_ANIMAL_CTX.breeding_partner, undefined, "line needed `BREEDING_PARTNER` but it wasn't defined!");
                str = BREEDING_ANIMAL_CTX.breeding_partner;
                break;
            case "treat_item":
                assert_neq(BREEDING_ANIMAL_CTX.treat_item, undefined, "line needed `TREAT_ITEM` but it wasn't defined!");
                str = BREEDING_ANIMAL_CTX.treat_item;
                break;
            case "offering_item_count":
                assert_neq(OFFERING_ITEM_COUNT, undefined, "OFFERING_ITEM_COUNT wasn't defined!");
                str = OFFERING_ITEM_COUNT;
                break;
            case "offering_item_name":
                assert_neq(OFFERING_ITEM_NAME, undefined, "OFFERING_ITEM_NAME wasn't defined!");
                str = OFFERING_ITEM_NAME;
                break;
            case "statue_cost_low":
                assert_neq(STATUE_CTX, undefined, "STATUE_CTX wasn't defined!");
                str = string(fiddle_get(format("misc/{}/low_price", STATUE_CTX)));
                break;
            case "statue_cost_high":
                assert_neq(STATUE_CTX, undefined, "STATUE_CTX wasn't defined!");
                str = string(fiddle_get(format("misc/{}/high_price", STATUE_CTX)));
                break;
            case "essence_charge":
                assert_neq(ESSENCE_CHARGE, undefined, "line needed `ESSENCE_CHARGE` but it wasn't defined!");
                str = ESSENCE_CHARGE;
                break;
            case "festival_small_animal_type":
                str = local_get(T2R.read("small_animal_festival_type"));
                break;
            case "festival_small_animal_name":
                str = T2R.read("small_animal_festival_name");
                break;
            case "festival_large_animal_type":
                str = local_get(T2R.read("large_animal_festival_type"));
                break;
            case "festival_large_animal_name":
                str = T2R.read("large_animal_festival_name");
                break;
            case "pet_name":
                str = PET.name;
                break;
            case "pet_type":
                var kind = local_get(format("misc_local/{PetKind}", PET.pet_kind()));
                str = string_lower(kind);
                break;
            case "elsie_romantic_npc":
                var npc = some_romantic_npc();
                if npc == NpcId.Caldarus {
                    str = local_get("misc_local/someone_named_caldarus");
                } else {
                    str = local_get(NPC_PROTOTYPES[npc].name);
                }
                break;
            case "factory_days_remaining":
                str = string(int64(FACTORY_INSPECT_CTX));
                break;
            case "factory_item_request":
                str = local_get(ITEM_PROTOTYPES[FACTORY_INSPECT_CTX].name_key);
                break;
            case "currently_held_item":
                str = local_get(ARI.held_item().prototype.name_key);
                break;
            case "child_0":
                str = array_length(ARI.children) > 0 ? ARI.children[0].name : "MISSING";
                break;
            case "child_1":
                str = array_length(ARI.children) > 1 ? ARI.children[1].name : "MISSING";
                break;
            case "infant":
                str = "MISSING";
                for (var j = 0; j < array_length(ARI.children); j++) {
                    var child = ARI.children[j];
                    if child.stage == ChildStage.Infant {
                        str = child.name;
                        break;
                    }
                }
                break;
            case "toddler":
                str = "MISSING";
                for (var j = 0; j < array_length(ARI.children); j++) {
                    var child = ARI.children[j];
                    if child.stage == ChildStage.Toddler {
                        str = child.name;
                        break;
                    }
                }
                break;
            case "child":
                str = "MISSING";
                if !array_is_empty(ARI.children) {
                    var child = ARI.children[irandom(array_length(ARI.children) - 1)];
                    str = child.name;
                }
                break;
            case "child_held_by_ari":
                str = "MISSING";
                for (var j = 0; j < array_length(ARI.children); j++) {
                    var child = ARI.children[j];
                    if child.location == ChildLocation.WithAri {
                        str = child.name;
                        break;
                    }
                }
                break;
            case "child_held_by_spouse":
                str = "MISSING";
                for (var j = 0; j < array_length(ARI.children); j++) {
                    var child = ARI.children[j];
                    if child.location == ChildLocation.WithSpouse {
                        str = child.name;
                        break;
                    }
                }
                break;
            case "ten_heart_romantic":
                str = "MISSING";
                for (var j = 0; j < NpcId.LEN; j++) {
                    if NPCS[j].is_partner() && NPCS[j].heart_level() == 10 {
                        str = local_get(NPC_PROTOTYPES[j].name);
                    }
                }
                break;
            case "fiance":
                str = "MISSING";
                for (var j = 0; j < NpcId.LEN; j++) {
                    if NPCS[j].is_fiance() {
                        str = local_get(NPC_PROTOTYPES[j].name);
                        break;
                    }
                }
                break;
            case "spouse":
                str = "MISSING";
                for (var j = 0; j < NpcId.LEN; j++) {
                    if NPCS[j].is_spouse() {
                        str = local_get(NPC_PROTOTYPES[j].name);
                        break;
                    }
                }
                break;
            case "most_eaten_dish":
                str = local_get(ITEM_PROTOTYPES[ItemId.WildBerries].name_key);
                var eaten = GAME_STATS.items_eaten;
                var eaten_counts = array_create(ItemId.LEN, 0);
                var is_dish = array_create(ItemId.LEN, undefined);
                var best_item = undefined;
                var best_count = 0;

                for (var j = 0, c = array_length(GAME_STATS.items_eaten); j < c; j++) {
                    var eaten_id = try_string_to_item_id( GAME_STATS.items_eaten[j].item);
                    if eaten_id == undefined {
                        continue;
                    }

                    var dish = is_dish[eaten_id];
                    if dish == undefined {
                        var eaten_proto = ITEM_PROTOTYPES[eaten_id];
                        dish = eaten_proto.tags.contains("food");
                        is_dish[eaten_id] = dish;
                    }
                    if !dish {
                        continue;
                    }

                    var eaten_count = eaten_counts[eaten_id] + 1;
                    eaten_counts[eaten_id] = eaten_count;
                    if eaten_count > best_count {
                        best_count = eaten_count;
                        best_item = eaten_id;
                    }
                }

                if best_item != undefined {
                    str = local_get(ITEM_PROTOTYPES[best_item].name_key);
                }
                break;

            default:
                crash("Unrecognized tag: {}", tag);
        }

        //
        //
        //
        str = string(str);

        input_text = string_replace_all(
            input_text,
            tag,
            str,
        )
    }

    //
    input_text = string_replace_all(input_text, "[", "");
    input_text = string_replace_all(input_text, "]", "");
    return input_text;
}

function TextboxMenu() : AnchorMenu(Menu.Textbox) constructor {
    //
    if ANCHOR.get_menu(Menu.Journal) != undefined {
        ANCHOR.get_menu(Menu.Journal).close();
    }
    self.interacted = false;
    self.state = TextboxState.Hidden;
    self.prompt_selected = undefined;
    self.driver = undefined;
    self.option_count = undefined;
    self.heart_anim_chain = undefined;
    self.prompt_callback = undefined;
    self.prompt_callback_args = undefined;
    self.user_callback = undefined;
    self.user_callback_args = undefined;
    self.current_speaker = undefined;
    self.requested_speaker = undefined;
    self.close_callback = undefined;
    self.close_callback_args = undefined;
    self.portrait_target_alpha = 1;
    self.blackout_frames = undefined;

    self.canvas.set_align(Align.Center, Align.BottomIn);

    self.portrait = ANCHOR.sprite(self.canvas, TextboxDepthLevel.Portrait)
        .set_xy(PORTRAIT_X, PORTRAIT_Y)
        .set_align(Align.Center, Align.BottomIn)
        .set_alpha(0)
        .set_think_callback(function() {
            if self.text.is_resting() || self.state == TextboxState.Translating {
                self.portrait.set_index(0);
            }
            if self.text.pause || FOCUS.out_of_focus() {
                self.portrait.set_index(0);
            }
        });

    self.baby = ANCHOR.sprite(self.portrait);

    self.portrait_two = ANCHOR.sprite(self.canvas, TextboxDepthLevel.Portrait)
        .set_xy(PORTRAIT_X, PORTRAIT_Y)
        .set_align(Align.Center, Align.BottomIn)
        .set_alpha(0)
        .set_think_callback(function() {
            if self.text.is_resting() || self.state == TextboxState.Translating {
                self.portrait_two.set_index(0);
            }
            if self.text.pause || FOCUS.out_of_focus() {
                self.portrait_two.set_index(0);
            }
        });

    self.portrait_effect = portrait_effect_ui(self.portrait);

    self.textbox = ANCHOR.nine_slice(self.canvas, TextboxDepthLevel.Textbox)
        .set_xy(0, TEXTBOX_Y)
        .set_sprite(spr_ui_dialogue_box)
        .set_size(TEXTBOX_WIDTH, TEXTBOX_HEIGHT)
        .set_align(Align.Center, Align.BottomIn)
        .set_label("Textbox::textbox")

    self.namebox_back = ANCHOR.nine_slice(self.textbox, TextboxDepthLevel.NameboxBack)
        .set_xy(0, -16)
        .set_align(Align.LeftIn, Align.TopIn)
        .set_size(74, 22)
        .set_sprite(spr_ui_dialogue_namebar_back)
        .set_alpha(0)

    self.namebox_front = ANCHOR.nine_slice(self.namebox_back, TextboxDepthLevel.NameboxFront)
        .set_xy(-3, -5)
        .set_size(40, 14)
        .set_sprite(spr_ui_dialogue_namebar_front)
        .set_align(Align.RightIn, Align.BottomIn)

    self.namebox_text = ANCHOR.text(self.namebox_front, TextboxDepthLevel.NameboxText)
        .set_xy(6, -1)
        .set_text("UNSET")
        .set_align(Align.LeftIn, Align.Middle)
        .set_lut(spr_ui_dialogue_font_lut, 2)

    self.namebox_heart_backplate = ANCHOR.sprite(self.namebox_back, TextboxDepthLevel.HeartBackplate)
        .set_xy(4, 3)
        .set_sprite(spr_ui_dialogue_namebar_heartinsert)

    self.namebox_heart = ANCHOR.sprite(self.namebox_heart_backplate, TextboxDepthLevel.Heart)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_dialogue_heart_blue)
        .set_think_callback(function() {
            if self.heart_anim_chain == undefined {
                self.heart_anim_chain = new_chain()
                    .join(LinkId.Timer, irandom_range(600, 900))
                    .append(LinkId.Function, function() {
                        self.namebox_heart.set_speed(1);
                        self.heart_anim_chain = undefined;
                    })
            }

            if self.namebox_heart.at_animation_end() {
                self.namebox_heart.set_speed(0);
                self.namebox_heart.set_index(0);
            }
        })

    //
    if matches(local_language(), "jpn", "zh-Hant", "zh-Hans", "kor") {
        self.namebox_back.add_height(2);
        self.namebox_back.add_y(-2);
        self.namebox_front.add_height(2);
        self.namebox_text.add_y(1);
    }

    var textbox_width = fiddle_get("ui/misc/textbox_pixel_width");

    self.text_canvas = ANCHOR.canvas(self.textbox, TextboxDepthLevel.TextCanvas)
        .set_xy(3, 3)
        .set_size(textbox_width + 20, 49)

    self.text = ANCHOR.typewriter(self.text_canvas, TextboxDepthLevel.Text)
        .set_xy(5, TEXT_Y)
        .set_max_width(textbox_width)
        .set_lut(spr_ui_dialogue_font_lut)
        .set_text_style("textbox")
        .set_speaker_sound_path("SoundEffects/NPCs/Vocal/TextBlipGeneric")

    var binding = BINDINGS.get_primary_binding(InputId.Interact);
    var display = get_display_for_keycode(binding.keycode);
    self.blinky = ANCHOR.sprite(self.textbox, TextboxDepthLevel.Blinky)
        .set_xy(-6, -7)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_alpha(0)
        .set_sprite(display.small_sprite)
        .set_index(display.index)
        .set_think_callback(function() {
            if matches(self.state, TextboxState.Say, TextboxState.Info) && self.text.is_resting() {
                self.blinky.set_alpha(1);
            } else {
                self.blinky.set_alpha(0);
            }
        });

    //
    self.textbox.disable();

    #macro PROMPT_BOTTOM_Y -15
    #macro PROMPT_VERTICAL_PADDING 5
    #macro PROMPT_START_X 50

    var prompt_pixel_width = fiddle_get("ui/misc/prompt_pixel_width");
    var prompt_container_width = prompt_pixel_width + 14;

    self.prompt_pilot = self.new_pilot()
        .allow_vertical_wrapping()

    self.prompt_one = ANCHOR.nine_slice(self.textbox, TextboxDepthLevel.PromptCanvas);
    self.prompt_two = ANCHOR.nine_slice(self.textbox, TextboxDepthLevel.PromptCanvas);
    self.prompt_three = ANCHOR.nine_slice(self.textbox, TextboxDepthLevel.PromptCanvas);

    var a = [self.prompt_one, self.prompt_two, self.prompt_three];
    for (var i = 0; i < 3; i++) {
        var box = a[i];

        box.set_locked_sprite(spr_ui_dialogue_box_disabled);

        box.reset_sprites = method(box, function() {
            self.set_sprites_from_key("spr_ui_dialogue_box");
            if self.blackboard.get("pink") == true {
                self.set_sprites_from_key("spr_ui_dialogue_box_pink");
                self.tab.enable();

                if !ARI.disable_break_ups && (ARI.spouse() != undefined || ARI.fiance() != undefined) {
                    self.set_sprites_from_key("spr_ui_dialogue_box_grey");
                    self.blackboard.insert("stay_locked", true);
                    self.tab.set_key_sprite_target(self.tab);
                    self.tab.lock();
                }
            } else {
                self.tab.unlock();
                self.tab.disable();
                self.tab.set_key_sprite_target(self);
            }

            self.locked_sprite = self.enabled_sprite;
            return self;
        });

        //
        box
            .add_to_pilot(self.prompt_pilot, true)
            .set_width(prompt_container_width)
            .set_align(Align.RightIn, Align.TopOut)
            .add_text_label("misc_local/placeholder", spr_ui_dialogue_font_lut)
            .set_tap_callback(function(index) {
                if !self.interacted && self.state == TextboxState.Ask {
                    self.select_prompt_option(index);
                }
            }, [i])
            .set_selected_getter(function(index) {
                return self.state == TextboxState.Translating && index == self.driver.prompt_index_selected;
            }, [i])
            .lock()

        //
        box.text_label
            .set_xy(8, 5)
            .set_align(Align.LeftIn, Align.TopIn)
            .set_max_width(prompt_pixel_width)

        box.tab = ANCHOR.sprite(box)
            .set_align(Align.RightIn, Align.TopIn)
            .set_xy(9, -4)
            .set_sprites_from_key("spr_ui_dialogue_box_heart_icon")
            .set_key_sprite_target(box)
            .set_think_callback(function(box) {
                //
                box.tab.set_y(-box.child_offset.y - 4);
            }, [box])
            .disable()
    }

    self.prompt_one.disable();
    self.prompt_two.disable();
    self.prompt_three.disable();

    self.text.set_think_callback(function() {
        if MIST.skip_popup != undefined {
            return;
        }
        if ANCHOR.take_tap() {
            if !self.text.is_resting() {
                self.text.counter = self.text.characters.count() - 1;
                self.text.pause_timer = 0;
                self.text.pause = false;
            } else if !self.interacted
                && (self.state == TextboxState.Info || self.state == TextboxState.Say)
                && self.chain == undefined
            {
                self.interact();
            }
        }
    });

    self.chain = undefined;

    //
    //
    //
    //
    function __TranslationOrder() constructor {
        static Hidden = {
            target: TextboxState.Hidden,
        }
        static Ready = {
            target: TextboxState.Ready,
        }
        static Say = function(localization_key) {
            return {
                target: TextboxState.Say,
                key: localization_key,
            }
        }
        static Ask = function(prompt_key, _option_keys) {
            return {
                target: TextboxState.Ask,
                key: prompt_key,
                option_keys: _option_keys,
            }
        }
        static Info = function(localization_key) {
            return {
                target: TextboxState.Info,
                key: localization_key,
            }
        }
        static Blackout = function(frames) {
            return {
                target: TextboxState.Blackout,
                frames,
            }
        }
    }

    self.translation_order_creator = new __TranslationOrder();
    #macro TranslationOrder self.translation_order_creator


    //
    function join_textbox_open_to_chain() {
        self.textbox.enable();
        var width = self.namebox_back.get_width();
        var height = TEXTBOX_MIN_HEIGHT;
        self.textbox.set_size(width, height);
        self.chain
            .join(
                LinkId.Ease,
                new Ease(EaseId.Linear, width, TEXTBOX_WIDTH, EASE_LENGTH),
                function(_, abs_val) {
                    self.textbox.set_width(abs_val);
                }
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.Linear, height, TEXTBOX_HEIGHT, EASE_LENGTH),
                function(_, abs_val) {
                    self.textbox.set_height(abs_val);
                }
            )
    }

    //
    function join_textbox_close_to_chain() {
        var width = self.namebox_back.get_width();
        var height = TEXTBOX_MIN_HEIGHT;
        self.chain
            .join(LinkId.Function, function() {
                TANGO.play("SoundEffects/UI/UIPopDown");
            })
            .join(
                LinkId.Ease,
                new Ease(EaseId.Linear, TEXTBOX_WIDTH, width, EASE_LENGTH),
                function(_, abs_val) {
                    self.textbox.set_width(abs_val);
                }
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.Linear, TEXTBOX_HEIGHT, height, EASE_LENGTH),
                function(_, abs_val) {
                    self.textbox.set_height(abs_val);
                }
            )
    }

    //
    function join_text_exit_to_chain() {
        self.chain
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, -5, 15), function(delta) {
                self.text.set_y(delta);
            })
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 15), function(delta) {
                self.text.add_alpha(delta);
            });
    }

    //
    function join_portrait_enter_to_chain(speaker) {
        var cut_off_diff = 6;
        var base_x = speaker.me.prototype.offsets.portrait[0];

        var base_two_x = base_x;
        if MIST.blackboard.get("caldaurs_textbox_hack") {
            var base_two_x = NPC_PROTOTYPES[NpcId.Caldarus].offsets.portrait[0];
        }

        self.chain
            .join(LinkId.Ease, new Ease(EaseId.CubicIn, 0, self.portrait_target_alpha, 10), function(delta) {
                self.portrait.add_alpha(delta);
                self.portrait_two.add_alpha(delta);
            })
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, base_x - PORTRAIT_X_OFFSET + cut_off_diff, base_x, 15),
                function(_, ab) {
                    self.portrait.set_x(ab);
                }
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, base_two_x - PORTRAIT_X_OFFSET + 220 - cut_off_diff, base_two_x + 220, 15),
                function(_, ab) {
                    self.portrait_two.set_x(ab);
                }
            );
    }

    //
    function join_portrait_exit_to_chain(speaker) {
        var base_x = speaker.me.prototype.offsets.portrait[0];

        var base_two_x = base_x;
        if MIST.blackboard.get("caldaurs_textbox_hack") {
            var base_two_x = NPC_PROTOTYPES[NpcId.Caldarus].offsets.portrait[0];
        }

        var cut_off_diff = 22;

        self.chain
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 15), function(delta) {
                self.portrait.add_alpha(delta);
                self.portrait_two.add_alpha(delta);
            })
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, base_x, base_x - PORTRAIT_X_OFFSET + cut_off_diff, 15),
                function(_, ab) {
                    self.portrait.set_x(ab);
                }
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, base_two_x + 220, base_two_x - PORTRAIT_X_OFFSET + 220 - cut_off_diff, 15),
                function(_, ab) {
                    self.portrait_two.set_x(ab);
                }
            );
    }

    //
    function join_text_close_to_chain() {
        self.chain
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 5), function(delta) {
                self.text.add_alpha(delta);
            });
    }

    //
    function join_prompt_slide_in_to_chain() {
        var a = [self.prompt_one, self.prompt_two, self.prompt_three];
        for (var i = 0; i < self.option_count; i++) {
            var box = a[i];
            box
                .enable()
                .reset_sprites()
                .lock()
                .set_x(PROMPT_START_X)
                .set_alpha(0)
            self.chain
                .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, -PROMPT_START_X, 25), function(delta, _, box) {
                    box.add_x(delta);
                }, [box])
                .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 25), function(delta, _, box) {
                    box.add_alpha(delta);
                }, [box])
        }
        self.chain.append(LinkId.Function, function() {
            var stay_locked = self.prompt_one.blackboard.try_take("stay_locked") == true;
            self.prompt_one.unlock();
            self.prompt_one.set_soft_locked(stay_locked);
            if self.option_count > 1 {
                var stay_locked = self.prompt_two.blackboard.try_take("stay_locked") == true;
                self.prompt_two.unlock();
                self.prompt_two.set_soft_locked(stay_locked);
            }
            if self.option_count > 2 {
                var stay_locked = self.prompt_three.blackboard.try_take("stay_locked") == true;
                self.prompt_three.unlock();
                self.prompt_three.set_soft_locked(stay_locked);
            }
            self.prompt_pilot.goto_default();
            ANCHOR.set_active_pilot(self.prompt_pilot);
        });
    }

    //
    //
    function join_prompt_option_selection_to_chain() {

        //
        if self.driver.prompt_index_selected != 0 {
            self.chain.join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 25), function(delta) {
                self.prompt_one.add_alpha(delta);
            })
        }
        if self.driver.prompt_index_selected != 1 && self.option_count > 1 {
            self.chain.join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 25), function(delta) {
                self.prompt_two.add_alpha(delta);
            })
        }
        if self.driver.prompt_index_selected != 2 && self.option_count > 2 {
            self.chain.join(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 25), function(delta) {
                self.prompt_three.add_alpha(delta);
            })
        }

        //
        self.chain.append(LinkId.Timer, 15);

        //
        var prompt;
        switch self.driver.prompt_index_selected {
            case 0:
                prompt = self.prompt_one;
                break;
            case 1:
                prompt = self.prompt_two;
                break;
            case 2:
                prompt = self.prompt_three;
                break;
            default: impossible("Invalid prompt selected: {}", self.driver.prompt_index_selected);
        }


        self.chain.append(LinkId.Ease, new Ease(EaseId.QuartOut, 1, 0, 25), function(_, val, prompt) {
            prompt.set_alpha(val);
        }, [prompt])

        //
        self.chain.append(LinkId.Function, function() {
            self.prompt_one.reset_sprites();
            self.prompt_one.disable();
            self.prompt_one.blackboard.remove("pink");
            if self.option_count > 1 {
                self.prompt_two.reset_sprites();
                self.prompt_two.disable();
                self.prompt_two.blackboard.remove("pink");
            }
            if self.option_count > 2 {
                self.prompt_three.reset_sprites();
                self.prompt_three.disable();
                self.prompt_three.blackboard.remove("pink");
            }
        });
    }

    //
    function join_blackout_to_chain(frames) {
        self.chain
            .append(LinkId.Function, function() {
                self.canvas.set_alpha(0);
                SCREEN_FADER.fade_out(FADE_SPEED_CUTSCENE);
            })
            .append(LinkId.Timer, frames + FADE_SPEED_CUTSCENE)
            .append(LinkId.Function, function() {
                SCREEN_FADER.fade_in(FADE_SPEED_CUTSCENE);
            })
            .append(LinkId.Timer, FADE_SPEED_CUTSCENE)
            .append(LinkId.Function, function() {
                self.current_speaker = undefined; //
                self.namebox_back.disable(); //
                self.text.set_speaker_sound_path("SoundEffects/NPCs/Vocal/TextBlipGeneric");
                self.canvas.set_alpha(1);
            })
    }

    function append_state_swap_to_chain(state) {
        self.chain.append(LinkId.Function, function(new_state) {
            self.state = new_state;
        }, [state]);
    }


    //
    function play_text(local_key) {
        self.prompt_selected = undefined;
        self.text.set_y(TEXT_Y);
        self.text.set_alpha(1);
        self.text.set_ghost_key(local_key);
        self.text.play(local_get(local_key));
    }

    //
    function handle_portrait() {
        self.portrait.set_speed(0.8);
        self.portrait_two.set_speed(0.8);
        if self.requested_speaker == undefined {
            if self.current_speaker == undefined {
                //
            } else {
                //
                self.join_portrait_exit_to_chain(self.current_speaker);
                self.namebox_back.disable();
                self.current_speaker = undefined;
                self.text.set_speaker_sound_path("SoundEffects/NPCs/Vocal/TextBlipGeneric");
            }
        } else {
            //
            if self.current_speaker == undefined {
                //
                self.namebox_back.enable();
                self.set_speaker(self.requested_speaker);
                self.join_portrait_enter_to_chain(self.requested_speaker);
            } else {
                //
                if self.requested_speaker.identity == self.current_speaker.identity {
                    self.set_speaker(self.requested_speaker);
                } else {
                    self.namebox_back.enable();
                    self.join_portrait_exit_to_chain(self.current_speaker);
                    self.chain.append(LinkId.Function, function() {
                        self.set_speaker(self.requested_speaker);
                    });
                    self.chain.join(LinkId.Wait);
                    self.join_portrait_enter_to_chain(self.requested_speaker);
                }
            }
        }
    }

    //
    function set_speaker(speaker) {
        self.current_speaker = speaker;

        var portrait_assets = speaker.portrait_assets();
        var nameplate_sprites = speaker.nameplate_sprites();

        self.portrait
            .set_speed(0.8)
            .set_sprite(portrait_assets.sprite)
            .set_index(1);

        self.baby.set_sprite(portrait_assets.baby ?? spr_nothing);

        if MIST.blackboard.get("caldarus_textbox_hack") == true {
            var s = MIST.npcs.get(NpcId.Caldarus)
                .wardrobe
                .outfit_current
                .portraits
                .get("pained");
            self.portrait_two
                .set_speed(0.8)
                .set_sprite(s)
                .set_index(1);
        }

        if MIST.blackboard.get("linnet_textbox_hack") == true {
            var s = MIST.cameos.get(CameoId.Wiscar)
                .wardrobe
                .outfit_current
                .portraits
                .get("happy");
            self.portrait_two
                .set_speed(0.8)
                .set_sprite(s)
                .set_index(1);
        }


        self.namebox_heart_backplate.set_sprite(nameplate_sprites.backplate);
        self.namebox_heart.set_sprite(nameplate_sprites.icon);
        self.text.set_override_sound(portrait_assets.override_sound);
        self.text.set_speaker_sound_path(portrait_assets.override_sound == undefined
            ? speaker.blip_sound
            : undefined
        );

        var local_key = speaker.name_key();
        self.namebox_back.set_alpha(1);
        self.namebox_text.set_key(local_key);
        var width = self.width_for_namebox(local_key);
        self.namebox_front.set_width(width);
        self.namebox_back.set_width(width + TEXTBOX_NAMEBOX_BACK_PADDING);

        if speaker.effect != undefined {
            self.portrait_effect.set(speaker.me.prototype, speaker.effect);
        } else {
            self.portrait_effect.disable();
        }
    }

    function width_for_namebox(key) {
        return string_width_font(local_get(key)) + 12;
    }

    //
    //
    function select_prompt_option(index) {
        self.prompt_one.lock();
        self.prompt_two.lock();
        self.prompt_three.lock();
        self.driver.prompt_index_selected = index;
        switch index {
            case 2:
                self.prompt_selected = self.prompt_three.text_label.get_local_key();
                break;
            case 1:
                self.prompt_selected = self.prompt_two.text_label.get_local_key();
                break;
            case 0:
                self.prompt_selected = self.prompt_one.text_label.get_local_key();
                break;
            default:
                impossible("Invalid prompt index: {}", index);
                break;
        }
        self.interact();
    }

    function get_npc_offset(npc_id) {
        var offset = fiddle_get(format("npcs/{NpcId}/offsets/portrait", npc_id));
        return Vec2(offset[0], offset[1]);
    }

    //
    //
    //
    //
    function translate(translation_order) {
        assert(self.state != TextboxState.Translating);
        if self.chain != undefined && self.chain.running {
            CHAINS.cancel_chain(self.chain);
        }
        self.chain = new_chain();
        switch self.state {
            case TextboxState.Hidden:
                switch translation_order.target {
                    case TextboxState.Hidden: crash("Illegal textbox translation: Hidden -> Hidden");
                    //
                    case TextboxState.Ready:
                        TANGO.play("SoundEffects/UI/UIPopUp");
                        self.join_textbox_open_to_chain();
                        self.append_state_swap_to_chain(translation_order.target);
                        break;
                    //
                    case TextboxState.Blackout:
                        self.append_state_swap_to_chain(translation_order.target);
                        self.join_blackout_to_chain(translation_order.frames);
                        //
                        self.append_state_swap_to_chain(TextboxState.Hidden);
                        self.chain.append(LinkId.Function, function() {
                            function_execute_alt(self.user_callback, self.user_callback_args);
                        });
                        break;
                    case TextboxState.Say: crash("Illegal textbox translation: Hidden -> Say");
                    case TextboxState.Ask: crash("Illegal textbox translation: Hidden -> Ask");
                    case TextboxState.Info: crash("Illegal textbox translation: Hidden -> Info");
                    default: impossible();
                }
                break;
            case TextboxState.Ready:
                switch translation_order.target {
                    //
                    case TextboxState.Hidden:
                        self.join_textbox_close_to_chain();
                        if self.current_speaker != undefined {
                            self.join_portrait_exit_to_chain(self.current_speaker);
                        }
                        self.append_state_swap_to_chain(translation_order.target);
                        break;
                    case TextboxState.Ready: crash("Illegal textbox translation: Ready -> Ready");
                    //
                    case TextboxState.Say:
                        self.handle_portrait();
                        self.chain.append(LinkId.Function, function(key) {
                            self.play_text(key);
                        }, [translation_order.key]);
                        self.append_state_swap_to_chain(TextboxState.Say);
                        break;
                    //
                    case TextboxState.Ask:
                        //
                        self.option_count = array_length(translation_order.option_keys);
                        var a = [self.prompt_one, self.prompt_two, self.prompt_three];
                        var yy = PROMPT_BOTTOM_Y;
                        for (var i = self.option_count - 1; i >= 0; i--) {
                            var box = a[i];
                            var key = translation_order.option_keys[i];
                            box.text_label
                                .set_ghost_key(key)
                                .set_text(filter_text_for_textbox(local_get(key)))

                            var height = box.text_label.measure().y + 10;
                            box
                                .set_height(height)
                                .set_y(yy)
                            yy -= height + PROMPT_VERTICAL_PADDING;
                        }

                        //
                        self.handle_portrait();

                        self.chain.append(LinkId.Function, function(key) {
                            self.play_text(key);
                        }, [translation_order.key]);

                        //
                        self.append_state_swap_to_chain(TextboxState.Say);

                        //
                        self.chain
                            .join(LinkId.Await, function() {
                                return self.text.is_resting();
                            })
                            .join(LinkId.Wait);

                        //
                        self.append_state_swap_to_chain(TextboxState.Ask);

                        //
                        self.join_prompt_slide_in_to_chain();
                        break;
                    //
                    case TextboxState.Info:
                        self.handle_portrait();
                        self.play_text(translation_order.key);
                        self.append_state_swap_to_chain(TextboxState.Info);
                        break;
                    default: impossible();
                }
                break;
            case TextboxState.Say:
                switch translation_order.target {
                    //
                    case TextboxState.Hidden:
                        self.join_textbox_close_to_chain();
                        self.join_text_close_to_chain();
                        if self.current_speaker != undefined {
                            self.join_portrait_exit_to_chain(self.current_speaker);
                        }
                        self.append_state_swap_to_chain(translation_order.target);
                        break;
                    //
                    case TextboxState.Ready:
                        self.join_text_exit_to_chain();
                        self.append_state_swap_to_chain(translation_order.target);
                        break;
                    case TextboxState.Say: crash("Illegal textbox translation: Say -> Say");
                    case TextboxState.Ask: crash("Illegal textbox translation: Say -> Ask");
                    case TextboxState.Info: crash("Illegal textbox translation: Say -> Info");
                    case TextboxState.Blackout: crash("Illegal textbox translation: Say -> Blackout");
                    default: impossible();
                }
                break;
            case TextboxState.Ask:
                switch translation_order.target {
                    //
                    case TextboxState.Hidden:
                        self.join_prompt_option_selection_to_chain();
                        self.chain.join(LinkId.Wait);
                        self.join_textbox_close_to_chain();
                        self.join_text_close_to_chain();
                        if self.current_speaker != undefined {
                            self.join_portrait_exit_to_chain(self.current_speaker);
                        }
                        self.append_state_swap_to_chain(translation_order.target);
                        ANCHOR.release_active_pilot();
                        break;
                    //
                    case TextboxState.Ready:
                        self.join_prompt_option_selection_to_chain();
                        self.chain.join(LinkId.Wait);
                        self.join_text_exit_to_chain();
                        self.append_state_swap_to_chain(translation_order.target);
                        ANCHOR.release_active_pilot();
                        break;
                    case TextboxState.Say: crash("Illegal textbox translation: Ask -> Say");
                    case TextboxState.Ask: crash("Illegal textbox translation: Ask -> Ask");
                    case TextboxState.Info: crash("Illegal textbox translation: Ask -> Info");
                    case TextboxState.Blackout: crash("Illegal textbox translation: Ask -> Blackout");
                    default: impossible();
                }
                break;
            case TextboxState.Info:
                switch translation_order.target {
                    //
                    case TextboxState.Hidden:
                        self.join_textbox_close_to_chain();
                        self.join_text_close_to_chain();
                        self.append_state_swap_to_chain(translation_order.target);
                        break;
                    //
                    case TextboxState.Ready:
                        self.join_text_exit_to_chain();
                        self.append_state_swap_to_chain(translation_order.target);
                        break;
                    case TextboxState.Say: crash("Illegal textbox translation: Info -> Say");
                    case TextboxState.Ask: crash("Illegal textbox translation: Info -> Ask");
                    case TextboxState.Info: crash("Illegal textbox translation: Info -> Info");
                    case TextboxState.Blackout: crash("Illegal textbox translation: Info -> Blackout");
                    default: impossible();
                }
                break;
            default: impossible();
        }

        //
        self.chain.append(LinkId.Function, function() {
            self.chain = undefined;
        });

        //
        self.state = TextboxState.Translating;

        //
        self.interacted = false;

    }

    //
    function ready() {
        self.translate(TranslationOrder.Ready);
    }

    //
    function say(local_key) {
        switch self.state {
            case TextboxState.Hidden:
            case TextboxState.Say:
            case TextboxState.Ask:
            case TextboxState.Info:
                new_chain()
                    .join(LinkId.Function, function() {
                        self.translate(TranslationOrder.Ready);
                    })
                    .append(LinkId.Await, function() {
                        return self.state != TextboxState.Translating;
                    })
                    .append(LinkId.Function, function(local_key) {
                        self.translate(TranslationOrder.Say(local_key));
                    }, [local_key]);
                break;
            case TextboxState.Ready:
                self.translate(TranslationOrder.Say(local_key));
                break;
            default: impossible();
        }
    }

    //
    function ask(prompt_key, option_keys) {
        switch self.state {
            case TextboxState.Hidden:
            case TextboxState.Say:
            case TextboxState.Ask:
            case TextboxState.Info:
                new_chain()
                    .join(LinkId.Function, function() {
                        self.translate(TranslationOrder.Ready);
                    })
                    .append(LinkId.Await, function() {
                        return self.state != TextboxState.Translating;
                    })
                    .append(LinkId.Function, function(prompt_key, option_keys) {
                        self.translate(TranslationOrder.Ask(prompt_key, option_keys));
                    }, [prompt_key, option_keys]);
                break;
            case TextboxState.Ready:
                self.translate(TranslationOrder.Ask(prompt_key, option_keys));
                break;
            default: impossible("Unexpected TextboxState: {}", self.state);
        }
    }

    //
    function info(local_key) {
        switch self.state {
            case TextboxState.Hidden:
            case TextboxState.Say:
            case TextboxState.Ask:
            case TextboxState.Info:
                new_chain()
                    .join(LinkId.Function, function() {
                        self.translate(TranslationOrder.Ready);
                    })
                    .append(LinkId.Await, function() {
                        return self.state != TextboxState.Translating;
                    })
                    .append(LinkId.Function, function(local_key) {
                        self.translate(TranslationOrder.Info(local_key));
                    }, [local_key]);
                break;
            case TextboxState.Ready:
                self.translate(TranslationOrder.Info(local_key));
                break;
            default: impossible("Unexpected TextboxState: {}", self.state);
        }
    }

    //
    function blackout(frames) {
        switch self.state {
            case TextboxState.Say:
            case TextboxState.Ask:
            case TextboxState.Info:
                new_chain()
                    .join(LinkId.Function, function() {
                        self.translate(TranslationOrder.Hidden);
                    })
                    .append(LinkId.Await, function() {
                        return self.state != TextboxState.Translating;
                    })
                    .append(LinkId.Function, function(frames) {
                        self.translate(TranslationOrder.Blackout(frames));
                    }, [frames]);
                break;
            default: impossible("Unexpected TextboxState: {}", self.state);
        }
    }

    //
    function begin_close() {
        self.translate(TranslationOrder.Hidden);
        new_chain()
            .join(LinkId.Await, function() {
                return self.state != TextboxState.Translating;
            })
            .append(LinkId.Function, function() {
                if self.close_callback != undefined {
                    function_execute_alt(self.close_callback, self.close_callback_args);
                }
                if MIST.running == false {
                    npcs_exit_pause_animations();
                }
                self.close();
            });
    }

    //
    function interact() {
        if self.state == TextboxState.Translating {
            return;
        }
        TANGO.play("SoundEffects/UI/UIClick");
        function_execute_alt(self.user_callback, self.user_callback_args);
        self.interacted = true;
    }

    //
    //
    function give_callback(func, arg_array) {
        self.user_callback = func;
        self.user_callback_args = arg_array;
    }

    //
    function give_close_callback(func, arg_array) {
        self.close_callback = func;
        self.close_callback_args = arg_array;
    }
}

//
//
//
//
function Speaker(id) constructor {
    self.id = id;
    self.portrait = "neutral";
    self.effect = undefined;
    self.me = undefined;
    self.blip_sound = "SoundEffects/NPCs/Vocal/TextBlipGeneric";
    self.override_sound = undefined;
    self.identity = undefined; //

    function set_portrait(portrait) {
        var effect = undefined;

        while true {
            var sprite = self.me.wardrobe.outfit_current.portraits.get(portrait);
            if sprite == undefined {
                effect = undefined;

                var fallback_data = T2R.fallback_portrait(portrait);
                portrait = fallback_data.portrait;
                effect = fallback_data.effect;
            } else {
                break;
            }
        }

        self.portrait = portrait;
        self.effect = effect;
    }

    function portrait_assets() {
        crash("Unimplemented function");
    }

    function name_key() {
        return self.me.prototype.name;
    }

    function nameplate_sprites() {
        crash("Unimplemented function");
    }
}

function NpcSpeaker(id) : Speaker(id) constructor {
    self.me = MIST.is_running() ? MIST.npcs.get(self.id) : NPCS[self.id];
    self.identity = npc_id_to_string(self.id);
    self.blip_sound = find_npc_blip_noise(self.id);

    function name_key() {
        if MIST.blackboard.get("caldarus_textbox_hack") == true {
            return "misc_local/seridia_and_caldarus";
        }

        if MIST.blackboard.get("linnet_textbox_hack") == true {
            return "misc_local/linnet_and_wiscar";
        }

        if self.id == NpcId.Seridia {
            if MIST.blackboard.get("head_priestess") == true {
                return "misc_local/head_priestess"; //
            } else if !npc_is_unlocked(NpcId.Seridia) {
                return "misc_local/priestess"; //
            }
        }

        return self.me.prototype.name;
    }

    function portrait_assets() {
        var sprite = self.me.wardrobe.outfit_current.portraits.get(self.portrait);
        var override_sound = self.me.prototype.portrait_sound_overrides[$ self.portrait];

        assert_neq(sprite, undefined, "Failed to get '{}' for {}", self.portrait, self.identity);

        var baby = undefined;
        var child = self.me.held_child();
        if child != undefined && self.me.wardrobe.outfit_name != "dragon_statue" {
            baby = string_to_asset(format(
                "spr_portrait_{NpcId}_baby_{ChildId}_{ChildSkinTone}",
                self.id,
                child.id,
                child.skin_tone,
            ));
        }

        return {
            sprite,
            override_sound,
            baby,
            effect: self.effect,
        };
    }

    function nameplate_sprites() {
        var sprites = self.me.prototype.dateable
            ?  fiddle_get("ui/textbox/dateable_heart_sprites")
            :  fiddle_get("ui/textbox/non_dateable_heart_sprites");

        var dateable = self.me.prototype.dateable;
        var icon = undefined;
        switch self.id {
            case NpcId.Caldarus:
                if MIST.blackboard.get("flashback_hearts") {
                    icon = string_to_asset(fiddle_get("ui/textbox/dateable_heart_sprites")[0]);
                }
                break;
            case NpcId.Seridia:
                if MIST.blackboard.get("flashback_hearts") {
                    dateable = false;
                    icon = string_to_asset(fiddle_get("ui/textbox/non_dateable_heart_sprites")[0]);
                } else if !npc_is_unlocked(NpcId.Seridia) {
                    dateable = false;
                }
                break;
        }

        if icon == undefined {
            icon = string_to_asset(sprites[self.me.heart_level()]);
        }

        var backplate = dateable
            ? spr_ui_dialogue_namebar_heartinsert
            : spr_ui_dialogue_namebar_circleinsert;

        return {
            backplate,
            icon,
        };
    }
}

function CameoSpeaker(id) : Speaker(id) constructor {
    assert(MIST.is_running(), "Cameos can only be used during cutscenes!");
    self.me = MIST.cameos.get(self.id);
    self.identity = cameo_id_to_string(self.id);
    self.blip_sound = self.me.prototype.voice;

    var off = fiddle_get(format("cameos/{}/offsets/portrait", self.identity));
    self.offset = Vec2(off[0], off[1]);

    function nameplate_sprites() {
        var sprites = fiddle_get("ui/textbox/non_dateable_heart_sprites");

        return {
            backplate: spr_ui_dialogue_namebar_circleinsert,
            icon: string_to_asset(sprites[0]),
        }
    }

    function portrait_assets() {
        var sprite = self.me.wardrobe.outfit_current.portraits.get(self.portrait);
        var override_sound = self.me.prototype.portrait_sound_overrides[$ self.portrait];

        assert_neq(sprite, undefined, "Failed to get '{}' for {}", self.portrait, self.identity);

        var baby = undefined;
        if MIST.blackboard.get("stork_child_portrait") == true {
            if array_is_empty(ARI.children) {
                var child = potential_child();
            } else {
                var child = ARI.children[0];
            }
            baby = string_to_asset(format(
                "spr_portrait_great_bird_baby_{ChildId}_{ChildSkinTone}",
                child.id,
                child.skin_tone,
            ));
        }

        return {
            sprite,
            override_sound,
            baby,
            effect: self.effect,
        };
    }
}

//
//
function find_npc_blip_noise(npc_id) {
    var npc = MIST.is_running() ? MIST.npcs.get(npc_id) : NPCS[npc_id];
    switch npc_id {
        case NpcId.Caldarus:
            if npc.wardrobe.outfit_name == "dragon_statue" {
                return "SoundEffects/NPCs/Vocal/TextBlipCaldarusDragonForm";
            }
            break;
        case NpcId.Seridia:
            switch npc.wardrobe.outfit_name {
                case "dragon": return "SoundEffects/NPCs/Vocal/TextBlipSeridiaDragonForm";
                case "flashback_priestess": return "SoundEffects/NPCs/Vocal/TextBlipPriestess";
                case "priestess": return "SoundEffects/NPCs/Vocal/TextBlipPriestess";
                default: return "SoundEffects/NPCs/Vocal/TextBlipSeridiaHuman";
            }
            break;
    }

    var sfx_name = format(
        "SoundEffects/NPCs/Vocal/TextBlip{}",
        capitalize(npc_id_to_string(npc_id))
    );

    if TANGO.name_exists(sfx_name) {
        return sfx_name;
    } else {
        return "SoundEffects/NPCs/Vocal/TextBlipGeneric";
    }
}
