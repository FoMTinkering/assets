//
//
function LiveItem(item_id, inner_item) constructor {
    self.item_id = item_id;
    self.prototype = ITEM_PROTOTYPES[self.item_id];
    self.inner_item = inner_item;
    self.gold_to_gain = undefined;
    self.cosmetic = undefined;
    self.pet_cosmetic_set_name = undefined;
    self.animal_cosmetic = undefined;
    self.auto_use = false;
    self.icon_override = undefined;
    self.date_photo = undefined;

    if self.prototype.default_infusion != undefined {
        self.infusion = self.prototype.default_infusion;
    } else {
        self.infusion = undefined;
    }

    static can_use = function() {
        if self.prototype.use == undefined {
            return false;
        }
        var cost = self.prototype.stamina_cost;
        if cost < 0 && ARI.get_stamina() < cost {
            create_notification("misc_local/out_of_stamina", 60 * 5);
            return false;
        }
        return true;
    }

    static soulbound = function() {
        if self.prototype.soulbind == undefined {
            return false;
        }
        switch self.prototype.soulbind.type {
            case Soulbind.Forever: return true;
            case Soulbind.Requirements: return requirements_pass(self.prototype.soulbind.requirements);
            default: impossible("Unexpected Soulbind: {Soulbind}", self.prototype.soulbind.type)
        }
    }

    static partial_eq = function(live_item) {
        //
        var animal_cosmetic_matches = self.animal_cosmetic == live_item.animal_cosmetic;
        if
            !animal_cosmetic_matches
            && self.animal_cosmetic != undefined
            && live_item.animal_cosmetic != undefined
        {
            animal_cosmetic_matches =
                self.animal_cosmetic.animal == live_item.animal_cosmetic.animal
                && self.animal_cosmetic.cosmetic == live_item.animal_cosmetic.cosmetic;
        }

        return
            self.item_id == live_item.item_id
            && self.inner_item == live_item.inner_item
            && self.gold_to_gain == live_item.gold_to_gain
            && self.cosmetic == live_item.cosmetic
            && self.infusion == live_item.infusion
            && self.pet_cosmetic_set_name == live_item.pet_cosmetic_set_name
            && self.date_photo == live_item.date_photo
            && animal_cosmetic_matches;
    }

    static get_infusion_modifier = function(infusion_type, key) {
        return self.infusion == infusion_type
            ? INFUSIONS.get(self.infusion)[$ key]
            : 0;
    }

    static get_display_name = function() {
        var item_data = ITEM_PROTOTYPES[self.item_id];
        if self.prototype.use == ItemUse.LearnRecipe && self.inner_item != undefined {
            var base = local_get(item_data.name_key);
            var insert = local_get(ITEM_PROTOTYPES[self.inner_item].name_key);
            return fmt(base, insert);
        } else if self.infusion != undefined && self.prototype.default_infusion == undefined {
            var adj = INFUSIONS.get(self.infusion).name;
            var space = local_get_info(LocalInfoRequest.InfusionSpace);
            if local_get_info(LocalInfoRequest.InfusionOrder) == InfusionOrder.Adjective {
                return format("{Local}{}{Local}", adj, space, item_data.name_key);
            } else {
                return format("{Local}{}{Local}", item_data.name_key, space, adj);
            }
        } else if self.item_id == ItemId.Cosmetic {
            return local_get(PLAYER_ANIMATION_DATABASE.player_assets.get(self.cosmetic).name);
        } else if self.item_id == ItemId.AnimalCosmetic {
            return local_get(
                ANIMAL_PROTOTYPES[self.animal_cosmetic.animal]
                    .cosmetics
                    .get(self.animal_cosmetic.cosmetic)
                    .name
            );
        } else if self.item_id == ItemId.PetCosmetic {
            return local_get(
                PET_PROTOTYPE
                    .cosmetic_sets
                    .get(self.pet_cosmetic_set_name)
                    .name
            );
        } else {
            return local_get(item_data.name_key);
        }
    }

    static get_display_description = function() {
        var item_data = ITEM_PROTOTYPES[self.item_id];
        if self.prototype.use == ItemUse.LearnRecipe && self.inner_item != undefined {
            var base = local_get(item_data.description_key);
            var insert = local_get(ITEM_PROTOTYPES[self.inner_item].name_key);
            return fmt(base, insert);
        } else if self.infusion != undefined && self.prototype.default_infusion == undefined {
            return local_get(INFUSIONS.get(self.infusion).description);
        } else {
            return local_get(item_data.description_key);
        }
    }

    static get_ui_icon = function() {
        switch self.item_id {
            case ItemId.Cosmetic:
                var asset = PLAYER_ANIMATION_DATABASE.player_assets.get(self.cosmetic);
                return asset.ui_merged_icon ?? asset.ui_asset_icon;
            case ItemId.AnimalCosmetic:
                return ANIMAL_PROTOTYPES[self.animal_cosmetic.animal]
                    .cosmetics
                    .get(self.animal_cosmetic.cosmetic)
                    .ui_icon;
            case ItemId.PetCosmetic:
                return PET_PROTOTYPE
                    .cosmetic_sets
                    .get(self.pet_cosmetic_set_name)
                    .ui_icon;
            case ItemId.MistHeldItem:
                //
                //
                return self.icon_override ?? self.prototype.icon_sprite;

            default: return self.prototype.icon_sprite;
        }
    }

    static get_world_icon = function() {
        //
        if self.item_id == ItemId.Cosmetic {
            return PLAYER_ANIMATION_DATABASE.player_assets.get(self.cosmetic).ui_asset_icon;
        } else {
            return self.get_ui_icon();
        }
    }

    static get_ui_lut = function() {
        if self.item_id == ItemId.Cosmetic {
            var asset = PLAYER_ANIMATION_DATABASE.player_assets.get(self.cosmetic);
            if asset.ui_merged_icon != undefined {
                return {
                    lut: spr_player_base_lut,
                    index: ARI.animation_assets().skin_tone,
                };
            }
        }
        return undefined;
    }

    static get_ui_sub_icon = function() {
        if self.animal_cosmetic != undefined {
            return ANIMAL_PROTOTYPES[self.animal_cosmetic.animal].core.cosmetic_sub_icon;
        }

        if self.pet_cosmetic_set_name != undefined {
            return PET_PROTOTYPE.pet_cosmetic_sub_icon;
        }

        if self.prototype.use == ItemUse.UnlockPetSkin {
            return spr_ui_item_sub_pet_unlock;
        }

        if self.infusion != undefined {
            return INFUSIONS.get(self.infusion).sub_icon;
        }


        if self.date_photo != undefined {
            var sub_icons = fiddle_get("ui/misc/item_sub_icons");
            for (var i = 0, ic = array_length(sub_icons); i < ic; i++) {
                var data = sub_icons[i];
                if format("{}_furniture", npc_id_to_string(DATE_PHOTOS[self.date_photo].npc)) == data.tag {
                    return string_to_asset(data.sprite);
                }
            }
            return undefined;
        }

        var sub_icons = fiddle_get("ui/misc/item_sub_icons");
        for (var i = 0; i < array_length(sub_icons); i++) {
            var data = sub_icons[i];
            if self.prototype.tags.contains(data.tag) {
                return string_to_asset(data.sprite);
            }
        }
        return undefined;
    }

    static get_ui_outline = function() {
        return OUTLINE_DICTIONARY[$ self.get_ui_icon()];
    }

    static store_value = function() {
        static STAR_PRICES = fiddle_get("misc/cooking_recipe_star_prices");
        if self.item_id == ItemId.RecipeScroll {
            return STAR_PRICES[ITEM_PROTOTYPES[self.inner_item].stars - 1];
        }

        if self.item_id == ItemId.Cosmetic {
            return PLAYER_ANIMATION_DATABASE.player_assets.get(self.cosmetic).price_override ?? self.prototype.value.store;
        }

        var discount = 0;
        if ARI.perk_active(Perk.DiscountTreats) && (self.item_id == ItemId.HeartShapedDuckTreat ||
            self.item_id == ItemId.HeartShapedHorseTreat ||
            self.item_id == ItemId.HeartShapedRabbitTreat ||
            self.item_id == ItemId.HeartShapedSheepTreat ||
            self.item_id == ItemId.HeartShapedCowTreat ||
            self.item_id == ItemId.HeartShapedCapybaraTreat ||
            self.item_id == ItemId.HeartShapedAlpacaTreat ||
            self.item_id == ItemId.HeartShapedChickenTreat
            )
        {
            discount = ARI.perk_value(Perk.DiscountTreats) * self.prototype.value.store;
        }

        return self.prototype.value.store - discount;
    }

    static bin_value = function() {
        var bin_val = self.prototype.value.bin + max(round(self.prototype.value.bin * self.get_infusion_modifier(Infusion.Quality, "amount") / 100), 0);

        if ARI.perk_active(Perk.BackInVogue) && self.prototype.tags.contains("archaeology") {
            bin_val += round(bin_val * ARI.perk_value(Perk.BackInVogue));
        }

        if ARI.perk_active(Perk.BackInVogueTwo) && self.prototype.tags.contains("archaeology") {
            bin_val += round(bin_val * ARI.perk_value(Perk.BackInVogueTwo));
        }

        return bin_val;
    }

    static clone = function() {
        var my_clone = new LiveItem(self.item_id);
        my_clone.inner_item = self.inner_item;
        my_clone.cosmetic = self.cosmetic;
        my_clone.animal_cosmetic = clone_value(self.animal_cosmetic);
        my_clone.pet_cosmetic_set_name = self.pet_cosmetic_set_name;
        my_clone.gold_to_gain = self.gold_to_gain;
        my_clone.infusion = self.infusion;
        my_clone.date_photo = self.date_photo;
        return my_clone;
    }

    //
    static purchasable = function() {
        var acquired = ARI.items_acquired[self.item_id];

        if self.prototype.set_unlock != undefined {
            return !acquired;
        }

        if self.item_id == ItemId.PerpetualSoupPot {
            return !any_item_matches(self);
        }

        switch self.prototype.use {
            case ItemUse.LearnRecipe: return !ari_has_recipe_anywhere(self.inner_item);
            case ItemUse.ExpandInventory: return !acquired;
            case ItemUse.UnlockCosmetic: return !ari_has_cosmetic_anywhere(self.cosmetic);
            case ItemUse.UnlockAnimalCosmetic: return !ari_has_animal_cosmetic_anywhere(
                self.animal_cosmetic.animal,
                self.animal_cosmetic.cosmetic,
            );
            case ItemUse.UnlockPetCosmetic: return !ari_has_pet_cosmetic_anywhere(self.pet_cosmetic_set_name);
            case ItemUse.UnlockPetSkin: return !ari_has_pet_skin_anywhere(self.prototype.pet_skin_unlock);
            case ItemUse.UnlockDate: return !ARI.date_unlocks[self.prototype.date_unlock] && !any_item_matches(self);
            case ItemUse.UnlockSong: return !array_has(ARI.song_unlocks, self.prototype.song) && !any_item_matches(self);
            default: return !ARI.annual_item_purchase_bans[self.item_id];
        }
    }

    static max_purchase = function() {
        if
            self.prototype.set_unlock != undefined
            || matches(self.prototype.use, ItemUse.LearnRecipe, ItemUse.ExpandInventory, ItemUse.UnlockCosmetic, ItemUse.UnlockAnimalCosmetic, ItemUse.UnlockPetCosmetic, ItemUse.UnlockPetSkin, ItemUse.UnlockDate)
            || self.prototype.purchased_once_per_year
            || self.item_id == ItemId.PerpetualSoupPot
        {
            return 1;
        }

        return undefined;
    }

    static serialize = function() {
        return {
            item_id: item_id_to_string(self.item_id),
            inner_item: opt_and_then(self.inner_item, item_id_to_string),
            gold_to_gain: self.gold_to_gain,
            cosmetic: self.cosmetic,
            animal_cosmetic: opt_and_then(clone_value(self.animal_cosmetic), function(v) {
                v.animal = animal_kind_to_string(v.animal);
                return v;
            }),
            infusion: opt_and_then(self.infusion, infusion_to_string),
            auto_use: self.auto_use,
            pet_cosmetic_set_name: self.pet_cosmetic_set_name,
            date_photo: self.date_photo,
        };
    }

    static pretty_print = function() {
        if self.item_id == ItemId.UnidentifiedArtifact {
            return format("UnidentifiedArtifact<{ItemId}>", self.inner_item);
        } else if self.prototype.use == ItemUse.LearnRecipe && self.inner_item != undefined {
            return format("RecipeLearner<{ItemId}>", self.inner_item);
        } else if self.gold_to_gain != undefined {
            return format("{ItemId}<{}>", self.item_id, self.gold_to_gain);
        } else if self.cosmetic != undefined {
            return format("Cosmetic<{}>", self.cosmetic);
        } else if self.animal_cosmetic != undefined {
            return format("AnimalCosmetic<{AnimalKind}/{}>", self.animal_cosmetic.animal, self.animal_cosmetic.cosmetic);
        } else if self.pet_cosmetic_set_name != undefined {
            return format("PetCosmetic<{}>", self.pet_cosmetic_set_name);
        } else if self.infusion != undefined {
            return format("{ItemId}<{Infusion}>", self.item_id, self.infusion);
        } else if self.date_photo != undefined {
            return format("DatePhoto<{NpcId}>", DATE_PHOTOS[self.date_photo].npc);
        } else {
            return item_id_to_string(self.item_id);
        }
    }

    toString = function() {
        return format("LiveItem({})", self.pretty_print());
    }
}

function deserialize_live_item(item) {
    var item_id = string_to_item_id_or_unknown(item.item_id);

    var live_item = new LiveItem(item_id);
    if !is_nullish(item.cosmetic) {
        live_item.cosmetic = item.cosmetic;
    }
    if !is_nullish(item.gold_to_gain) {
        live_item.gold_to_gain = item.gold_to_gain;
    }
    if !is_nullish(item.infusion) {
        live_item.infusion = string_to_infusion(item.infusion);
    }
    if !is_nullish(item.inner_item) {
        live_item.inner_item = string_to_item_id_or_unknown(item.inner_item);
    }
    if !is_nullish(item.animal_cosmetic) {
        live_item.animal_cosmetic = {
            animal: string_to_animal_kind(item.animal_cosmetic.animal),
            cosmetic: item.animal_cosmetic.cosmetic,
        };
    }
    if !is_nullish(item[$ "pet_cosmetic_set_name"]) {
        live_item.pet_cosmetic_set_name = item.pet_cosmetic_set_name;
    }
    if !is_nullish(item[$ "auto_use"]) {
        live_item.auto_use = item[$ "auto_use"] ?? false;
    }
    if !is_nullish(item[$ "date_photo"]) {
        live_item.date_photo = item.date_photo;
    }
    return live_item;
}

//
function test_live_item_partial_eq() {
    static ASSERT_ITEM_EQ = function(a, b) {
        assert(a.partial_eq(b), "{} did not match {}!", a.pretty_print(), b.pretty_print());
    }
    static ASSERT_ITEM_NEQ = function(a, b) {
        assert(!a.partial_eq(b), "{} matches {}!", a.pretty_print(), b.pretty_print());
    }

    var acorn = new LiveItem(ItemId.Acorn);
    var copper_sword = new LiveItem(ItemId.SwordCopper);
    var infused_copper_sword = new LiveItem(ItemId.SwordCopper);
    infused_copper_sword.infusion = Infusion.Sharp;
    var cookie_recipe = new LiveItem(ItemId.RecipeScroll, ItemId.MonsterCookie);
    var pear_recipe = new LiveItem(ItemId.RecipeScroll, ItemId.PoachedPear);
    var purse_100 = new LiveItem(ItemId.Purse);
    purse_100.gold_to_gain = 100;
    var purse_200 = new LiveItem(ItemId.Purse);
    purse_200.gold_to_gain = 200;
    var pixie_hair = new LiveItem(ItemId.Cosmetic);
    pixie_hair.cosmetic = "hair_pixie";
    var rounded_afro = new LiveItem(ItemId.Cosmetic);
    rounded_afro.cosmetic = "hair_rounded_afro";

    ASSERT_ITEM_EQ(acorn, acorn);
    ASSERT_ITEM_EQ(copper_sword, copper_sword);
    ASSERT_ITEM_EQ(infused_copper_sword, infused_copper_sword);
    ASSERT_ITEM_EQ(cookie_recipe, cookie_recipe);
    ASSERT_ITEM_EQ(purse_100, purse_100);
    ASSERT_ITEM_EQ(pixie_hair, pixie_hair);

    ASSERT_ITEM_NEQ(acorn, copper_sword);
    ASSERT_ITEM_NEQ(infused_copper_sword, copper_sword);
    ASSERT_ITEM_NEQ(cookie_recipe, pear_recipe);
    ASSERT_ITEM_NEQ(purse_100, purse_200);
    ASSERT_ITEM_NEQ(pixie_hair, rounded_afro);
}
