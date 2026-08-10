//
//
function create_renderer_at_depth(z, callback, args) {
    var inst = instance_create_depth(0, 0, z, obj_renderer);
    inst.draw_call = callback;
    inst.args = args ?? [];
    return inst;
}

function create_sprite_renderer(x, y, z_offset, spr) {
    var inst = instance_create_layer(x, y, "Instances", obj_sprite_renderer);
    inst.depth = get_instance_depth(inst.y, z_offset);
    inst.sprite_index = spr;

    return inst;
}
