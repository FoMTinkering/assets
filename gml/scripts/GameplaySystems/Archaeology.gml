#macro ARCHAEOLOGY global.__archaeology
global.__archaeology = undefined;

//
#macro ARTIFACTS_DISTRIBUTION global.__artifacts_distributions
ARTIFACTS_DISTRIBUTION = undefined;

function Archaeology() constructor {
    working_generic = List();
    working_special = List();
    dig_site_count = 0;
    special_dig_site_count = 0;

    location_loot_tables = array_create(LocationId.LEN, undefined);
    dig_sites_per_room = array_create(LocationId.LEN, undefined);

    //
    var f = fiddle_get("artifacts");
    self.rarity_votes = array_create(ForageableRarity.LEN, undefined);
    for (var i = 0; i < ForageableRarity.LEN; i++) {
        self.rarity_votes[i] = f.votes[$ forageable_rarity_to_string(i)];
    }

    static GET_LOOT_FROM_SET = function(set_name, spawn_distro, f_loot, extra_condition) {
        var set = MUSEUM_DATA.data[MuseumWing.Archaeology].sets.get(set_name);
        assert_neq(set, undefined, "no archaeology set named {} found", set_name);

        for (var i = 0; i < array_length(set.items); i++) {
            var item = set.items[i];
            var rarity = f_loot[$ item_id_to_string(item)];
            if rarity != undefined {
                var conditions = new SpawnConditions();
                var rarity = string_to_forageable_rarity(rarity);
                var value = self.rarity_votes[rarity];
                conditions.add(value, Condition.None);

                switch rarity {
                    case ForageableRarity.Legendary:
                        conditions.add(3, Condition.HasPerk(Perk.MuseumQualityThree));
                        break;
                    case ForageableRarity.Rare:
                        conditions.add(4, Condition.HasPerk(Perk.MuseumQualityTwo));
                        break;
                    case ForageableRarity.Uncommon:
                        conditions.add(6, Condition.HasPerk(Perk.MuseumQualityOne));
                        break;
                    case ForageableRarity.Common:
                        conditions.add(-3, Condition.PursuitIsActive);
                        break;
                    default: impossible("unexpected forageable rarity: {}", rarity);
                }

                if extra_condition != undefined {
                    conditions.require(clone_condition(extra_condition));
                }

                spawn_distro.add_candidate(item, conditions);
            }
        }
    }

    static MAKE_TABLE_QUICK = function(new_set_name, f_loot) {
        var new_distro = new SpawnDistribution();
        GET_LOOT_FROM_SET(new_set_name, new_distro, f_loot);
        return new_distro;
    }

    self.location_loot_tables = array_create(LocationId.LEN, undefined);

    //
    var f = fiddle_get("artifacts");
    for (var i = 0; i < LocationId.LEN; i++) {
        var spawn_distribution_per_location = new SpawnDistribution();

        GET_LOOT_FROM_SET("common_finds", spawn_distribution_per_location, f.loot);
        GET_LOOT_FROM_SET("oopart", spawn_distribution_per_location, f.loot, Condition.HasPerk(Perk.WellPlaced));

        var set_name_for_location = f.locations[$ location_id_to_string(i)];
        if set_name_for_location != undefined {
            GET_LOOT_FROM_SET(set_name_for_location, spawn_distribution_per_location, f.loot);
        }
        self.location_loot_tables[i] = spawn_distribution_per_location;
    }

    //
    self.fishing_table = MAKE_TABLE_QUICK("aquatic", f.loot);
    self.diving_table = MAKE_TABLE_QUICK("sunken", f.loot);

    //
    self.dungeon_biome_tables = array_create(array_length(DUNGEON.biomes), undefined);
    for (var j = 0; j < array_length(DUNGEON.biomes); j++) {
        var distro = new SpawnDistribution();
        GET_LOOT_FROM_SET(DUNGEON.biomes[j].artifact_set, distro, f.loot);

        //
        if DUNGEON.biomes[j].artifact_set != "mine" {
            GET_LOOT_FROM_SET("mine", distro, f.loot);
        }
        self.dungeon_biome_tables[j] = distro;
    }

    self.ritual_chamber_table = MAKE_TABLE_QUICK("ritual", f.loot);

    function get_or_create_dig_site_list(location_id) {
        var dig_site = self.dig_sites_per_room[location_id];
        if dig_site == undefined {
            dig_site = { generic: List(), special: List() };
            self.dig_sites_per_room[location_id] = dig_site;
        }
        return dig_site;
    }

    function spawn_dig_sites(grid) {
        var these_sites = self.dig_sites_per_room[grid.location_id];
        if these_sites == undefined {
            return;
        }

        var generic_max = LOCATIONS[grid.location_id].dig_sites;
        var special_max = LOCATIONS[grid.location_id].special_dig_sites;

        if grid.location_id == LocationId.WesternRuins {
            special_max += ARI.perk_value(Perk.WesternRuinsScholar);
            GAME_STATS.perks[$ perk_to_string(Perk.WesternRuinsScholar)] += 1;
        }

        if grid.location_id == LocationId.EasternRoad {
            special_max += ARI.perk_value(Perk.EasternRoadScholar);
            GAME_STATS.perks[$ perk_to_string(Perk.EasternRoadScholar)] += 1;
        }

        if grid.location_id == LocationId.Farm {
            generic_max += ARI.perk_value(Perk.FormerFarmers);
            GAME_STATS.perks[$ perk_to_string(Perk.FormerFarmers)] += 1;
        }

        if generic_max == 0 && special_max == 0 {
            return;
        }

        self.working_generic.clear();
        self.working_special.clear();

        //
        for (var i = 0, c = these_sites.generic.count(); i < c; i++) {
            var coord = these_sites.generic.get(i);
            var ni = grid.node_index_for_cell(coord.x, coord.y);

            if grid.node_object_id[ni] == ObjectId.DigSite {
                erase_object_node(grid, ni);
            }

            if grid.node_object_id[ni] == undefined {
                self.working_generic.push(coord);
            }
        }

        //
        for (var i = 0, c = these_sites.special.count(); i < c; i++) {
            var coord = these_sites.special.get(i);
            var ni = grid.node_index_for_cell(coord.x, coord.y);

            if grid.node_object_id[ni] == ObjectId.DigSite {
                erase_object_node(grid, ni);
            }

            if grid.node_object_id[ni] == undefined {
                self.working_special.push(coord);
            }
        }

        //
        if self.working_generic.count() == 0 && self.working_special.count() == 0 {
            return;
        }

        for (var i = 0; i < generic_max; i++) {
            var idx = irandom_range(0, self.working_generic.count() - 1);
            var location = self.working_generic.swap_remove(idx);

            var output = grid.write_node(location.x, location.y, ObjectId.DigSite);
            if output == undefined {
                if grid.location_id == LocationId.Farm {
                    //
                    i -= 1;
                } else {
                    error("We couldn't spawn a dig site at {LocationId}:{}x{}, even though we should have been able to.", grid.location_id, location.x, location.y);
                }
            }
        }

        for (var i = 0; i < special_max; i++) {
            var idx = irandom_range(0, self.working_special.count() - 1);
            var location = self.working_special.swap_remove(idx);

            var output = grid.write_node(location.x, location.y, ObjectId.DigSite);
            if output == undefined {
                error("We couldn't spawn a dig site at {LocationId}:{}x{}, even though we should have been able to.", grid.location_id, location.x, location.y);
            }
        }
    }

    //
    function choose_random_artifact() {
        var table = is_dungeon_room(room())
            ? self.dungeon_biome_tables[DUNGEON_BIOME]
            : self.location_loot_tables[CURRENT_LOCATION_ID];

        return table.get_candidate_votes_at_cell(GRID, 0, 0).get_candidate();
    }
}
