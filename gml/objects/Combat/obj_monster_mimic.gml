object_create(
    "obj_monster_mimic",
    object_reserve("par_monster"),
    {
        sprite_index: spr_monster_mimic_main_idle_south,
        create: function() {
            event_inherit(ObjectEvent.Create);

            function gobble(items) {
                var item = items.get(0);

                if item.prototype.use != ItemUse.Attack
                    && item.prototype.use != ItemUse.UseTool
                    && item.prototype.use != ItemUse.Blueprint
                    && item.prototype.use != ItemUse.UnlockCosmetic
                    && item.prototype.use != ItemUse.IdentifyItem
                    && item.prototype.use != ItemUse.OpenChest
                    && item.prototype.use != ItemUse.GainGold
                    && item.prototype.use != ItemUse.GainGoldInstant
                    && item.prototype.use != ItemUse.ExpandInventory
                    && item.prototype.use != ItemUse.CrackEssenceStone
                    && item.prototype.use != ItemUse.UnlockAnimalCosmetic
                    && item.prototype.use != ItemUse.UnlockPetCosmetic
                    && item.prototype.use != ItemUse.UnlockPetSkin
                    && item.prototype.use != ItemUse.UnlockDate
                    && item.prototype.use != ItemUse.UnlockSong
                    && item.prototype.use != ItemUse.LearnRecipe
                    && item.prototype.use != ItemUse.Bomb //
                {
                    items.remove(0);

                    self.fsm.blackboard.insert("valid_gobble", true);

                    var data = get_treasure_from_distribution(self.x, self.y);
                    if data != undefined {
                        self.fsm.blackboard.insert("items", List(data[0]));
                    }

                    if ARI.perk_active(Perk.GiftExchange) {
                        var data = get_treasure_from_distribution(self.x, self.y);
                        if data != undefined {
                            self.fsm.blackboard.insert("secondary_items", List(data[0]));
                        }
                    }
                } else {
                    self.fsm.blackboard.insert("valid_gobble", false);
                }

                self.fsm.blackboard.insert("return_items", items);
                self.fsm.change_state(MimicState.Gobble);
            }

            depth = get_instance_depth(self.y, self.z);

            interactable = instance_create_depth(
                self.x,
                self.y,
                self.depth,
                obj_mimic_interactable,
            );
            interactable.mimic = self;

            interactable.register_interaction(
                InputId.Interact,
                "misc_local/input_interact",
                function() {
                    self.fsm.change_state(MimicState.Attack);
                },
                function() {
                    return self.fsm.current_state_id() == MimicState.Idle;
                },
            );

            fsm = StateMachineBuilder(MimicState.LEN)
                .add_state(
                    StateBuilder(MimicState.Idle)
                        .start(function() {
                            owner.set_state_sprite(true, MimicState.Idle);

                            in_variant = false;
                            variant_timer = irandom_range(owner.config.idle_variant[0], owner.config.idle_variant[1]);
                        })
                        .step(function() {
                            if self.in_variant == false {
                                self.variant_timer -= 1;
                                if self.variant_timer <= 0 {
                                    //
                                    TANGO.play(owner.config.misc_tango.idle_shake, owner.x, owner.y);
                                    owner.sprite_index = owner.config.misc_sprites.idle_two;
                                    owner.image_index = 0;
                                    shadow_caster_set_sprite(owner.shadow_caster, SHADOW_DICTIONARY.get(owner.sprite_index));

                                    self.in_variant = true;
                                }
                            }
                        })
                        .anim_end(function() {
                            if self.in_variant {
                                owner.set_state_sprite(true, MimicState.Idle);
                                self.in_variant = false;
                                self.variant_timer = irandom_range(owner.config.idle_variant[0], owner.config.idle_variant[1]);
                            }
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MimicState.Attack)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            self.projectile = undefined;
                            self.index_lock = 0;
                            self.poof = false;
                        })
                        .step(function() {
                            if self.projectile == undefined && owner.image_index >= 8 {
                                self.projectile = instance_create_depth(
                                    owner.x,
                                    owner.y,
                                    get_floor_depth(),
                                    obj_mimic_attack,
                                    {
                                        damage: owner.config.damage,
                                        monster_id: owner.monster_id,
                                        stats_entry: owner.stats_entry,
                                    }
                                );
                            }

                            if self.projectile != undefined && instance_exists(self.projectile) == false {
                                self.fsm.change_state(MimicState.Fade);
                            }

                            self.index_lock = floor(owner.image_index);
                        })
                        .anim_end(function() {
                            owner.image_index = self.index_lock;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MimicState.Hurt)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            CAMERA.add_trauma(0.1);
                            owner.show_damage = 1000;
                        })
                        .anim_end(function() {
                            fsm.change_state(MimicState.Attack);
                        })
                        .stop(function() {
                            owner.show_damage = 0;
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MimicState.Gobble)
                        .start(function() {
                            owner.set_state_sprite();
                            owner.play_state_tango();

                            self.items = self.blackboard.try_take("items", undefined);
                            self.secondary_items = self.blackboard.try_take("secondary_items", undefined);
                            self.return_items = self.blackboard.take("return_items");
                            self.poof = false;
                        })
                        .step(function() {
                            if self.poof == false && floor(owner.image_index) == owner.config.spit_frame {
                                self.poof = true;

                                TANGO.play("SoundEffects/Inventory/ItemDrop", owner.x, owner.y);

                                //
                                if self.items != undefined {
                                    var item = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                    item.final_x = owner.x + irandom_range(-16, 16);
                                    item.final_y = owner.y + irandom_range(6, 32);
                                    item.setup(self.items);
                                }

                                //
                                if self.secondary_items != undefined {
                                    var item = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                    item.final_x = owner.x + irandom_range(-16, 16);
                                    item.final_y = owner.y + irandom_range(6, 32);
                                    item.setup(self.secondary_items);
                                }

                                if self.return_items.is_empty() == false {
                                    var item = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                    item.final_x = owner.x + irandom_range(-16, 16);
                                    item.final_y = owner.y + irandom_range(6, 32);
                                    item.setup(self.return_items);
                                }

                                repeat 3 {
                                    var item = new LiveItem(ItemId.MobCoin);
                                    item.auto_use = true;
                                    item.gold_to_gain = 1;
                                    var item_obj = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                    item_obj.final_x = owner.x + irandom_range(-16, 16);
                                    item_obj.final_y = owner.y + irandom_range(6, 32);

                                    item_obj.setup(List(item));
                                }

                                if self.blackboard.try_take("valid_gobble", false) {
                                    if ari_has_cosmetic_anywhere("head_mimic_hat") == false
                                        && chance_percent(5)
                                    {
                                        var item = new LiveItem(ItemId.Cosmetic);
                                        item.cosmetic = "head_mimic_hat";
                                        var item_obj = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                        item_obj.final_x = owner.x + irandom_range(-16, 16);
                                        item_obj.final_y = owner.y + irandom_range(6, 32);
    
                                        item_obj.setup(List(item));
                                    }
    
                                    if ari_has_pet_skin_anywhere("mimic") == false
                                        && ARI.perk_active(Perk.FriendShaped)
                                        && chance_percent(5)
                                    {
                                        var item = new LiveItem(ItemId.PetSkinMimic);
                                        var item_obj = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                        item_obj.final_x = owner.x + irandom_range(-16, 16);
                                        item_obj.final_y = owner.y + irandom_range(6, 32);
    
                                        item_obj.setup(List(item));
                                    }
                                }
                            }
                        })
                        .anim_end(function() {
                            self.fsm.change_state(MimicState.Dying);
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MimicState.Dying)
                        .start(function() {
                            owner.set_state_sprite();

                            var ae = create_animation_effect_on_object(owner, spr_fx_small_monster_death_poof, -1);
                            ae.owner = owner;
                            ae.image_idx = 5;
                            ae.image_idx_func = method(ae, function() {
                                instance_destroy(self.owner);
                                if game_stats_mines_floor_available() {
                                    var key = monster_id_to_string(self.owner.monster_id);
                                    if GS_MINES_FLOOR.enemy_kill[$ key] == undefined {
                                        GS_MINES_FLOOR.enemy_kill[$ key] = 0;
                                    }
                                    GS_MINES_FLOOR.enemy_kill[$ key] += 1;
                        
                                }
                            });
                        })
                        .spawn()
                )
                .add_state(
                    StateBuilder(MimicState.Fade)
                        .start(function() {
                            owner.set_state_sprite();
                            poof = false;
                            self.index_lock = 0;
                        })
                        .step(function() {
                            if self.poof == false && floor(owner.image_index) >= 4 {
                                poof = true;
                                repeat 2 {
                                    var item = new LiveItem(ItemId.MobCoin);
                                    item.auto_use = true;
                                    item.gold_to_gain = 1;
                                    var item_obj = instance_create_layer(owner.x, owner.y, "Instances", obj_item);
                                    item_obj.final_x = owner.x + irandom_range(-6, 6);
                                    item_obj.final_y = owner.y + irandom_range(6, 6);

                                    item_obj.setup(List(item));
                                }
                                TANGO.play("SoundEffects/Inventory/ItemDrop", owner.x, owner.y);
                            }

                            if owner.image_index >= 8 {
                                instance_destroy(self.owner);
                            }
                        })
                        .spawn()
                )
                .spawn(MimicState.Idle, self, Map());

            //
            with obj_monster_mimic {
                if self.id != other.id {
                    self.skip_destroy_logic = true;
                    instance_destroy();
                }
            }
            if instance_exists(obj_dungeon_elevator) {
                self.skip_destroy_logic = true;
                instance_destroy();
            }
        },
        step: function() {
            event_inherit(ObjectEvent.Step);

            if game_paused() {
                return;
            }

            fsm.step();
        },
        step_end: function() {
            if game_paused() {
                return;
            }

            shadow_caster_set_position(self.shadow_caster, x, y);
            process_white_vfx();
            shadow_caster_set_image(self.shadow_caster, self.image_index);
            self.process_status();

            fsm.end_step();

            if !instance_exists(self) {
                return;
            }

            var csi = fsm.current_state_id();
            if csi != MimicState.Idle {
                return;
            }

            var next_dmg = self.receiver.try_take_damage();
            if next_dmg == undefined {
                return;
            }

            self.process_tarball_status(next_dmg.tarball);

            if next_dmg.status != ReceiverStatus.Normal {
                return;
            }

            //
            spawn_damage_numbers(
                self,
                self.config.damage_number_offset,
                0,
                next_dmg.tarball.damage_flag(),
            );

            TANGO.play(self.config.misc_tango.weak_damage, x, y);

            //
            CAMERA.camera_stop = 1;
            self.fsm.change_state(MimicState.Hurt);
        },
        draw: function() {
            if self.fsm.current_state_id() == MimicState.Idle && self.interactable.highlighter.update(x, y) {
                gpu_set_extra(UberShaderKind.Overlay);
                self.image_blend = self.interactable.highlighter.color;
                self.image_alpha = self.interactable.highlighter.strength;
                event_inherit(ObjectEvent.Draw);
                gpu_reset_extra();
                self.image_blend = c_white;
                self.image_alpha = 1.0;
            } else {
                event_inherit(ObjectEvent.Draw);
            }
        },
        destroy: function() {
            instance_destroy(self.interactable);
        },
    }
);
