function CraftingMenu(object_id) : AnchorMenu(Menu.Crafting) constructor {
    function on_free() {
        ANCHOR.free_node(self.corner_plate);
    }

    function on_close() {
        var items_to_yield = List();
        for (var i = 0, c = self.recipe_history.count(); i < c; i++) {
            var recipes = ITEM_PROTOTYPES[self.recipe_history.get(i).item_id].recipe;
            var return_item_chance = 0;
            var triggered_perk = -1;
            var secondary_perk = -1;

            switch self.context {
                case RecipeContext.Woodcrafting:
                    return_item_chance = ARI.perk_value(Perk.WorkingWithTheGrain) + ARI.perk_value(Perk.WorkingWithTheGrainTwo);
                    triggered_perk = Perk.WorkingWithTheGrain;
                    secondary_perk = Perk.WorkingWithTheGrainTwo;

                    if chance_percent(ARI.perk_value(Perk.SetPieces)) {
                        items_to_yield.push(new LiveItem(self.recipe_history.get(i).item_id));
                        GAME_STATS.perks[$ perk_to_string(Perk.SetPieces)] += 1;
                    }

                    if ARI.perk_active(Perk.AncientInspiration) && ARI.ancient_inspiration_time <= 0 {
                        repeat (array_length(ANCIENT_INSPIRATION) * 2) {
                            var item = ANCIENT_INSPIRATION[irandom_range(0, array_length(ANCIENT_INSPIRATION) - 1)];

                            if ari_has_recipe_anywhere(item) {
                                continue;
                            }

                            items_to_yield.push(new LiveItem(ItemId.CraftingScroll, item));
                            GAME_STATS.perks[$ perk_to_string(Perk.AncientInspiration)] += 1;
                            ARI.ancient_inspiration_time = fiddle_get(format("perks/{Perk}/days", Perk.AncientInspiration));
                            break;
                        }
                    }
                    break;

                case RecipeContext.Cooking:
                    return_item_chance = ARI.perk_value(Perk.WasteNotWantNot);
                    triggered_perk = Perk.WasteNotWantNot;

                    if chance_percent(ARI.perk_value(Perk.DinnerForTwo)) {
                        GAME_STATS.perks[$ perk_to_string(Perk.DinnerForTwo)] += 1;
                        items_to_yield.push(new LiveItem(self.recipe_history.get(i).item_id));
                    }
                    break;

                case RecipeContext.Milling:
                    if chance_percent(ARI.perk_value(Perk.MaximumMilling)) && ITEM_PROTOTYPES[self.recipe_history.get(i).item_id].animal_feed != undefined {
                        GAME_STATS.perks[$ perk_to_string(Perk.MaximumMilling)] += 1;
                        items_to_yield.push(new LiveItem(self.recipe_history.get(i).item_id));
                    }
                    break;
                case RecipeContext.Refining:
                    if chance_percent(ARI.perk_value(Perk.BreakOneGetTwo)) {
                        GAME_STATS.perks[$ perk_to_string(Perk.BreakOneGetTwo)] += 1;
                        items_to_yield.push(new LiveItem(self.recipe_history.get(i).item_id));
                    }
                    break;
            }

            if chance_percent(return_item_chance) {
                //
                var temp_list = List();
                var components = recipes.components;
                for (var j = 0; j < components.count(); j++) {
                    var component = components.get(j);
                    if component.type == RecipeComponentType.Item {
                        temp_list.push(component.item_id);
                    }
                }

                items_to_yield.push(new LiveItem(temp_list.choose_random()));
                GAME_STATS.perks[$ perk_to_string(triggered_perk)] += 1;
                if secondary_perk != -1 && ARI.perks[secondary_perk] {
                    GAME_STATS.perks[$ perk_to_string(secondary_perk)] += 1;
                }
            }
        }

        var consolidated_list = List();
        while !items_to_yield.is_empty() {
            var item = items_to_yield.pop();
            var found_match = false;
            for (var i = 0; i < consolidated_list.count(); i++) {
                var test_list = consolidated_list.get(i);
                var test_item = test_list.first();
                if test_item.partial_eq(item) {
                    found_match = true;
                    test_list.push(item);
                }
            }
            if !found_match {
                consolidated_list.push(List(item));
            }
        }

        for (var i = 0; i < consolidated_list.count(); i++) {
            var items = consolidated_list.get(i).to_array();
            var dir_range = Vec2Zero();
            if matches(CURRENT_LOCATION_ID, LocationId.Inn, LocationId.Mill) {
                dir_range.x = 245;
                dir_range.y = 315;
            }

            item_from_critical_poof(
                self.object_coordinates.x,
                self.object_coordinates.y,
                items,
                dir_range.x,
                dir_range.y,
                true,
            );
        }
    }

    function initialize(sub_data) {
        self.sub_data = sub_data;
        self.context = self.sub_data.get("context");

        var sprites = self.sub_data.get("sprites");
        self.recipe_history = List();
        self.book.set_sprite(sprites.get("backplate"));
        self.text_lut = sprites.get("text_lut");
        self.item_name.set_lut(self.text_lut, self.lut_indexes.get("title"));
        self.description.set_lut(self.text_lut, self.lut_indexes.get("body"));
        self.quantity_text.set_lut(self.text_lut, self.lut_indexes.get("quantity"));
        self.stat_one_root.set_enabled(self.sub_data.get("stat_one") != undefined);
        if self.stat_one_root.get_enabled() {
            self.stat_one_icon.set_sprite(sprites.get("stat_one_icon"));
            self.stat_one_text.set_lut(self.text_lut, self.lut_indexes.get("stat_numbers"));
        }
        self.stat_two_root.set_enabled(self.sub_data.get("stat_two") != undefined);
        if self.stat_two_root.get_enabled() {
            self.stat_two_icon.set_sprite(sprites.get("stat_two_icon"));
            self.stat_two_text.set_lut(self.text_lut, self.lut_indexes.get("stat_numbers"));
        }
        self.craft_icon.set_sprite(sprites.get("craft_icon"))
        self.craft_button.set_lut(sprites.get("button_lut"))
        self.plus_button.set_lut(sprites.get("button_lut"))
        self.plus_icon.set_lut(sprites.get("button_label_invalid_lut"))
        self.minus_button.set_lut(sprites.get("button_lut"))
        self.minus_icon.set_lut(sprites.get("button_label_invalid_lut"))
        self.max_button.set_lut(sprites.get("button_lut"))
        self.max_icon.set_lut(sprites.get("button_label_invalid_lut"))
        self.duration_icon.set_sprite(sprites.get("clock"));
        self.craft_button.text_label.set_lut(sprites.get("button_label_invalid_lut"));

        var index = self.sub_data.get("open_to_index");
        self.select_category(index);

        self.carousel = self.build_carousel(index);
        self.carousel.window.set_sprite(sprites.get("window"));
        self.carousel.arrow_left_icon.set_sprite(sprites.get("left_arrow"));
        self.carousel.arrow_right_icon.set_sprite(sprites.get("right_arrow"));
        self.carousel.arrow_left_button.set_lut(sprites.get("button_lut"));
        self.carousel.arrow_right_button.set_lut(sprites.get("button_lut"));
        self.corner_skill.skill = self.sub_data.get("skill");
        if self.corner_skill.skill == undefined {
            self.corner_plate.disable();
        } else {
            self.corner_plate.set_sprite(sprites.get("corner_plate"));
            self.corner_skill.update_level();
        }
        self.object_coordinates = Vec2(0, 0);
        self.duration_text.set_x(sprite_get_width(self.duration_icon.get_sprite()) / 2);

        if sub_data.get("corner_tier") {
            self.corner_tier.enable();
            self.corner_tier.text.set_text(NODE_PROTOTYPES[self.object_id].interact_menu.kitchen_level);
            self.corner_skill.add_y(17);
            self.level_requirement_box.set_xy(self.layout.level_requirement_box.cooking_position);
        }
    }

    function select_category(category_index) {
        self.category_index = category_index;
        var category = self.sub_data.get("categories").get(self.category_index);

        self.left_pilot.reset();

        //
        if self.scroller != undefined {
            self.scroller.free();
        }
        self.scroller = create_scroller(self.left_body)
            .subscribe_to_pilot(self.left_pilot)
            .set_pilot_padding(37, 32)
            .alternate_colors(false)
            //

        self.scroller.outline.enable();
        self.scroller.outline.set_sprite(self.sub_data.get("sprites").get("scroller_outline"));

        var true_sub_cat_len = category.sub_categories.count();
        var filtered_sub_cats = category.sub_categories.fold(List(), function(filtered_sub_cats, sub_category) {
            var any_unlocked = sub_category.items.any(function(e) {
                return ARI.recipe_unlocks[e.item_id];
            });

            if !any_unlocked {
                return filtered_sub_cats;
            }

            //
            var items = sub_category.items.clone();

            if !sub_category.is_manually_ordered {
                items.sort_with(function(e1, e2) {
                    var e1_unlocked = ARI.recipe_unlocks[e1.item_id];
                    var e2_unlocked = ARI.recipe_unlocks[e2.item_id];
                    if e1_unlocked && e2_unlocked {
                        var e1_name = e1.get_display_name();
                        var e2_name = e2.get_display_name();
                        if e1_name == e2_name {
                            return e1.item_id < e2.item_id ? -1 : 1;
                        } else {
                            return string_alphanumeric_comparison(e1_name, e2_name);
                        }
                    } else if e1_unlocked {
                        return -1;
                    } else {
                        return 1;
                    }
                });
            }

            //
            if sub_category.craftable_only {
                items.retain(function(item) {
                    return check_item_craftable(item, 1);
                });
            }

            //
            if !sub_category.show_locked {
                items.retain(function(item) {
                    return ARI.recipe_unlocks[item.item_id];
                });
            }

            //
            if items.is_empty() {
                return filtered_sub_cats;
            }

            filtered_sub_cats.push({
                items: items,
                sub_category: sub_category,
            });
            return filtered_sub_cats;
        });

        //
        var header = self.scroller.new_element(self.layout.category.header_height)
            .set_enabled_sprite(self.sub_data.get("sprites").get("category_header"))

        var icon = ANCHOR.sprite(header)
            .set_sprite(category.icon)
            .set_align(Align.LeftIn, Align.Middle)
            .set_x(self.layout.category.icon_offset.x)

        ANCHOR.text(icon)
            .set_x(4)
            .set_align(Align.RightOut, Align.Middle)
            .set_key(category.name)
            .set_lut(self.text_lut, self.lut_indexes.get("category_name"))

        for (var i = 0; i < filtered_sub_cats.count(); i++) {
            var filtered_sub_cat = filtered_sub_cats.get(i);
            var items = filtered_sub_cat.items;
            var sub_category = filtered_sub_cat.sub_category;

            //
            if true_sub_cat_len == 1 {
                var element = self.scroller.new_element(self.layout.category.bottom_padding)
            } else {
                var element = self.scroller.new_element(self.layout.category.top_padding)

                var icon = ANCHOR.sprite(element)
                    .set_sprite(sub_category.icon)
                    .set_xy(self.layout.category.icon_offset)

                ANCHOR.text(icon)
                    .set_x(4)
                    .set_align(Align.RightOut, Align.Middle)
                    .set_key(sub_category.name)
                    .set_lut(self.text_lut, self.lut_indexes.get("body"))
            }

            //
            //
            var layout = new GridLayout(
                items,
                self.left_pilot,
                self.layout.options.per_row,
                self.layout.options.square_size,
            );

            var container_size = layout.container_size();
            var container = ANCHOR.positional(element)
                .set_size(container_size)
                .set_align(Align.Center, Align.TopIn)
                .set_y(element.get_height())

            //
            self.scroller.add_height_to_element(
                element,
                container_size.y + self.layout.category.bottom_padding,
            );

            while layout.has_next() {
                var next = layout.next(container);
                var square = next.square;
                var icon = next.icon;
                var item = next.asset;

                if !self.sub_data.get("use_common_slice") {
                    square.set_sprites_from_key("spr_ui_crafting_box");
                }

                if item != undefined {
                    square.board_set("item_id", item.item_id);

                    if !ARI.recipe_unlocks[item.item_id] {
                        square.listen_for_taps();
                        square.set_soft_locked();
                        icon.set_sprite(self.sub_data.get("sprites").get("lock"));
                    } else {
                        icon.set_sprite(item.get_ui_icon());
                        square.set_tap_callback(function(item) {
                            self.quantity = 1;
                            self.set_to_item(item);
                            ANCHOR.set_active_pilot(self.bottom_pilot)
                        }, [item]);
                        square.set_selected_getter(function(item) {
                            return item == self.item && ANCHOR.get_active_pilot() != self.left_pilot;
                        }, [item])

                        if !self.check_item_craftable(item, 1) {
                            icon.set_alpha(0.5);
                        }
                    }
                }
            }
        }
    }

    function reset_right_page() {
        self.item = undefined;
        self.item_name.disable();
        self.description.disable();
        self.quantity_text.disable();
        self.duration_text.disable();
        self.stat_one_text.set_text("--");
        self.stat_two_text.set_text("--");
        self.stat_one_root.update_size();
        self.stat_two_root.update_size();
        self.tier_requirement.disable();
        self.level_requirement_root.disable();
        self.plus_button.set_valid(false);
        self.minus_button.set_valid(false);
        self.max_button.set_valid(false);
        self.craft_button.set_valid(false);
        ANCHOR.free_children(self.preview_box);
        ANCHOR.free_children(self.recipe_box);
        self.right_pilot.reset();
        if self.tooltip != undefined {
            self.tooltip = undefined;
        }
    }

    function set_to_item(item) {

        item = is_struct(item) ? item : new LiveItem(item);
        self.reset_right_page();

        self.item = item;

        //
        self.item_name
            .enable()
            .set_ghost_key(self.item.prototype.name_key)
            .set_text(self.item.get_display_name())
        self.description
            .enable()
            .set_ghost_key(self.item.prototype.description_key)
            .set_text(self.item.get_display_description())
        self.duration_icon.enable();

        self.handle_preview(self.item);

        var gold_icon = ANCHOR.sprite(self.preview_box)
            .set_position(-1, 1, 1)
            .set_align(Align.RightIn, Align.TopIn)
            .set_sprite(spr_ui_crafting_tesserae_icon)

        ANCHOR.text(gold_icon)
            .set_sprite_font("item_count")
            .set_align(Align.LeftOut, Align.Middle)
            .set_text(item.bin_value());

        var stat_one_key = self.sub_data.get("stat_one");
        var stat_two_key = self.sub_data.get("stat_two");
        if stat_one_key != undefined {
            var stat = self.item.prototype[$ stat_one_key];
            self.stat_one_text.set_text(stat == undefined || stat == 0 ? "--" : stat);
            self.stat_one_root.update_size();
        }
        if stat_two_key != undefined {
            var stat = self.item.prototype[$ stat_two_key];
            self.stat_two_text.set_text(stat == undefined || stat == 0 ? "--" : stat);
            self.stat_two_root.update_size();
        }

        var can_craft_whole_item = self.check_item_craftable(self.item, self.quantity);

        var recipe = self.item.prototype.recipe.components.clone();

        if self.item.prototype.kitchen_tier_requirement != undefined {
            var needed_tier = item.prototype.kitchen_tier_requirement;
            var satisfies_kitchen = NODE_PROTOTYPES[self.object_id].interact_menu.kitchen_level >= needed_tier;
            var lut_index = satisfies_kitchen ? CommonLutIndex.Green : CommonLutIndex.Red;
            self.tier_requirement.enable();
            self.tier_requirement.set_text(item.prototype.kitchen_tier_requirement);
            self.tier_requirement.set_lut_index(lut_index);
        }

        if item.prototype.crafting_level_requirement != undefined {
            var skill = self.sub_data.get("skill");
            self.level_requirement_root.enable();
            var satisfies_level = ARI.level(skill) >= item.prototype.crafting_level_requirement;
            var lut_index = satisfies_level ? CommonLutIndex.Green : CommonLutIndex.Red;
            self.level_requirement_icon.set_sprite(
                string_to_asset(fiddle_get(format("skills/{Skill}/sprite", skill)))
            );
            self.level_requirement.set_text(item.prototype.crafting_level_requirement);
            self.level_requirement.set_lut_index(lut_index);
            self.level_requirement_root.set_width_for_nodes([
                self.level_requirement_icon,
                self.level_requirement,
            ]);
        } else {
            self.level_requirement_root.disable();
        }

        if self.item.prototype.stars != undefined {
            self.stars.enable();
            self.stars.set_sprite(
                string_to_asset(
                    format(
                        "spr_ui_cooking_quality_star_level_{}",
                        item.prototype.stars,
                    )
                )
            );
        } else {
            self.stars.disable();
        }

        //
        var duration_index = recipe.find(function(e) {
            return e.type == RecipeComponentType.Duration;
        });
        if duration_index != undefined {
            var comp = recipe.remove(duration_index);
            var duration = get_modified_component_count(comp, self.context, self.item.item_id) * self.quantity;
            var can_afford = can_fulfill_component(comp, self.item.item_id, self.quantity, self.context);

            self.duration_text.enable();
            var lut_index = self.lut_indexes.get(can_afford ? "duration" : "duration_invalid");
            self.duration_text.set_lut(self.text_lut, lut_index);
            var display_number = duration >= hours(1) ? duration / hours(1) : duration / minutes(1);
            display_number = (round(display_number * 10)) / 10; //
            self.duration_text.set_text(fmt(
                "{} {Local}",
                num_display(display_number),
                duration >= hours(1) ? "misc_local/hr" : "misc_local/min",
            ));
        } else {
            self.duration_text.disable();
        }

        //
        var len = recipe.count();
        assert(
            is_between_inclusive(len, 1, 6),
            "Recipes must have 1 to 6 items, cannot support {}",
            len,
        );

        var pos = self.layout.recipe_square.start_pos.clone();
        for (var i = 0; i < len; i++) {
            var component = recipe.remove(0);

            var this_item = undefined;
            switch component.type {
                case RecipeComponentType.Item:
                    this_item = new LiveItem(component.item_id);
                    break;
                case RecipeComponentType.Essence:
                    this_item = new LiveItem(ItemId.FakeEssence);
                    break;
                default: break;
            }

            var box = common_slice(self.recipe_box)
                .set_xy(pos)
                .set_size(self.layout.recipe_square.size)
                .listen_for_hovers()
                .add_to_pilot(self.right_pilot);

            if !self.sub_data.get("use_common_slice") {
                box.set_sprites_from_key("spr_ui_crafting_box");
            }

            if this_item != undefined {
                box.set_think_callback(function(this_item, box) {
                    if box.hover_duration() >= 30 {
                        if self.tooltip == undefined {
                            self.tooltip = create_tooltip(this_item, box);
                        }
                    } else if self.tooltip != undefined && self.tooltip.source_node == box {
                        self.tooltip.close();
                        self.tooltip = undefined;
                    }
                }, [this_item, box])
            }

            var can_afford = can_fulfill_component(component, self.item.item_id, self.quantity, self.context);

            var can_afford_without_chests = can_fulfill_component(component, self.item.item_id, self.quantity, undefined, false);

            if can_afford && !can_afford_without_chests {
                ANCHOR.sprite(box)
                    .set_sprite(spr_ui_crafting_icon_storage)
                    .set_align(Align.RightIn, Align.TopIn)
            }

            var icon = ANCHOR.sprite(box)
                .set_xy(self.layout.recipe_item.position)
                .set_align(Align.Center, Align.TopIn)
                .set_alpha(can_afford ? 1 : 0.5)

            var ari_needs = string(get_modified_component_count(component, self.context, self.item.item_id) * self.quantity);

            switch component.type {
                case RecipeComponentType.Item:
                    icon.set_sprite(this_item.get_ui_icon());

                    var ari_has = maximum_fulfillment_for_component(component);
                    ari_has = ari_has > 99 ? "99+" : string(ari_has);

                    //
                    var width = sprite_font_width(format("{}/{}", ari_has, ari_needs), "item_count");
                    var count_container = ANCHOR.positional(box)
                        .set_align(Align.Center, Align.BottomIn)
                        .set_size(width, 7)
                        .set_y(-2)

                    var ari_count = ANCHOR.text(count_container)
                        .set_text(ari_has)
                        .set_align(Align.LeftIn, Align.Middle)
                        .set_sprite_font("item_count")
                        .set_lut(self.text_lut, self.lut_indexes.get(can_afford ? "quantity_valid" : "quantity_invalid"));

                    var slash = ANCHOR.text(ari_count)
                        .set_text("/")
                        .set_align(Align.RightOut, Align.Middle)
                        .set_sprite_font("item_count")
                        .set_lut(self.text_lut, self.lut_indexes.get("quantity_neutral"));

                    ANCHOR.text(slash)
                        .set_text(ari_needs)
                        .set_align(Align.RightOut, Align.Middle)
                        .set_sprite_font("item_count")
                        .set_lut(self.text_lut, self.lut_indexes.get("quantity_neutral"));
                    break;
                case RecipeComponentType.Essence:
                    icon.set_sprite(spr_ui_item_essence);

                    ANCHOR.text(box)
                        .set_align(Align.Center, Align.BottomIn)
                        .set_y(-2)
                        .set_text(ari_needs)
                        .set_sprite_font("item_count")
                        .set_lut(self.text_lut, self.lut_indexes.get(can_afford ? "quantity_valid" : "quantity_invalid"));

                    break;
                default: impossible("Menu is not set up to display {RecipeComponentType}", component.type);
            }

            if (i + 1) % self.layout.recipe_box.columns == 0 {
                pos.x = self.layout.recipe_square.start_pos.x;
                pos.y += self.layout.recipe_square.inc.y;
                self.right_pilot.request_newline();
            } else {
                pos.x += self.layout.recipe_square.inc.x;
            }
        }

        //
        self.craft_button.board_set("can_craft", can_craft_whole_item);
        self.minus_button.set_valid(self.quantity > 1);
        self.plus_button.set_valid();
        self.max_button.set_valid(true);
        self.craft_button.set_valid(can_craft_whole_item);
        self.quantity_text
            .enable()
            .set_text(self.quantity)
            .set_lut(
                self.text_lut,
                self.lut_indexes.get(
                    can_craft_whole_item
                    ? "quantity_count_valid"
                    : "quantity_count_invalid"
                )
            )
    }

    function check_item_craftable(item, quantity) {
        return self.maximum_crafts(item) >= quantity;
    }

    function maximum_crafts(item) {
        var maximum = I32_MAX;
        var recipe = item.prototype.recipe.components.clone();

        if item.prototype.kitchen_tier_requirement != undefined {
            var needed_tier = item.prototype.kitchen_tier_requirement;
            var satisfies_kitchen = NODE_PROTOTYPES[self.object_id].interact_menu.kitchen_level >= needed_tier;
            if !satisfies_kitchen {
                return 0;
            }
        }

        //
        var duration_index = recipe.find(function(e) {
            return e.type == RecipeComponentType.Duration;
        });
        if duration_index != undefined {
            var comp = recipe.remove(duration_index);
            var denominator = get_modified_component_count(comp, self.context, item.item_id);
            if denominator != 0 {
                var max_fulfill = maximum_fulfillment_for_component(comp) div denominator;
                maximum = min(maximum, max_fulfill);
            }
        }

        var skill = self.sub_data.get("skill");
        if skill != undefined
            && ARI.level(skill) < item.prototype.crafting_level_requirement
        {
                return 0;
        }

        for (var i = 0; i < recipe.count(); i++) {
            var comp = recipe.get(i);
            var denominator = get_modified_component_count(comp, self.context, item.item_id);
            var max_fulfill = maximum_fulfillment_for_component(comp) div denominator;
            maximum = min(maximum, max_fulfill);
        }

        return maximum;
    }

    function handle_preview(item) {
        //
        ANCHOR.free_children(self.preview_box);

        //
        if item.prototype.crafting_preview_sprite != undefined {
            var centered = centered_position_from_bbox(
                item.prototype.crafting_preview_sprite,
                self.preview_box.get_size(),
            );

            ANCHOR.sprite(self.preview_box)
                .set_sprite(item.prototype.crafting_preview_sprite)
                .set_xy(centered)
                .set_speed(1);

            return;
        }

        //
        var is_furniture = opt_and_then(item.prototype.object, function(v) {
            return object_id_to_object_category(v) == ObjectCategory.Furniture;
        });

        if is_furniture {
            var proto = NODE_PROTOTYPES[item.prototype.object];
            assert(
                array_length(proto.cardinals) > 0,
                "{ObjectId} has no cardinals!",
                proto.object_id,
            );

            var first_cardinal = proto.cardinal_data[proto.cardinals[0]];

            var sprite = first_cardinal[$ "on_sprite"] ?? first_cardinal.sprite;

            //
            if animation_to_shape(sprite) == undefined {
                warn("Missing a shape for '{gm_sprite}'!", sprite);
                var centered = Vec2Zero();
            } else {
                var centered = centered_position_from_bbox(
                    sprite,
                    self.preview_box.get_size(),
                );
            }

            var preview = ANCHOR.sprite(self.preview_box)
                .set_sprite(sprite)
                .set_xy(centered)

            if first_cardinal[$ "on_sprite"] != undefined {

                preview.set_speed(1);
                preview.set_think_callback(function(preview) {
                    var centered = centered_position_from_bbox(
                        preview.get_sprite(),
                        self.preview_box.get_size(),
                        preview.get_index()
                    );
                    preview.set_xy(centered);
                }, [preview]);
            }

            if first_cardinal[$ "top_sprite"] != undefined {
                var centered = centered_position_from_bbox(
                    first_cardinal.top_sprite,
                    self.preview_box.get_size(),
                );
                ANCHOR.sprite(self.preview_box)
                    .set_sprite(first_cardinal.top_sprite)
                    .set_xy(centered)
                    .set_z(preview.get_z() - 1)
            }

            return;
        }

        //
        ANCHOR.sprite(self.preview_box)
            .set_align(Align.Center, Align.Middle)
            .set_sprite(item.get_ui_icon())
            .set_y(self.sub_data.get("preview_y_offset"))
            .set_speed(1);
    }
    //
    function build_carousel(index_to_select=0) {
        var cats = self.sub_data.get("categories");
        var icons = cats.map_to(function(v) {
            return v.icon;
        });

        var carousel = new Carousel();
        carousel.spawn(icons, self.left_header, self.carousel_callback, index_to_select);

        carousel.arrow_left_button.set_sprites_from_key("spr_ui_crafting_button");
        carousel.arrow_right_button.set_sprites_from_key("spr_ui_crafting_button");
        carousel.arrow_left_button.set_size(22, 22);
        carousel.arrow_right_button.set_size(22, 22);
        carousel.arrow_left_icon.set_sprite(self.sub_data.get("sprites").get("left_arrow"));
        carousel.arrow_right_icon.set_sprite(self.sub_data.get("sprites").get("right_arrow"));
        carousel.arrow_left_icon.set_key_sprite_target(undefined);
        carousel.arrow_right_icon.set_key_sprite_target(undefined);

        return carousel;
    }

    function carousel_callback(cat_index) {
        self.select_category(cat_index);
        ANCHOR.set_active_pilot(self.left_pilot);
        self.reset_right_page();
    }

    //
    function modify_quantity(amount) {
        self.quantity = clamp(self.quantity + amount, 1, 999);
        self.set_to_item(self.item);
    }

    //
    function start_craft_sequence() {
        //
        var recipe = self.item.prototype.recipe;
        self.item_lists.clear();
        var temp_list = List();
        repeat self.quantity {
            recipe.craft_into(temp_list);
            for (var i = 0; i < temp_list.count(); i++) {
                var item = temp_list.get(i);
                var found_match = false;
                for (var j = 0; j < self.item_lists.count(); j++) {
                    var test_list = self.item_lists.get(j);
                    var test_item = test_list.first();
                    if test_item.partial_eq(item) {
                        found_match = true;
                        test_list.push(item);
                    }
                }
                if !found_match {
                    self.item_lists.push(List(item));
                }
            }
            temp_list.clear();
        }

        //
        var target_time = CLOCK.time;
        for (var i = 0; i < recipe.components.count(); i++) {
            var component = recipe.components.get(i);
            if component.type == RecipeComponentType.Duration {
                target_time +=
                    get_modified_component_count(component, self.context, self.item.item_id)
                    * self.quantity;
            }
        }

        //
        self.lock();

        var skill = self.sub_data.get("skill");
        var eases = List();
        if skill != undefined && skill_xp_to_level(skill, ARI.skill_xp[skill]) < MAX_SKILL_LEVEL {
            var value = 0;

            for (var i = 0; i < self.item_lists.count(); i++) {
                var list = self.item_lists.get(i);

                //
                var addition = 0;
                var level = list.first().prototype.crafting_level_requirement;
                level -= level % 2;

                //
                switch skill {
                    case Skill.Cooking:
                        switch level {
                            case 0:
                                addition = 3;
                                break;
                            case 2:
                                addition = 4;
                                break;
                            case 4:
                                addition = 5;
                                break;
                            default:
                                addition = level;
                                break;
                        }
                        break;
                    case Skill.Blacksmithing:
                        switch level {
                            case 0:
                                addition = 3;
                                break;
                            case 2:
                                addition = 3;
                                break;
                            default:
                                addition = level;
                                break;
                        }
                        break;
                    case Skill.Woodcrafting:
                        addition = level == 0 ? 1 : level;
                        break;
                    default: impossible("Unexpected Skill: {Skill}", skill);
                }

                value += addition * list.count();
            }

            if value != 0 {
                eases = calculate_progress_ease_orders(
                    ARI.level(skill),
                    ARI.skill_xp[skill],
                    value,
                    126,
                    MAX_SKILL_LEVEL,
                    function(level, skill) {
                        return skill_level_cost(skill, level);
                    },
                    function(level, skill) {
                        return skill_level_individual_cost(skill, level);
                    },
                    function() {
                        return false;
                    },
                    [skill]
                );

                ARI.gain_xp(skill, value, true);
            }
        }

        MIST.place_on_runtime_blackboard("ari_x", self.ari_pos.x);
        MIST.place_on_runtime_blackboard("ari_y", self.ari_pos.y);
        MIST.place_on_runtime_blackboard("skill", skill == undefined ? "none" : skill_to_string(skill));
        SCREEN_FADER.fade_out(FADE_SPEED_TRANSITION, function(recipe, target_time, eases, skill_id) {
            ANCHOR.spawn_menu(Menu.CraftingSequence, self, recipe, self.item_lists.clone(), target_time, eases, skill_id);
            MIST.place_on_runtime_blackboard("item", item_id_to_string(self.item.item_id));
            MIST.run_scene("crafting");
            self.request_hide();
        }, [recipe, target_time, eases, skill]);

        for (var i = 0; i < self.quantity; i++) {
            self.recipe_history.push(self.item);
            array_push(GAME_STATS[$ self.sub_data.get("game_stats_key")], {
                item: self.item.pretty_print(),
                day: total_days(),
            });
        }
    }

    //
    function run_post_sequence() {
        var recipe = self.item.prototype.recipe;
        pay_component_costs(recipe.components, self.item.item_id, self.quantity, self.context);
        self.item_lists.drain(function(list) {
            ARI.give_item(list.first(), list.count());
        })
        self.quantity = 1;
        self.select_category(self.category_index);
        self.set_to_item(self.item);
        self.unlock();
        self.request_show();
        if self.corner_plate.get_enabled() {
            self.corner_skill.update_level();
        }
        ANCHOR.set_active_pilot(self.bottom_pilot);
    }

    function on_think() {
        var directional_in_page =
            ANCHOR.get_active_pilot() != self.left_pilot
            && ANCHOR.in_directional_control();
        self.scroller.canvas.set_alpha(!directional_in_page ? 1 : 0.5);
        if directional_in_page {
            GLYPH_GUIDE.set_input(InputId.MenuBack, "misc_local/back");
            if INPUT.take_press(InputId.MenuBack) {
                //
                ANCHOR.set_active_pilot(self.left_pilot);
            }
        }

        if self.minus_button.is_pressed() {
            self.minus_icon.set_lut_index(3);
        } else if self.minus_button.is_hovered() {
            self.minus_icon.set_lut_index(2);
        } else {
            self.minus_icon.set_lut_index(1);
        }

        if self.plus_button.is_pressed() {
            self.plus_icon.set_lut_index(3);
        } else if self.plus_button.is_hovered() {
            self.plus_icon.set_lut_index(2);
        } else {
            self.plus_icon.set_lut_index(1);
        }

        if self.max_button.is_pressed() {
            self.max_icon.set_lut_index(3);
        } else if self.max_button.is_hovered() {
            self.max_icon.set_lut_index(2);
        } else {
            self.max_icon.set_lut_index(1);
        }

        self.corner_plate.set_alpha(self.canvas.get_alpha());

        var hovered_node = self.left_pilot.get();
        if hovered_node != undefined
            && ANCHOR.in_directional_control()
            && !hovered_node.soft_locked
            && hovered_node.blackboard.contains_key("item_id")
            && (
                self.item == undefined
                || hovered_node.blackboard.get("item_id") != self.item.item_id
            )
        {
            self.quantity = 1;
            self.set_to_item(hovered_node.blackboard.get("item_id"));
        }
    }

    self.layout = clone_value(fiddle_get("ui/crafting/layout"));
    self.lut_indexes = Map(struct_take(self.layout, "lut_indexes"));
    apply_func(self.layout, function(elem) {
        return apply_func(elem, function(elem) {
            return try_array_to_vec2(elem) ?? elem;
        })
    });

    self.quantity = 1;
    self.category_index = 0;
    self.item = undefined;
    self.sub_data = undefined;
    self.text_lut = undefined;
    self.context = undefined;
    self.item_lists = List();
    self.carousel_nodes = List();
    create_journal_nodes(self.canvas, self);
    self.left_page.set_sprite(spr_nothing);
    self.right_page.set_sprite(spr_nothing);
    self.left_header
        .set_size(self.layout.left_header.size)
        .set_xy(self.layout.left_header.position)
    self.right_header
        .set_size(self.layout.right_header.size)
        .set_xy(self.layout.right_header.position)
    self.object_id = object_id;
    self.tooltip = undefined;
    self.ari_pos = undefined;

    self.item_name = title_for_journal("misc_local/empty_string", self.right_header)
        .disable()

    self.left_pilot = self.new_pilot()
        .allow_horizontal_wrapping()
        .allow_vertical_wrapping();
    self.right_pilot = self.new_pilot();

    self.bottom_pilot = self.new_pilot()

    self.right_pilot.set_neighbor(self.bottom_pilot, Cardinal.South);
    self.bottom_pilot.set_neighbor(self.right_pilot, Cardinal.North);
    self.scroller = undefined;

    self.recipe_box = ANCHOR.positional(self.right_body)
        .set_size(self.layout.recipe_box.size)
        .set_xy(self.layout.recipe_box.position)

    self.preview_box = ANCHOR.canvas(self.right_body)
        .set_size(self.layout.preview_box.size)
        .set_xy(self.layout.preview_box.position)
        .set_render_partial(
            0,
            0,
            self.layout.preview_box.size.x,
            self.layout.preview_box.size.y,
        )

    self.stat_box = ANCHOR.positional(self.right_body)
        .set_size(self.layout.stat_box.size)
        .set_xy(self.layout.stat_box.position)

    self.stat_one_root = ANCHOR.positional(self.stat_box)
        .set_align(Align.Center, Align.TopIn)
        .set_y(7)

    self.stat_one_icon = ANCHOR.sprite(self.stat_one_root)
        .set_align(Align.LeftIn, Align.TopIn)

    self.stat_one_text = ANCHOR.text(self.stat_one_icon)
        .set_x(4)
        .set_align(Align.RightOut, Align.Middle)
        .set_sprite_font("player_level")
        .set_text("--");

    self.stat_one_root.update_size = function() {
        self.stat_one_root.set_width_for_nodes([self.stat_one_icon, self.stat_one_text]);
        self.stat_one_root.set_height(self.stat_one_icon.get_height());
    }
    self.stat_one_root.update_size();

    self.stat_two_root = ANCHOR.positional(self.stat_box)
        .set_align(Align.Center, Align.BottomIn)
        .set_y(-7)

    self.stat_two_icon = ANCHOR.sprite(self.stat_two_root)
        .set_align(Align.LeftIn, Align.TopIn)

    self.stat_two_text = ANCHOR.text(self.stat_two_icon)
        .set_x(4)
        .set_align(Align.RightOut, Align.Middle)
        .set_sprite_font("player_level")
        .set_text("--");

    self.stat_two_root.update_size = function() {
        self.stat_two_root.set_width_for_nodes([self.stat_two_icon, self.stat_two_text]);
        self.stat_two_root.set_height(self.stat_two_icon.get_height());
    }
    self.stat_two_root.update_size();

    self.tier_requirement = ANCHOR.text(self.right_body)
        .set_xy(self.layout.tier_requirement.position)
        .set_sprite_font("player_level")
        .set_lut(COMMON_LUT);

    self.level_requirement_box = ANCHOR.positional(self.right_body)
        .set_size(self.layout.level_requirement_box.size)
        .set_xy(self.layout.level_requirement_box.position);

    self.level_requirement_root = ANCHOR.positional(self.level_requirement_box)
        .set_align(Align.Center, Align.Middle)

    self.level_requirement_icon = ANCHOR.sprite(self.level_requirement_root)
        .set_align(Align.LeftIn, Align.Middle);

    self.level_requirement = ANCHOR.text(self.level_requirement_icon)
        .set_sprite_font("player_level")
        .set_lut(COMMON_LUT)
        .set_align(Align.RightOut, Align.Middle)
        .set_x(2)

    self.stars = ANCHOR.sprite(self.right_body)
        .set_xy(self.layout.stars.position)

    self.description_box = ANCHOR.positional(self.right_body)
        .set_size(self.layout.description_box.size)
        .set_xy(self.layout.description_box.position)

    self.description = ANCHOR.text(self.description_box)
        .set_x(3)
        .set_align(Align.LeftIn, Align.TopIn)
        .allow_line_breaks()
        .prevent_spillover()
        .set_line_height(13)
        .disable()

    self.quantity_box = ANCHOR.positional(self.right_body)
        .set_xy(self.layout.quantity_box.position)
        .set_size(self.layout.quantity_box.size)
        .set_align(Align.LeftIn, Align.BottomIn)

    self.minus_button = ANCHOR.nine_slice(self.quantity_box)
        .set_sprites_from_key("spr_ui_crafting_button_invalid")
        .set_size(self.layout.minus_button.size)
        .set_xy(self.layout.minus_button.position)
        .set_align(Align.LeftOut, Align.Middle)
        .add_to_pilot(self.bottom_pilot)
        .enable_tap_repeating()
        .set_tap_callback(function() {
            if self.item == undefined {
                return;
            }
            if self.quantity > 1 {
                self.modify_quantity(-1);
            }
        })

    self.minus_icon = ANCHOR.sprite(self.minus_button)
        .set_align(Align.Center, Align.Middle)
        .set_sprite(spr_ui_crafting_minus_icon)
        .set_xy(self.layout.minus_icon.position)

    self.minus_button.set_valid = function(boo=true) {
        if boo {
            self.minus_button.set_sprites_from_key("spr_ui_crafting_button");
            self.minus_button.set_tap_sound("SoundEffects/UI/UIDecrement");
            self.minus_icon.set_alpha(1);
            self.minus_icon.set_lut(self.sub_data.get("sprites").get("button_label_lut"));
        } else {
            self.minus_button.set_sprites_from_key("spr_ui_crafting_button_invalid");
            self.minus_button.set_tap_sound("SoundEffects/UI/UIUnableToInteract");
            self.minus_icon.set_alpha(0.5);
            self.minus_icon.set_lut(self.sub_data.get("sprites").get("button_label_invalid_lut"));
        }
    }

    self.plus_button = ANCHOR.nine_slice(self.quantity_box)
        .set_sprites_from_key("spr_ui_crafting_button_invalid")
        .set_size(self.layout.plus_button.size)
        .set_xy(self.layout.plus_button.position)
        .set_align(Align.RightOut, Align.Middle)
        .add_to_pilot(self.bottom_pilot)
        .enable_tap_repeating()
        .set_tap_callback(function() {
            if self.item == undefined {
                return;
            }
            self.modify_quantity(1);
        })

    self.plus_icon = ANCHOR.sprite(self.plus_button)
        .set_sprite(spr_ui_crafting_plus_icon)
        .set_align(Align.Center, Align.Middle)
        .set_xy(self.layout.plus_icon.position)

    self.plus_button.set_valid = function(boo=true) {
        if boo {
            self.plus_button.set_sprites_from_key("spr_ui_crafting_button");
            self.plus_button.set_tap_sound("SoundEffects/UI/UIIncrement");
            self.plus_icon.set_alpha(1);
            self.plus_icon.set_lut(self.sub_data.get("sprites").get("button_label_lut"));
        } else {
            self.plus_button.set_sprites_from_key("spr_ui_crafting_button_invalid");
            self.plus_button.set_tap_sound("SoundEffects/UI/UIUnableToInteract");
            self.plus_icon.set_alpha(0.5);
            self.plus_icon.set_lut(self.sub_data.get("sprites").get("button_label_invalid_lut"));
        }
    }

    self.craft_button = ANCHOR.nine_slice(self.right_body)
        .set_size(self.layout.craft_button.size)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_sprites_from_key("spr_ui_crafting_big_button_invalid")
        .set_xy(self.layout.craft_button.position)
        .add_to_pilot(self.bottom_pilot, true)
        .board_set("can_craft", false)
        .add_text_label("misc_local/ok")
        .set_tap_sound("SoundEffects/UI/UIExtraPositiveClick")
        .set_tap_callback(function() {
            if self.item == undefined {
                return;
            }
            if self.craft_button.board_get("can_craft") {
                self.start_craft_sequence();
            }
        })

    self.craft_button.text_label
        .set_align(Align.Center, Align.BottomIn)
        .set_y(-6)
        .set_alpha(0.5)

    self.craft_button.set_valid = function(boo=true) {
        self.craft_button.set_soft_locked(!boo);
        if boo {
            self.craft_button.set_sprites_from_key("spr_ui_crafting_big_button");
            self.craft_button.text_label.set_lut(self.sub_data.get("sprites").get("button_label_lut"));
            self.craft_icon.set_alpha(1);
        } else {
            self.craft_button.set_sprites_from_key("spr_ui_crafting_big_button_invalid");
            self.craft_button.text_label.set_lut(self.sub_data.get("sprites").get("button_label_invalid_lut"));
            self.craft_icon.set_alpha(0.5);
        }
    }

    self.craft_icon = ANCHOR.sprite(self.craft_button)
        .set_align(Align.Center, Align.TopIn)
        .set_y(6)
        //


    self.max_button = ANCHOR.nine_slice(self.quantity_box)
        .set_sprites_from_key("spr_ui_crafting_button_invalid")
        .set_align(Align.Center, Align.BottomOut)
        .set_xy(self.layout.max_button.position)
        .set_size(self.layout.max_button.size)
        .add_to_pilot(self.bottom_pilot)
        .set_tap_callback(function() {
            if self.item == undefined {
                return;
            }

            self.modify_quantity(self.maximum_crafts(self.item) - self.quantity);
        });

    self.max_icon = ANCHOR.sprite(self.max_button)
        .set_sprite(spr_ui_crafting_max_icon)
        .set_align(Align.Center, Align.Middle)
        .set_xy(self.layout.max_icon.position)

    switch local_language() {
        case "spa":
            self.max_button.set_width(38);
            self.max_icon.set_sprite(spr_ui_crafting_max_icon_es);
            break;
        case "kor":
            self.max_button.set_width(38);
            self.max_icon.set_sprite(spr_ui_crafting_max_icon_kr);
            break;
        case "rus":
            self.max_button.set_width(40);
            self.max_icon.set_sprite(spr_ui_crafting_max_icon_ru);
            break;
    }

    self.max_button.set_valid = function(boo=true) {
        if boo {
            self.max_button.set_sprites_from_key("spr_ui_crafting_button");
            self.max_button.set_tap_sound("SoundEffects/UI/UIIncrement");
            self.max_icon.set_alpha(1);
            self.max_icon.set_lut(self.sub_data.get("sprites").get("button_label_lut"));
        } else {
            self.max_button.set_tap_sound("SoundEffects/UI/UIUnableToInteract");
            self.max_icon.set_alpha(0.5);
            self.max_icon.set_lut(self.sub_data.get("sprites").get("button_label_invalid_lut"));
        }
    }

    self.quantity_text = ANCHOR.text(self.quantity_box)
        .set_align(Align.Center, Align.Middle)
        .set_xy(self.layout.quantity_text.position)

    self.duration_container = ANCHOR.positional(self.right_body)
        .set_align(Align.RightIn, Align.BottomIn)
        .set_xy(self.layout.duration_container.position)
        .set_size(self.layout.duration_container.size)

    self.duration_text = ANCHOR.text(self.duration_container)
        .set_align(Align.Center, Align.Middle)

    self.duration_icon = ANCHOR.sprite(self.duration_text)
        .set_align(Align.LeftOut, Align.Middle)
        .set_x(-2)
        .disable()

    self.corner_plate = ANCHOR.sprite(ANCHOR.screen_canvas, 0, AnchorLayer.Popup)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-2, 2)
        .set_alpha(0)

    self.corner_tier = render_kitchen_tier(self.corner_plate, 0)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-4, 3)
        .disable()

    self.corner_skill = render_skill_level(self.corner_plate, Skill.Cooking, false)
        .set_align(Align.RightIn, Align.TopIn)
        .set_xy(-4, 5)
}

#macro WOODCRAFTING_UI_DATA global.__woodcrafting_ui_data
WOODCRAFTING_UI_DATA = undefined;

#macro COOKING_UI_DATA global.__cooking_ui_data
COOKING_UI_DATA = undefined;

#macro BLACKSMITHING_UI_DATA global.__blacksmithing_ui_data
BLACKSMITHING_UI_DATA = undefined;

#macro MILLING_UI_DATA global.__milling_ui_data
MILLING_UI_DATA = undefined;

#macro REFINING_UI_DATA global.__refining_ui_data
REFINING_UI_DATA = undefined;

#macro DRAGON_FORGING_UI_DATA global.__dragon_forging_ui_data
DRAGON_FORGING_UI_DATA = undefined;

function load_crafting_ui_data(key) {
    var data = fiddle_get(format("ui/crafting/{}", key));
    filter_toml_nulls(data);
    data.skill = opt_and_then(data[$ "skill"], string_to_skill);
    data.sprites = Map(apply_func(data.sprites, string_to_asset));
    data.context = string_to_recipe_context(data.context);
    data.categories = ListFromArray(apply_func(data.categories, function(elem) {
        elem.icon = try_string_to_asset(elem.icon) ?? spr_illegal_8;
        if is_nullish(elem[$ "display_in_aggregate"]) {
            elem.display_in_aggregate = true;
        }
        elem.sub_categories = ListFromArray(apply_func(elem.sub_categories, function(sub) {
            sub.icon = try_string_to_asset(sub.icon) ?? spr_illegal_8;
            sub.tags = ListFromArray(sub[$ "tags"] ?? []);
            sub.craftable_only = sub[$ "craftable_only"] ?? false;
            sub.show_locked = sub[$ "show_locked"] ?? true;
            sub.items = ListFromArray(apply_func(sub[$ "manual_order"] ?? [], function(v) {
                return new LiveItem(string_to_item_id(v));
            }));
            sub.is_manually_ordered = !sub.items.is_empty();
            return sub;
        }));
        return elem;
    }));

    //
    for (var i = 0; i < data.categories.count(); i++) {
        var cat = data.categories.get(i);
        for (var j = 0; j < cat.sub_categories.count(); j++) {
            var sub = cat.sub_categories.get(j);
            for (var k = 0; k < ItemId.LEN; k++) {
                var proto = ITEM_PROTOTYPES[k];
                if proto.recipe != undefined
                    && proto.tags.any(function(tag, tags_to_accept) {
                        return tags_to_accept.contains(tag);
                    }, sub.tags)

                {
                    sub.items.push(new LiveItem(k));
                }
            }
        }
    }

    var all_items = data.categories.fold(List(), function(a, v) {
        for (var i = 0 ; i < v.sub_categories.count(); i++) {
            a.copy_from(v.sub_categories.get(i).items);
        }
        return a;
    });
    var omni_sub_cats = List();
    var craftable_sub_cats = List();
    for (var i = 0; i < data.categories.count(); i++) {
        var cat = data.categories.get(i);
        if !cat.display_in_aggregate {
            continue;
        }
        var items = cat.sub_categories.fold(List(), function(list, sub) {
            list.copy_from(sub.items);
            return list;
        });
        omni_sub_cats.push({
            name: cat.name,
            icon: cat.icon,
            craftable_only: false,
            show_locked: true,
            is_manually_ordered: true,
            tags: List(),
            items,
        });
        craftable_sub_cats.push({
            name: cat.name,
            icon: cat.icon,
            craftable_only: true,
            show_locked: false,
            is_manually_ordered: true,
            tags: List(),
            items,
        });
    }

    for (var i = 0; i < data.categories.count(); i++) {
        var cat = data.categories.get(i);
        if !cat.display_in_aggregate {
            var all_tags = cat.sub_categories.fold(List(), function(a, v) {
                a.copy_from(v.tags);
                return a;
            });
            cat.sub_categories.push({
                name: "misc_local/other",
                icon: spr_ui_crafting_category_icon_misc,
                craftable_only: false,
                show_locked: true,
                is_manually_ordered: true,
                tags: List(),
                items: all_items.retain(function(item, all_tags) {
                    return !item.prototype.tags.any(function(tag, all_tags) {
                        return all_tags.contains(tag);
                    }, all_tags);
                }, all_tags),
            })
        }
    }

    data.categories.insert({
        name: "misc_local/all_items",
        icon: spr_ui_crafting_category_icon_all,
        sub_categories: omni_sub_cats,
    }, 0);
    data.categories.push({
        name: "misc_local/craftable",
        icon: spr_ui_crafting_category_icon_craftable,
        sub_categories: craftable_sub_cats,
    });

    return Map(data);
}

function load_cooking_ui_data() {
    var data = load_crafting_ui_data("cooking");

    //
    static STAR_SUB_CAT = function(stars) {
        var list = List();
        for (var i = 0; i < ItemId.LEN; i++) {
            var proto = ITEM_PROTOTYPES[i];
            if proto.recipe != undefined && proto.stars == stars {
                list.push(new LiveItem(i));
            }
        }
        return {
            name: "misc_local/empty_string",
            icon: string_to_asset(format("spr_ui_cooking_quality_star_level_{}", stars)),
            craftable_only: false,
            show_locked: true,
            tags: undefined,
            items: list,
            is_manually_ordered: false,
        };
    }

    var star_sub_cats = List();
    star_sub_cats.push(STAR_SUB_CAT(1));
    star_sub_cats.push(STAR_SUB_CAT(2));
    star_sub_cats.push(STAR_SUB_CAT(3));
    star_sub_cats.push(STAR_SUB_CAT(4));
    star_sub_cats.push(STAR_SUB_CAT(5));

    data.get("categories").push({
        name: "misc_local/rank",
        icon: spr_ui_cooking_category_icon_quality,
        sub_categories: star_sub_cats,
    });

    static KITCHEN_SUB_CAT = function(tier) {
        var list = List();
        for (var i = 0; i < ItemId.LEN; i++) {
            var proto = ITEM_PROTOTYPES[i];
            if proto.recipe != undefined && proto.kitchen_tier_requirement == tier {
                list.push(new LiveItem(i));
            }
        }
        return {
            name: format("misc_local/level_{}", tier),
            icon: string_to_asset(format("spr_ui_cooking_category_icon_kitchen_level_{}", tier)),
            craftable_only: false,
            show_locked: true,
            tags: undefined,
            items: list,
            is_manually_ordered: false,
        };
    }

    var kitchen_sub_cats = List();
    kitchen_sub_cats.push(KITCHEN_SUB_CAT(1));
    kitchen_sub_cats.push(KITCHEN_SUB_CAT(2));
    kitchen_sub_cats.push(KITCHEN_SUB_CAT(3));

    data.get("categories").push({
        name: "misc_local/kitchen_tiers",
        icon: spr_ui_cooking_category_icon_kitchen_level,
        sub_categories: kitchen_sub_cats,
    });

    return data;
}

function spawn_crafting_menu(sub_data, xx, yy, object_id) {
    var menu = ANCHOR.spawn_menu(Menu.Crafting, object_id);
    menu.ari_pos = Vec2(xx ?? obj_ari.x, yy ?? obj_ari.y);
    menu.initialize(sub_data);
    menu.reset_right_page();
    ANCHOR.set_active_pilot(menu.left_pilot);
    return menu;
}

enum CraftingDepth {
    Arrows = 1,
    Window = 2,
    Carousel = 3,
    HoveredItem = 4,
    NormalItem = 5,
    ItemContainer = 6,
    ItemElement = 7,
}
