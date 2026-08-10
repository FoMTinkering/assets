function Stable(building) constructor {
    self.building = building;
    self.stalls = ListFromArray(array_create(building.prototype.max_occupants, undefined));
    self.incubating_fetuses = List();

    if building.prototype.double_manger {
        self.left_inventory = array_create(building.prototype.manger_size, undefined);
        self.right_inventory = array_create(building.prototype.manger_size, undefined);
    } else {
        self.inventory = array_create(building.prototype.manger_size, undefined);
    }

    //
    function get(idx) {
        var animal = self.stalls.find_value(function(animal, idx) {
            return animal.idx == idx;
        }, idx);
        assert_neq(animal, undefined, "Animal {} does not exist!", idx);
        return animal;
    }

    //
    function animals() {
        return self.stalls
            .clone()
            .retain(function(v) {
                return v != undefined;
            })
    }

    //
    function register(animal, move_to_stall=true) {
        var index = self.stalls.find(function(v) {
            return v == undefined;
        });
        assert_neq(index, undefined, "Tried to add an animal to a full stall!");

        self.stalls.set(index, animal);

        animal.stable = self;

        //
        if animal.ate_breeding_treat {
            var partner_animal = self.stalls.find_value(function(v, other_animal) {
                return v != undefined
                    && v.ate_breeding_treat
                    && v.kind == other_animal.kind
                    && v.sex != other_animal.sex
                    && v.breeding_with == undefined;
            }, animal);

            if partner_animal != undefined {
                animal.breeding_with = partner_animal.idx;
                partner_animal.breeding_with = animal.idx;
            }
        }

        if move_to_stall || animal.location_position == undefined {
            animal.send_to_stall_point();
            if animal.instance != undefined {
                instance_destroy(animal.instance);
            }
        }

        refresh_achievements([Requirement.HasAnimalOfRank, Requirement.HasAnyAnimal]);
    }

    //
    function deregister(animal) {
        var index = self.stalls.find_lazy(animal);
        //
        if animal.breeding_with != undefined {
            trace("de-pairing them from `{}`", animal.breeding_with);

            var other_animal = find_animal(animal.breeding_with, false);
            assert(!other_animal.is_pet);

            other_animal.breeding_with = undefined;
            animal.breeding_with = undefined;
        }

        //
        if animal.ate_breeding_treat {
            animal.ate_breeding_treat = false;

            if CURRENT_DYN_INDEX == animal.location_position.dyn_index {
                drop_item(animal.prototype.breeding.treat, animal.location_position.pos.x, animal.location_position.pos.y);
            } else {
                DYNAMIC_GRIDS.get(animal.location_position.dyn_index)
                    .lost_items
                    .push({
                        x: animal.location_position.pos.x,
                        y: animal.location_position.pos.y,
                        items: List(new LiveItem(animal.prototype.breeding.treat)),
                    });
            }
        }

        self.stalls.set(index, undefined);
        animal.stable = undefined;
    }

    //
    function occupancy() {
        return self.building.prototype.max_occupants - self.availability();
    }

    //
    //
    //
    function availability() {
        var occupants = self.stalls.sum_with(function(v) {
            return v != undefined;
        });
        return self.building.prototype.max_occupants
            - occupants
            - self.gather_breeding_pairs().count()
            - self.incubating_fetuses.count();
    }

    //
    function incubator_availability() {
        return
            self.building.prototype.incubators
            - self.incubators_in_use()
            - self.gather_breeding_pairs().count();

    }

    //
    function incubators_in_use() {
        return self.incubating_fetuses.count();
    }

    //
    function on_room_start() {
        //
        var c = self.stalls.count();

        for (var i = 0; i < c; i++) {
            var animal = self.stalls.get(i);
            if animal != undefined && animal.is_present() && animal.instance == undefined {
                spawn_animal(animal);
            }
        }

        if self.building.dyn_index == CURRENT_DYN_INDEX {
            var inc_to_find = 0;
            for (var i = 0; i < self.incubating_fetuses.count(); i++) {
                var fetus = self.incubating_fetuses.get(i);
                var fetus_prototype = ANIMAL_PROTOTYPES[fetus.animal.kind];
                if fetus_prototype.breeding.uses_egg {
                    var inst = instance_find(obj_incubator, inc_to_find);
                    inst.sprite_index = spr_coop_incubator_egg_spring;
                    inst.parent_data = {
                        mother: fetus.female_parent,
                        father: fetus.male_parent,
                        almost_done: fetus.days >= (fetus_prototype.breeding.incubation_days - 1),
                    };
                    inc_to_find += 1;
                }
            }
        }

        if self.building.dyn_index != CURRENT_DYN_INDEX {
            return;
        }

        with obj_incubator {
            shadow_caster_set_sprite(SHADOW_GRID.caster_create(self.x, self.y), SHADOW_DICTIONARY.get(self.sprite_index));
        }

        //
        var me = self;

        //
        with par_manger {
            if me.building.prototype.double_manger {
                if self.left {
                    self.inventory = me.left_inventory;
                } else {
                    self.inventory = me.right_inventory;
                }
            } else {
                self.inventory = me.inventory;
            }

            self.animal_feed_size = me.building.prototype.permitted_animal_size;

            if array_length(self.inventory) > 4 {
                sprite_index = spr_barn_manger_large_spring;
            }

            shadow_caster_set_sprite(SHADOW_GRID.caster_create(self.x, self.y), SHADOW_DICTIONARY.get(self.sprite_index));
        }
    }

    //
    function gather_breeding_pairs() {
        var collection = List();

        for (var i = 0; i < self.stalls.count(); i++) {
            var animal = self.stalls.get(i);

            if animal != undefined
                && animal.sex == Sex.Female
                && animal.ate_breeding_treat
                && animal.breeding_with != undefined
            {
                collection.push([animal.breeding_with, animal.idx]);
            }
        }

        return collection;
    }

    //
    function on_new_day() {
        static HEART_POINTS = fiddle_get("ranching/misc/heart_points");

        var statistics = {
            fed: 0,
            not_fed: 0,
            pet: 0,
            not_pet: 0,
            inside: 0,
            outside: 0,
        };

        //
        var pairs = self.gather_breeding_pairs();
        for (var i = 0; i < pairs.count(); i++) {
            var pair = pairs.get(i);
            var male_idx = pair[0];
            var female_idx = pair[1];

            var male = self.stalls.find_value(function(v, idx) {
                return v != undefined && v.idx == idx;
            }, male_idx);

            var female = self.stalls.find_value(function(v, idx) {
                return v != undefined && v.idx == idx;
            }, female_idx);

            self.incubating_fetuses.push({
                male_parent: male_idx,
                female_parent: female_idx,
                days: -1,
                animal: roll_animal_breeding(female.kind, female, male),
            });

            //
            female.is_incubating = true;
            female.breeding_with = undefined;
            male.is_incubating = true;
            male.breeding_with = undefined;

            ARI.gain_xp(Skill.Ranching, ANIMAL_XP.breed, true);

            if chance_percent(ARI.perk_value(Perk.GeminiSeason))
                && self.availability() > 0
                && (female.prototype.breeding.uses_egg == false || self.incubator_availability() > 0)
            {
                self.incubating_fetuses.push({
                    male_parent: male_idx,
                    female_parent: female_idx,
                    days: -1,
                    animal: roll_animal_breeding(female.kind, female, male),
                });
                GAME_STATS.perks[$ perk_to_string(Perk.GeminiSeason)] += 1;
            }
        }

        var grid = DYNAMIC_GRIDS.get(self.building.dyn_index);
        var animal_found = false;

        for (var i = 0; i < self.stalls.count(); i++) {
            var animal = self.stalls.get(i);

            if animal == undefined {
                continue;
            }
            animal_found = true;

            animal.bark_on_sight = undefined;

            //
            var proto = animal.prototype;
            var production = animal.sex == Sex.Female
                ? proto.production.female
                : proto.production.male;

            //
            animal.days_old += 1;

            //
            if animal.has_been_pat == false {
                animal.add_heart_points(-HEART_POINTS.pet);
                statistics.not_pet += 1;
            } else {
                statistics.pet += 1;
            }

            //
            if !animal.has_eaten {
                animal.add_heart_points(-HEART_POINTS.feed);
                statistics.not_fed += 1;
            } else {
                statistics.fed += 1;
            }

            //
            var left_outside = !animal.is_home();
            if left_outside {
                animal.add_heart_points(HEART_POINTS.left_outside_penalty);
                animal.bark_on_sight = BarkId.Annoyed;
                statistics.outside += 1;
            } else {
                statistics.inside += 1;
            }

            //
            var is_happy = !left_outside && animal.has_eaten && animal.has_been_pat;

            //
            var perk_bonus = ARI.perk_value(Perk.CloseBond);
            if is_happy && perk_bonus != 0 {
                animal.add_heart_points(perk_bonus);
                GAME_STATS.perks[$ perk_to_string(Perk.CloseBond)] += 1;
            }

            perk_bonus = ARI.perk_value(Perk.CloseBondTwo);

            if is_happy && perk_bonus != 0 {
                animal.add_heart_points(perk_bonus);
                GAME_STATS.perks[$ perk_to_string(Perk.CloseBondTwo)] += 1;
            }

            if !animal.is_baby() && is_happy {
                //
                animal.production_days += 1;

                //
                if animal.production_days >= production.days_to_produce {
                    animal.production_days = 0;

                    //
                    //
                    static PRODUCTION = fiddle_get("ranching/misc/production_tiers");
                    var my_tier = undefined;
                    for (var j = 0; j < array_length(PRODUCTION); j++) {
                        var tier = PRODUCTION[j];
                        if points_to_animal_heart_level(animal.heart_points) >= tier.hearts_required {
                            my_tier = tier;
                        }
                    }

                    static HANDLE_DROPS = function(entry, product, bonus) {
                        var list = List();
                        repeat entry.count {
                            list.push(new LiveItem(product));
                        }
                        if random(1) <= (entry.additional_chance + bonus) {
                            list.push(new LiveItem(product));
                        }
                        return list;
                    }

                    var normal_bonus = ARI.perk_active(Perk.BarnyardBounty) && !points_at_max_animal_heart_level(animal.heart_points)
                        && (animal.kind == AnimalKind.Chicken || animal.kind == AnimalKind.Cow)
                        ? ARI.perk_value(Perk.BarnyardBounty)
                        : 0;

                    var normal_bonus_two = ARI.perk_active(Perk.BarnyardBountyTwo) && !points_at_max_animal_heart_level(animal.heart_points)
                        && (animal.kind == AnimalKind.Duck || animal.kind == AnimalKind.Horse)
                        ? ARI.perk_value(Perk.BarnyardBountyTwo)
                        : 0;

                    var normal_bonus_three = ARI.perk_active(Perk.BarnyardBountyThree) && !points_at_max_animal_heart_level(animal.heart_points)
                        && (animal.kind == AnimalKind.Sheep || animal.kind == AnimalKind.Rabbit)
                        ? ARI.perk_value(Perk.BarnyardBountyThree)
                        : 0;

                    var normal_products = HANDLE_DROPS(
                        my_tier.normal,
                        production.normal_product,
                        normal_bonus + normal_bonus_two + normal_bonus_three,
                    );

                    var golden_bonus = ARI.perk_active(Perk.BarnyardBounty) && points_at_max_animal_heart_level(animal.heart_points)
                        && (animal.kind == AnimalKind.Chicken || animal.kind == AnimalKind.Cow)
                        ? ARI.perk_value(Perk.BarnyardBounty)
                        : 0;

                    var golden_bonus_two = ARI.perk_active(Perk.BarnyardBountyTwo) && points_at_max_animal_heart_level(animal.heart_points)
                        && (animal.kind == AnimalKind.Duck || animal.kind == AnimalKind.Horse)
                        ? ARI.perk_value(Perk.BarnyardBountyTwo)
                        : 0;

                    var golden_bonus_three = ARI.perk_active(Perk.BarnyardBountyThree) && points_at_max_animal_heart_level(animal.heart_points)
                        && (animal.kind == AnimalKind.Sheep || animal.kind == AnimalKind.Rabbit)
                        ? ARI.perk_value(Perk.BarnyardBountyThree)
                        : 0;

                    if golden_bonus != 0 || normal_bonus != 0 {
                        GAME_STATS.perks[$ perk_to_string(Perk.BarnyardBounty)] += 1;
                    }

                    if golden_bonus_two != 0 || normal_bonus_two != 0 {
                        GAME_STATS.perks[$ perk_to_string(Perk.BarnyardBountyTwo)] += 1;
                    }

                    if normal_bonus_three != 0 || golden_bonus_three {
                        GAME_STATS.perks[$ perk_to_string(Perk.BarnyardBountyThree)] += 1;
                    }

                    var golden_products = HANDLE_DROPS(
                        my_tier.golden,
                        production.golden_product,
                        golden_bonus + golden_bonus_two + golden_bonus_three,
                    );

                    if animal.prototype.breeding.uses_egg
                        && golden_products.is_empty() == false
                        && chance_percent(ARI.perk_value(Perk.Eggstra))
                    {
                        normal_products.push(new LiveItem(production.normal_product));
                        GAME_STATS.perks[$ perk_to_string(Perk.Eggstra)] += 1;
                    }

                    //
                    var pos = trellis_point(self.building.prototype.stall_points.get(i));
                    if !normal_products.is_empty() {

                        array_push(GAME_STATS.animal_production, {
                            item: normal_products.first().pretty_print(),
                            count: normal_products.count(),
                            day: total_days(),
                        });

                        grid.lost_items.push({
                            x: pos.x + irandom(16),
                            y: pos.y + irandom(16),
                            items: normal_products,
                        });
                    }
                    if !golden_products.is_empty() {

                        array_push(GAME_STATS.animal_production, {
                            item: golden_products.first().pretty_print(),
                            count: golden_products.count(),
                            day: total_days(),
                        });

                        grid.lost_items.push({
                            x: pos.x + irandom(16),
                            y: pos.y + irandom(16),
                            items: golden_products,
                        });
                    }
                    if chance_percent(ARI.perk_value(Perk.CurrencyOfCareTwo)) {
                        grid.lost_items.push({
                            x: pos.x + irandom(16),
                            y: pos.y + irandom(16),
                            items: List(new LiveItem(ItemId.AnimalCurrency)),
                        });
                        GAME_STATS.perks[$ perk_to_string(Perk.CurrencyOfCareTwo)] += 1;

                        array_push(GAME_STATS.animal_bead_drops, {
                            amount: 1,
                            day: total_days(),
                        });
                    }

                    var made_item = try_gather_item_spawn(
                        GatherDropChance.AnimalProduction,
                        pos.x + irandom(16),
                        pos.y + irandom(16),
                        grid,
                    );

                    if made_item {
                        array_push(GAME_STATS.animal_production, {
                            item: "gather_item",
                            count: 1,
                            day: total_days(),
                        });
                    }
                }
            }

            //
            //
            if left_outside && animal.location_position.location_id != LocationId.Farm {
                animal.location_position = new LocationPosition(
                    LocationId.Farm,
                    Vec2(
                        building_send_animal_out_x(animal.stable.building),
                        building_send_animal_out_y(animal.stable.building),
                    )
                );
            }

            animal.has_eaten = false;
            animal.has_been_pat = grid.ocarina != undefined && grid.ocarina.essence_supply > 0;
            animal.has_been_outside = false;
            animal.ate_breeding_treat = false;
        }

        //
        if animal_found && grid.ocarina != undefined {
            grid.ocarina.essence_supply -= 1;
        }

        //
        if grid.auto_feeder != undefined {
            while true {
                var inventory_to_fill = undefined;
                if self.building.prototype.double_manger {
                    if array_has(self.left_inventory, undefined) {
                        inventory_to_fill = self.left_inventory;
                    } else if array_has(self.right_inventory, undefined) {
                        inventory_to_fill = self.right_inventory;
                    }
                } else if array_has(self.inventory, undefined) {
                    inventory_to_fill = self.inventory;
                }

                if inventory_to_fill == undefined {
                    break;
                }

                var slot = grid.auto_feeder.inventory.slots.find_value(function(slot) {
                    return slot.item != undefined;
                });

                if slot == undefined {
                    break;
                }

                var item = slot.pop().item_id;
                var tier = feeder_item_to_feed_tier(item);
                var output = undefined;
                switch tier {
                    case AnimalFeedTier.Normal:
                        output = self.building.prototype.permitted_animal_size == AnimalSize.Small
                            ? ItemId.GrassSeed
                            : ItemId.Hay;
                        break;
                    case AnimalFeedTier.Quality:
                        output = self.building.prototype.permitted_animal_size == AnimalSize.Small
                            ? ItemId.QualitySmallAnimalFeed
                            : ItemId.QualityHay;
                        break;
                    case AnimalFeedTier.Deluxe:
                        output = self.building.prototype.permitted_animal_size == AnimalSize.Small
                            ? ItemId.DeluxeSmallAnimalFeed
                            : ItemId.DeluxeHay;
                        break;
                    case AnimalFeedTier.Ultimate:
                        output = self.building.prototype.permitted_animal_size == AnimalSize.Small
                            ? ItemId.UltimateSmallAnimalFeed
                            : ItemId.UltimateHay;
                        break;
                    default: impossible("Unexpected AnimalFeedTier: {}", tier);
                }

                var index = array_index(inventory_to_fill, undefined);
                inventory_to_fill[index] = new LiveItem(output);
            }
        }

        for (var i = self.incubating_fetuses.count() -1; i >= 0; i--) {
            var fetus = self.incubating_fetuses.get(i);

            //
            fetus.days += 1;
            if fetus.days >= ANIMAL_PROTOTYPES[fetus.animal.kind].breeding.incubation_days && self.availability() <= self.building.prototype.max_occupants {
                var baby = new PlayerAnimal(fetus.animal.kind, fetus.animal.variant, fetus.animal.sex)
                baby.name = fetus.animal.name;
                initialize_new_animal_for_ari(baby);
                self.register(baby);

                //
                //
                //
                var all_animals = get_all_animals(true);
                var dad = all_animals.find_value(function(animal, idx) {
                    return animal.idx == idx;
                }, fetus.male_parent);
                var mom = all_animals.find_value(function(animal, idx) {
                    return animal.idx == idx;
                }, fetus.female_parent);

                //
                if dad != undefined {
                    dad.is_incubating = false;
                    dad.add_heart_points(HEART_POINTS.child_born);
                }
                if mom != undefined {
                    mom.is_incubating = false;
                    mom.add_heart_points(HEART_POINTS.child_born);
                }

                //
                array_push(GAME_STATS.animals, {
                    source: "breeding",
                    animal_kind: animal_kind_to_string(baby.kind),
                    sex: sex_to_string(baby.sex),
                    variant: baby.variant,
                    day: total_days(),
                    idx: baby.idx,
                    dad_variant: dad != undefined ? dad.variant : "unknown",
                    mom_variant: mom != undefined ? mom.variant : "unknown",
                });

                self.incubating_fetuses.remove(i);
            }
        }

        return statistics;
    }

    function serialize() {
        var animals = array_create(self.stalls.count(), undefined);
        for (var i = 0; i < self.stalls.count(); i++) {
            animals[i] = opt_and_then(self.stalls.get(i), function(v) {
                return v.serialize();
            });
        }
        var incubating_fetuses = array_create(self.incubating_fetuses.count(), undefined);
        for (var i = 0; i < self.incubating_fetuses.count(); i++) {
            var incubating_fetus = self.incubating_fetuses.get(i);
            incubating_fetuses[i] = {
                days: incubating_fetus.days,
                animal: {
                    kind: animal_kind_to_string(incubating_fetus.animal.kind),
                    variant: incubating_fetus.animal.variant,
                    sex: sex_to_string(incubating_fetus.animal.sex),
                    name: incubating_fetus.animal.name,
                },
                male_parent: incubating_fetus.male_parent,
                female_parent: incubating_fetus.female_parent,
            };
        }

        var o = {
            animals,
            incubating_fetuses,
        };

        if self.building.prototype.double_manger {
            o.left_inventory = array_map(self.left_inventory, function(value) {
                if value != undefined {
                    return value.serialize();
                } else {
                    return undefined;
                }
            });
            o.right_inventory = array_map(self.right_inventory, function(value) {
                if value != undefined {
                    return value.serialize();
                } else {
                    return undefined;
                }
            });
        } else {
            o.inventory = array_map(self.inventory, function(value) {
                if value != undefined {
                    return value.serialize();
                } else {
                    return undefined;
                }
            });
        }

        return o;
    }

    function deserialize(data) {
        for (var i = 0; i < array_length(data.animals); i++) {
            var animal_data = data.animals[i];
            if animal_data == undefined {
                continue;
            }
            var animal = new PlayerAnimal(
                string_to_animal_kind(animal_data.kind),
                animal_data.variant,
                string_to_sex(animal_data.sex),
                true
            );
            animal.deserialize(animal_data);

            self.register(
                animal,
                animal.location_position != undefined && animal.location_position.location_id == building.prototype.location_id
            );
        }

        //
        for (var i = 0; i < array_length(data.incubating_fetuses); i++) {
            var incubating_fetus = data.incubating_fetuses[i];

            self.incubating_fetuses.push({
                days: incubating_fetus.days,
                male_parent: incubating_fetus.male_parent,
                female_parent: incubating_fetus.female_parent,

                animal: {
                    kind: string_to_animal_kind(incubating_fetus.animal.kind),
                    variant: incubating_fetus.animal.variant,
                    sex: string_to_sex(incubating_fetus.animal.sex),
                    name: incubating_fetus.animal.name,
                },
            });
        }

        if self.building.prototype.double_manger {
            self.left_inventory = array_map(data.left_inventory, function(v) {
                if is_nullish(v) {
                    return undefined;
                }
                return deserialize_live_item(v);
            });
            self.right_inventory = array_map(data.right_inventory, function(v) {
                if is_nullish(v) {
                    return undefined;
                }
                return deserialize_live_item(v);
            });
        } else {
            self.inventory = array_map(data.inventory, function(v) {
                if is_nullish(v) {
                    return undefined;
                }
                return deserialize_live_item(v);
            });
        }
    }
}

function feeder_item_to_feed_tier(item) {
    var proto = ITEM_PROTOTYPES[item];

    if proto.animal_feed != undefined {
        return proto.animal_feed.tier;
    }

    if item_to_tree(item) != undefined {
        return AnimalFeedTier.Ultimate;
    }

    var crop = item_to_crop(item);
    if crop != undefined {
        var object = NODE_PROTOTYPES[crop];

        if object_id_to_object_category(crop) == ObjectCategory.Bush {
            return AnimalFeedTier.Normal;
        } else if item_to_seed(item) == undefined {
            return AnimalFeedTier.Quality;
        } else if object.post_harvest_day_to_stage != undefined {
            return AnimalFeedTier.Deluxe;
        } else if object.day_to_stage.count() >= 7 {
            return AnimalFeedTier.Ultimate;
        } else {
            return AnimalFeedTier.Quality;
        }
    }

    if proto.stars == 1 {
        return AnimalFeedTier.Quality;
    } else if proto.stars != undefined {
        return AnimalFeedTier.Ultimate;
    }

    return AnimalFeedTier.Normal;
}

//
function test_auto_feeder_items() {
    assert_eq(feeder_item_to_feed_tier(ItemId.Hay), AnimalFeedTier.Normal);
    assert_eq(feeder_item_to_feed_tier(ItemId.QualityHay), AnimalFeedTier.Quality);
    assert_eq(feeder_item_to_feed_tier(ItemId.DeluxeHay), AnimalFeedTier.Deluxe);
    assert_eq(feeder_item_to_feed_tier(ItemId.UltimateHay), AnimalFeedTier.Ultimate);
    assert_eq(feeder_item_to_feed_tier(ItemId.Fennel), AnimalFeedTier.Quality);
    assert_eq(feeder_item_to_feed_tier(ItemId.Turnip), AnimalFeedTier.Quality);
    assert_eq(feeder_item_to_feed_tier(ItemId.Strawberry), AnimalFeedTier.Deluxe);
    assert_eq(feeder_item_to_feed_tier(ItemId.Cabbage), AnimalFeedTier.Ultimate);
    assert_eq(feeder_item_to_feed_tier(ItemId.BlueberryJam), AnimalFeedTier.Quality);
    assert_eq(feeder_item_to_feed_tier(ItemId.DeviledEggs), AnimalFeedTier.Ultimate);
    assert_eq(feeder_item_to_feed_tier(ItemId.GrassSeed), AnimalFeedTier.Normal);

    //
    for (var i = 0; i < ItemId.LEN; i++) {
        feeder_item_to_feed_tier(i);
    }
}
