object_create(
    "obj_dungeon_ritual_altar",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_dungeon_mines_ritual_altar_spring_closed,
        create: function() {
            event_inherit(ObjectEvent.Create);

            function dungeon_init() {
                depth = get_instance_depth(y);

                //
                var ox = self.x div 8;
                var oy = self.y div 8;
                set_collision_on_node_region(GRID, ox - 3, oy - 2, ox + 4, oy + 1, false);

                self.shadow_caster = SHADOW_GRID.caster_create(x, y);
                shadow_caster_set_sprite(self.shadow_caster, SHADOW_DICTIONARY.get(self.sprite_index));

                //
                var fiddle_data = fiddle_get("interaction/dungeon_ritual_altar_offset");
                self.offset_x = fiddle_data[0];
                self.offset_y = fiddle_data[1];

            }

            self.prize = undefined;

            self.second_prize = undefined;

            self.register_interaction(
                InputId.Interact,
                "misc_local/open",
                function() {
                    TANGO.play("SoundEffects/SpecialEvents/SteleOpen");

                    self.sprite_index = spr_dungeon_mines_ritual_altar_spring_opening;
                    self.image_speed = 1;

                    self.prize = ARCHAEOLOGY.ritual_chamber_table.get_candidate_votes_at_cell(GRID, 0, 0).get_candidate();

                    if ARI.items_acquired[self.prize] == false {
                        self.prize = new LiveItem(ItemId.UnidentifiedArtifact, self.prize);
                    }

                    static COSMETICS = [
                        "back_gear_dragon_cleric_cape",
                        "robe_dragon_cleric",
                        "face_gear_dragon_cleric_earrings",
                        "head_dragon_cleric_diadem",
                        "shoes_boots_dragon_cleric",
                    ];

                    if chance_percent(50) {
                        array_shuffle_mut(COSMETICS);

                        for (var i = 0; i < array_length(COSMETICS); i++) {
                            var cosmetic = COSMETICS[i];
                            if !ari_has_cosmetic_anywhere(cosmetic) {
                                self.second_prize = new LiveItem(ItemId.Cosmetic)
                                self.second_prize.cosmetic = cosmetic;
                                break;
                            }
                        }
                    }

                },
                function() {
                    return self.prize == undefined;
                }
            )
        },
        animation_end: function() {
            if self.sprite_index == spr_dungeon_mines_ritual_altar_spring_opening {
                self.sprite_index = spr_dungeon_mines_ritual_altar_spring_open;
                self.image_speed = 0;
                drop_item(self.prize, self.x, self.y);
                if self.second_prize != undefined {
                    drop_item(self.second_prize, self.x, self.y);
                }
            }
        },
    }
);
