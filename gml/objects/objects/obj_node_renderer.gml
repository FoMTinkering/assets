object_create(
    "obj_node_renderer",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create_draw_callback: function() {
            //
            //
            switch self.object_category {
                case ObjectCategory.Breakable:
                case ObjectCategory.DigSite:
                case ObjectCategory.Grass:
                case ObjectCategory.Rock:
                case ObjectCategory.Stump:
                    return undefined;
                default:
                    return function() {
                        var xx = self.x + self.draw_x_offset;
                        var yy = self.y + self.draw_y_offset;

                        var perform_transparency = (self.object_category == ObjectCategory.Tree || self.object_category == ObjectCategory.Building)
                            && (self.image_alpha < 1.0 || self.translucent);

                        if perform_transparency {
                            if self.translucent {
                                self.image_alpha = approach(self.image_alpha, 0.5, 0.05);
                                self.translucent = false;
                            } else {
                                self.image_alpha = approach(self.image_alpha, 1.0, 0.05);
                            }
                            //
                            gpu_set_color_write(false);
                            gpu_set_depth_test(cmpfunc_lessequal);

                            if self.secondary_sprite != undefined {
                                var old_depth = gpu_get_depth();
                                gpu_set_depth(old_depth + 1.0);
                                draw_sprite_ext(self.secondary_sprite, self.image_index, xx, yy, self.image_xscale, 1, 0, c_white, self.image_alpha);
                                gpu_set_depth(old_depth);
                            }
                            draw_sprite_ext(self.sprite_index, image_index, xx, yy, self.image_xscale, 1, 0, self.image_blend, self.image_alpha);
                            self.draw_func(NodeDrawFlag.PERFORMING_PREPASS);

                            //
                            if self.fruit_sprite != undefined {
                                var old_depth = gpu_get_depth();
                                gpu_set_depth(old_depth - 1.0);

                                for (var i = 0, c = array_length(self.fruit_sprite_positions); i < c; i++) {
                                    var pos_vec = self.fruit_sprite_positions[i];
                                    draw_sprite(fruit_sprite, 0, xx + pos_vec.x, yy + pos_vec.y);
                                }
                                gpu_set_depth(old_depth);
                            }

                            gpu_set_color_write(true);
                            gpu_set_depth_test(cmpfunc_equal);
                        }

                        //
                        if self.object_category == ObjectCategory.Furniture && self.node.prototype.fence && self.preview_fence_idx != undefined {
                            draw_sprite_ext(sprite_index, self.preview_fence_idx, xx, yy, image_xscale, 1, 0, c_white, 0.75);
                            self.preview_fence_idx = undefined;
                        }

                        var use_highlighter = self.highlight_interactable && self.highlighter.update(x, y);

                        //
                        if self.secondary_sprite != undefined {
                            var old_depth = gpu_get_depth();
                            gpu_set_depth(old_depth + 1.0);

                            draw_sprite_ext(self.secondary_sprite, self.image_index, xx, yy, image_xscale, 1, 0, c_white, self.image_alpha);
                            gpu_set_depth(old_depth);
                        }

                        self.is_being_selected = false;
                        if use_highlighter && perform_transparency == false {
                            gpu_set_extra(UberShaderKind.Overlay);
                            self.is_being_selected = true;

                            //
                            if self.top_sheet_renderer != undefined {
                                self.top_sheet_renderer.interacting = true;
                                self.top_sheet_renderer.image_blend = self.highlighter.color;
                                self.top_sheet_renderer.image_alpha = self.highlighter.strength;
                            }
                            draw_sprite_ext(sprite_index, image_index, xx, yy, image_xscale, 1, rot, self.highlighter.color, self.highlighter.strength);
                            gpu_reset_extra();
                        } else if rot == 0 {
                            draw_sprite_ext(sprite_index, image_index, xx, yy, image_xscale, 1, 0, image_blend, image_alpha);
                        } else if perform_transparency {
                            var reset_ztest_func = gpu_get_depth_test();
                            var reset_write = gpu_get_depth_write();
                            gpu_set_depth_test(cmpfunc_always);
                            draw_sprite_ext(sprite_index, image_index, xx, yy, image_xscale, 1, rot, image_blend, image_alpha);
                            if reset_ztest_func != undefined {
                                gpu_set_depth_test(reset_ztest_func, reset_write);
                            }
                        } else {
                            draw_sprite_ext(sprite_index, image_index, xx, yy, image_xscale, 1, rot, image_blend, image_alpha);
                        }

                        if self.fruit_sprite != undefined {
                            var alpha = 1.0;
                            if perform_transparency {
                                alpha = 0.5;
                            } else if self.highlighter.highlight_this_frame {
                                gpu_set_extra(UberShaderKind.Overlay);
                            }

                            var old_depth = gpu_get_depth();
                            gpu_set_depth(old_depth - 1.0);

                            for (var i = 0, c = array_length(self.fruit_sprite_positions); i < c; i++) {
                                var pos_vec = self.fruit_sprite_positions[i];
                                draw_sprite_ext(fruit_sprite, 0, xx + pos_vec.x, yy + pos_vec.y, 1, 1, 0, c_white, alpha);
                            }
                            if self.highlighter.highlight_this_frame {
                                gpu_reset_extra();
                            }

                            gpu_set_depth(old_depth);
                        }

                        self.draw_func(
                            perform_transparency ? NodeDrawFlag.PERFORMING_TRANSPARENCY : NodeDrawFlag.EMPTY
                        );

                        if self.essence_machine && self.node.essence_supply > 0 {
                            var strength = 1;
                            var c = c_white;
                            if self.highlighter.highlight_this_frame {
                                gpu_set_extra(UberShaderKind.Overlay);
                                strength = 0.5;
                                c = c_white;
                            } else if self.image_index > 0 {
                                gpu_set_extra(UberShaderKind.OverlayCorrect);
                                strength = max(sin(pi * (self.image_index - 2) / 3), 0);
                                c = self.highlighter.color;
                            }
                            draw_sprite_ext(self.essence_stone_sprite, 0, xx + self.essence_stone_offset_x, yy + self.essence_stone_offset_y, 1, 1, 0, c, strength);

                            if self.highlighter.highlight_this_frame || self.image_index > 0 {
                                gpu_reset_extra();
                            }
                        }

                        if self.node.object_id == ObjectId.BabyCradle {
                            for (var i = 0; i < array_length(ARI.children); i++) {
                                var child = ARI.children[i];
                                //
                                //
                                var t = current_time() mod 2000;
                                var f = (t >= 200) + (t >= 1000) + (t >= 1200);
                                if child.location == ChildLocation.InCradle {
                                    draw_sprite(child.get_sprite("sleep_south"), f, self.x, self.y + 8);
                                }
                            }
                        }

                        if perform_transparency {
                            gpu_set_depth_test(cmpfunc_always);
                        }
                    };
            }
        },
        create_draw_end_callback: function() {
            if self.object_id == ObjectId.Mailbox {
                return function() {
                    if MIST.running {
                        return;
                    }
                    self.bouncer.status = InteractBounceStatus.Distant;
                    if ARI.inbox.has_unread_mail() == false {
                        return;
                    }

                    self.bouncer.alpha = BARK_MIN_ALPHA;

                    var is_being_selected = self.bouncer.update();

                    if is_being_selected {
                        draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        draw_sprite_ext(spr_ui_bark_icon_letter, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                    } else {
                        draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        draw_sprite_ext(spr_ui_bark_icon_letter_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                    }
                }
            }

            if self.is_factory {
                return function() {
                    if MIST.running {
                        return;
                    }
                    self.image_speed = !game_paused();
                    var is_being_selected = self.bouncer.update();
                    self.bouncer.status = InteractBounceStatus.Distant;
                    self.bouncer.alpha = 1;
                    if self.node.production_request != undefined {
                        draw_sprite_ext(spr_ui_bark_bubble_large_open, 0, x + self.node.prototype.factory.thought_bubble_offset.x, y + self.node.prototype.factory.thought_bubble_offset.y + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        draw_sprite_ext(ITEM_PROTOTYPES[self.node.production_request].icon_sprite, 0, x + self.node.prototype.factory.thought_bubble_offset.x, y + self.node.prototype.factory.thought_bubble_offset.y + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                    } else if self.node.inventory.total_items() < 4 {
                        if is_being_selected {
                            draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                            draw_sprite_ext(self.node.prototype.factory.bark_icon, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        } else {
                            draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                            draw_sprite_ext(self.node.prototype.factory.bark_icon_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        }
                    }
                }

            }

            if self.essence_machine {
                return function() {
                    if MIST.running {
                        return;
                    }
                    self.bouncer.status = InteractBounceStatus.Distant;

                    if self.node.essence_supply != 0 {
                        return;
                    }

                    self.bouncer.alpha = approach(self.bouncer.alpha, BARK_MIN_ALPHA, BARK_FADE_SPEED);
                    var is_being_selected = self.bouncer.update();

                    if is_being_selected {
                        draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        draw_sprite_ext(spr_ui_bark_icon_essence_stone, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                    } else {
                        draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        draw_sprite_ext(spr_ui_bark_icon_essence_stone_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                    }
                }
            }

            if self.object_id == ObjectId.TurnInBox {
                return function() {
                    if MIST.running {
                        return;
                    }
                    if self.node[$ "building_box"] && inventory_satisfies_recipe(BLUEPRINT_PROTOTYPES[self.node.blueprint_id].turn_in_box_recipe, self.node.inventory) {
                        return;
                    }
                    self.bouncer.status = InteractBounceStatus.Distant;
                    self.bouncer.alpha = BARK_MIN_ALPHA;

                    var is_being_selected = self.bouncer.update();

                    if is_being_selected {
                        draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, 1);
                        draw_sprite_ext(spr_ui_bark_icon_donate, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, 1);
                    } else {
                        draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                        draw_sprite_ext(spr_ui_bark_icon_donate_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                    }
                }
            }

            var has_interaction = false;
            switch object_id {
                case ObjectId.StableCraftingTable:
                case ObjectId.SeedMaker:
                case ObjectId.AutoFeeder:
                case ObjectId.EspressoMachine:
                case ObjectId.CaldarusDragonswornStatue:
                    has_interaction = true;
                    break;
                default:
                    if object_id_to_object_category(object_id) == ObjectCategory.Furniture
                        && node.prototype.interact_menu != undefined
                    {
                        has_interaction = true;
                    }

                     if self.node.prototype["restoration"] != undefined {
                        has_interaction = true;
                    }

                    if self.node.prototype["is_crystal_resonator"] == true {
                        has_interaction = true;
                    }

                    if self.node.prototype[$ "interaction_chest"] != undefined {
                        has_interaction = true;
                    }
            }

            if has_interaction == false {
                return undefined;
            }

            //
            return function() {
                if MIST.running {
                    return;
                }
                var bubble_small = undefined;
                var bubble_big = undefined;

                switch object_id {
                    case ObjectId.EspressoMachine:
                        if !ARI.used_object_today[object_id] {
                            bubble_big = spr_ui_bark_icon_espresso;
                            bubble_small = spr_ui_bark_icon_espresso_small;
                        }
                        break;
                    case ObjectId.StableCraftingTable:
                        bubble_big = spr_ui_bark_icon_build;
                        bubble_small = spr_ui_bark_icon_build_small;
                        break;
                    case ObjectId.SeedMaker:
                        bubble_big = spr_ui_bark_icon_vegetable;
                        bubble_small = spr_ui_bark_icon_vegetable_small;
                        break;
                    case ObjectId.AutoFeeder:
                        bubble_big = spr_ui_storage_chest_bark_icon_food;
                        bubble_small = spr_ui_storage_chest_bark_icon_food_small;
                        break;
                    case ObjectId.CaldarusDragonswornStatue:
                        if !ARI.used_object_today[object_id] {
                            bubble_big = spr_ui_storage_chest_bark_icon_essence;
                            bubble_small = spr_ui_storage_chest_bark_icon_essence_small;
                        }
                        break;
                    default:
                        if self.node.prototype["restoration"] != undefined && !ARI.used_object_today[object_id] {
                            bubble_big = spr_ui_bark_icon_stamina;
                            bubble_small = spr_ui_bark_icon_stamina_small;
                        }

                        if self.node.prototype["is_crystal_resonator"] == true {
                            bubble_big = spr_ui_bark_icon_music;
                            bubble_small = spr_ui_bark_icon_music_small;
                        }

                        if object_id_to_object_category(object_id) == ObjectCategory.Furniture
                            && node.prototype.interact_menu != undefined
                        {
                            bubble_big = node.prototype.interact_menu.bubble_big;
                            bubble_small = node.prototype.interact_menu.bubble_small;
                        }

                        if self.node.prototype[$ "interaction_chest"] != undefined
                            && self.node.chest_icon != undefined
                        {
                            bubble_big = string_to_asset(format("spr_ui_storage_chest_bark_icon_{ChestIcon}", self.node.chest_icon));
                            bubble_small = string_to_asset(format("spr_ui_storage_chest_bark_icon_{ChestIcon}_small", self.node.chest_icon));
                        }
                }

                //
                if bubble_big == undefined || bubble_small == undefined {
                    return;
                }

                self.bouncer.status = InteractBounceStatus.Distant;

                var target = 0;
                if distance_to_ari_interactable() < STANDARD_INTERACTION_DISTANCE {
                    target = BARK_MIN_ALPHA;
                }
                self.bouncer.alpha = approach(self.bouncer.alpha, target, BARK_FADE_SPEED);
                var is_being_selected = self.bouncer.update();
                if game_paused() {
                    self.bouncer.alpha = 0;
                    self.bouncer.status = InteractBounceStatus.Distant;
                    self.bouncer.alpha_refresh_rate = BARK_FADE_SPEED;
                }
                if bouncer.alpha >= 1 {
                    self.bouncer.alpha_refresh_rate = 1;
                }

                if is_being_selected {
                    draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                    draw_sprite_ext(bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                } else {
                    draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                    draw_sprite_ext(bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, c_white, self.bouncer.alpha);
                }
            }
        },
        create: function() {
            event_inherit(ObjectEvent.Create);
            z = 0;

            perform_outline = false;

            node = undefined;
            //
            object_id = undefined;
            //
            object_category = undefined;

            collided = false;
            trauma = 0;

            rotational_trauma = 0;
            rotational_trauma_range = 0;

            secondary_sprite = undefined;
            secondary_sprite_shadow = undefined;

            outline = false;

            highlight_interactable = false;

            fruit_sprite = undefined;
            fruit_sprite_positions = undefined;
            outline_fruit = false;
            translucent = false;

            draw_func = empty_function;

            water_base_renderer = undefined;
            sound_controller = undefined;

            backing_sprite = undefined;
            top_sheet_renderer = undefined;
            floor_renderer = undefined;
            light = undefined;
            targets_to_destroy = undefined;

            draw_xscale = 1;

            shadow_caster = undefined;
            shadow_caster_secondary = undefined;

            linked_object = undefined;

            burn_iframes = 0;

            rot = 0;
            sway = false;
            sway_counter = 0;
            sway_multiplier = 1;

            shadow_grid = SHADOW_GRID;

            essence_machine = false;

            is_factory = false;

            function collide(is_moving, cardinal) {
                if self.object_category == ObjectCategory.Grass {
                    collide_grass(self);
                } else if self.sway_on_impact && is_moving {
                    sway_renderer(self, cardinal);
                }
            }

            //
            //
            function give_animation_end_callback(func) {
                event_overwrite(self, ObjectEvent.AnimationEnd, method(self, func));
            }

            //
            function init(node, spr, depth_offset=0, explicit_shadow_grid=undefined) {
                self.node = node;
                self.object_id = node.object_id;
                self.object_category = object_id_to_object_category(self.object_id);

                if self.object_category == ObjectCategory.Furniture && node.prototype.factory != undefined {
                    self.is_factory = true;
                }

                self.set_sprite(spr);

                //
                self.z -= depth_offset;
                depth = get_instance_depth(y, z);

                self.sway = false;
                self.sway_on_impact = false;

                //
                switch self.object_category {
                    case ObjectCategory.Grass:
                        self.image_speed = 0;

                        //
                        self.counter_max = sprite_get_number(sprite_index);
                        self.count_back = false;
                        self.counter_spd = 10.0 / 60.0;

                        self.grass_back = instance_create_depth(self.x, self.y, 0, obj_grass_backing);
                        break;
                    case ObjectCategory.Tree:
                        self.highlighter.interact_strength = fiddle_get("interaction/highlight/tree_strength");
                        break;
                    case ObjectCategory.Furniture:
                        if self.node.prototype.factory != undefined {
                            var fiddle_data = fiddle_get(self.node.prototype.factory.apiary_offset);
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.prototype.essence_machine != undefined {
                            var fiddle_data = fiddle_get(self.node.prototype.essence_machine.interaction_fiddle_path);
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];

                            self.essence_machine = true;
                        }

                        if self.node.prototype.restoration != undefined {
                            var fiddle_data = fiddle_get("interaction/restoration_offset");
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                         if self.node.prototype.is_crystal_resonator {
                            var fiddle_data = fiddle_get("interaction/resonator_offset");
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.object_id == ObjectId.CaldarusDragonswornStatue {
                            var fiddle_data = fiddle_get("interaction/dragonsworn_statue_offset");
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.object_id == ObjectId.CelinesRevivedFlower {
                            var fiddle_data = fiddle_get("interaction/celines_flower_offset");
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.object_id == ObjectId.EilandsLegacyStele {
                            var fiddle_data = fiddle_get("interaction/eilands_stelle_offset");
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.object_id == ObjectId.RyisHawthornTree {
                            var fiddle_data = fiddle_get("interaction/ryis_tree_offset");
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.prototype.interact_menu != undefined {
                            var fiddle_data = fiddle_get(self.node.prototype.interact_menu.offset);
                            self.bounce_x_offset = fiddle_data[0];
                            self.bounce_y_offset = fiddle_data[1];
                        }

                        if self.node.prototype.interaction_chest != undefined {
                            self.bounce_x_offset = self.node.prototype.interaction_chest.bark_offset[0];
                            self.bounce_y_offset = self.node.prototype.interaction_chest.bark_offset[1];
                        }
                        break;
                }

                switch self.object_id {
                    case ObjectId.Mailbox:
                        self.sfx_play = true;

                        var fiddle_data = fiddle_get("interaction/mailbox_offset");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;

                    case ObjectId.EspressoMachine:
                        var fiddle_data = fiddle_get("interaction/espresso_offset");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;

                    case ObjectId.TesseraeTree:
                        var fiddle_data = fiddle_get("interaction/tesserae_tree");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;

                    case ObjectId.StableCraftingTable:
                        var fiddle_data = fiddle_get("interaction/stable_crafting_offset");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;

                    case ObjectId.TurnInBox:
                        var fiddle_data = fiddle_get("interaction/turn_in_box");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;

                    case ObjectId.SeedMaker:
                        var fiddle_data = fiddle_get("interaction/seed_maker_offset");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;

                    case ObjectId.AutoFeeder:
                        var fiddle_data = fiddle_get("interaction/auto_feeder_offset");
                        self.bounce_x_offset = fiddle_data[0];
                        self.bounce_y_offset = fiddle_data[1];
                        break;
                }

                //
                var my_object_draw_end = method(self, self.create_draw_end_callback)();
                if my_object_draw_end != undefined {
                    event_overwrite(self, ObjectEvent.DrawEnd, my_object_draw_end);
                }

                //
                var my_object_draw = method(self, self.create_draw_callback)();
                event_overwrite(self, ObjectEvent.Draw, my_object_draw);

                //
                if explicit_shadow_grid != undefined {
                    self.shadow_grid =  explicit_shadow_grid;
                }
                if self.shadow_grid != undefined
                    && self.shadow_grid.is_freed == false
                {
                    self.shadow_caster = self.shadow_grid.caster_create(self.x, self.y);
                    self.set_sprite(self.sprite_index);
                    self.set_secondary_sprite(self.secondary_sprite);
                }
            }

            //
            //
            function set_secondary_sprite(secondary_sprite) {
                self.secondary_sprite = secondary_sprite;
                self.secondary_sprite_shadow = undefined;

                if secondary_sprite != undefined {
                    self.secondary_sprite_shadow = SHADOW_DICTIONARY.get(secondary_sprite);
                }

                if self.secondary_sprite_shadow != undefined && self.shadow_grid != undefined {
                    if self.shadow_caster_secondary == undefined {
                        self.shadow_caster_secondary = self.shadow_grid.caster_create(self.x, self.y);
                    }
                    shadow_caster_set_sprite(self.shadow_caster_secondary, self.secondary_sprite_shadow);
                }
            }

            //
            function set_sprite(spr) {
                self.sprite_index = spr;

                //
                //
                if self.shadow_caster != undefined {
                    self.shadow_sprite = SHADOW_DICTIONARY.get(spr);
                    shadow_caster_set_sprite(shadow_caster, self.shadow_sprite, self.image_index);
                }
            }

            function interact(anchor_name, mask) {
                //
                self.override_mask = mask;
                self.highlight_interactable = true;

                register_interactable(self);

                self.register_interaction(
                    InputId.Interact,
                    anchor_name,
                    function() {
                        return interact(self.node);
                    },
                    function() {
                        return can_interact(self.node);
                    }
                );
            }
        },
        destroy: function() {
            if self.water_base_renderer != undefined {
                instance_destroy(self.water_base_renderer);
            }

            if self.backing_sprite != undefined {
                instance_destroy(self.backing_sprite);
            }

            if self.light != undefined {
                instance_destroy(self.light);
            }

            if self.top_sheet_renderer != undefined {
                instance_destroy(self.top_sheet_renderer);
            }

            if self.floor_renderer != undefined {
                instance_destroy(self.floor_renderer);
            }

            if self.targets_to_destroy != undefined {
                for (var i = 0; i < self.targets_to_destroy.count(); i++) {
                    var m = self.targets_to_destroy.get(i);
                    if m != undefined && instance_is_alive(m) {
                        instance_destroy(m);
                    }
                }
            }

            if self.linked_object != undefined {
                instance_destroy(self.linked_object);
            }

            //
            if self[$ "shadow_level"] != undefined {
                self.shadow_level.target_shadow_grid.free();
                instance_destroy(self.shadow_level);
            }

            if self["grass_back"] != undefined {
                instance_destroy(self.grass_back);
            }
        },
        cleanup: function() {
            if self.sound_controller != undefined {
                self.sound_controller.force_stop();
            }
            stop_animal_toy_sfx(self.node);
            //
            if self.shadow_caster != undefined {
                self.shadow_grid.caster_remove(shadow_caster);
            }
            if self.shadow_caster_secondary != undefined {
                self.shadow_grid.caster_remove(shadow_caster_secondary);
            }
        },
    }
);

object_create(
    "obj_grass_backing",
    undefined,
    {
        visible: false,
        image_speed: 0.0,
    },
);
