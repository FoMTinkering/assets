//
function create_rock_prototype(object_id, rock_fiddle) {
    var spring_sprite = array_map(rock_fiddle.spring_sprites ?? [], string_to_asset);
    var variants = [
        spring_sprite,
        spring_sprite,
        spring_sprite,
        spring_sprite,
    ];

    if rock_fiddle[$ "summer_sprites"] != undefined {
        variants[Season.Summer] = array_map(rock_fiddle.summer_sprites, string_to_asset);
    }

    if rock_fiddle[$ "fall_sprites"] != undefined {
        variants[Season.Fall] = array_map(rock_fiddle.fall_sprites, string_to_asset);
    }

    if rock_fiddle[$ "winter_sprites"] != undefined {
        variants[Season.Winter] = array_map(rock_fiddle.winter_sprites, string_to_asset);
    }

    return {
        sprite_variants: variants,
        object_id: object_id,
        max_hitpoints: rock_fiddle[$ "hp"],
        mining_xp_gain: rock_fiddle.mining_xp_gain,
        size: fiddle_deserialize_vec2(rock_fiddle[$ "size"]),
        drop_bundle: create_fiddle_drops(rock_fiddle[$ "drops"] ?? []),
        collideable: rock_fiddle.collideable,
        jumpable: rock_fiddle.jumpable,
        ladder_candidate: rock_fiddle.ladder_candidate,
        minimum_quality: string_to_quality_id(rock_fiddle.minimum_quality),
        offset: fiddle_deserialize_vec2(rock_fiddle.offset),
        light: opt_and_then(rock_fiddle[$ "light"], function(data) {
            return {
                name: string_to_light(data.name),
                offset: fiddle_deserialize_vec2(data.offset),
            }
        })
    }
}

//
function write_rock_to_location(grid, xx, yy, proto) {
    var node = attempt_to_write_object_node(grid, xx, yy, proto.size, proto, proto.collideable, false, TerrainKind.Ground, proto.jumpable);
    if (node == undefined) {
        return undefined;
    }

    //
    node.hitpoints = node.prototype.max_hitpoints;
    node.variant_idx = irandom_range(0, 99) / 100.0;
    node.ladder_candidate = node.prototype.ladder_candidate;

    return node;
}

function create_rock_renderer(node) {
    var sprite_array = node.prototype.sprite_variants[CALENDAR.season()];
    var spr = sprite_array[floor(array_length(sprite_array) * node.variant_idx)];

    node.renderer = create_node_renderer(
        (node.top_left_x * 8) + node.prototype.offset.x,
        node.top_left_y * 8 + node.prototype.offset.y,
        node,
        spr,
    );

    if node.prototype.light != undefined {
        var light = instance_create_depth(
            node.renderer.x + node.prototype.light.offset.x,
            node.renderer.y + node.prototype.light.offset.y,
            -10000,
            par_light
        );
        light.tiered_light = node.prototype.light.name;
        light.sprite_index = LIGHTS[light.tiered_light][0];
        light.secondary = true;

        node.renderer.targets_to_destroy = List(light);
    }

    //
    if node.prototype.collideable == false {
        node.renderer.depth = get_floor_depth();
        node.renderer.y += 8;
    }
}

function create_rock_debris(renderer) {
    static ROCK_DEBRIS = new ParticleRockBundle();

    var _sprite;
    if renderer.node.prototype.size.x == 2 && renderer.node.prototype.size.y == 2 {
        _sprite = (CALENDAR.season() == Season.Winter) ? spr_part_farm_rock_small_winter : spr_part_farm_rock_small_spring;
    } else {
        _sprite = (CALENDAR.season() == Season.Winter) ? spr_part_farm_rock_big_winter : spr_part_farm_rock_big_spring;
    }

    var _rep = ROCK_DEBRIS.get_instances();

    repeat (_rep) {
        create_debris(
            renderer.x,
            renderer.y,
            renderer.depth - 1,
            _sprite,
            ROCK_DEBRIS,
        )
    }
}
