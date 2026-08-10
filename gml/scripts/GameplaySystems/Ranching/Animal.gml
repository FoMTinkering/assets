function BaseAnimal(kind, variant, sex) constructor {
    self.kind = kind;
    self.prototype = ANIMAL_PROTOTYPES[self.kind];
    self.idx = irandom(I32_MAX);
    self.variant = variant;
    self.location_position = undefined;
    self.sex = sex;
    self.name = random_animal_name(self.sex);
    self.instance = undefined;
    self.days_old = 0;
    self.animation = "idle";
    self.cardinality = Cardinal.South;
    self.baby_sound_index = irandom(array_length(self.prototype.sounds.baby) - 1);
    self.adult_sound_index = irandom(array_length(self.prototype.sounds.adult) - 1);
    self.cosmetic = undefined;

    is_pet = false;

    //
    function move_accel() {
        return Vec2(self.prototype.behavior.move_speed, self.prototype.behavior.move_speed);
    }

    function starting_cardinality() {
        return self.prototype.core.size == AnimalSize.Small ? Cardinal.East : Cardinal.South;
    }

    function can_make_sounds() {
        return true;
    }

    //
    function is_baby() {
        return self.days_old < self.prototype.breeding.days_until_adult;
    }

    function held_offset() {
        return self.prototype.petting.held_offset;
    }

    function celebration_animation() {
        if self.is_baby() {
            return self.prototype.celebration_data.baby_animation
        } else {
            return self.prototype.celebration_data.adult_animation;
        }
    }

    function bark_offsets() {
        return self.is_baby() ? self.prototype.bark_offsets.baby : self.prototype.bark_offsets.adult;
    }

    //
    function is_present() {
        var loc = self.location_position;
        return
            loc != undefined
            && loc.location_id == CURRENT_LOCATION_ID
            && loc.dyn_index == CURRENT_DYN_INDEX;
    }

    //
    function tier() {
        return self.prototype.variants.get(self.variant).tier;
    }

    //
    function set_cardinality(card) {
        if self.cardinality == card {
            return;
        }
        self.cardinality = card;
        if self.instance != undefined {
            self.instance.set_sprites(self.animation);
            self.instance.update_bark_offset();
        }
    }

    //
    function active_animation() {
        return self.prototype.animations.get(self.animation);
    }

    //
    function animations() {
        return self.prototype.animations;
    }

    //
    function active_sprites() {
        return self.sprites_for_animation(self.animation, self.cardinality);
    }

    //
    function sprites_for_animation(animation, cardinality) {
        var variant = self.prototype.variants.get(self.variant);
        var key = self.is_baby()
            ? "baby"
            : sex_to_string(self.sex);

        //
        var entry = variant[$ key];
        var card_to_use = cardinality;
        var base_sprites = entry.sprites.base.get(animation);
        var top_sprites = entry.sprites.top.get(animation);
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

        var base_cosmetic = undefined;
        var top_cosmetic = undefined;
        if !self.is_baby() && self.cosmetic != undefined {
            var cosmetic = self.prototype.cosmetics.get(self.cosmetic);
            var base_cosmetic_sprites = cosmetic[$ key].sprites.base.get(animation);
            if base_cosmetic_sprites != undefined {
                base_cosmetic = base_cosmetic_sprites[card_to_use];
            }
            var top_cosmetic_sprites = cosmetic[$ key].sprites.top.get(animation);
            if top_cosmetic_sprites != undefined {
                top_cosmetic = top_cosmetic_sprites[card_to_use];
            }
        }

        var top_sprite = top_sprites != undefined ? top_sprites[card_to_use] : undefined;

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
            base_sprite: base_sprite,
            top_sprite: top_sprite,
            base_cosmetic: base_cosmetic,
            top_cosmetic: top_cosmetic,
            shadow: SHADOW_DICTIONARY.get(base_sprite),
            lut: lut,
            lut_texture: lut_texture,
            lut_index: entry.lut_index,
            lut_uvs,
        };
    }

    //
    function has_animation(animation) {
        var variant = self.prototype.variants.get(self.variant);
        var key = self.is_baby()
            ? "baby"
            : sex_to_string(self.sex);

        //
        var entry = variant[$ key];

        return entry.sprites.base.contains_key(animation);
    }

    //
    //
    function has_animation_with_cardinal(animation, cardinality) {
        var variant = self.prototype.variants.get(self.variant);
        var key = self.is_baby()
            ? "baby"
            : sex_to_string(self.sex);

        //
        var entry = variant[$ key];

        if entry == undefined {
            return false;
        }

        var base_sprite = entry.sprites.base.get(animation);
        if base_sprite == undefined {
            return false;
        }

        return base_sprite[cardinality] != undefined;
    }


    //
    //
    function sounds() {
        return self.is_baby()
            ? self.prototype.sounds.baby[self.baby_sound_index]
            : self.prototype.sounds.adult[self.adult_sound_index];
    }
}

//
function PlayerAnimal(kind, variant, sex) : BaseAnimal(kind, variant, sex) constructor {
    self.stable = undefined;
    self.heart_points = 0;
    self.has_eaten = false;
    self.has_been_pat = false;
    self.has_been_outside = false;
    self.bark_on_sight = undefined;
    self.unhappy_days = 0;
    self.is_incubating = false;
    self.must_name = false;
    self.production_days = 0;
    self.celibate = false;
    self.ate_breeding_treat = false;
    self.breeding_with = undefined;
    self.birthday = 0;
    self.liminal = false;
    self.festival_tier = undefined;

    //
    self.eat_data = undefined;

    //
    function can_breed() {
        return
            !self.is_baby()
            && !self.celibate
            && self.stable.availability() > 0
            && (self.prototype.breeding.uses_egg == false || self.stable.incubator_availability() > 0);
    }

    //
    function can_pet() {
        return !self.has_been_pat;
    }

    //
    function pet() {
        assert(self.can_pet(), "Cannot pet more than once a day!");
        self.has_been_pat = true;
        self.add_heart_points(fiddle_get("ranching/misc/heart_points/pet"));
        ARI.gain_xp(Skill.Ranching, ANIMAL_XP.pet);
    }

    //
    function feed(item) {
        if self.has_eaten {
            error("You fed an animal twice! You can't do that!");
            return;
        }

        var item_prototype = is_struct(item) ? item.prototype : ITEM_PROTOTYPES[item];
        self.has_eaten = true;
        self.add_heart_points(item_heart_value_for_animal(item_prototype));
        ARI.gain_xp(Skill.Ranching, ANIMAL_XP.feed);
    }

    //
    function add_heart_points(points) {
        if ARI.perk_active(Perk.TrueTrust) && points < 0 {
            return;
        }
        static MAX_POINTS = animal_heart_level_to_points(10);
        var old_level = points_to_animal_heart_level(self.heart_points);
        self.heart_points = clamp(self.heart_points + points, 0, MAX_POINTS);
        var new_level = points_to_animal_heart_level(self.heart_points);

        if new_level > old_level {
            ARI.gain_xp(Skill.Ranching, ANIMAL_XP.gain_heart * (new_level - old_level));
        }
    }

    //
    function can_mount() {
        return !self.is_baby()
            && self.prototype.mounting.is_mount
            && points_at_max_animal_heart_level(self.heart_points);
    }

    //
    function is_home() {
        return
            self.location_position != undefined
            && self.stable != undefined
            && self.location_position.location_id == self.stable.building.prototype.location_id
            && self.location_position.dyn_index == self.stable.building.dyn_index;
    }

    //
    function in_daycare() {
        return DAYCARE.contains(self);
    }

    //
    function sell_value() {
        var multip = self.prototype.pricing.tier_sell_price_multipliers[self.tier()];
        if self.is_baby() {
            return round(self.prototype.pricing.baby_sell_price * multip);
        } else {
            return round(self.prototype.pricing.adult_sell_prices[points_to_animal_heart_level(self.heart_points)] * multip);
        }
    }

    //
    function send_to_stall_point() {
        if self.stable != undefined {
            var home = self.stable.building;

            //
            var index = self.stable.stalls.find(function(v) {
                return v != undefined && v.idx == self.idx;
            });
            assert_neq(index, undefined, "An animal was unable to find its stall index!");
            var point_name = home.prototype.stall_points.get(index);
            self.location_position = trellis_point_location_position(point_name);
            self.location_position.dyn_index = home.dyn_index;
        }
    }

    function serialize() {
        return {
            kind: animal_kind_to_string(self.kind),
            variant: self.variant,
            sex: sex_to_string(self.sex),
            idx: self.idx,
            name: self.name,
            cosmetic: self.cosmetic,
            heart_points: self.heart_points,
            unhappy_days: self.unhappy_days,
            days_old: self.days_old,
            is_incubating: self.is_incubating,
            baby_sound_index: self.baby_sound_index,
            adult_sound_index: self.adult_sound_index,
            has_been_pat: self.has_been_pat,
            has_been_outside: self.has_been_outside,
            bark_on_sight: try_bark_id_to_string(self.bark_on_sight),
            has_eaten: self.has_eaten,
            ate_breeding_treat: self.ate_breeding_treat,
            breeding_with: self.breeding_with,
            birthday: self.birthday,
            location_position: opt_and_then(self.location_position, serialize_location_position),
            production_days: self.production_days,
            festival_tier: self.festival_tier,
        };
    }

    function deserialize(animal_data) {
        self.sex = string_to_sex(animal_data.sex);
        self.variant = animal_data.variant;
        self.kind = string_to_animal_kind(animal_data.kind);
        self.idx = animal_data.idx;
        self.name = animal_data.name;
        self.cosmetic = animal_data.cosmetic;
        self.heart_points = animal_data.heart_points;
        self.unhappy_days = animal_data.unhappy_days;
        self.days_old = animal_data.days_old;
        self.ate_breeding_treat = animal_data.ate_breeding_treat;
        self.is_incubating = animal_data.is_incubating;
        self.baby_sound_index = animal_data.baby_sound_index;
        self.adult_sound_index = animal_data.adult_sound_index;
        self.has_been_pat = animal_data.has_been_pat;
        self.birthday = animal_data.birthday;
        self.has_eaten = animal_data.has_eaten;
        self.bark_on_sight = try_string_to_bark_id(animal_data[$ "bark_on_sight"] ?? undefined);
        self.production_days = animal_data[$ "production_days"] ?? 0;
        self.festival_tier = animal_data[$ "festival_tier"];

        if is_nullish(animal_data[$ "breeding_with"]) {
            self.breeding_with = undefined;
        } else {
            self.breeding_with = animal_data.breeding_with;
        }

        //
        self.has_been_outside = animal_data.has_been_outside;

        if animal_data[$ "location_position"] != undefined {
            self.location_position = deserialize_location_position(animal_data.location_position);
        }
    }
}

//
function NonPlayerAnimal(kind, variant, sex) : BaseAnimal(kind, variant, sex) constructor {
    //
    function is_home() {
        return false;
    }
}

//
//
function initialize_new_animal_for_ari(animal) {
    animal.birthday = seasons(CALENDAR.season()) + days(CALENDAR.day());

    ARI.animal_variant_unlocks[animal.kind].insert(animal.variant);

    var bonus_hearts = 0;
    if ARI.perk_active(Perk.WelcomeHomeTwo) {
        bonus_hearts = ARI.perk_value(Perk.WelcomeHomeTwo);
    } else if ARI.perk_active(Perk.WelcomeHome) {
        bonus_hearts = ARI.perk_value(Perk.WelcomeHome);
    }
    animal.heart_points += animal_heart_level_to_points(bonus_hearts);


    animal.cosmetic = animal.prototype.variants.get(animal.variant).default_cosmetic;
    if animal.cosmetic != undefined {
        ARI.animal_cosmetic_unlocks[animal.kind].insert(animal.cosmetic);
    }
}
