object_create(
    "par_animal",
    object_reserve("par_interactable"),
    {
        sprite_index: undefined,
        create: function() {
            //
            event_inherit(ObjectEvent.Create, par_interactable);

            assert_neq(self.me, undefined, "animals must have a `me` animal passed in!");

            self.shadow_caster = SHADOW_GRID.caster_create(self.x, self.y);
            self.shadow_draw = true;
            self.z = 0;
            self.move_spd = Vec2();
            self.sprites = undefined;
            self.ambient_sound = undefined;
            self.bark_emitter = new BarkEmitter(self);
            self.time_until_ambient = irandom_range(120, 720);

            self.move_accel = self.me.move_accel();
            self.dir = irandom_range(0, 360);
            self.ignore_collision = false;
            self.inhibit_shadow = false;
            self.inhibit_depth = false;

            //
            self.collision_last_frame = MovementCollisionDirection.NONE;
            self.can_update_location_position = true;

            setup_move_and_collide();

            function try_accept_pathfinding_request() {
                return false;
            }

            function set_sprites(animation) {
                self.me.animation = animation;
                self.sprites = self.me.active_sprites();
                self.sprite_index = self.sprites.base_sprite;
            }

            function draw_routine(xx, yy) {
                if self.highlighter.update(x, y) {
                    self.image_blend = self.highlighter.color;
                    self.image_alpha = self.highlighter.strength;
                } else {
                    self.image_blend = c_white;
                    self.image_alpha = 0.0;
                }

                animal_set_up_draw(self.sprites);
                self.wrapped_draw(self.sprite_index, xx, yy);
                gpu_reset_extra();

                if self.sprites.base_cosmetic != undefined {
                    gpu_set_extra(UberShaderKind.Overlay);
                    draw_sprite_ext(
                        self.sprites.base_cosmetic,
                        self.image_index,
                        xx,
                        yy,
                        self.image_xscale,
                        1,
                        0,
                        image_blend,
                        image_alpha,
                    );
                }

                if self.sprites.top_sprite != undefined {
                    animal_set_up_draw(self.sprites);
                    self.wrapped_draw(self.sprites.top_sprite, xx, yy);
                    gpu_reset_extra();
                }

                if self.sprites.top_cosmetic != undefined {
                    gpu_set_extra(UberShaderKind.Overlay);
                    draw_sprite_ext(
                        self.sprites.top_cosmetic,
                        self.image_index,
                        xx,
                        yy,
                        self.image_xscale,
                        1,
                        0,
                        image_blend,
                        image_alpha,
                    );
                }
                gpu_reset_extra();
            }
            function setup_celebration_animation(face_ari, animation_count=1) {
                self.fsm.blackboard.set("animation", self.me.celebration_animation());
                if face_ari {
                    self.fsm.blackboard.set("animation_direction_override", point_direction(self.x, self.y, obj_ari.x, obj_ari.y));
                }
                self.fsm.blackboard.set("force_end_after_animation", animation_count);

                var target_state;
                switch self.object_index {
                    case obj_npa:
                        target_state = NpaState.Animate;
                        break;
                    case obj_player_animal:
                        target_state = AnimalState.Animate;
                        break;
                    case obj_pet:
                        target_state = PetState.Animate;
                        break;
                    default: impossible("unexpected object_indx for a `par_animal`: {GmObject}", self.object_index);
                }
                self.fsm.change_state(target_state);
            }

            function pet_animal_interaction(ari_interacts=true, cycle_count=1) {
                self.on_pet();

                if ARI.held_animal_id != self.me.idx {
                    self.setup_celebration_animation(ari_interacts, cycle_count);
                }

                if ari_interacts {
                    obj_ari.enter_action_animation(self.x, self.y);
                    //
                    set_rumble(RumbleKind.Pet);
                    new_chain()
                        .append(LinkId.Timer, 30)
                        .append(LinkId.Function, function() {
                            set_rumble(RumbleKind.Pet);
                        });
                }
            }

            function wrapped_draw(sprite, xx, yy) {
                if is_nullish(xx) {
                    xx = self.x;
                    yy = self.y;
                }
                draw_sprite_ext(
                    sprite,
                    self.image_index,
                    xx,
                    yy,
                    self.image_xscale,
                    1,
                    0,
                    image_blend,
                    image_alpha,
                );
            }


            function update_bark_offset() {
                var bark_offsets = self.me.bark_offsets();

                self.bark_emitter.x_offset = bark_offsets[self.me.cardinality].x;
                self.bark_emitter.y_offset = bark_offsets[self.me.cardinality].y;

                if ARI.held_animal_id == self.me.idx {
                    var par = obj_ari.par;
                    var slot = par.slots[AnimationSlot.HeldItem];
                    var left_arm_slot = par.slots[AnimationSlot.BaseArmLeft];

                    //
                    if left_arm_slot.modifier.animation_name == undefined
                        || slot.modifier.animation_name == undefined
                    {
                        return;
                    }
                    var base_offset = left_arm_slot.modifier.current_frame.offset;
                    var diff_offset = left_arm_slot.base.current_frame.offset;
                    var y_offset = slot.modifier.current_frame.offset.y + (diff_offset.y - base_offset.y) + par.held_sprite.y_offset;

                    self.bark_emitter.y_offset += y_offset + obj_ari.par_offset.y;
                }
            }

            function should_use_hop_movement() {
                return self.me[$ "kind"] == AnimalKind.Rabbit
                    || self.me == PET && matches(PET.pet_kind(), PetKind.Oreclod, PetKind.Rockclod, PetKind.Enchantern, PetKind.Stalagmite, PetKind.Mimic, PetKind.RockStack, PetKind.GriffinStatue);
            }

            self.me.instance = self;
            self.me.set_cardinality(self.me.starting_cardinality());
        },
        step: function() {
            if non_cutscene_pause() {
                return;
            }

            self.fsm.step();
        },
        step_begin: function() {
            fsm.new_tick();
        },
        step_end: function() {
            if self.inhibit_depth == false {
                depth = get_instance_depth(y, z);
            }

            if non_cutscene_pause() {
                return;
            }

            if SETTINGS.get("sound_animals")
                && self.me.can_make_sounds()
                && self.time_until_ambient >= 0
                && self.me.active_animation().play_ambient_sounds
                && self.me.sounds().ambient != undefined
            {
                self.time_until_ambient -= 1;
                if self.time_until_ambient <= 0 {
                    var sounds = self.me.sounds();
                    if self.ambient_sound != undefined {
                        self.ambient_sound.force_stop();
                    }
                    self.ambient_sound = new SoundInstanceController(TANGO.play(sounds.ambient, self.x, self.y));
                }
            }

            var ni = GRID.try_node_index_for_room_position(self.x, self.y);
            if ni != undefined
                && GRID.node_object_id[ni] != undefined
                && GRID.node_parent[ni].renderer != undefined
                && instance_exists(GRID.node_parent[ni].renderer)
            {
                GRID.node_parent[ni].renderer.collide(!self.move.is_zero(), self.me.cardinality);
            }

            self.fsm.end_step();

            if !instance_exists(self) {
                return;
            }

            shadow_caster_set_position(self.shadow_caster, self.x, self.y - self.z);

            if self.should_use_hop_movement()
                && self.me.animation == "walk"
                && self.image_index >= 2
            {
                self.move.x = 0;
                self.move.y = 0;
            }

            if self.ignore_collision {
                self.x += self.move.x;
                self.y += self.move.y;

                self.move.x = 0;
                self.move.y = 0;
                self.collision_last_frame = MovementCollisionDirection.NONE;
            } else {
                self.collision_last_frame = movement_and_collide();
            }

            if self.ambient_sound != undefined {
                self.ambient_sound.update_instance_position(self.x, self.y);
            }
        },
        draw: function() {
            if self.inhibit_shadow == false {
                shadow_caster_set_sprite(self.shadow_caster, self.sprites.shadow);
                shadow_caster_set_image(self.shadow_caster, self.image_index);
                shadow_caster_set_image_xscale(self.shadow_caster, self.image_xscale);
            }
            self.image_xscale = self.me.cardinality == Cardinal.West ? -1 : 1;

            self.draw_routine(self.x, self.y);
        },
        animation_end: function() {
            fsm.anim_end();
        },
        destroy: function() {
            if self.fsm != undefined {
                self.fsm.destroy();
            }
        },
        cleanup: function() {
            if self.ambient_sound != undefined {
                self.ambient_sound.force_stop();
            }
            if self.fsm != undefined {
                self.fsm.cleanup();
            }
            self.me.instance = undefined;
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);
