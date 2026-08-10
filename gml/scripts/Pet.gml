#macro PET global.__pet
PET = undefined;

#macro PET_ID -1 //

//
//
enum PetKind {
    Cat,
    Dog,
    Sapling,
    Mushroom,
    Rockclod,
    Oreclod,
    Enchantern,
    Stalagmite,
    EssenceBat,
    Mimic,
    FlameSpirit,
    LavaCat,
    VoidCat,
    RockStack,
    FlyingTome,
    GriffinStatue,

    LEN
}

enum PetJob {
    None,

    Wood,
    Stone,
    Forageables,

    LEN,
}

function Pet() constructor {
    self.animation = "idle";
    self.cardinality = Cardinal.South;
    self.instance = undefined;
    self.cosmetic = undefined;
    self.sex = Sex.Female;
    self.variant = "cat_tabby";
    self.name = local_get("misc_local/default_pet_name");

    self.job = PetJob.None;
    self.job_active = false;
    self.items_to_pop = [];

    self.has_eaten = false;
    self.has_been_pat = false;
    self.heart_points = 0;

    //
    self.kind = undefined;
    self.idx = PET_ID;

    self.location_id = LocationId.PlayerHome;
    self.management = PetManagement.Morning;

    self.is_pet = true;
    self.cutscene_speed = Vec2(0.35, 0.35);

    function unlocked() {
        return MIST.scene_history.contains("pet_arrival");
    }

    //
    function move_accel() {
        if has_flag(PAUSE_STATUS, PauseStatus.CUTSCENE) {
            return self.cutscene_speed;
        } else {
            return Vec2(0.35, 0.35);
        }
    }

    function held_offset() {
        return Vec2(9, 16);
    }

    function is_baby() {
        return false;
    }

    function bark_offsets() {
        return PET_PROTOTYPE.bark_offsets;
    }

    function is_home() {
        return is_home_location(CURRENT_LOCATION_ID);
    }

    //
    function active_sprites() {
        return self.sprites_for_animation(self.animation, self.cardinality);
    }

    //
    function active_animation() {
        return PET_PROTOTYPE.animations.get(self.animation);
    }

    //
    function animations() {
        return PET_PROTOTYPE.animations;
    }

    function celebration_animation() {
        return PET_PROTOTYPE.celebration_animation;
    }

    //
    function sprites_for_animation(animation, cardinality) {
        var entry = PET_PROTOTYPE.variants.get(self.variant);

        //
        var card_to_use = cardinality;
        var base_sprites = entry.sprites.get(animation);
        var base_sprite = base_sprites[card_to_use];

        if base_sprite == undefined {
            static BACKUP_ORDER = [Cardinal.East, Cardinal.South, Cardinal.North];
            for (var i = 0; i < array_length(BACKUP_ORDER); i++) {
                card_to_use = BACKUP_ORDER[i];
                var base_sprite = base_sprites[card_to_use];
                if base_sprite != undefined {
                    break;
                }
            }
        }

        var cosmetic = undefined;
        if self.cosmetic != undefined {
            var cosmetic = PET_PROTOTYPE.cosmetics.get(self.cosmetic);
            var cosmetic_sprites = cosmetic.sprites.get(animation);
            if cosmetic_sprites != undefined {
                cosmetic = cosmetic_sprites[card_to_use];
            }
        }

        var lut = entry.lut;
        var lut_texture = undefined;
        var lut_uvs = undefined;

        if lut != undefined {
            var uvs = sprite_get_uvs(lut, 0);
            lut_uvs = [
                uvs[0],
                uvs[1],
                uvs[2],
                uvs[3],
            ];
            lut_texture = lut;
        }

        return {
            lut_index: entry[$ "lut_index"],
            shadow: SHADOW_DICTIONARY.get(base_sprite),
            base_sprite,
            base_cosmetic: cosmetic,
            lut,
            lut_texture,
            lut_uvs,
            top_sprite: undefined,
            top_cosmetic: undefined,
        };
    }

    function pet() {
        if self.has_been_pat {
            return;
        }
        self.has_been_pat = true;
        self.add_heart_points(fiddle_get("ranching/misc/heart_points/pet"));
    }

    //
    function pet_kind() {
        return PET_PROTOTYPE.variants.get(self.variant).pet_kind;
    }

    function positive_react_tango_event_name() {
        switch self.pet_kind() {
            case PetKind.Cat: return "SoundEffects/Animals/CatPositiveReact";
            case PetKind.Dog: return "SoundEffects/Animals/DogPositiveReact";
            case PetKind.Sapling: return "SoundEffects/Enemies/Sapling/PetPositiveReact";
            case PetKind.Mushroom: return "SoundEffects/Enemies/Mushroom/PetPositiveReact";
            case PetKind.Rockclod: return "SoundEffects/Enemies/Rockclod/PetPositiveReact";
            case PetKind.Oreclod: return "SoundEffects/Enemies/Rockclod/PetPositiveReact";
            case PetKind.Enchantern: return "SoundEffects/Enemies/Enchantern/PetPositiveReact";
            case PetKind.Stalagmite: return "SoundEffects/Enemies/Stalagmite/PetPositiveReact";
            case PetKind.EssenceBat: return "SoundEffects/Enemies/EssenceBat/PetPositiveReact";
            case PetKind.Mimic: return "SoundEffects/Enemies/MimicChest/PetPositiveReact";
            case PetKind.FlameSpirit: return "SoundEffects/Enemies/FlameSprite/PetPositiveReact";
            case PetKind.LavaCat: return "SoundEffects/Enemies/LavaCat/PetPositiveReact";
            case PetKind.VoidCat: return "SoundEffects/Enemies/LavaCat/PetPositiveReact";
            case PetKind.RockStack: return "SoundEffects/Enemies/RockStack/PetPositiveReact";
            case PetKind.FlyingTome: return "SoundEffects/Enemies/Tome/PetPositiveReact";
            case PetKind.GriffinStatue: return "SoundEffects/Enemies/GriffinStatue/PetPositiveReact";
            default: impossible("unexpected pet_kind");
        }
    }

    //
    function set_cardinality(card) {
        if self.cardinality == card {
            return;
        }
        self.cardinality = card;
        if self.instance != undefined {
            self.instance.set_sprites(self.animation);
        }
    }

    function starting_cardinality() {
        return Cardinal.South;
    }

    function can_make_sounds() {
        return false;
    }

    //
    function feed(item) {
        self.add_heart_points(ANIMAL_HEART_POINTS.base_value + ANIMAL_HEART_POINTS.feed[item.prototype.pet_treat.tier]);
    }

    //
    function add_heart_points(points) {
        static MAX_POINTS = animal_heart_level_to_points(10);
        self.heart_points = clamp(self.heart_points + points, 0, MAX_POINTS);
    }

    function serialize() {
        return {
            variant: self.variant,
            sex: sex_to_string(self.sex),
            name: self.name,
            job: pet_job_to_string(self.job),
            items_to_pop: array_map(self.items_to_pop, item_id_to_string),
            cosmetic: self.cosmetic,
            heart_points: self.heart_points,
            has_eaten: self.has_eaten,
            has_been_pat: self.has_been_pat,
        };
    }

    function deserialize(pet_data, time) {
        self.variant = pet_data.variant;
        if !DEBUG_ASSERTIONS && PET_PROTOTYPE.variants.contains_key(self.variant) == false {
            error("Unexpected pet variant: `{}`, replaced with `cat_tabby`", self.variant);
            self.variant = "cat_tabby";
        }
        self.sex = string_to_sex(pet_data.sex);
        self.name = pet_data.name;
        self.cosmetic = pet_data.cosmetic;
        self.heart_points = pet_data.heart_points;
        self.has_eaten = pet_data.has_eaten;
        self.items_to_pop = array_map(pet_data.items_to_pop, string_to_item_id);
        //
        self.has_been_pat = pet_data[$ "has_been_pat"] ?? false;

        self.job = string_to_pet_job(pet_data.job);

        if time >= hours(19) {
            self.management = PetManagement.Night;
            self.location_id = pet_valid_house_location();
            self.job_active = false;
        } else if time >= hours(11) {
            self.management = PetManagement.Afternoon;
            if !WEATHER.is_inclement() {
                self.location_id = location_for_job(self.job);
                self.job_active = true;
            } else {
                self.location_id = pet_valid_house_location();
                self.job_active = false;
            }
        } else {
            self.management = PetManagement.Morning;
            self.location_id = pet_valid_house_location();
            self.job_active = false;
        }
    }
}

enum PetInitialization {
    Normal,
    Bed,
    Held,
    EatDish,
    EnterViaDoor,
    DoJob,
    Cutscene,
}

enum PetManagement {
    Morning,
    Afternoon,
    Night,
}

function pet_on_room_start() {
    if PET.unlocked() && PET.location_id == CURRENT_LOCATION_ID {
        spawn_pet();
    }
}

function time_to_pet_management(time) {
    if time >= hours(19) {
        return PetManagement.Night;
    } else if time >= hours(11) {
        return PetManagement.Afternoon;
    } else {
        return PetManagement.Morning;
    }
}

function pet_update_at_time(time, should_spawn_pet=true, obey_pause=true) {
    //
    if PET.unlocked() == false || (game_paused() && obey_pause) {
        return;
    }

    var new_pet_management_time = time_to_pet_management(time);

    for (var i = PET.management; i < new_pet_management_time; i++) {
        //
        switch i {
            case PetManagement.Morning:
                if WEATHER.is_inclement() == false {
                    if instance_exists(obj_pet) {
                        if is_home_location(CURRENT_LOCATION_ID) {
                            obj_pet.go_to_farm();
                        } else {
                            //
                            //
                            obj_pet.deferred_job_active_status = true;
                        }
                    } else {
                        PET.location_id = location_for_job(PET.job);
                        if CURRENT_LOCATION_ID == LocationId.Farm
                            && PET.location_id == LocationId.Farm
                            && should_spawn_pet
                        {
                            spawn_pet(PetInitialization.EnterViaDoor);
                        }
                        PET.job_active = true;
                    }
                }
                break;
            case PetManagement.Afternoon:
                var reward = PET.job_active && PET.job != PetJob.None;

                //
                if instance_exists(obj_pet) && (obj_pet.deferred_job_active_status != undefined || obj_pet.try_leave_house) {
                    //
                    reward = PET.job != PetJob.None;
                    //
                    obj_pet.deferred_job_active_status = undefined;
                }

                if reward {
                    var job_data = PET_PROTOTYPE.job_setup_data[PET.job];
                    var heart_level = clamp(points_to_animal_heart_level(PET.heart_points), 0, 10);
                    var reward_range = job_data.reward_table[heart_level];
                    var reward_count = irandom_range(reward_range[0], reward_range[1]);
                    if job_data.reward == undefined {
                        //
                        //
                        assert_eq(PET.job, PetJob.Forageables);
                        repeat reward_count {
                            var forageable = FORAGEABLES.roll_forageable_at_location(GRIDS[LocationId.EasternRoad], 0, 0);
                            if forageable != undefined {
                                array_push(PET.items_to_pop, NODE_PROTOTYPES[forageable].harvest);
                            }
                        }
                    } else {
                        for (var i = 0; i < reward_count; i++) {
                            array_push(PET.items_to_pop, job_data.reward);
                        }
                    }
                }

                if instance_exists(obj_pet) {
                    if CURRENT_LOCATION_ID == LocationId.Farm || is_home_location(CURRENT_LOCATION_ID) {
                        //
                        //
                        //
                        //
                        obj_pet.go_home();
                    } else {
                        //
                        obj_pet.deferred_job_active_status = false;
                    }
                } else {
                    PET.job_active = false;
                    if CURRENT_LOCATION_ID == LocationId.PlayerHome {
                        if should_spawn_pet {
                            PET.location_id = LocationId.PlayerHome;
                            spawn_pet(PetInitialization.EnterViaDoor);
                        } else {
                            PET.location_id = pet_valid_house_location();
                        }
                    } else {
                        PET.location_id = pet_valid_house_location();
                    }
                }
                break;
            case PetManagement.Night:
                //
                break;
        }

        //
        PET.management = i + 1;
    }
}

function spawn_pet(override_pet_initialization) {
    instance_create_layer(0, 0, "Instances", obj_pet, { override_pet_initialization });
}

function pet_valid_house_location() {
    var valid_locations = [];

    var g = GRIDS[LocationId.PlayerHome];
    if array_length(g.pet_beds)!= 0 || array_length(g.pet_dishes) != 0 {
        array_push(valid_locations, LocationId.PlayerHome);
    }

    if DECOR.size_upgrade >= HomeUpgrade.LargeWest {
        g = GRIDS[LocationId.PlayerHomeWest];
        if array_length(g.pet_beds)!= 0 || array_length(g.pet_dishes) != 0 {
            array_push(valid_locations, LocationId.PlayerHomeWest);
        }
    }

    if DECOR.size_upgrade == HomeUpgrade.LargeWestEast {
        g = GRIDS[LocationId.PlayerHomeEast];
        if array_length(g.pet_beds)!= 0 || array_length(g.pet_dishes) != 0 {
            array_push(valid_locations, LocationId.PlayerHomeEast);
        }
    }

    if STAIR_COUNT > 0 {
        var grids = [LocationId.PlayerHomeUpperCentral, LocationId.PlayerHomeUpperWest, LocationId.PlayerHomeUpperEast];
        for (var i = 0; i < array_length(grids); i++) {
            g = GRIDS[grids[i]];
            if array_length(g.pet_beds)!= 0 || array_length(g.pet_dishes) != 0 {
                array_push(valid_locations, grids[i]);
            }
        }
    }

    var loc_count = array_length(valid_locations);
    if loc_count == 0 {
        return LocationId.PlayerHome;
    } else {
        return valid_locations[irandom(loc_count - 1)];
    }
}

function try_position_pet() {
    var mask_cache = self.mask_index;

    //
    var locus_x = room_width() / 2;
    var locus_y = room_height() / 2;
    var locus_radius = min(locus_x / 2, locus_y / 2);

    //
    var animal = undefined;

    if instance_exists(obj_player_animal) && chance_percent(75) {
        animal = instance_find(obj_player_animal, irandom(instance_number(obj_player_animal) - 1));
        if animal.me.idx == ARI.held_animal_id {
            animal = undefined;
        }
    }

    if animal != undefined {
        locus_x = animal.x;
        locus_y = animal.y;
        locus_radius = 300;
    } else if CURRENT_LOCATION_ID == LocationId.Farm {
        locus_x = 808;
        locus_y = 312;
        locus_radius = 300;
    }

    //
    self.mask_index = spr_large_animal_mask;

    //
    repeat 25 {
        var dir = random(360);
        var dist = random(locus_radius);

        self.x = round(locus_x + lengthdir_x(dist, dir));
        self.y = round(locus_y + lengthdir_y(dist, dir));

        var pos_is_valid = true;

        //
        for (var xx = bbox_left; xx <= bbox_right; xx += 4) {
            if pos_is_valid == false {
                break;
            }
            for (var yy = bbox_top; yy <= bbox_bottom; yy += 4) {
                var ni = GRID.try_node_index_for_room_position(xx, yy);
                if ni == undefined
                    || GRID.node_terrain_kind[ni] != TerrainKind.Ground
                    || GRID.node_collideable[ni]
                    || ((is_home_location(CURRENT_LOCATION_ID) || CURRENT_LOCATION_ID == LocationId.Farm)
                        && has_flag(GRID.node_flags[ni], TileFlag.Placeable) == false)
                {
                    pos_is_valid = false;
                    break;
                }
            }
        }

        if pos_is_valid {
            self.mask_index = mask_cache;
            return true;
        }
    }

    return false;
}

function location_for_job(job) {
    if job == PetJob.None {
        return LocationId.Farm;
    } else {
        return PET_PROTOTYPE.job_setup_data[job].location_id;
    }
}

//
function pet_kind_unlocked(kind) {
    var keys = PET_PROTOTYPE.variants.keys();
    for (var i = 0; i < array_length(keys); i++) {
        var variant = PET_PROTOTYPE.variants.get(keys[i]);
        if variant.pet_kind == kind
            && (variant.unlock_key == undefined || array_contains(ARI.pet_skin_unlocks, variant.unlock_key)) {
            return true;
        }
    }
    return false;
}

//
//
//
//
//
function pet_cosmetics_available(pet_kind, cosmetic_sets_unlocked) {
    var output = [];

    var cosmetic_keys = PET_PROTOTYPE.cosmetics.keys();
    for (var i = 0; i < array_length(cosmetic_keys); i++) {
        var cosmetic_name = cosmetic_keys[i];
        var cosmetic = PET_PROTOTYPE.cosmetics.get(cosmetic_name);

        if cosmetic.pet_kind == pet_kind
            && array_contains(cosmetic_sets_unlocked, cosmetic.cosmetic_set)
        {
            array_push(output, cosmetic_name);
        }
    }

    return output;
}

//
//
function pet_cosmetics(pet_kind) {
    var output = [];

    var cosmetic_keys = PET_PROTOTYPE.cosmetics.keys();
    for (var i = 0; i < array_length(cosmetic_keys); i++) {
        var cosmetic_name = cosmetic_keys[i];
        var cosmetic = PET_PROTOTYPE.cosmetics.get(cosmetic_name);

        if cosmetic.pet_kind == pet_kind {
            array_push(output, cosmetic_name);
        }
    }

    return output;
}
