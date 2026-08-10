object_create(
    "obj_artifact_replicator",
    object_reserve("par_interactable"),
    {
        sprite_index: spr_museum_entryhall_artifact_replicator_main_idle,
        create: function() {
            event_inherit(ObjectEvent.Create);

            var requirement = array_create(Requirement.LEN, undefined);
            requirement[Requirement.CompletedMuseumSetWithin] = [MuseumWing.Archaeology];
            if !requirements_pass(requirement) {
                instance_destroy();
                return;
            }

            SHADOW_WAIT_LIST.push({
                x,
                y,
                sprite: SHADOW_DICTIONARY.get(self.sprite_index),
            });

            for (var i = 41; i <= 43; i++) {
                for (var j = 17; j <= 18; j++) {
                    set_collision_on_node(GRIDS[LocationId.MuseumEntry], i, j);
                }
            }

            function find_replica_artifact(item_id) {
                return try_string_to_item_id(format("artifact_replica_{ItemId}", item_id));
            }

            self.register_interaction(
                InputId.Interact,
                "misc_local/use",
                function() {
                    self.sprite_index = spr_museum_entryhall_artifact_replicator_main_bounce;
                    var item = ARI.inventory.slot(ARI.held_item_index).pop();
                    var replica = self.find_replica_artifact(item.item_id);
                    drop_item(replica, self.x, self.y);
                    TANGO.play("SoundEffects/Objects/ArtifactMaker");
                },
                function() {
                    return ARI.held_item() != undefined && find_replica_artifact(ARI.held_item().item_id) != undefined;
                }
            );

            self.register_interaction(
                InputId.SecondaryInteract,
                "misc_local/inspect",
                function() {
                    play_conversation_from_path(NpcId.Adeline, GAMEPLAY_CONVERSATIONS[GpTriggeredConversation.InspectArtifactReplicator]);
                }
            )


            depth = get_instance_depth(y);

            var fiddle_data = fiddle_get("interaction/artifact_replicator_offset");

            self.bounce_x_offset = fiddle_data[0];
            self.bounce_y_offset = fiddle_data[1];
        },
        draw_end: function() {
            self.bouncer.status = InteractBounceStatus.Distant;

            if game_paused() {
                return;
            }

            self.bouncer.alpha = BARK_MIN_ALPHA;

            var is_being_selected = self.bouncer.update();

            if is_being_selected {
                draw_sprite_ext(spr_ui_interact_bubble_big, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_archaeology, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            } else {
                draw_sprite_ext(spr_ui_interact_bubble_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
                draw_sprite_ext(spr_ui_bark_icon_archaeology_small, 0, x + self.bounce_x_offset, y + self.bounce_y_offset + 1 + self.bouncer.offset, 1, 1, 0, image_blend, self.bouncer.alpha);
            }
        },
        animation_end: function() {
            if self.sprite_index == spr_museum_entryhall_artifact_replicator_main_bounce {
                self.sprite_index = spr_museum_entryhall_artifact_replicator_main_idle;
            }
        },
    }
);
