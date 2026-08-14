enum ShrineMenuVariant {
    Caldarus,
    Seridia,
    Horse,
    LEN
}

function DragonShrineMenu(variant) : AnchorMenu(Menu.DragonShrine) constructor {
    self.chain = undefined;

    //
    function on_free() {
        self.cancel_transition();
        ANCHOR.free_node(self.essence_backplate);
    }

    function cancel_transition() {
        if self.chain != undefined {
            if self.chain.running {
                CHAINS.cancel_chain(self.chain);
            }
            self.chain = undefined;
        }
    }

    //
    //
    function create_category_nodes(cat_to_hover) {
        var create_category = function(cat_key, xx, yy) {
            var category_data = DRAGON_SHRINE_DATA.get(cat_key);
            var cat_level_text = string(ari_level_in_category(category_data));
            var tile = ANCHOR.sprite(self.category_backplate)
                .set_align(Align.Center, Align.Middle)
                .set_xy(xx, yy)
                .add_to_pilot(self.category_pilot)
                .set_sprites_from_key(category_data.icon_sprite_key)
                .set_tap_callback(function(cat_key) {
                    self.transition(
                        DragonShrineState.TierScreen,
                        function(cat_key) {
                            ANCHOR.free_node(self.category_backplate);
                            self.create_tier_nodes(cat_key);
                        },
                        [cat_key],
                    );
                }, [cat_key])

            var x_padding = string_length(cat_level_text) == 1 ? 3 : 0;
            var level_sprite = ANCHOR.sprite(tile)
                .set_sprite(string_to_asset(format("spr_ui_skills_lvl_{}", asset_local_insert())))
                .set_align(Align.Center, Align.BottomOut)
                .set_xy(-6 + x_padding, 5)

            ANCHOR.text(level_sprite)
                .set_text(cat_level_text)
                .set_align(Align.RightOut, Align.Middle)
                .set_x(2)
                .set_sprite_font("player_level")
                .set_lut(spr_ui_skills_lut);

            var name = local_get(category_data.name);
            var width = string_width_font(name) + 24;
            var bubble = ANCHOR.nine_slice(tile, tile.get_z() - 10);
            bubble
                .set_sprite(spr_ui_skills_namebubble)
                .set_size(width, 15)
                .set_y(-3)
                .set_align(Align.Center, Align.TopOut)
                .set_think_callback(function(tile, bubble) {
                    bubble.set_alpha(tile.is_hovered() ? 1 : 0);
                }, [tile, bubble])
            ANCHOR.sprite(bubble)
                .set_sprite(spr_ui_skills_namebubble_arrow)
                .set_align(Align.Center, Align.BottomOut)
                .set_y(-1)
            ANCHOR.text(bubble)
                .set_key(category_data.name)
                .set_align(Align.Center, Align.Middle)
                .set_lut(spr_ui_skills_lut)

            return tile;
        }

        self.category_nodes.clear();
        self.header_text
            .set_key("misc_local/skills")
            .set_lut_index(1)
        self.category_pilot = self.new_pilot()
            .allow_horizontal_wrapping()
            .allow_vertical_wrapping();
        self.category_backplate = ANCHOR.nine_slice(self.sub_canvas)
            .set_sprite(spr_ui_skills_box_3)
            .set_size(250, 130)
            .set_align(Align.Center, Align.Middle)

        static PADDING = 13;
        static ICON_WIDTH = sprite_get_width(spr_ui_skills_domain_icon_farming_enabled);
        static ICON_HEIGHT = sprite_get_height(spr_ui_skills_domain_icon_farming_enabled);
        static Y_POSITIONS = [-34, 20];

        var order = fiddle_get(format("ui/misc/shrine_categories/{ShrineMenuVariant}", self.variant));
        var y_positions = centered_positions(array_length(order), ICON_HEIGHT, PADDING);
        for (var i = 0; i < array_length(y_positions); i++) {
            var y_pos = y_positions[i] - 8;
            var row = order[i];
            var size = array_length(row);
            var positions = centered_positions(size, ICON_WIDTH, PADDING);
            for (var j = 0; j < size; j++) {
                var node = create_category(row[j], positions[j], y_pos);
                if row[j] == cat_to_hover {
                    self.category_pilot.force_select(node);
                }
                self.category_nodes.push(node);
            }
            self.category_pilot.request_newline();
        }

        ANCHOR.set_active_pilot(self.category_pilot)
    }

    //
    function create_tier_nodes(cat_key) {
        self.tier_pilot = self.new_pilot();
        var category_data = DRAGON_SHRINE_DATA.get(cat_key);
        self.header_text.set_key(category_data.name);
        self.scroller = create_scroller_ext(
            self.sub_canvas,
            Vec2(0, 16),
            Vec2(342, 152),
            Vec2(Align.Center, Align.TopIn),
            Vec2(-10, 0),
            Vec2(10, 130),
            Vec2(Align.RightIn, Align.Middle),
        );
        self.scroller.set_scroll_sprites(
            spr_ui_skills_scrollbar_arrow_up_released,
            spr_ui_skills_scrollbar_arrow_down_released,
            spr_ui_skills_scrollbar_bar_bg,
            spr_ui_skills_scrollbar_bar_button,
        );
        self.scroller.subscribe_to_pilot(self.tier_pilot, 30, 30);

        //
        self.scroller.canvas.board_set("cat_key", cat_key);

        //
        static SCROLLER_PADDING = 12;
        self.scroller.add_vertical_space(SCROLLER_PADDING);

        //
        self.entry_nodes.clear();
        var iter = 0;
        for (var i = 0; i < 5; i++) {
            var min_level = category_data.level_requirements[i];
            var at_req_level = ari_level_in_category(category_data) >= min_level;
            var tier_entries = category_data[$ fmt("tier_{}", i + 1)];
            if array_length(tier_entries) == 0 {
                continue;
            }
            var tier_backplate = self.create_tier(i, min_level, at_req_level);
            static TILE_WIDTH = sprite_get_width(spr_ui_skills_skill_slot_disabled);
            static PADDING = 15;
            var len = array_length(tier_entries);
            var positions = centered_positions(len, TILE_WIDTH, PADDING);
            for (var j = 0; j < array_length(tier_entries); j++) {
                var node = self.create_entry(tier_entries[j], category_data, positions[j], tier_backplate, at_req_level);
                iter += 1;
                self.entry_nodes.push(node);
            }
            self.tier_pilot.request_newline();
        }

        self.scroller.add_vertical_space(SCROLLER_PADDING);
        ANCHOR.set_active_pilot(self.tier_pilot);
    }

    //
    function create_tier(tier_index, tier_level, unlocked) {
        static BACKPLATE_HEIGHT = 40;
        static BACKPLATE_PADDING = 10;
        static ELEMENT_HEIGHT = BACKPLATE_HEIGHT + (BACKPLATE_PADDING * 2);

        var element = self.scroller.new_element(ELEMENT_HEIGHT)
            .set_enabled_sprite(spr_nothing_nineslice)

        var backplate = ANCHOR.nine_slice(element)
            .set_sprite(spr_ui_skills_box_3)
            .set_size(200, BACKPLATE_HEIGHT)
            .set_align(Align.Center, Align.Middle);

        //
        var left_square = ANCHOR.nine_slice(backplate)
            .set_sprite(spr_ui_skills_box_2)
            .set_size(58, 32)
            .set_align(Align.LeftOut, Align.Middle)
            .set_x(-8)
        var tier_text = ANCHOR.text(left_square)
            .set_key(fmt("misc_local/tier_{}", tier_index + 1))
            .set_lut(spr_ui_skills_lut, unlocked ? 1 : 4)

        if self.variant != ShrineMenuVariant.Horse {
            tier_text.set_align(Align.Center, Align.TopIn);
            tier_text.set_y(5);

            var x_pad = string_length(string(tier_level)) == 1 ? 3 : 0;
            var level_sprite = ANCHOR.sprite(left_square)
                .set_sprite(string_to_asset(format("spr_ui_skills_lvl_{}", asset_local_insert())))
                .set_align(Align.Center, Align.BottomIn)
                .set_xy(-6 + x_pad, -7)
                .set_lut(spr_ui_skills_lut, unlocked ? 0 : 4)
            ANCHOR.text(level_sprite)
                .set_text(string(tier_level))
                .set_align(Align.RightOut, Align.Middle)
                .set_x(2)
                .set_sprite_font("player_level")
                .set_lut(spr_ui_skills_lut, unlocked ? 1 : 4)
        } else {
            tier_text.set_align(Align.Center, Align.Middle);
        }

        return backplate;
    }

    //
    function create_entry(entry, category, xx, backplate, at_req_level) {
        static TILE_Z = 10
        static BUBBLE_Z = 1
        var tile = ANCHOR.sprite(backplate, TILE_Z)
            .set_x(xx)
            .set_align(Align.Center, Align.Middle)
            .set_lut(spr_ui_skills_icon_lut, 0)
            .add_to_pilot(self.tier_pilot)
            .set_sprites_from_key(at_req_level
                ? "spr_ui_skills_skill_slot"
                : "spr_ui_skills_skill_slot_locked"
            )
            .set_tap_callback(function(entry) {
                self.entry_popup = self.create_entry_popup(entry);
            }, [entry])
        var icon = ANCHOR.sprite(tile)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(entry.icon)
            .set_lut(spr_ui_skills_icon_lut, 0)
            .set_alpha(at_req_level ? 1 : 0)

        //
        if !at_req_level {
            //
            tile.set_soft_locked();
            tile.set_think_callback(function(tile, icon, category) {
                var index = tile.is_hovered() ? category.hovered_lut_index : category.default_lut_index;
                tile.set_lut_index(index);
                icon.set_lut_index(index);
            }, [tile, icon, category]);
        } else {
            tile.set_think_callback(function(tile, icon, entry, category) {
                var acquired = self.entry_is_acquired(entry);
                var enabled = self.entry_is_enabled(entry);
                var default_index = undefined;
                var hovered_index = undefined;
                if !acquired {
                    default_index = 1;
                    hovered_index = 2;
                } else {
                    default_index = enabled ? category.default_lut_index : category.disabled_lut_index;
                    hovered_index = enabled ? category.hovered_lut_index : category.disabled_lut_index;
                }
                var index = tile.is_hovered() ? hovered_index : default_index;
                tile.set_lut_index(index);
                icon.set_lut_index(index);
            }, [tile, icon, entry, category]);
        }

        //
        var name = at_req_level ? local_get(entry.name) : "???";
        var width = string_width_font(name) + 24;
        var bubble = ANCHOR.nine_slice(tile, BUBBLE_Z);
        bubble
            .set_sprite(spr_ui_skills_namebubble)
            .set_size(width, 18)
            .set_y(-3)
            .set_alpha(0)
            .set_align(Align.Center, Align.TopOut)
            .set_think_callback(function(bubble, tile) {
                bubble.set_alpha(tile.is_hovered() ? 1 : 0);
            }, [bubble, tile]);
        ANCHOR.sprite(bubble)
            .set_sprite(spr_ui_skills_namebubble_arrow)
            .set_align(Align.Center, Align.BottomOut)
            .set_y(-1)
        ANCHOR.text(bubble)
            .set_text(name)
            .set_align(Align.Center, Align.Middle)
            .set_lut(spr_ui_skills_lut);

        if at_req_level {
            self.create_cost_nodes(tile, entry, spr_ui_skills_essence_icon_no_shadow)
                .set_y(5)
        }


        return tile;
    }

    //
    function create_entry_popup(entry) {
        var acquired = self.entry_is_acquired(entry);
        var popup = popup_creator(entry.name, entry.description);
        popup.create_button("misc_local/close");
        if !acquired {
            var button = popup.create_button(
                "misc_local/learn",
                self.purchase_entry,
                [entry],
                "SoundEffects/UI/UIExtraPositiveClick",
            );
            var can_afford = self.can_purchase_entry(entry);
            button.set_unlocked(can_afford);
        } else {
            var enabled = self.entry_is_enabled(entry);
            if !enabled {
                popup.body_text.set_alpha(0.5);
                popup.title.set_alpha(0.5);
            }
            popup.enable_button = popup.create_button(
                format("misc_local/{}", enabled ? "disable" : "enable"),
                function(entry) {
                    if self.entry_is_enabled(entry) {
                        ARI.perks_active[entry.perk] = false;
                    } else {
                        ARI.perks_active[entry.perk] = true;
                    }
                },
                [entry]
            );
        }
        if !self.entry_is_acquired(entry) {
            popup.backplate.add_height(9);
            self.create_cost_nodes(popup.header, entry)
                .set_y(3)
        }
        return popup.spawn();
    }

    //
    function create_cost_nodes(parent, entry, icon_spr=spr_ui_journal_inventory_essence_icon) {
        var cost = ANCHOR.text(parent);
        cost
            .set_text(entry.essence)
            .set_align(Align.Center, Align.BottomOut)
            .set_x(-sprite_get_width(spr_ui_skills_essence_icon) / 2)
            .set_sprite_font("item_count")
            .set_think_callback(function(cost, entry) {
                var acquired = self.entry_is_acquired(entry);
                cost.set_alpha(acquired ? 0 : 1);
                cost.set_lut(spr_ui_skills_lut, ARI.get_essence() >= entry.essence ? 1 : 4);
            }, [cost, entry])
        ANCHOR.sprite(cost)
            .set_sprite(icon_spr)
            .set_align(Align.RightOut, Align.Middle)
                .set_x(1);
        return cost;
    }

    //
    function transition(target_state, build_function, args) {
        self.cancel_transition();
        self.state = DragonShrineState.Transition;
        self.lock();
        ANCHOR.release_active_pilot();
        var a = self.sub_canvas.get_alpha();
        self.chain = new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, a, 0, 15), function(_, ab) {
                self.sub_canvas.set_alpha(ab);
            })
            .append(LinkId.Timer, 10)
            .append(LinkId.Function, function(build_function, args) {
                function_execute_alt(build_function, args);
            }, [build_function, args])
            .append(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 15), function(_, ab) {
                self.sub_canvas.set_alpha(ab);
            })
            .append(LinkId.Function, function(target_state) {
                self.unlock();
                self.state = target_state;
                self.chain = undefined;
            }, [target_state])
    }

    //
    function ari_level_in_category(category) {
        switch self.variant {
            case ShrineMenuVariant.Caldarus:
            case ShrineMenuVariant.Seridia:
                return ARI.level(category.skill);
            case ShrineMenuVariant.Horse: return 1;
            default: impossible("Unexpected ShrineMenuVariant: {}", self.variant);
        }
    }

    //
    function entry_is_acquired(entry) {
        assert_neq(entry.perk != undefined, "Can't handle entry: {}", entry);
        return ARI.perks[entry.perk];
    }

    //
    function can_purchase_entry(entry) {
        assert_neq(entry.perk != undefined, "Can't handle entry: {}", entry);
        return ARI.get_essence() >= entry.essence;
    }

    //
    function entry_is_enabled(entry) {
        return ARI.perk_active(entry.perk);
    }

    //
    function purchase_entry(entry) {
        ARI.modify_essence(-entry.essence);
        assert_neq(entry.perk != undefined, "Can't handle entry: {}", entry);
        ARI.acquire_perk(entry.perk);
    }

    //
    self.canvas.set_think_callback(function() {
        switch self.state {
            case DragonShrineState.CategoryScreen:
                if INPUT.take_press(InputId.MenuBack) {
                    self.close();
                }
                break;
            case DragonShrineState.TierScreen:
                if INPUT.take_press(InputId.MenuBack) {
                    self.transition(DragonShrineState.CategoryScreen, function() {
                        self.create_category_nodes(self.scroller.canvas.board_get("cat_key"));
                        self.scroller.free();
                    });
                }
                break;
            default: break;
        }
    });

    function on_close() {
        self.cancel_transition();

        if !ari_has_recipe_anywhere(ItemId.BigBell) && ARI.perks[Perk.TheBellTolls] {
            if instance_exists(obj_dragonshrine) {
                item_from_critical_poof(
                    obj_dragonshrine.x,
                    obj_dragonshrine.y + 20,
                    new LiveItem(ItemId.CraftingScroll, ItemId.BigBell)
                );
            } else {
                ARI.unlock_recipe(ItemId.BigBell, true);
            }
        }

        if !ari_has_recipe_anywhere(ItemId.EssenceStoneGiant) && ARI.perks[Perk.MagicDesign] {
            if instance_exists(obj_dragonshrine) {
                item_from_critical_poof(
                    obj_dragonshrine.x,
                    obj_dragonshrine.y + 20,
                    new LiveItem(ItemId.CraftingScroll, ItemId.EssenceStoneGiant)
                );
            } else {
                ARI.unlock_recipe(ItemId.EssenceStoneGiant, true);
            }
        }

        var can_drop = true;

        with obj_item {
            if item_id == ItemId.VoidSetScrollBundle {
                can_drop = false;
                break;
            }
        }

        if can_drop && ARI.items_acquired[ItemId.VoidSetScrollBundle] == false && ARI.perks[Perk.VoidCrafting] {
            if instance_exists(obj_dragonshrine) {
                item_from_critical_poof(
                    obj_dragonshrine.x,
                    obj_dragonshrine.y + 20,
                    new LiveItem(ItemId.VoidSetScrollBundle)
                );
            } else {
                ARI.give_item(ItemId.VoidSetScrollBundle);
            }
        }

        if !ari_has_recipe_anywhere(ItemId.WaterSpriteStatueLargeV1) && ARI.perks[Perk.BigWaterSprites] {
            if instance_exists(obj_dragonshrine) {
                item_from_critical_poof(
                    obj_dragonshrine.x,
                    obj_dragonshrine.y + 20,
                    new LiveItem(ItemId.CraftingScroll, ItemId.WaterSpriteStatueLargeV1)
                );
            } else {
                ARI.unlock_recipe(ItemId.WaterSpriteStatueLargeV1, true);
            }
        }
    }

    //
    self.essence_backplate = ANCHOR.nine_slice(ANCHOR.screen_canvas)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-5, 5)
        .set_size(30, 16)
        .set_sprite(spr_ui_generalstore_inventory_currencytab)
        .set_think_callback(function() {
            self.essence_backplate.set_alpha(self.canvas.get_alpha());
        })

    self.essence_icon = ANCHOR.sprite(self.essence_backplate)
        .set_x(-4)
        .set_align(Align.RightIn, Align.Middle)
        .set_sprite(spr_ui_hud_info_essence_icon)

    self.essence_text = ANCHOR.text(self.essence_icon)
        .set_x(-2)
        .set_align(Align.LeftOut, Align.Middle)
        .set_sprite_font("currency")
        .set_think_callback(function() {
            var s = num_display(ARI.get_essence());
            self.essence_backplate.set_width(24 + (string_length(s) * 6));
            self.essence_text.set_text(s);
        });

    self.backplate = ANCHOR.nine_slice(self.canvas)
        .set_sprite(spr_ui_skills_box)
        .set_size(400, 184)
        .set_align(Align.Center, Align.Middle)

    self.header_backplate = ANCHOR.nine_slice(self.backplate)
        .set_size(100, 24)
        .set_y(-8)
        .set_sprite(spr_ui_skills_box_header)
        .set_align(Align.Center, Align.TopIn)

    self.header_text = ANCHOR.text(self.header_backplate)
        .set_key("misc_local/skills")
        .set_lut(spr_ui_skills_lut, 1)
        .set_align(Align.Center, Align.Middle)

    //
    self.sub_canvas = ANCHOR.canvas(self.backplate)
        .set_size(self.backplate.get_size())

    self.category_nodes = List();
    self.entry_nodes = List();
    self.variant = variant;
    if self.variant == ShrineMenuVariant.Horse {
        self.create_tier_nodes("mount");
    } else {
        self.create_category_nodes();
    }
    self.state = DragonShrineState.CategoryScreen;
}

#macro DRAGON_SHRINE_DATA global.__dragon_shrine_data
DRAGON_SHRINE_DATA = undefined;

function load_dragon_shrine_data() {
    var toml_data = MapWrap(fiddle_get_directory("ui/skill_menu"));
    var defaults = filter_toml_nulls(toml_data.take("defaults"));
    var keys = toml_data.keys();
    var collection = Map();
    for (var i = 0; i < array_length(keys); i++) {
        //
        var key = keys[i];
        var prototype = toml_data.get(key);
        filter_toml_nulls(prototype);
        apply_defaults(prototype, defaults.category);

        //
        for (var j = 0; j < 5; j++) {
            var tier = prototype[$ fmt("tier_{}", j + 1)];
            for (var k = 0; k < array_length(tier); k++) {
                var entry = tier[k];
                filter_toml_nulls(entry);
                apply_defaults(entry, defaults.entry);
                entry.icon = string_to_asset(entry.icon);
                if entry.perk != undefined {
                    entry.perk = string_to_perk(entry.perk);
                    var perk_data = fiddle_get(format("perks/{Perk}", entry.perk));
                    entry.name = perk_data.name;
                    entry.description = perk_data.description;

                    //
                    var fields = struct_get_names(perk_data);
                    for (var h = 0; h < array_length(fields); h++) {
                        var field_name = fields[h];
                        var pattern = fmt("{{{}}}", field_name);
                        if string_pos(pattern, entry.description) != 0 {
                            entry.description = string_replace_all(
                                entry.description,
                                pattern,
                                perk_data[$ field_name],
                            );
                        }
                    }
                }

                //
                tier[k] = entry;
            }
        }

        //
        prototype.skill = try_string_to_skill(key);
        collection.set(key, prototype);
    }
    return collection;
}

//
//
function get_tier_five_perks_by_category() {
    var groups = [];
    var keys = DRAGON_SHRINE_DATA.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var tier_five = DRAGON_SHRINE_DATA.get(keys[i]).tier_5;
        var perks = [];
        for (var j = 0; j < array_length(tier_five); j++) {
            if tier_five[j].perk != undefined {
                array_push(perks, tier_five[j].perk);
            }
        }
        if !array_is_empty(perks) {
            array_push(groups, perks);
        }
    }
    return groups;
}

enum DragonShrineState {
    CategoryScreen,
    TierScreen,
    Transition,
    LEN,
}
