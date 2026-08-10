object_create(
    "obj_morsel",
    undefined,
    {
        sprite_index: spr_item_essence_big,
        create: function() {
            z = 0;
            v = 0;
            start_v = 16;
            v_counter = 0;
            lerp_amnt = 0.12;
            chase_counter = 0;

            wait_time = 45;
            sound_started = false;
            chase_player_counter = 0;

            image_xscale = 1;
            image_yscale = image_xscale;
            light = undefined;
            initial_x = x;
            initial_y = y;

            self.sprite_index = morsel_type_and_size_to_sprite(self.type, self.size);
            self.state = MorselState.Init;

            var snd;
            switch self.type {
                case MorselType.Essence:
                    snd = "SoundEffects/Inventory/EssenceDrop";
                    break;

                case MorselType.Stamina:
                    snd = "SoundEffects/Inventory/StaminaBulbSpawn";
                    break;

                case MorselType.Health:
                    snd = "SoundEffects/Inventory/StaminaBulbAbsorb";
                    break;
            }

            function give_resource() {
                switch self.type {
                    case MorselType.Essence:
                        if self.play_sound {
                            TANGO.play("SoundEffects/Inventory/EssenceAbsorb");
                        }
                        ARI.modify_essence(self.amount);
                        break;

                    case MorselType.Stamina:
                        if self.play_sound {
                            TANGO.play("SoundEffects/Inventory/StaminaBulbAbsorb");
                        }
                        if ARI.get_stamina() < ARI.get_max_stamina() {
                            ARI.modify_stamina(self.amount);
                        }
                        break;

                    case MorselType.Health:
                        //
                        if self.play_sound {
                            TANGO.play("SoundEffects/Inventory/StaminaBulbAbsorb");
                        }
                        ARI.modify_health(self.amount);
                        break;
                }
            }

            if self.play_sound {
                TANGO.play(snd);
            }
        },
        step: function() {
            depth = get_instance_depth(y, z);

            switch self.state {
                case MorselState.Init:
                    x = self.initial_x + sin(v_counter * pi / 60) * self.move_x;
                    y = self.initial_y + sin(v_counter * pi / 30) * self.move_y;

                    if v_counter >= 30 {
                        self.state = MorselState.Settle;
                        v_counter = 0;
                    }
                    v_counter += 1;
                    break;
                case MorselState.Settle:
                    if instance_exists(obj_ari) {
                        y = self.initial_y + sin(v_counter * pi / 60) * 2;
                        if v_counter >= 6 && point_distance(x, y, obj_ari.x, obj_ari.y) < 128 {
                            self.state = MorselState.Chase;
                        };
                        v_counter += 1;
                    }
                    break;

                case MorselState.Chase:
                    if instance_exists(obj_ari) {
                        var _dir = point_direction(x, y, obj_ari.x, obj_ari.y);
                        x += lengthdir_x(4.0, _dir);
                        y += lengthdir_y(4.0, _dir);

                        if point_distance(x, y, obj_ari.x, obj_ari.y) <= 4.0 {
                            give_resource(type, amount);
                            instance_destroy();
                        }
                    }
                    break;
                default: impossible("unexpected state: {}", self.state);
            }
        },
        draw: function() {
            draw_sprite_ext(
                sprite_index,
                image_index,
                x,
                y,
                image_xscale,
                image_yscale,
                image_angle,
                image_blend,
                image_alpha
            );

            if self.light != undefined && instance_exists(self.light)  {
                self.light.x = x;
                self.light.y = y;
            }
        },
        destroy: function() {
            if light != undefined && instance_exists(light) {
                instance_destroy(light);
            }
        },
    }
);
