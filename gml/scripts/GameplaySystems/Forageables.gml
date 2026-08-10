#macro FORAGEABLES global.__forageables
global.__forageables = undefined;

enum ForageableRarity {
    Common,
    Uncommon,
    Rare,
    Legendary,

    LEN
}

function Forageables() constructor {
    self.working_list = List();

    //
    self.candidate_positions = array_create(LocationId.LEN, undefined);
    self.distribution = new SpawnDistribution();

    var f = fiddle_get("forageables");
    self.votes = struct_to_array(f.votes, ForageableRarity.LEN, string_to_forageable_rarity);

    for (var season = 0; season < Season.LEN; season++) {
        var season_table = f[$ season_to_string(season)];

        for (var rarity = 0; rarity < ForageableRarity.LEN; rarity++) {
            var rarity_list = season_table[$ forageable_rarity_to_string(rarity)];

            //
            for (var i = 0; i < array_length(rarity_list); i++) {
                var obj = string_to_object_id(rarity_list[i]);
                assert_eq(object_id_to_object_category(obj), ObjectCategory.Crop);
                var conditions = new SpawnConditions();
                conditions.require(Condition.CurrentSeason(season));
                conditions.require(Condition.Invert(Condition.Sand));
                conditions.add(self.votes[rarity], Condition.None);

                //
                switch obj {
                    case ObjectId.Middlemist:
                        conditions.add(0, Condition.CurrentLocation(LocationId.Summit));
                        break;
                    case ObjectId.Marigold:
                        conditions.add(0, Condition.CurrentLocation(LocationId.WesternRuins));
                        break;
                    case ObjectId.Cosmos:
                        conditions.add(0, Condition.CurrentLocation(LocationId.HaydensFarm));
                        break;
                }

                //
                self.distribution.add_candidate(obj, conditions);
            }
        }
    }

    //
    for (var i = 0; i < array_length(f.sand_forageables); i++) {
        var conditions = new SpawnConditions();
        conditions.add(self.votes[ForageableRarity.Common], Condition.None);
        conditions.require(Condition.Sand);

        var obj = string_to_object_id(f.sand_forageables[i]);
        assert_eq(object_id_to_object_category(obj), ObjectCategory.Crop);

        self.distribution.add_candidate(obj, conditions);
    }

    function get_or_create_candidate_list(location_id) {
        var output = self.candidate_positions[location_id]
        if output == undefined {
            output = List();
            self.candidate_positions[location_id] = output;
        }

        return output;
    }

    function spawn_forageables(grid) {
        var candidates = self.candidate_positions[grid.location_id];
        var spawn_cap = LOCATIONS[grid.location_id].forageables;

        if candidates == undefined || spawn_cap == 0 {
            return;
        }

        self.working_list.clear();
        var forageables_present = 0;

        for (var i = 0, c = candidates.count(); i < c; i++) {
            var coord = candidates.get(i);
            var ni = grid.node_index_for_cell(coord.x, coord.y);

            if grid.node_object_id[ni] == undefined {
                self.working_list.push(coord);
            } else if
                grid.node_object_id[ni] != undefined
                && object_id_to_object_category(grid.node_object_id[ni]) == ObjectCategory.Crop
                && has_flag(grid.node_parent[ni].ctx, CropFlag.FORAGEABLE)
            {
                forageables_present += 1;
            }
        }

        if self.working_list.count() == 0 {
            return;
        }

        //
        var should_spawn = max(spawn_cap - forageables_present, 0);
        if should_spawn > self.working_list.count() {
            warn(
                "There are not enough free forageable spots in {LocationId}, place at least {} more in the room editor!",
                grid.location_id,
                should_spawn - positions.count(),
            );
            should_spawn = self.working_list.count();
        }

        //
        repeat should_spawn {
            var idx = irandom_range(0, self.working_list.count() - 1);
            var coord = self.working_list.swap_remove(idx);
            var is_sand = false;
            if grid.location_id == LocationId.Beach {
                //
                is_sand = grid.node_footstep_kind[grid.node_index_for_cell(coord.x, coord.y)] == FootstepKind.Sand;
            }

            var object = self.roll_forageable_at_location(grid, coord.x, coord.y);

            if object != undefined {
                grid.write_node(coord.x, coord.y, object, CropFlag.FORAGEABLE | CropFlag.SPAWN_GROWN);
            }
        }
    }

    function roll_forageable_at_location(grid, xx, yy) {
        return self.distribution.get_candidate_votes_at_cell(grid, xx, yy).get_candidate();
    }
}
