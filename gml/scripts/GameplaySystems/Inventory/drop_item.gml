//
function drop_item(value, xx, yy, z_offset=0) {
    var array = drop_item_input_cleanup(value);
    if array == undefined {
        return;
    }

    for (var i = 0; i < array_length(array); i++) {
        var item = array[i];
        item = is_struct(item) ? item : new LiveItem(item);
        drop_item_default_setup(
            instance_create_layer(xx, yy, "Instances", obj_item),
            List(item),
            drop_item_random_dir_distance(),
            z_offset
        );
    }
    TANGO.play("SoundEffects/Inventory/ItemDrop", xx, yy);
}

function drop_item_input_cleanup(value) {
    var array;
    if is_numeric(value) {
        array = [new LiveItem(value)];
    } else if is_struct(value) {
        array = [value];
    } else {
        array = value;
    }

    //
    if !is_array(array) || array_length(array) == 0 {
        return undefined;
    } else {
        return array;
    }
}

function drop_item_stack(xx, yy, stack_list) {
    var inst = drop_item_default_setup(
        instance_create_layer(xx, yy, "Instances", obj_item),
        stack_list,
        drop_item_random_dir_distance(),
    );
    TANGO.play("SoundEffects/Inventory/ItemDrop", xx, yy);
    return inst;
}

function drop_item_default_setup(inst, items, random_offsets, z_offset=0) {
    inst.final_x = inst.x + random_offsets[0];
    inst.final_y = inst.y + random_offsets[1];

    if z_offset != 0 {
        inst.z += z_offset;
        inst.move_z = true;
    }
    inst.setup(items);

    return inst;
}

function drop_item_to_ground(xx, yy, z_offset) {
    var inst = instance_create_layer(xx, yy, "Instances", obj_item);
    inst.move_draw_z = true;
    inst.draw_z_offset = z_offset;
    inst.ignore_collision = true;

    return inst;
}

function drop_item_random_dir_distance(dir_min=0, dir_max=360) {
    var distance = random_range(15, 30);
    var dir = random_range(dir_min, dir_max);
    return [lengthdir_x(distance, dir), lengthdir_y(distance, dir)];
}
