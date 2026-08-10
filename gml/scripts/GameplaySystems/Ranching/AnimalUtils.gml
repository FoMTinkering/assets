#macro ANIMAL_NAME_MAX_WIDTH 80

#macro BREEDING_ANIMAL_CTX global.__breeding_animal_ctx
global.__breeding_animal_ctx = {
    animal_name: undefined,
    animal_pair: undefined,
    breeding_partner: undefined,
    treat_item: undefined,
}

#macro ANIMAL_TOYS_IN_ROOM global.__animal_toys_in_room
global.__animal_toys_in_room = List();

enum AnimalToyPosition {
    Left,
    Center,
    Right,
}

enum AnimalKind {
    Chicken,
    Cow,
    Duck,
    Horse,
    Rabbit,
    Sheep,
    Capybara,
    Alpaca,
    LEN
}

enum Sex {
    Female,
    Male,
    LEN,
}

enum FeedKind {
    Seed,
    Hay,
    LEN,
}

enum BreedingKind {
    Egg,
    NonEgg,
    LEN,
}

enum PettingKind {
    Pet,
    PickUp,
    LEN,
}

enum HomeBehavior {
    Stall,
    Roam,
    LEN,
}

enum AnimalSize {
    Small,
    Large,
    LEN,
}

enum AnimalState {
    Idle,
    Wander,
    Pathfinding,
    Animate,
    Eat,
    Held,
    UsingToy,
    MoveDirected,
    LEN,
}

enum CutsceneAnimalState {
    Idle,
    Animate,
    LEN
}

//
//
function roll_animal_breeding(kind, a, b) {
    //
    var animal_data = ANIMAL_PROTOTYPES[kind];
    var tier = undefined;

    //
    if a.tier() == b.tier() {
        tier = a.tier() + 1;
    } else {
        var lower_animal_tier = min(a.tier(), b.tier());
        tier = random(1) >= 0.5
            ? lower_animal_tier + 1
            : lower_animal_tier + 2;
    }

    //
    //
    if tier == 6 && !chance_percent(20) {
        tier = 5;
    }

    //
    var variant = undefined;
    while true {
        var keys = animal_data.variants.keys();
        var potential_variants = [];
        for (var i = 0; i < array_length(keys); i++) {
            var this_variant = animal_data.variants.get(keys[i]);
            if this_variant.tier == tier
                && this_variant.born_in[CALENDAR.season()]
                && this_variant.acquirable
            {
                array_push(potential_variants, keys[i]);
            }
        }

        if array_is_empty(potential_variants) {
            //
            tier -= 1;
            continue;
        }

        variant = potential_variants[irandom(array_length(potential_variants) - 1)];
        break;
    }

    //
    var sex = chance_percent(50) ? Sex.Female : Sex.Male;
    return {
        kind,
        variant,
        sex,
        name: random_animal_name(sex),
    };
}

//
//
function get_animal_icon_data(kind, variant, sex=Sex.Female, adult=true) {
    var animal = ANIMAL_PROTOTYPES[kind];
    variant = variant == undefined ? animal.core.default_icon_variant : variant;
    var insert = adult ? sex_to_string(sex) : "baby";
    var variant_data = animal.variants.get(variant)[$ insert];
    return {
        sprite: variant_data.ui_icon,
        lut: variant_data.lut,
        lut_index: variant_data.lut_index,
    };
}

function get_all_animals(include_daycare=false) {
    var animals = get_buildings()
        .fold(List(), function(animals, building) {
            if building.prototype.player_building_kind == PlayerBuildingKind.Stable {
                animals.copy_from(building.stable.animals());
            }
            return animals;
        });

    if include_daycare {
        animals.copy_from(DAYCARE)
    }

    return animals;
}

function find_animal(idx, include_daycare=false) {
    if idx == PET_ID {
        return PET;
    }

    return get_all_animals(include_daycare).find_value(function(a, idx) {
        return a.idx == idx;
    }, idx);
}

//
function spawn_animal(animal) {
    animal.instance = instance_create_layer(
        animal.location_position.pos.x,
        animal.location_position.pos.y,
        "Instances",
        obj_player_animal,
        {
            me: animal,
        }
    );
}

//
function despawn_animal(animal) {
    if animal.instance != undefined {
        instance_destroy(animal.instance);
    }
}

//
//
//
function find_nearest_animal_food(xx, yy, eating_offset) {
    static NEAREST = List();
    NEAREST.clear();

    var output = undefined;

    repeat 15 {
        var food_marker = instance_nearest(xx, yy, obj_animal_food_marker);
        if food_marker == undefined || food_marker.processed {
            break;
        }

        if food_marker.animal_claimed || node_is_animal_food(food_marker.paired_renderer.node) == false {
            food_marker.original_x = food_marker.x;
            food_marker.original_y = food_marker.y;
            food_marker.processed = true;

            //
            food_marker.x = infinity;
            food_marker.y = infinity;

            NEAREST.push(food_marker);
            continue;
        }

        var x_sign = choose(-1, 1);
        var cardinal = x_sign == 1 ? Cardinal.West : Cardinal.East;

        var target_x;
        var target_y;

        if cardinal == Cardinal.East {
            target_x = food_marker.x + 4 - eating_offset.x;
            target_y = food_marker.y + 4 + eating_offset.y;
        } else {
            target_x = food_marker.x + 4 + eating_offset.x;
            target_y = food_marker.y + 4 + eating_offset.y;
        }

        var path = PATHFINDING.calculate_local_path(
            xx,
            yy,
            target_x,
            target_y,
            true,
        );
        if path == undefined {
            food_marker.original_x = food_marker.x;
            food_marker.original_y = food_marker.y;
            food_marker.processed = true;
            food_marker.x = infinity;
            food_marker.y = infinity;

            NEAREST.push(food_marker);
        } else {
            food_marker.animal_claimed = true;

            output = {
                item: new ItineraryItem(
                    new LocationPosition(CURRENT_LOCATION_ID, Vec2(xx, yy)),
                    new LocationPosition(CURRENT_LOCATION_ID, Vec2(target_x, target_y)),
                    path.distance,
                    path.output_list,
                ),
                cardinal,
                node: food_marker.paired_renderer.node,
            };

            break;
        }
    }

    for (var i = 0, c = NEAREST.count(); i < c; i++) {
        var food_marker = NEAREST.get(i);
        food_marker.x = food_marker.original_x;
        food_marker.y = food_marker.original_y;
        food_marker.processed = false;
    }

    return output;
}

//
//
//
function find_nearest_place_to_chill(xx, yy) {
    global.big_out = undefined;

    var output_position = find_free_position_spiral(xx div 8, yy div 8, function(x_pos, y_pos, data) {
        var ni = GRID.try_node_index_for_cell(x_pos, y_pos);
        if ni == undefined
            || GRID.node_object_id[ni] != undefined
            || GRID.node_animal_claimed[? ni]
            || GRID.node_terrain_kind[ni] != TerrainKind.Ground
        {
            return false;
        }

        //
        if irandom(100) < 95 {
            return false;
        }

        var xx = x_pos * 8 + 4;
        var yy = y_pos * 8 + 4;

        var path = PATHFINDING.calculate_local_path(
            data[0],
            data[1],
            xx,
            yy,
            true,
        );
        if path != undefined {
            GRID.node_animal_claimed[? ni] = true;
            global.big_out = new ItineraryItem(
                new LocationPosition(CURRENT_LOCATION_ID, Vec2(data[0], data[1])),
                new LocationPosition(CURRENT_LOCATION_ID, Vec2(xx, yy)),
                path.distance,
                path.output_list,
            );

            return true;
        }

        return false;
    }, [xx, yy]);

    if output_position == undefined {
        return undefined;
    }

    return global.big_out;
}

//
function node_is_animal_food(node) {
    switch object_id_to_object_category(node.object_id) {
        case ObjectCategory.Grass:
            return node.object_id == ObjectId.GrassMedium || node.object_id == ObjectId.GrassLarge;
        case ObjectCategory.Crop:
            var item_prototype = ITEM_PROTOTYPES[NODE_PROTOTYPES[node.object_id].harvest];
            return can_interact(node) && (item_prototype.edible || item_prototype.tags.contains("animals_can_eat"));
        default:
            return false;
    }
}

//
function stable_food_from_inventory(inventory) {
    for (var k = 0; k < array_length(inventory); k++) {
        var item = inventory[k];
        if item != undefined {
            inventory[k] = undefined;
            return item;
        }
    }

    return undefined;
}

function add_rename_popups_to_chain(chain) {
    var buildings = get_buildings();
    for (var i = 0; i < buildings.count(); i++) {
        var building = buildings.get(i);
        if building.prototype.player_building_kind != PlayerBuildingKind.Stable {
            continue;
        }
        var fetuses = building.stable.incubating_fetuses;

        for (var k = 0; k < fetuses.count(); k++) {
            var fetus = fetuses.get(k);
            if (fetus.days + 1) >= ANIMAL_PROTOTYPES[fetus.animal.kind].breeding.incubation_days {
                chain.append(LinkId.Function, function(fetus, building) {
                    var dummy_animal = new BaseAnimal(fetus.animal.kind, fetus.animal.variant, fetus.animal.sex);
                    var popup = create_animal_naming_popup(dummy_animal);

                    popup.backplate.add_height(13);
                    popup.inner_backplate.add_y(13);

                    var building_name = ANCHOR.text(popup.backplate)
                        .set_align(Align.Center, Align.TopIn)
                        .set_xy(2, 7)
                        .set_lut(COMMON_LUT)
                        .set_text(building.name)

                    var icon = building_icon(building);
                    ANCHOR.sprite(building_name)
                        .set_align(Align.LeftOut, Align.Middle)
                        .set_xy(-3, -1)
                        .set_sprite(icon)

                    ANCHOR.sprite(popup.image_background)
                        .set_sprite(fetus.animal.sex == Sex.Female ? spr_ui_generic_female_icon : spr_ui_generic_male_icon)
                        .set_y(2)
                        .set_align(Align.Center, Align.BottomOut)

                    rainbow_text(popup.backplate, "misc_local/new_animal_born")
                        .set_align(Align.Center, Align.TopOut)
                        .set_y(-8)

                    var confirm_button = popup.create_button(
                        "misc_local/confirm",
                        function(fetus, popup) {
                            fetus.animal.name = popup.name_input.get_text();
                        },
                        [fetus, popup]
                    );
                    confirm_button.remove_glyph();

                    TANGO.play("SoundEffects/NPCs/DialogSparkle");
                    popup.include_background(false);

                    popup.spawn();
                }, [fetus, building])
                .append(LinkId.Await, function() {
                    return !ANCHOR.open_menus.any(function(e) {
                        return e.type == Menu.Popup;
                    })
                });
            }
        }
    }
}

function animal_is_unlocked(animal) {
    return requirements_pass(ANIMAL_PROTOTYPES[animal].core.requirements)
}

//
function animal_try_to_eat_from_stable(animal, stable) {
    //
    if stable == undefined {
        return;
    }

    var found_food = undefined;
    if stable.building.prototype.double_manger {
        found_food = stable_food_from_inventory(stable.left_inventory)
            ?? stable_food_from_inventory(stable.right_inventory);
    } else {
        found_food = stable_food_from_inventory(stable.inventory);
    }

    if found_food != undefined {
        animal.feed(found_food);

        array_push(GAME_STATS.animal_eats, {
            source: "stable",
            item: found_food.pretty_print(),
            day: total_days(),
        });

        return true;
    } else {
        return false;
    }
}

function item_heart_value_for_animal(item_prototype) {
    var bonus = 0;

    if item_prototype.stars != undefined {
        bonus = ANIMAL_HEART_POINTS.cooked_star_bonuses[item_prototype.stars - 1];
    } else if item_prototype.animal_feed != undefined {
        bonus = ANIMAL_HEART_POINTS.feed[item_prototype.animal_feed.tier];
    } else {
        for (i = 0; i < ObjectId.LEN; i++) {
            var obj_proto = NODE_PROTOTYPES[i];
            var is_crop = obj_proto.category_id == ObjectCategory.Crop
                && obj_proto.harvest == item_prototype.item_id;

            if is_crop {
                bonus = ANIMAL_HEART_POINTS.crop_tree;
                break;
            }

            var is_tree = obj_proto.category_id == ObjectCategory.Tree
                && obj_proto.fruit_data != undefined
                && obj_proto.fruit_data.harvest == item_prototype.item_id;

            if is_tree {
                bonus = ANIMAL_HEART_POINTS.crop_tree;
                break;
            }
        }
    }

    return ANIMAL_HEART_POINTS.base_value + bonus;
}

//
//
function animal_heart_level_to_points(level) {
    static TABLE = fiddle_get("ranching/misc/heart_point_table");
    if level == 0 {
        return 0;
    }

    return TABLE[level - 1];
}

//
//
function points_to_animal_heart_level(heart_points) {
    static TABLE = fiddle_get("ranching/misc/heart_point_table");
    for (var i = 0; i < array_length(TABLE); i++) {
        if heart_points < TABLE[i] {
            return i;
        }
    }
    return array_length(TABLE);
}

//
function points_at_max_animal_heart_level(heart_points) {
    return points_to_animal_heart_level(heart_points) == 10;
}

function spawn_animal_toys() {
    if CURRENT_LOCATION_ID != LocationId.Farm {
        ANIMAL_TOYS_IN_ROOM.clear();
        return;
    }

    for (var i = 0; i < ANIMAL_TOYS_IN_ROOM.count(); i++) {
        var toy = ANIMAL_TOYS_IN_ROOM.get(i);
        var possible_animals = List();

        with obj_player_animal {
            if toy.prototype.animal_toy.species[self.me.kind]
                && distance_to_object(toy.renderer) < 512
                && self.me.is_baby() == false
                && matches(self.fsm.current_state_id(), AnimalState.Wander, AnimalState.Idle, AnimalState.Animate)
                && self.fsm.next_state == undefined
                && self.me.has_eaten
            {
                possible_animals.push(self);
            }
        }

        //
        if instance_exists(obj_pet)
            && toy.prototype.animal_toy.species[AnimalKind.Chicken]
            && ARI.held_animal_id != PET_ID
        {
            possible_animals.push(obj_pet);
        }


        //
        if CLOCK.time < hours(20) {
            var left = possible_animals.remove_random();
            var right = possible_animals.remove_random();
            var big_guy = undefined;

            //
            if toy.prototype.animal_toy.attach_points.center != undefined  {
                if left != undefined && left.me.is_pet && toy.prototype.animal_toy.centered_pets[left.me.pet_kind()] {
                    big_guy = left;
                } else if right != undefined && right.me.is_pet && toy.prototype.animal_toy.centered_pets[right.me.pet_kind()] {
                    big_guy = right;
                }
            }

            if big_guy != undefined {
                big_guy.fsm.blackboard.insert("toy", toy);
                big_guy.fsm.blackboard.insert("animal_toy_position", AnimalToyPosition.Center);
                big_guy.fsm.change_state(big_guy.me.is_pet ? PetState.UsingToy : AnimalState.UsingToy);
                toy.animal_count = 1;
                toy.renderer.set_sprite(toy.prototype.animal_toy.active_animation);
            } else if left != undefined && right != undefined {
                left.fsm.blackboard.insert("toy", toy);
                left.fsm.blackboard.insert("animal_toy_position", AnimalToyPosition.Left);
                left.fsm.change_state(left.me.is_pet ? PetState.UsingToy : AnimalState.UsingToy);

                right.fsm.blackboard.insert("toy", toy);
                right.fsm.blackboard.insert("animal_toy_position", AnimalToyPosition.Right);
                right.fsm.change_state(left.me.is_pet ? PetState.UsingToy : AnimalState.UsingToy);

                //
                toy.animal_count = 2;
                toy.renderer.set_sprite(toy.prototype.animal_toy.active_animation);
            }

            if toy.animal_count >= 1 && toy.prototype.animal_toy.active_sfx != undefined {
                stop_animal_toy_sfx(toy);
                toy.active_toy_sfx = TANGO.play(toy.prototype.animal_toy.active_sfx, toy.renderer.x, toy.renderer.y);
            }
        }
    }

    ANIMAL_TOYS_IN_ROOM.clear();
}

//
function stop_animal_toy_sfx(node) {
    if node[$ "active_toy_sfx"] == undefined {
        return;
    }

    TANGO.request_stop(node.active_toy_sfx);
    node.active_toy_sfx = undefined;
}

function run_debug_animal_progression(day_count) {
    repeat day_count {
        get_all_animals().for_each(function(animal) {
            animal.feed(ItemId.UltimateHay);
            if animal.can_pet() {
                animal.pet();
            }
            animal.has_been_outside = true;
        });

        get_buildings().for_each(function(building) {
            if building.prototype.player_building_kind == PlayerBuildingKind.Stable {
                building.stable.on_new_day();
            }
        });
    }
}

function animal_set_up_draw(sprites) {
    if sprites.lut != undefined {
        shader_set_texture("u_LutTexture", sprites.lut_texture, 0, "u_LutTexelSize");
        gpu_set_extra(UberShaderKind.Animal, sprites.lut_uvs[0], sprites.lut_uvs[1], real(sprites.lut_index));
    } else {
        gpu_set_extra(UberShaderKind.Overlay);
    }
}

//
//
//
//
function item_prototype_to_beads(prototype) {
    if prototype.stars != undefined {
        return prototype.stars * 2;
    }

    if prototype.animal_feed != undefined {
        return prototype.animal_feed.tier + 1;
    }

    for (i = 0; i < array_length(NODE_PROTOTYPES); i++) {
        var proto = NODE_PROTOTYPES[i];
        if proto.category_id == ObjectCategory.Crop && proto.harvest == prototype.item_id {
            return proto.currency;
        }
        if proto.category_id == ObjectCategory.Tree
            && proto.fruit_data != undefined
            && proto.fruit_data.harvest == prototype.item_id
        {
            return proto.currency;
        }
    }

    return 1;
};

function animal_festival_score(tier, hearts) {
    return (15 + (tier * 5)) + max(hearts - 1, 0) * 5;
}

function animal_festival_selection_popup(size) {
    var ui = animal_selection_ui(size, 23);

    for (var i = 0; i < ui.entries.count(); i++) {
        var entry = ui.entries.get(i);
        var animal = entry.animal;

        entry.root.set_selected_getter(function(animal) {
            return animal.idx == ARI.quest_artifacts.get("festival_selected_small_animal")
                || animal.idx == ARI.quest_artifacts.get("festival_selected_large_animal");
        }, [animal]);

        ANCHOR.sprite(entry.root)
            .set_sprite(spr_ui_journal_animal_heart_level)
            .set_index(points_to_animal_heart_level(animal.heart_points))
            .set_align(Align.RightIn, Align.Middle)
            .set_x(-4)

        entry.root.set_tap_callback(function(animal, popup) {
            var confirmation = popup_creator(
                "misc_local/select_an_animal",
                ANCHOR.wrap_for_local(format(local_get("misc_local/select_animal_for_competition"), animal.name))
            );
            confirmation.create_button("misc_local/no");
            confirmation.create_button("misc_local/yes", function(animal, popup) {
                ARI.quest_artifacts.insert(
                    format("festival_selected_{AnimalSize}_animal", animal.prototype.core.size),
                    animal.idx,
                );
                T2R.write(format("{AnimalSize}_animal_festival_name", animal.prototype.core.size), animal.name);
                T2R.write(format("{AnimalSize}_animal_festival_type", animal.prototype.core.size), animal.prototype.core.name);
                popup.close();
            }, [animal, popup]);

            confirmation.canvas.set_layer_recursive(AnchorLayer.Debug);
            confirmation.spawn();
        }, [animal, ui.popup]);
    }
}

function new_animal_variant_popup() {
     var popup = popup_creator("misc_local/placeholder", "misc_local/placeholder");

    popup.backplate.set_size(202, 112);

 popup.header
        .set_xy(0, 0)
        .set_sprite(spr_ui_tooltip_header_box)
        .set_size(popup.backplate.get_width(), 36)

    popup.title
        .set_align(Align.Center, Align.Middle)
        .set_ghost_key(item.prototype.name_key)
        .set_text(item.get_display_name())


  popup.body
        .set_size(popup.backplate.get_width(), 42)
        .set_align(Align.Center, Align.BottomIn)
        .set_sprite(spr_ui_tooltip_new_item_description_box)

    popup.body_text
        .set_align(Align.Center, Align.TopIn)
        .set_y(7)
        .set_text_align(TextAlign.Center)
        .set_ghost_key(item.prototype.description_key)
        .set_text(item.get_display_description())


 ribbon_key = "misc_local/new_unlock";
        popup.body_text.set_key("misc_local/new_animal_cosmetic_available");

            var dummy_animal = new NonPlayerAnimal(
            item.animal_cosmetic.animal,
            ANIMAL_PROTOTYPES[item.animal_cosmetic.animal].core.default_icon_variant,
            Sex.Female,
        );
        dummy_animal.days_old = I32_MAX;
        dummy_animal.cosmetic = item.animal_cosmetic.cosmetic;

        var backplate = ANCHOR.nine_slice(popup.backplate)
            .set_align(Align.Center, Align.Middle)
            .set_size(68, 68)
            .set_y(-16)
            .set_sprite(spr_ui_journal_animal_preview_box)

        popup.backplate.add_height(backplate.get_height() - 20);

        render_animal_in_ui(dummy_animal, backplate);
}
