object_create(
    "obj_fish_trap",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_beach_fish_trap_open,
        create: function() {
            event_inherit(ObjectEvent.Create);

            function can_open() {
                return FISH_TRAP_TIMESTAMP != undefined && CALENDAR.time - FISH_TRAP_TIMESTAMP >= days(1);
            }

            function can_add_bait() {
                return FISH_TRAP_TIMESTAMP == undefined
                    && ARI.held_item() != undefined
                    && ARI.held_item().prototype.tags.contains("fish_bait");
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/open",
                function() {
                    var item_count = 0;
                    var roll = irandom(10);
                    if roll > 6 {
                        item_count = 3;
                    } else if roll > 3 {
                        item_count = 2;
                    } else {
                        item_count = 1;
                    }

                    var ocean_fish = Map();
                    for (var i = 0; i < FishId.LEN; i++) {
                        var data = fiddle_get(format("fish/{FishId}", i));
                        if data[$ "legendary"] == true {
                            continue;
                        }
                        var seasons = data[$ "seasons"] ;
                        if seasons != undefined && is_array(seasons) && !array_has(seasons, season_to_string(CALENDAR.season())) {
                            continue;
                        }
                        if data[$ "water_type"] == "ocean" {
                            var item = FISH[i].item;
                            if ITEM_PROTOTYPES[item].tags.contains("fishy") {
                                var rarity_list = ocean_fish.get_or_insert(FISH[i].rarity, List());
                                rarity_list.push(FISH[i].item);
                            }
                        }
                    }

                    var fish_trap_fish = ListFromArray(MUSEUM_DATA.get_collection(MuseumWing.Fish, "fish_trap").items);
                    fish_trap_fish.retain(function(item) {
                        for (var i = 0; i < FishId.LEN; i++) {
                            if FISH[i].item == item {
                                return FISH[i].rarity == FISH_TRAP_RARITY;
                            }
                        }
                        return false;
                    });

                    var fish_trap_artifacts = ListFromArray(MUSEUM_DATA.get_collection(MuseumWing.Archaeology, "fish_trap").items);
                    fish_trap_artifacts.retain(function(item) {
                        var rarity = fiddle_get(format("artifacts/loot/{ItemId}", item));
                        if FISH_TRAP_RARITY == "rare" {
                            return matches(rarity, "legendary", "rare");
                        } else {
                            return rarity == FISH_TRAP_RARITY;
                        }
                    });

                    var pirate_set = List();
                    for (var i = 0; i < ItemId.LEN; i++) {
                        if ITEM_PROTOTYPES[i].tags.contains("pirate_set") {
                            pirate_set.push(i);
                        }
                    }

                    var yield = List();
                    var item_id = ocean_fish.get(FISH_TRAP_RARITY).choose_random();
                    yield.push(new LiveItem(item_id));
                    var item = irandom(1) == 0 ? ItemId.Seaweed : ItemId.WaterChestnut;
                    repeat irandom_range(2, 4) {
                        yield.push(new LiveItem(item));
                    }

                    if item_count > 1 {
                        yield.push(new LiveItem(
                            irandom(1) ? fish_trap_fish.choose_random() : pirate_set.choose_random(),
                        ));
                    }

                    if item_count > 2 {
                        switch irandom(2) {
                            case 0:
                                switch FISH_TRAP_RARITY {
                                    case "common":
                                        yield.push(new LiveItem(ItemId.TreasureBoxCopper));
                                        break;
                                    case "uncommon":
                                        yield.push(new LiveItem(ItemId.TreasureBoxSilver));
                                        break;
                                    case "rare":
                                        yield.push(new LiveItem(ItemId.TreasureBoxGold));
                                        break;
                                    default: impossible();
                                }
                                break;
                            case 1:
                                switch FISH_TRAP_RARITY {
                                    case "common":
                                        yield.push(new LiveItem(ItemId.EssenceStoneTiny));
                                        break;
                                    case "uncommon":
                                        yield.push(new LiveItem(ItemId.EssenceStoneSmall));
                                        break;
                                    case "rare":
                                        yield.push(new LiveItem(ItemId.EssenceStoneMedium));
                                        break;
                                    default: impossible();
                                }
                                break;
                            case 2:
                                yield.push(new LiveItem(fish_trap_artifacts.choose_random()));
                                break;
                        }
                    }

                    TANGO.play("SoundEffects/Tools/FishingRodRetract");
                    TANGO.play("SoundEffects/Inventory/RewardDropAddition");

                    yield.drain(function(v) {
                        drop_item(v, obj_ari.x, obj_ari.y);
                    });

                    FISH_TRAP_RARITY = undefined;
                    FISH_TRAP_TIMESTAMP = undefined;
                },
                self.can_open,
            )

            self.register_interaction(
                InputId.Interact,
                "misc_local/add_bait",
                function() {
                    TANGO.play("SoundEffects/Tools/SaplingPlant");
                    FISH_TRAP_TIMESTAMP = CALENDAR.time;
                    var item = ARI.inventory.slot(ARI.held_item_index).pop();
                    switch item.item_id {
                        case ItemId.FishBaitCommon:
                            FISH_TRAP_RARITY = "common";
                            break;
                        case ItemId.FishBaitUncommon:
                            FISH_TRAP_RARITY = "uncommon";
                            break;
                        case ItemId.FishBaitRare:
                            FISH_TRAP_RARITY = "rare";
                            break;
                        default: impossible();
                    }
                },
                self.can_add_bait,
            )

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectFishTrap]);
                },
                function() {
                    return !self.can_add_bait() && !self.can_open() && FISH_TRAP_TIMESTAMP == undefined;
                }
            );

            self.register_interaction(
                InputId.Interact,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectBaitedFishTrap]);
                },
                function() {
                    return !self.can_add_bait() && !self.can_open() && FISH_TRAP_TIMESTAMP != undefined;
                }
            );

            self.depth = get_instance_depth(self.y);

            var fiddle_data = fiddle_get("interaction/fish_trap_offset");
            self.bounce_x_offset = fiddle_data[0];
            self.bounce_y_offset = fiddle_data[1];
        },
        step: function() {
            self.sprite_index = FISH_TRAP_TIMESTAMP == undefined
                ? spr_beach_fish_trap_open
                : spr_beach_fish_trap_closed;
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            if game_paused() || (FISH_TRAP_TIMESTAMP != undefined && FISH_TRAP_TIMESTAMP + days(1) > CALENDAR.time) {
                return;
            }

            self.bouncer.alpha = BARK_MIN_ALPHA;

            var is_being_selected = self.bouncer.update();

            var small_bubble = FISH_TRAP_RARITY == undefined
                ? spr_ui_bark_icon_fish_bait_small
                : spr_ui_bark_icon_exclamation_small;

            var large_bubble = FISH_TRAP_RARITY == undefined
                ? spr_ui_bark_icon_fish_bait
                : spr_ui_bark_icon_exclamation_mark;

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(large_bubble, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(small_bubble, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            }
        },
        animation_end: function() {

        },
    }
);
