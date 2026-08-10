function create_grass_prototype(object_id, fiddle_obj) {
    return {
        object_id: object_id,
        sprites: fiddle_deserialize_season(fiddle_obj.sprites, function(sprite_array) { return array_map(sprite_array, string_to_asset)}),
        outline_sprites: fiddle_deserialize_season(fiddle_obj.outline_sprites, function(sprite_array) { return array_map(sprite_array, string_to_asset)}),
        on_destruction_particles: fiddle_deserialize_season(fiddle_obj[$ "on_destruction_particles"], function(sprite_array) { return array_map(sprite_array, string_to_asset)}),
        drop_bundle: create_fiddle_drops(fiddle_obj[$ "drops"] ?? []),
        offset: fiddle_deserialize_vec2(fiddle_obj[$ "offset"]),
        day_to_stage: opt_and_then(fiddle_obj[$ "day_to_stage"], function(v) {
            return ListFromArray(array_map(v, string_to_object_id));
        }),
        stunt_chance: fiddle_obj.stunt_chance,
        size: fiddle_deserialize_vec2(fiddle_obj[$ "size"]),
        sound_on_collide: fiddle_obj[$ "sound_on_collide"],
    }
}

function write_grass_to_location(grid, xx, yy, grass_prototype) {
    //
    //
    if (xx > (grid.dims.x - 1)) || (yy > (grid.dims.y - 1)) {
        return undefined;
    }

    var ni = grid.node_index_for_cell(xx, yy);
    //
    if !(grid.node_terrain_kind[ni] == TerrainKind.Ground && grid.node_terrain_ground_kind[ni] == GroundKind.Grass) {
        return undefined;
    }

    var node = attempt_to_write_object_node(grid, xx, yy, grass_prototype.size, grass_prototype, false);
    if node == undefined {
        return undefined;
    }

    node.variant_idx = irandom_range(0, 99) / 100.0;
    node.stunt_growth = chance_percent(grass_prototype.stunt_chance);

    //
    var min_age = undefined;

    for (var i = 0, c = node.prototype.day_to_stage.count(); i < c; i++) {
        var this_stage = node.prototype.day_to_stage.get(i);
        if this_stage == grass_prototype.object_id {
            min_age = i;
        }
    }
    node.day_count = min_age;

    node.offset_x = irandom_range(-1, 1);
    node.offset_y = irandom_range(-1, 1);

    return node;
}

function create_grass_renderer(node) {
    var sprite_variants = node.prototype.sprites[CALENDAR.season()];
    var sprite = sprite_variants[floor(array_length(sprite_variants) * node.variant_idx)];

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x + node.offset_x,
        (node.top_left_y * 8) + node.prototype.offset.y + node.offset_y,
        node,
        sprite,
    );
    node.renderer.grass_back.sprite_index = node.prototype.outline_sprites[CALENDAR.season()][floor(array_length(sprite_variants) * node.variant_idx)];

    if CURRENT_LOCATION_ID == LocationId.Farm && node_is_animal_food(node) {
        node.renderer.linked_object = instance_create_layer(node.renderer.x, node.renderer.y, "Instances", obj_animal_food_marker, {
            paired_renderer: node.renderer
        });
    }
}

function create_grass_debris(renderer) {
    static LARGE = new ParticleGrassBundle()
        .set_instances_range(3, 3);
    static MEDIUM = new ParticleGrassBundle()
        .set_instances_range(2, 2);
    static SMALL = new ParticleGrassBundle()
        .set_instances_range(1, 1);

    var debris;
    switch renderer.node.object_id {
        case ObjectId.GrassSmall:
        case ObjectId.MarshGrassSmall:
            debris = SMALL;
            break;
        case ObjectId.GrassMedium:
        case ObjectId.MarshGrassMedium:
            debris = MEDIUM;
            break;
        case ObjectId.GrassLarge:
        case ObjectId.MarshGrassLarge:
            debris = LARGE;
            break;
    }

    var _rep = debris.get_instances();
    var sprite_variants = renderer.node.prototype.on_destruction_particles[CALENDAR.season()];
    var sprite = sprite_variants[floor(array_length(sprite_variants) * renderer.node.variant_idx)];

    repeat (_rep) {
        create_debris(
            renderer.x,
            renderer.y,
            renderer.depth - 1,
            sprite,
            debris,
        )
    }
}

//
function level_up_grass(node) {
    var next_id = undefined;
    var output = 1;
    if node.object_id == ObjectId.GrassSmall {
        output = 2;
        next_id = ObjectId.GrassMedium;
    } else {
        output = 1;
        next_id = ObjectId.GrassLarge;
    }
    var xx = node.top_left_x;
    var yy = node.top_left_y;
    var old_variant_idx = node.variant_idx;
    var old_stunt_growth = node.stunt_growth;
    var old_offset_x = node.offset_x;
    var old_offset_y = node.offset_y;

    erase_object_node_by_parent(GRID, node);
    node = GRID.write_node_without_initializing(xx, yy, next_id);

    node.variant_idx = old_variant_idx;
    node.stunt_growth = old_stunt_growth;
    node.offset_x = old_offset_x;
    node.offset_y = old_offset_y;
    GRID.initialize_node_renderer(node);

    //
    if chance_percent(25) {
        create_animation_effect(node.renderer.x, node.renderer.y, node.renderer.depth - 4, spr_part_sparkle_item_icon);
    }

    if next_id == ObjectId.GrassMedium {
        //
        new_chain()
            .append(LinkId.Timer, GROWTH_SPELL_DING_LENGTH)
            .append(LinkId.Function, level_up_grass, [node]);
    }

    //
    if instance_exists(node.renderer) {
        node.renderer.highlight_interactable = true;
        node.renderer.highlighter.request_highlight_mode = true;
        node.renderer.highlighter.override_strength = 0.45;
        node.renderer.highlighter.override_strength_decrease = 0.01;

        //
        sway_renderer(node.renderer, Cardinal.East);
    }

    return output;
}
