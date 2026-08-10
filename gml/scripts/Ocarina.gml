function activate_ocarina(node) {
    if ANCHOR.get_menu(Menu.Eod) != undefined {
        return;
    }
    var buildings = get_buildings();
    var building;
    for (var i = 0, ic = buildings.count(); i < ic; i++) {
        building = buildings.get(i);
        if building.dyn_index == CURRENT_DYN_INDEX {
            if building.prototype.player_building_kind == PlayerBuildingKind.Stable
                && building.stable.animals().is_empty()
            {
                return;
            } else {
                break;
            }
        }
    }

    node.renderer.image_speed = 1;
    node.renderer.image_index = 1;
    node.activated_today = true;

    node.sound_idx = TANGO.play("SoundEffects/Objects/PettingOcarina");

    //
    for (var i = 0; i < building.stable.animals().count(); i++) {
        var animal = building.stable.animals().get(i);
        if animal.instance == undefined {
            animal.has_been_pat = true;
        }
    }

    //
    new_world_chain(node.renderer, CURRENT_LOCATION_ID)
        .append(LinkId.Timer, 60)
        .append(LinkId.Await, method({ timer: 60, node }, function() {
            self.timer += 2;

            with obj_player_animal {
                if distance_to_object(other.node.renderer) < other.timer
                    && self[$ "activated_by_ocarina"] == undefined
                {
                    self.activated_by_ocarina = true;
                    self.me.has_been_pat = true;

                    if ARI.held_animal_id != self.me.idx {
                        self.setup_celebration_animation(false, 2);
                    }

                    //
                    if SETTINGS.get("sound_animals") && self.me.can_pet() == false {
                        TANGO.play(self.me.sounds().positive_react, self.x, self.y);
                    }

                    //
                    self.bark_emitter.emit(BarkId.Heart, BarkType.Thought);
                }
            }

            if node.renderer.image_index == 0 {
                node.renderer.image_speed = 0;
                return true;
            } else {
                return false;
            }
        }));
}
