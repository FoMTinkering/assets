#macro ESSENCE_MORSEL_SMALL 10
#macro ESSENCE_MORSEL_MEDIUM 30
#macro ESSENCE_MORSEL_LARGE 50
#macro MORSEL_SMALL 1
#macro MORSEL_MEDIUM 3
#macro MORSEL_LARGE 5

enum MorselSize {
    Small,
    Medium,
    Large,
    LEN
}
enum MorselType {
    Essence,
    Stamina,
    Health,
    LEN
}

function create_essence_morsels(pos_x, pos_y, dist, amount, depth_level=0) {
    if !requirements_pass(Requirement.CollectEssence) {
        return;
    }
    //
    repeat amount div (ESSENCE_MORSEL_LARGE + 2 * ESSENCE_MORSEL_MEDIUM + 4 * ESSENCE_MORSEL_SMALL) {
        var morsel = create_morsel(pos_x, pos_y, dist, MorselType.Essence, MorselSize.Large, MORSEL_LARGE, depth_level);
        morsel.light = instance_create_depth(morsel.x, morsel.y, morsel.depth, obj_light_tiny);
        amount -= ESSENCE_MORSEL_LARGE;
    }

    //
    repeat amount div (ESSENCE_MORSEL_MEDIUM + 2 * ESSENCE_MORSEL_SMALL) {
        var morsel = create_morsel(pos_x, pos_y, dist, MorselType.Essence, MorselSize.Medium, MORSEL_MEDIUM, depth_level);
        morsel.light = instance_create_depth(morsel.x, morsel.y, morsel.depth, obj_light_tiny);
        amount -= ESSENCE_MORSEL_MEDIUM;
    }

    repeat amount div ESSENCE_MORSEL_SMALL {
        var morsel = create_morsel(pos_x, pos_y, dist, MorselType.Essence, MorselSize.Small, MORSEL_SMALL, depth_level);
        morsel.light = instance_create_depth(morsel.x, morsel.y, morsel.depth, obj_light_tiny);
        amount -= ESSENCE_MORSEL_SMALL;
    }

    return amount;
}

function create_morsel(pos_x, pos_y, dist, morsel_type, morsel_size, amount, depth_level=0, play_sound=true) {
    var _dir = random_range(67.5, 112.5);
    var _len = random_range(4, dist);
    var move_x = lengthdir_x(_len, _dir);
    var move_y = lengthdir_y(_len, _dir);

    if play_sound {
        TANGO.play("SoundEffects/Inventory/EssenceDrop", pos_x, pos_y);
    }

    return instance_create_depth(pos_x, pos_y, depth_level, obj_morsel, {
        move_x: move_x,
        move_y: move_y,
        size: morsel_size,
        type: morsel_type,
        amount: amount,
        play_sound,
    });
}

function create_morsels(pos_x, pos_y, dist, morsel_type, amount, depth_level=0) {
    switch morsel_type {
        case MorselType.Essence:
            //
            if !requirements_pass(Requirement.CollectEssence) {
                return;
            }
            create_essence_morsels(pos_x, pos_y, dist, amount, depth_level);
            break;

        case MorselType.Health:
        case MorselType.Stamina:
            var morsel_amount;
            var morsel_size;

            while amount > 0 {
                if amount >= MORSEL_LARGE {
                    morsel_amount = MORSEL_LARGE;
                    morsel_size = MorselSize.Large;
                } else if amount >= MORSEL_MEDIUM {
                    morsel_amount = MORSEL_MEDIUM;
                    morsel_size = MorselSize.Medium;
                } else if amount >= MORSEL_SMALL {
                    morsel_amount = MORSEL_SMALL;
                    morsel_size = MorselSize.Small;
                } else {
                    morsel_amount = amount;
                    morsel_size = MorselSize.Small;
                }
                amount -= morsel_amount;

                create_morsel(pos_x, pos_y, dist, morsel_type, morsel_size, morsel_amount, depth_level);
            }
            break;
        default: impossible("unexpected morsel type: {}", morsel_type);
    }
}

//
function morsel_type_and_size_to_sprite(type, size) {
    static DATA = [
        [spr_item_essence_small, spr_item_essence_medium, spr_item_essence_big],
        [spr_item_stamina_small, spr_item_stamina_medium, spr_item_stamina_big],
        [spr_item_health_small, spr_item_health_medium, spr_item_health_big],
    ];

    return DATA[type][size];
}

function morsel_type_to_color(type) {
    static DATA = [
        hex($9044e1),
        hex($5cc97b),
        hex($e1446b),
    ];

    return DATA[type];
}
