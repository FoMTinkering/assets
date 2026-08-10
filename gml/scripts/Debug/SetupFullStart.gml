#macro FULL_START_RESERVED_FARM_AREA Vec4(70, 42, 124, 116)

//
function full_start_farm_setup(grid) {
    var f = fiddle_get("full_start");

    //
    var y1 = f.area_top_left[1];
    var y2 = f.area_bottom_right[1];
    var x1 = f.area_top_left[0];
    var x2 = f.area_bottom_right[0];

    var object_ids = array_map(f.crops[$ season_to_string(CALENDAR.season())], string_to_object_id);

    //
    for(var yy = y1; yy < y2; yy++) {
        for(var xx = x1; xx < x2; xx++) {
            var ni = grid.node_index_for_cell(xx, yy);
            if grid.node_object_id[ni] != undefined {
                erase_object_node(grid, ni);
            }
            if grid.node_rug_id[ni] != undefined {
                erase_rug_node(grid, ni);
            }

            grid.write_ground(xx, yy, GroundKind.Soil);
        }
    }

    //
    var i = 0;
    var crop_stage = 0;
    for(var yy = y1; yy <= y2; yy += 2) {
        for(var xx = x1; xx < x2; xx += 2) {
            if i < array_length(object_ids) {
                var node = grid.write_node(xx, yy, object_ids[i]);
                assert_neq(node, undefined, "we couldn't make crop `{ObjectId}`", object_ids[i]);
                //
                var ni = grid.node_index_for_cell(xx, yy);

                water_chunk(grid, xx, yy);
                //
                while true {
                    if grid.node_parent[ni].stage >= crop_stage {
                        break;
                    }

                    if crop_node_new_day(grid, grid.node_parent[ni]) == false {
                        break;
                    }
                }

                crop_stage++;
                if crop_stage > 4 {
                    i++;
                    crop_stage = 0;
                }
            }
        }
    }

    //
    var i = 0;
    var tree_stage = 0;
    var fruit_trees = array_map(f.trees, string_to_object_id);

    for(var yy = f.tree_start; yy <= y2; yy+=8) {
        for(var xx = x1; xx < x2; xx+=8) {
            if (i < array_length(fruit_trees)) {
                var node = grid.write_node(xx, yy, fruit_trees[i]);
                assert_neq(node, undefined, "we couldn't make the fruit tree");
                while (true) {
                    if node.stage >= tree_stage {
                        break;
                    }
                    tree_node_new_day(grid,node);
                }
                if (node.stage == 4) {
                    repeat(10) {
                        tree_node_new_day(grid,node);
                    }
                }
                tree_stage++;
                if tree_stage > 4 {
                    i++;
                    tree_stage = 0;
                }
            }
        }
    }

    //
    static MAKE_ANIMAL = function(kind, sex, age, building) {
        var variants = ANIMAL_PROTOTYPES[kind].variants.keys();
        var cosmetics = ANIMAL_PROTOTYPES[kind].cosmetics.keys();
        var variant = undefined;
        while true {
            variant = variants[irandom(array_length(variants) - 1)];
            if ANIMAL_PROTOTYPES[kind].variants.get(variant).acquirable {
                break;
            }
        }
        var animal = new PlayerAnimal(kind, variant, sex);
        animal.days_old = age;
        animal.heart_points = animal_heart_level_to_points(10);
        if !array_is_empty(cosmetics) {
            animal.cosmetic = cosmetics[irandom(array_length(cosmetics) - 1)];
        }
        building.stable.register(animal);
    }

    var coop = GRIDS[LocationId.Farm].write_node(100, 52, ObjectId.LargeCoop, 0);
    assert_neq(coop, undefined, "we couldn't make a coop");
    MAKE_ANIMAL(AnimalKind.Duck, Sex.Male, 5, coop);
    MAKE_ANIMAL(AnimalKind.Duck, Sex.Female, 5, coop);
    MAKE_ANIMAL(AnimalKind.Duck, Sex.Male, 0, coop);
    MAKE_ANIMAL(AnimalKind.Capybara, Sex.Male, 5, coop);
    MAKE_ANIMAL(AnimalKind.Capybara, Sex.Female, 5, coop);
    MAKE_ANIMAL(AnimalKind.Capybara, Sex.Male, 0, coop);
    MAKE_ANIMAL(AnimalKind.Chicken, Sex.Male, 5, coop);
    MAKE_ANIMAL(AnimalKind.Chicken, Sex.Female, 5, coop);
    MAKE_ANIMAL(AnimalKind.Chicken, Sex.Male, 0, coop);
    MAKE_ANIMAL(AnimalKind.Rabbit, Sex.Male, 5, coop);
    MAKE_ANIMAL(AnimalKind.Rabbit, Sex.Female, 5, coop);
    MAKE_ANIMAL(AnimalKind.Rabbit, Sex.Male, 0, coop);

    var barn = GRIDS[LocationId.Farm].write_node(72, 52, ObjectId.LargeBarn, 0);
    assert_neq(barn, undefined, "we couldn't make a barn");
    MAKE_ANIMAL(AnimalKind.Cow, Sex.Male, 5, barn);
    MAKE_ANIMAL(AnimalKind.Cow, Sex.Female, 5, barn);
    MAKE_ANIMAL(AnimalKind.Cow, Sex.Male, 0, barn);
    MAKE_ANIMAL(AnimalKind.Horse, Sex.Male, 5, barn);
    MAKE_ANIMAL(AnimalKind.Horse, Sex.Female, 5, barn);
    MAKE_ANIMAL(AnimalKind.Horse, Sex.Male, 0, barn);
    MAKE_ANIMAL(AnimalKind.Alpaca, Sex.Male, 5, barn);
    MAKE_ANIMAL(AnimalKind.Alpaca, Sex.Female, 5, barn);
    MAKE_ANIMAL(AnimalKind.Alpaca, Sex.Male, 0, barn);
    MAKE_ANIMAL(AnimalKind.Sheep, Sex.Male, 5, barn);
    MAKE_ANIMAL(AnimalKind.Sheep, Sex.Female, 5, barn);
    MAKE_ANIMAL(AnimalKind.Sheep, Sex.Male, 0, barn);

    //
    GRIDS[LocationId.Farm].write_node(152, 26, ObjectId.SmallGreenhouse, 0);

    //
    GRIDS[LocationId.Farm].write_node(136, 31, ObjectId.MiniMuseum, 0);
}
