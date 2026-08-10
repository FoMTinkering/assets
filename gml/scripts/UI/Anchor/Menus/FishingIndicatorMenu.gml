enum FishingIndiciatorMenuDepths {
    Indicator,
    Dots,
}

function FishingIndicatorMenu() : AnchorMenu(Menu.FishingIndicator) constructor {
    function release() {
        self.in_release = true;
        var ni = GRID.try_node_index_for_cell(FISHING.fishing_grid_position.x, FISHING.fishing_grid_position.y);
        if ni != undefined && GRID.node_terrain_kind[ni] == TerrainKind.Water && GRID.node_collideable[ni] == false {
            self.indicator.set_sprite(spr_cast_cursor_tile_idle_select);
        } else {
            self.indicator.set_sprite(spr_cast_cursor_tile_blocked_select);
        }
        self.indicator.set_speed(1);
        self.indicator.set_index(0);
        new_chain()
            .join(LinkId.Ease, new Ease(EaseId.QuadOut, 1, 0, 15), function (delta) {
                self.canvas.add_alpha(delta);
            })
            .append(LinkId.Function, function() {
                self.close();
            });
    }

    assert(obj_ari.fsm.current_state_id() == PlayerState.Fishing, "Cannot spawn the FishingIndicatorMenu when not... fishing!");

    self.in_release = false;
    self.dot_count = ARI.held_item().prototype.range + 1;
    self.dot_iterator = 0;
    self.position_last = FISHING.fishing_grid_position_start.clone();
    //
    self.pips = [
        "SoundEffects/Tools/FishingValidPips/01",
        "SoundEffects/Tools/FishingValidPips/02",
        "SoundEffects/Tools/FishingValidPips/03",
        "SoundEffects/Tools/FishingValidPips/04",
        "SoundEffects/Tools/FishingValidPips/05",
        "SoundEffects/Tools/FishingValidPips/06",
        "SoundEffects/Tools/FishingValidPips/07",
        "SoundEffects/Tools/FishingValidPips/08",
        "SoundEffects/Tools/FishingValidPips/09",
        "SoundEffects/Tools/FishingValidPips/10",
        "SoundEffects/Tools/FishingValidPips/11",
        "SoundEffects/Tools/FishingValidPips/12",
        "SoundEffects/Tools/FishingValidPips/13",
        "SoundEffects/Tools/FishingValidPips/14",
        "SoundEffects/Tools/FishingValidPips/15",
        "SoundEffects/Tools/FishingValidPips/16",
        "SoundEffects/Tools/FishingValidPips/16",
    ];

    var start_pos = Vec2(
        (FISHING.fishing_grid_position_start.x * OBJECT_CELL_SIZE) - floor(CAMERA.left()),
        (FISHING.fishing_grid_position_start.y * OBJECT_CELL_SIZE) - floor(CAMERA.top()),
    );
    self.grid_dots = [];
    var dot_pos = start_pos.clone();
    dot_pos.x += floor(CAMERA.left());
    dot_pos.y += floor(CAMERA.top());
    var cardinal = obj_ari.cardinal;
    for (var i = 0; i < self.dot_count; i++) {
        self.grid_dots[i] = ANCHOR.sprite(self.canvas, FishingIndiciatorMenuDepths.Dots)
            .set_sprite(spr_cast_range_dot)
            .set_think_callback(function(xx, yy, i) {
                self.grid_dots[i].set_xy(
                    xx - floor(CAMERA.left()),
                    yy - floor(CAMERA.top()),
                );
            }, [dot_pos.x, dot_pos.y, i]);
        switch cardinal {
            case Cardinal.North:
                dot_pos.y -= OBJECT_CELL_SIZE;
                break;
            case Cardinal.East:
                dot_pos.x += OBJECT_CELL_SIZE;
                break;
            case Cardinal.South:
                dot_pos.y += OBJECT_CELL_SIZE;
                break;
            case Cardinal.West:
                dot_pos.x -= OBJECT_CELL_SIZE;
                break;
            default: impossible("Unrecognized cardinal: {}", cardinal);
        }
    }

    self.indicator = ANCHOR.sprite(self.canvas, FishingIndiciatorMenuDepths.Indicator)
        .set_xy(start_pos.x - OBJECT_CELL_SIZE, start_pos.y - OBJECT_CELL_SIZE)
        .set_sprite(spr_cast_cursor_tile_idle_tick)
        .set_speed(1)
        .set_animation_end_callback(function() {
            self.indicator.set_speed(0);
        })
        .set_think_callback(function() {
            //
            if !instance_exists(obj_ari) {
                //
                return;
            }

            if self.in_release {
                return;
            }

            var collision = false;
            var ni = GRID.try_node_index_for_cell(FISHING.fishing_grid_position.x, FISHING.fishing_grid_position.y);
            if ni != undefined && GRID.node_terrain_kind[ni] == TerrainKind.Water && GRID.node_collideable[ni] == false {
                self.indicator.set_sprite(spr_cast_cursor_tile_idle_tick);
                self.pip_snd = self.pips[self.dot_iterator];
            } else {
                self.indicator.set_sprite(spr_cast_cursor_tile_blocked_tick);
                self.pip_snd = "SoundEffects/Tools/FishingInvalidPip";
                collision = true;
            }

            //
            if FISHING.fishing_grid_position.x != self.position_last.x || FISHING.fishing_grid_position.y != self.position_last.y {
                self.position_last.x = FISHING.fishing_grid_position.x;
                self.position_last.y = FISHING.fishing_grid_position.y;
                self.dot_iterator += 1;
                var lut_length = sprite_get_width(spr_cast_cursor_tile_lut);
                var needed_lut_index = (lut_length div self.dot_count) * self.dot_iterator;
                self.indicator.set_speed(1);
                self.indicator.set_index(0);
                if collision == false {
                    self.indicator.set_lut_index(needed_lut_index);
                } else {
                    self.indicator.set_lut_index(0);
                }
                TANGO.play(self.pip_snd);
            }

            //
            self.indicator.set_xy(
                (FISHING.fishing_grid_position.x * OBJECT_CELL_SIZE) - floor(CAMERA.left()) - OBJECT_CELL_SIZE,
                (FISHING.fishing_grid_position.y * OBJECT_CELL_SIZE) - floor(CAMERA.top()) - OBJECT_CELL_SIZE,
            );

        })
        .set_lut(spr_cast_cursor_tile_lut);

}
