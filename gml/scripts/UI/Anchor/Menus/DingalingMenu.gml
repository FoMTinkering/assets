enum DingalingType {
    Skill,
    Heart,
    LEN
}

function DingalingMenu() : AnchorMenu(Menu.Dingaling) constructor {
    self.wait_list = List();
    self.playing_animation = false;
    self.icon_x_offset = 0;
    self.icon_y_offset = 0;
    self.number_x_offset = 0;
    self.number_y_offset = 0;
    self.life_chain = undefined;

    //
    function create_next_dingaling() {
        var _info = self.wait_list.get(0);
        self.__create_dingaling(_info);
        self.wait_list.remove(0);
        self.level_up_displaying = true;
    }

    self.canvas .set_think_callback(function() {
        if (!self.playing_animation && self.wait_list.count() > 0) {
            self.create_next_dingaling();
        }
    });

    function on_free() {
        if self.life_chain != undefined {
            CHAINS.cancel_chain(self.life_chain);
        }
    }

    function __create_dingaling(data) {
        self.icon_x_offset = 0;
        self.icon_y_offset = 0;
        self.number_x_offset = 0;
        self.number_y_offset = 0;
        self.playing_animation = true;
        if !instance_exists(obj_ari) {
            warn("Rejected a dingaling request because Ari is not here!");
            return;
        }
        var icon_spr;
        switch data.type {
            case DingalingType.Skill:
                icon_spr = string_to_asset(fiddle_get(format("skills/{Skill}/sprite", data.skill_id)));
                break;
            case DingalingType.Heart:
                icon_spr = get_small_npc_icon(data.npc_id);
                break;
            default: impossible("Unexpected DingalingType: {}", data.type);
        }

        var get_level = function(data) {
            switch data.type {
                    case DingalingType.Skill:
                        return ARI.level(data.skill_id);
                        break;
                    case DingalingType.Heart: return NPCS[data.npc_id].heart_level();
                        break;
                    default: impossible("Unexpected DingalingType: {}", data.type);
                }
        }

        var number_node = ANCHOR.text(self.canvas);
        number_node
            .set_sprite_font("skill_font")
            .set_alpha(0)
            .set_align(Align.Center, Align.Middle)
            .board_set("dinged", false)
            .disable()
            .set_think_callback(function(number_node, data, get_level) {
                if !instance_exists(obj_ari) {
                    return;
                }
                var level = get_level(data);
                number_node.set_text(number_node.board_get("dinged") ? level : data.starting_level);
                number_node.set_x(floor(self.number_x_offset + obj_ari.x - CAMERA.cam_pos.x - CAMERA.view_width / 2));
                number_node.set_y(floor(self.number_y_offset + obj_ari.y - CAMERA.cam_pos.y - CAMERA.view_height / 2 - 40));
            }, [number_node, data, get_level])

        var icon_node = ANCHOR.sprite(self.canvas);
        icon_node
            .set_sprite(icon_spr)
            .set_index(data.type == DingalingType.Skill ? data.skill_id : 0)
            .set_alpha(0)
            .set_align(Align.Center, Align.Middle)
            .set_think_callback(function(icon_node) {
                if !instance_exists(obj_ari) {
                    return;
                }
                icon_node.set_x(floor(self.icon_x_offset + obj_ari.x - CAMERA.cam_pos.x - CAMERA.view_width / 2));
                icon_node.set_y(floor(self.icon_y_offset + obj_ari.y - CAMERA.cam_pos.y - CAMERA.view_height / 2 - 40));
            }, [icon_node])

        if data.type == DingalingType.Heart {
            ANCHOR.sprite(icon_node)
                .set_align(Align.LeftOut, Align.Middle)
                .set_sprite(spr_dingaling_heart)
        }

        var x_gap = string_length(string(get_level(data))) == 1 ? 6 : 9;
        self.life_chain = new_chain(icon_node)
            .join(LinkId.Ease, new Ease(EaseId.QuartOut, 0, 1, 10), function(delta, _, icon_node) {
                icon_node.add_alpha(delta);
            }, [icon_node])
            .append(LinkId.Timer, 5)
            .append(LinkId.Function, function(number_node) {
                number_node.enable();
            }, [number_node])
            .join(
                LinkId.Ease,
                new Ease(EaseId.Linear, 0, -x_gap, 10),
                function (d) {
                    self.icon_x_offset += d;
                }
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.Linear, 0, x_gap, 10),
                function (d) {
                    self.number_x_offset += d;
                }
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 0, 1, 10),
                function (delta, _, number_node) {
                    number_node.add_alpha(delta);
                },
                [number_node]
            )
            .append(LinkId.Timer, 30)

            //
            .append(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 0, -3, 5),
                function (_, ab) {
                    self.number_y_offset = ab;
                },
            )
            .append(LinkId.Function, function(number_node) {
                number_node.board_set("dinged", true);
            }, [number_node])
            .append(LinkId.Timer, 1)
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, -3, 0, 5),
                function (_, ab) {
                    self.number_y_offset = ab;
                },
            )
            .append(LinkId.Timer, 30)
            .append(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 0, -10, 10),
                function (_, ab) {
                    self.icon_y_offset = ab;
                    self.number_y_offset = ab;
                },
            )
            .join(
                LinkId.Ease,
                new Ease(EaseId.QuartOut, 1, 0, 10),
                function (delta, _, number_node, icon_node) {
                    icon_node.add_alpha(delta);
                    number_node.add_alpha(delta);
                },
                [number_node, icon_node]
            )
            .append(LinkId.Function, function(number_node, icon_node) {
                ANCHOR.free_node(number_node);
                ANCHOR.free_node(icon_node);
                self.playing_animation = false;
                self.life_chain = undefined;
            }, [number_node, icon_node])
    }

    function create_skill_dingaling(skill_id, starting_level) {
        for (var i = 0; i < self.wait_list.count(); i++) {
            if self.wait_list.get(i)[$ "skill_id"] == skill_id {
                return;
            }
        }
        self.wait_list.push({
            type: DingalingType.Skill,
            skill_id: skill_id,
            starting_level: starting_level,
        });
    }

    function create_heart_dingaling(npc_id, starting_level) {
        var index = self.wait_list.find(function(e, v) {
            return e[$ "npc_id"] == v;
        }, npc_id);
        if index != undefined {
            return;
        }
        self.wait_list.push({
            type: DingalingType.Heart,
            npc_id: npc_id,
            starting_level: starting_level,
        });
    }
}
