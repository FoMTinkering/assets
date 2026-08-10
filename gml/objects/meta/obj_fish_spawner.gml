object_create(
    "obj_fish_spawner",
    undefined,
    {
        sprite_index: spr_blue_block,
        dive_spawn_maximum: 0.0,
        dive_spawn_minimum: 0.0,
        fish_spawn_maximum: 0.0,
        fish_spawn_minimum: 0.0,
        giant_fish_votes: 1.0,
        large_fish_votes: 1.0,
        medium_fish_votes: 1.0,
        school_spawn_maximum: 0.0,
        school_spawn_minimum: 0.0,
        small_fish_votes: 1.0,
        water_kind: WaterType.Pond,
        visible: false,
        create: function() {
            self.fish_id = undefined;

            self.spawn_count = array_create(FishSpawn.LEN, undefined);
            self.spawn_count[FishSpawn.Fish] = irandom_range(fish_spawn_minimum, fish_spawn_maximum);
            self.spawn_count[FishSpawn.Divespot] = irandom_range(dive_spawn_minimum, dive_spawn_maximum);
            self.spawn_count[FishSpawn.School] = irandom_range(school_spawn_minimum, school_spawn_maximum);

            self.size_locations = array_create_ext(FishSize.LEN, EmptyList);
            var boundary = Vec4(
                self.bbox_left div 16,
                self.bbox_top div 16,
                self.bbox_right div 16,
                self.bbox_bottom div 16,
            );

            var fish_sizes = strict_layer_tilemap_get_id(strict_layer_get_id("Tiles_Fish_Size"));
            for (var yy = boundary.y1; yy < boundary.y2; yy++) {
                for (var xx = boundary.x1; xx < boundary.x2; xx++) {
                    var size_data = tilemap_get(fish_sizes, xx, yy);
                    if size_data == 0 {
                        continue;
                    }

                    //
                    self.size_locations[size_data - 1].push(Vec2(xx * 16, yy * 16));
                }
            }

            self.fish_votes = new SlowVotes();

            fish_votes.add_candidate(FishSize.Small, small_fish_votes);
            fish_votes.add_candidate(FishSize.Medium, medium_fish_votes);
            fish_votes.add_candidate(FishSize.Large, large_fish_votes);
            fish_votes.add_candidate(FishSize.Giant, giant_fish_votes);

            function find_fallback_position() {
                var position = undefined;
                var offset = irandom_range(0, FishSize.LEN - 1);
                for (var fs = 0; fs < FishSize.LEN; fs++) {
                    //
                    var output = (offset + fs) % FishSize.LEN;
                    position = self.size_locations[output].choose_random();
                    if position != undefined {
                        break;
                    }
                }

                if position == undefined {
                    error("Fallback position failed! Returning top-left corner...this will likely fail.");
                    return Vec2(x, y);
                } else {
                    return position;
                }
            }
        },
    }
);
