function setup_white_vfx() {
    show_damage = 0;
    perform_effect = false;
    effect_alpha = 1;
}

function process_white_vfx() {
    if self.show_damage > 0 {
        if (self.show_damage % 4) == 0 {
            self.perform_effect = !self.perform_effect;
            if self.perform_effect {
                self.effect_alpha = random_range(0.7, 1.0);
            }
        }
        self.show_damage -= 1;
    }
}

function white_vfx() {
    if self.perform_effect && self.show_damage > 0 {
        gpu_set_extra(UberShaderKind.Flat);
        self.image_alpha = self.effect_alpha;
        self.draw();
        self.image_alpha = 1.0;
        gpu_reset_extra();
    }
}

function monster_death_poof(owner, optional_position=undefined) {
    if chance_percent(ARI.perk_value(Perk.InMotion)) {
        var time = CALENDAR.unified_time();
        ARI.status_effects.register(
            StatusEffectId.KillHaste,
            fiddle_get("perks/in_motion/modifier"),
            time,
            time + minutes(fiddle_get("perks/in_motion/duration_minutes")),
        );
    }

    if ARI.perk_active(Perk.SureStrike) {
        var time = CALENDAR.unified_time();
        if ARI.status_effects.get_effect_value(StatusEffectId.SureStrike, 0) == 0 {
            ARI.status_effects.register(
                StatusEffectId.SureStrike,
                1,
                time,
                time + ARI.perk_value(Perk.SureStrike, "duration_frames") * GAME_SECONDS_PER_FRAME,
                false,
                true
            );
        } else {
            var val = ARI.status_effects.get_effect_value(StatusEffectId.SureStrike);
            ARI.status_effects.cancel(StatusEffectId.SureStrike);
            ARI.status_effects.register(
                StatusEffectId.SureStrike,
                clamp(val + 1, 0, 5),
                time,
                time + ARI.perk_value(Perk.SureStrike, "duration_frames") * GAME_SECONDS_PER_FRAME,
                false,
                true
            );
        }
    }

    var ae = undefined;

    if optional_position != undefined {
        create_animation_effect(optional_position.x, optional_position.y, owner.depth - 1, spr_fx_small_monster_death_sparkle);
        ae = create_animation_effect(optional_position.x, optional_position.y, owner.depth - 1, spr_fx_small_monster_death_poof);
    } else {
        create_animation_effect_on_object(owner, spr_fx_small_monster_death_sparkle, -2);
        ae = create_animation_effect_on_object(owner, spr_fx_small_monster_death_poof, -1);
    }

    ae.owner = owner;
    ae.image_idx = 5;
    ae.image_idx_func = method(ae, function() {
        if requirements_pass(Requirement.HasVoidSight) && chance_percent(fiddle_get("misc/void_powder_chance")) {
            item_from_critical_poof(self.x, self.y, ItemId.VoidPowder);
        }

        if self.owner != undefined && instance_exists(self.owner) {
            repeat (chance_percent(ARI.perk_value(Perk.GenerousInDefeat) + ARI.perk_value(Perk.GenerousInDefeatTwo)) + 1) {
                create_drops_and_essence(
                    self.owner.config.drops,
                    self.owner.config.essence,
                    self.x,
                    self.y,
                    self.owner.monster_id,
                    irandom_range(self.owner.config.coin_count.x, self.owner.config.coin_count.y)
                );
                GAME_STATS.perks[$ perk_to_string(Perk.GenerousInDefeat)] += 1;
                if ARI.perk_active(Perk.GenerousInDefeatTwo) {
                    GAME_STATS.perks[$ perk_to_string(Perk.GenerousInDefeatTwo)] += 1;
                }
            }

            if game_stats_mines_floor_available() {
                var key = monster_id_to_string(self.owner.monster_id);
                if GS_MINES_FLOOR.enemy_kill[$ key] == undefined {
                    GS_MINES_FLOOR.enemy_kill[$ key] = 0;
                }
                GS_MINES_FLOOR.enemy_kill[$ key] += 1;

            }

            instance_destroy(self.owner);
        }

        if chance_percent(ARI.perk_value(Perk.Resonance)) {
            var lookup = fiddle_get(format("perks/{Perk}", Perk.Resonance));
            var fix_list = List();
            repeat 100 {
                var nearest_node = instance_nearest(self.x, self.y, obj_node_renderer);

                if nearest_node == undefined {
                    break;
                }

                if object_id_to_object_category(nearest_node.node.object_id) == ObjectCategory.Rock
                    && point_distance(obj_ari.x, obj_ari.y, nearest_node.x, nearest_node.y) < lookup.distance
                {
                    create_animation_effect(
                        nearest_node.x,
                        nearest_node.y + 5,
                        get_floor_depth(),
                        spr_fx_critical_swing_poof
                    );
                    var temp_dop = new TangoDoppel();
                    TANGO.play("SoundEffects/Inventory/StaminaPreSpawnPoof", nearest_node.x, nearest_node.y);
                    pick_node(GRID,
                        nearest_node.x div 8,
                        nearest_node.y div 8,
                        ITEM_PROTOTYPES[ItemId.PickAxeMistril],
                        I32_MAX,
                        "SoundEffects/Objects/EarthbreakerRockBreak",
                        temp_dop
                    );
                    temp_dop.resolve();
                    break;
                } else {
                    nearest_node.original_x = nearest_node.x;
                    nearest_node.original_y = nearest_node.y;
                    nearest_node.x = infinity;
                    nearest_node.y = infinity;
                    fix_list.push(nearest_node);
                }
            }

            for (var i = 0; i < fix_list.count(); i++) {
                var node = fix_list.get(i);
                node.x = node.original_x;
                node.y = node.original_y;

                //
                node.original_x = undefined;
                node.original_y = undefined;
            }
        }
    });
}

function monster_critical_fx(monster) {
    static POSSIBLE_POSES = [
        [Vec2(4, -10), Vec2(-4, -2)],
        [Vec2(4, -2), Vec2(-4, -10)]
    ];
    static SPRS = [
        spr_part_spinning_star_blue,
        spr_part_spinning_star_pink,
    ];
    var pos = POSSIBLE_POSES[choose(true, false)];
    var pos_choice = choose(true, false);
    var spr_choice = choose(true, false);

    create_animation_effect_on_object(monster, SPRS[spr_choice], -102, pos[pos_choice].y, pos[pos_choice].x);

    pos_choice = !pos_choice;
    spr_choice = !spr_choice;

    create_animation_effect_on_object(monster, SPRS[spr_choice], -100, pos[pos_choice].y, pos[pos_choice].x);

    TANGO.play("SoundEffects/Ari/CritConfirm");
}

function monster_outside_bounds(xx, yy, inst_id) {
    var ni = GRID.try_node_index_for_room_position(xx, yy);
    if ni == undefined || GRID.node_terrain_kind[ni] != TerrainKind.Ground {
        inst_id.insta_kill_timer += 1;
        if inst_id.insta_kill_timer >= 30 {
            instance_destroy(inst_id);
        }
    } else {
        inst_id.insta_kill_timer = 0;
    }
}

function create_drops_and_essence(drops, essence, xx, yy, monster_id, coin_count) {
    var items = undefined;
    //
    //
    repeat 10 {
        items = drops.choose_drop().to_array();
        if array_length(items) == 1 {
            var item = items[0];
            var can_be_given = true;
            switch item.item_id {
                case ItemId.Cosmetic:
                    can_be_given = !ari_has_cosmetic_anywhere(item.cosmetic);
                    break;
                case ItemId.AnimalCosmetic:
                    can_be_given = !ari_has_animal_cosmetic_anywhere(item.animal_cosmetic.animal, item.animal_cosmetic.cosmetic);
                    break;
                case ItemId.PetCosmetic:
                    if ari_has_pet_cosmetic_anywhere(item.pet_cosmetic_set_name) {
                        can_be_given = false;
                        break;
                    }
                    var any = false;
                    var set = PET_PROTOTYPE.cosmetic_sets.get(item.pet_cosmetic_set_name);
                    for (var i = 0; i < array_length(set.cosmetics_to_unlock); i++) {
                        var cosmetic = PET_PROTOTYPE.cosmetics.get(set.cosmetics_to_unlock[i]);
                        if pet_kind_unlocked(cosmetic.pet_kind) {
                            any = true;
                            break;
                        }
                    }
                    can_be_given = any;
                    break;
                case ItemId.RecipeScroll:
                case ItemId.CraftingScroll:
                    can_be_given = !ari_has_recipe_anywhere(item.inner_item);
                    break;
                default:
                    if item.prototype.pet_skin_unlock != undefined {
                        can_be_given = !ari_has_pet_skin_anywhere(item.prototype.pet_skin_unlock) && ARI.perk_active(Perk.FriendShaped);
                    } else {
                        can_be_given = true;
                    }
                    break;
            }

            //
            if can_be_given {
                break;
            }

            items = undefined;
        } else {
            break;
        }
    }

    //
    if items == undefined {
        items = [];
    }

    if game_stats_mines_floor_available() {
        var key = monster_id_to_string(monster_id);

        array_push(GS_MINES_FLOOR.enemy_drops, {
            monster: key,
            items: array_map(items, function(v) {
                return v.pretty_print();
            }),
            coins: coin_count,
        });
    }

    drop_item(items, xx, yy);

    for (var i = 0; i < coin_count; i++) {
        var item = new LiveItem(ItemId.MobCoin);
        item.auto_use = true;
        item.gold_to_gain = 1;
        drop_item(item, xx + irandom_range(-6, 6), yy + irandom_range(-6, 6));
    }

    try_gather_item_spawn(GatherDropChance.KillEnemy, xx, yy);

    ARI.gain_essence(essence, xx, yy, 2, 0);

    if is_dungeon_room(room()) {
        ARI.gain_xp(Skill.Combat, DUNGEON.biomes[DUNGEON_BIOME].combat_xp_gain);
    }
}

//
function monster_vertical_cardinal_from_dir(dir) {
    if dir < 10 || dir >= 170 {
        return Cardinal.South;
    }
    return Cardinal.North;
}

function create_clod_projectile(spd, parent_clod, monster_id, stats_entry, config) {
    return {
        spd,
        parent_clod,
        monster_id,
        stats_entry,
        dmg: config.damage,
        sprite_index: config.misc_sprites.projectile,
        rock_particle: config.misc_sprites.rock_particle,
        death_tango: config.misc_tango.projectile_break,
        reflect_tango: config.misc_tango.projectile_reflect,
        split_angle: config.split_angle,
        split_distance: config.split_distance,
        split_depth: config.split_depth,
        split_speed: config.split_speed,
        split_depreciation: config.split_depreciation
    }
}

function create_smoke(xx, yy, sprite, source_depth, smoke_number=5) {
    static SMOKE_DEBRIS = new ParticleSmokeBundle();

    repeat smoke_number {
        create_debris(
            xx + random_range(-6, 6),
            yy + random_range(-12, 6),
            source_depth,
            sprite,
            SMOKE_DEBRIS,
        );
    }
}

function monster_category_to_ui_info(cat) {
    switch cat {
        case MonsterCategory.Shroom: return {
            icon: spr_ui_stillwell_quest_icon_mushroom_green,
            label: "misc_local/shrooms_defeated",
        };
        case MonsterCategory.Clod: return {
            icon: spr_ui_stillwell_quest_icon_rockclod,
            label: "misc_local/rock_clods_defeated",
        };
        case MonsterCategory.Sap: return {
            icon: spr_ui_stillwell_quest_icon_sapling_green,
            label: "misc_local/saps_defeated",
        };
        case MonsterCategory.Enchantern: return {
            icon: spr_ui_stillwell_quest_icon_enchantern_blue,
            label: "misc_local/enchanterns_defeated",
        };
        case MonsterCategory.Mite: return {
            icon: spr_ui_stillwell_quest_icon_stalagmite_green,
            label: "misc_local/mites_defeated",
        };
        case MonsterCategory.Bat: return {
            icon: spr_ui_stillwell_quest_icon_essence_bat_blue,
            label: "misc_local/bats_defeated",
        };
        case MonsterCategory.Mimic: return {
            icon: spr_ui_stillwell_quest_icon_mimic,
            label: "misc_local/mimics_defeated",
        };
        case MonsterCategory.Spirit: return {
            icon: spr_ui_stillwell_quest_icon_flame_spirit,
            label: "misc_local/spirits_defeated",
        };
        case MonsterCategory.Cat: return {
            icon: spr_ui_stillwell_quest_icon_lava_cat,
            label: "misc_local/cats_defeated",
        };
        case MonsterCategory.RockStack: return {
            icon: spr_ui_stillwell_quest_icon_rock_stack,
            label: "misc_local/rock_stacks_defeated",
        };
        case MonsterCategory.Statue: return {
            icon: spr_ui_stillwell_quest_icon_gryphon,
            label: "misc_local/statues_defeated",
        };
        case MonsterCategory.Tome: return {
            icon: spr_ui_stillwell_quest_icon_flying_tome,
            label: "misc_local/tomes_defeated",
        };
    }
}
