enum CameoState {
    Idle,
    Pathfinding,
    LEN,
}

function cameo_id_to_gm_obj_id(cameo) {
    switch cameo {
        case CameoId.Linnet: return object("obj_linnet");
        case CameoId.Wiscar: return object("obj_wiscar");
        case CameoId.Darren: return object("obj_darren");
        case CameoId.Wynne: return object("obj_wynne");
        default: IMPOSSIBLE("Unexpected cameo: {CameoId}", cameo);
    }
}

object_create(
    "obj_cameo",
    undefined,
    {
        sprite_index: undefined,
        me: undefined,
        create: function() {
            function update_animation() {
                var sprite_pack_collection = self.me
                .wardrobe
                .outfit_current
                .cycles
                .get(self.me.animation);


                if sprite_pack_collection != self.animator.sprite_pack_collection {
                    self.animator.set_animation(sprite_pack_collection);
                }
            }

            function update_cardinality() {
                self.image_xscale = self.me.cardinality != Cardinal.West ? 1 : -1;
                self.animator.set_cardinality(self.me.cardinality);
            }

            function create_default_fsm() {
                return StateMachineBuilder(CameoState.LEN)
                    .add_state(StateBuilder(CameoState.Idle)
                        .start(function() {
                            if self.owner.me.animation == "walk" {
                                self.owner.me.set_animation("idle");
                            }

                            self.owner.update_cardinality();
                            self.owner.update_animation();
                        })
                        .step(function() {
                            if self.owner.me.itinerary != undefined {
                                self.fsm.change_state(CameoState.Pathfinding);
                            }
                        })
                        .draw(function() {
                            var ratio = DISPLAY.asset_resize();
                            var draw_x = floor(owner.x * ratio) / ratio;
                            var draw_y = floor(owner.y * ratio) / ratio + owner.y_offset;

                            draw_sprite_ext(owner.sprite_index, owner.image_index, draw_x, draw_y, self.owner.image_xscale, 1, 0, self.owner.image_blend, self.owner.image_alpha);
                        })
                        .spawn()
                    )
                    .add_state(StateBuilder(CameoState.Pathfinding)
                        .start(function() {
                            self.itinerary = pathfinding_util_get_itinerary();
                            pathfinding_util_create_local_path(self.itinerary, self.owner);

                            self.owner.position.x = owner.x;
                            self.owner.position.y = owner.y;
                            self.owner.me.set_animation("walk");
                        })
                        .step(function() {
                            self.owner.position.set(self.owner);
                            self.owner.move_spd.set_zero();

                            self.owner.pathfinding_agent.move_along_path();
                            var completed = pathfinding_util_move_along_path(owner.position, owner.move_accel, owner.move_spd, self.owner.pathfinding_agent, self.owner);

                            if completed {
                                self.owner.me.location_position = self.itinerary
                                    .current_item()
                                    .target_location
                                    .clone();

                                self.owner.x = self.owner.me.location_position.pos.x;
                                self.owner.y = self.owner.me.location_position.pos.y;

                                if self.itinerary.on_last_item() {
                                    self.owner.me.brain.blackboard.set("pathfind_complete", true);
                                    self.owner.me.itinerary = undefined;
                                    self.fsm.change_state(CameoState.Idle);
                                }
                            }

                        })
                        .end_step(function() {
                            pathfinding_util_end_step();
                            if self.owner.move_spd.is_zero() == false {
                                var cardinality = self.owner.move_spd.cardinality_heuristic();
                                self.owner.me.set_cardinality(cardinality);
                            }
                        })
                        .draw(function() {
                            var ratio = DISPLAY.asset_resize();
                            var draw_x = floor(owner.x * ratio) / ratio;
                            var draw_y = floor(owner.y * ratio) / ratio + owner.y_offset;
                            self.owner.anim_speed = 1;
                            draw_sprite_ext(self.owner.sprite_index, self.owner.image_index, draw_x, draw_y, self.owner.image_xscale, 1, 0, self.owner.image_blend, self.owner.image_alpha);
                        })
                        .spawn()
                    )
            }

            function animate() {
                self.animator.animate(self.anim_speed);
                self.sprite_index = self.animator.sprite();
                self.image_index = self.animator.index();
                self.image_xscale = self.animator.cardinality != Cardinal.West ? 1 : -1;
                if self.animator.animation_is_over && self.reset_cycle_name != undefined {
                    self.me.set_cardinality(self.reset_cycle_cardinality ?? self.me.cardinality);
                    self.me.set_animation(self.reset_cycle_name);
                    self.reset_cycle_name = undefined;
                    self.reset_cycle_cardinality = undefined;
                }
            }

            function initialize(cameo, override_state) {
                self.me = cameo;
                self.debug_name = cameo_id_to_string(self.me.id);
                self.update_cardinality();
                self.update_animation();
                self.animate(0);
                self.me.brain.blackboard.set("instance", self.id);
                self.fsm = self.create_default_fsm().spawn(CameoState.Idle, self, Map());
            }

            function update_position() {
                self.position.set_add(move_spd);
                self.x = self.position.x;
                self.y = self.position.y;
            }

            self.z = 0;
            self.y_offset = 0;
            self.shadow_caster = SHADOW_GRID.caster_create(x, y);
            shadow_caster_set_sprite(shadow_caster, spr_npc_shadow);
            self.mask_index = spr_npc_mask;
            self.move_accel = Vec2(HUMAN_WALK_SPEED, HUMAN_WALK_SPEED);
            self.move_spd = Vec2(0, 0);
            self.position = Vec2Object(self);
            self.pathfinding_agent = new PathfindingAgent(new PathfindingMeddler(PathfindingAgentKind.Npc, self));
            self.animator = new NpcAnimationHandler(self);
            self.anim_speed = 1;
            self.bark_emitter = new BarkEmitter(self, 0, -38);
        },
        step: function() {
            self.depth = get_instance_depth(self.y, self.z);
            self.fsm.step();
        },
        step_begin: function() {
            self.fsm.new_tick();
        },
        step_end: function() {
            self.fsm.end_step();
            self.animate();

            var y_off = MIST.is_running() && MIST.blackboard.get("offset_shadows_while_seated") && self.me.is_seated() ? -4 : 0;
            shadow_caster_set_position(self.shadow_caster, x, y + y_off);
        },
        draw: function() {
            self.fsm.draw();
        },
        draw_end: function() {
            self.bark_emitter.on_draw();
        },
        destroy: function() {
            self.fsm.destroy();
        },
        cleanup: function() {
            self.fsm.cleanup();
            self.pathfinding_agent.clear_all_reservations();
            self.me.brain.blackboard.set("manual_override", false);
            self.me.brain.blackboard.set("instance", undefined);
            self.animator.stop_sound();
            SHADOW_GRID.caster_remove(self.shadow_caster);
        },
    }
);


object_create("obj_linnet", object_reserve("obj_cameo"), {});
object_create("obj_wiscar", object_reserve("obj_cameo"), {});
object_create("obj_darren", object_reserve("obj_cameo"), {});
object_create("obj_wynne", object_reserve("obj_cameo"), {});
