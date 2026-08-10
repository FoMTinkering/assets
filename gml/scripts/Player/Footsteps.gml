enum FootstepKind {
    Grass,
    Wood,
    Stone,
    Carpet,
    Sand,
    Water,
    Snow,
    Dirt,
    DarkGrass,
    Void,
    Soil,
    Mud,
    LEN
}

enum MountCycle {
    None,
    Front,
    Back,
}

function try_play_footstep_at_position(xx, yy, cardinality, running, mount_cycle, owner) {
    static PARTICLE_BUNDLE = new ParticleBasicBundle()
        .set_lifetime_range(3.8, 3.9)
        .set_alpha_info(1, 0.75)
        .set_depth_on_floor();

    var footstep_kind = try_find_footstep_at_position(xx, yy, owner);
    if footstep_kind == undefined {
        return;
    }

    var ni = GRID.node_index_for_room_position(xx, yy);
    var overwrite_depth = undefined;
    if GRID.node_furniture_footstep[? ni] != undefined
        && object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Furniture
        && GRID.node_parent[ni].prototype.depth_to_floor
    {
        overwrite_depth = GRID.node_parent[ni].renderer.depth - 1;
    }

    var data = FOOTSTEPS[footstep_kind];
    var particle_sprite = undefined;

    if SETTINGS.get("sound_footsteps") {
        var tango_asset = undefined;
        switch mount_cycle {
            case MountCycle.None:
                if running {
                    tango_asset = data.run_sound;
                } else {
                    tango_asset = data.walk_sound;
                }
                break;
            case MountCycle.Front:
                if running {
                    tango_asset = data.mount_run_sound_front;
                } else {
                    tango_asset = data.mount_walk_sound;
                }
                break;
            case MountCycle.Back:
                if running {
                    tango_asset = data.mount_run_sound_back;
                } else {
                    tango_asset = data.mount_walk_sound;
                }
                break;
            default: impossible("unexpected `{}`, mount_cycle");
        }
        TANGO.play(tango_asset, xx, yy);
    }

    var particle_data;
    if CALENDAR.season() == Season.Winter && LOCATIONS[CURRENT_LOCATION_ID].ignore_seasons == false {
        particle_data = data.winter_particle_sprites;
    } else {
        particle_data = data.particle_sprites;
    }

    if particle_data != undefined {
        static OFFSET = 1;

        var particle_sprite;
        var y_off = 0;
        var x_off = 0;
        if cardinality == Cardinal.North || cardinality == Cardinal.South {
            particle_sprite = particle_data.vertical;
            x_off = OFFSET;
        } else {
            particle_sprite = particle_data.horizontal;
            y_off = OFFSET;
        }
        var inst = create_debris(xx + x_off, yy + y_off, 0, particle_sprite, PARTICLE_BUNDLE);

        if overwrite_depth != undefined {
            inst.depth = overwrite_depth;
        }

        OFFSET *= -1;
    }
}

//
function try_find_footstep_at_position(xx, yy, owner) {
    var override = MIST.blackboard.get("footstep_override");
    if override != undefined {
        return string_to_footstep_kind(override);
    }

    var ni = GRID.try_node_index_for_room_position(xx, yy);
    if ni == undefined {
        return undefined;
    }

    //
    with owner {
        if overlap_instance(xx, yy, obj_sticky_patch) != undefined
            || overlap_instance(xx, yy, obj_hot_patch) != undefined
        {
            return FootstepKind.Mud;
        }
    }

    var footstep_kind = GRID.node_footstep_kind[ni];
    var overwrite_depth = undefined;

    if GRID.node_furniture_footstep[ni] != undefined {
        var maybe_footstep_kind = GRID.node_furniture_footstep[ni];
        if is_array(maybe_footstep_kind) {
            footstep_kind = maybe_footstep_kind[CALENDAR.season() == Season.Winter];
        } else {
            footstep_kind = maybe_footstep_kind;
        }
        if object_id_to_object_category(GRID.node_object_id[ni]) == ObjectCategory.Furniture && GRID.node_parent[ni].prototype.depth_to_floor {
            overwrite_depth = GRID.node_parent[ni].renderer.depth - 1;
        }
    }

    if footstep_kind == 0 {
        if GRID.node_terrain_kind[ni] == undefined {
            return undefined;
        }

        switch GRID.node_terrain_kind[ni] {
            case TerrainKind.Ground:
                switch GRID.node_terrain_ground_kind[ni] {
                    case GroundKind.Grass:
                    case GroundKind.RiverBank:
                        footstep_kind = FootstepKind.Grass;
                        break;
                    case GroundKind.Dirt:
                        footstep_kind = overlap_point_any(xx, yy, obj_lavaplatform) ? FootstepKind.Stone : FootstepKind.Dirt;
                        break;
                    case GroundKind.Soil:
                        footstep_kind = GRID.node_terrain_is_watered[ni] ? FootstepKind.Mud : FootstepKind.Dirt;
                        break;
                    default: impossible("unexpected ground_kind: {}", GRID.node_terrain_ground_kind[ni]);
                }
                break;

            case TerrainKind.Lava:
                footstep_kind = FootstepKind.Stone;
                break;
            case TerrainKind.Water:
                //
                footstep_kind = FootstepKind.Water;
                break;
            default: impossible("unexpected terrain_kind: {}", GRID.node_terrain_kind[ni]);
        }
    }

    if
        CALENDAR.season() == Season.Winter
        && (footstep_kind == FootstepKind.DarkGrass || footstep_kind == FootstepKind.Grass)
    {
        footstep_kind = FootstepKind.Snow;
    }

    return footstep_kind;
}
