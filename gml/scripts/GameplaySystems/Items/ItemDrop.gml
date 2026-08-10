function ItemDropBundle(incoming, functor) constructor {
    self.functor = functor;
    self.exclusive_drops = List();
    self.drops = List();

    incoming.sort(function(lhs, rhs) {
        return cmp(lhs.chance, rhs.chance);
    });

    //
    var exclusive_queue = List();
    for (var i = 0; i < incoming.count(); i++) {
        var drop = incoming.get(i);

        if drop.is_exclusive {
            exclusive_queue.push(drop);
        } else {
            self.drops.push(drop);
        }
    }

    //
    //
    for (var i = 0; i < exclusive_queue.count(); i++) {
        var drop = exclusive_queue.get(i);
        var new_sub_list = List(drop);

        //
        while true {
            var next_drop = exclusive_queue.try_get(i + 1);
            if next_drop == undefined || next_drop.chance != drop.chance {
                break;
            }

            i += 1;
            new_sub_list.push(next_drop);
        }

        self.exclusive_drops.push(new_sub_list);
    }

    //
    static choose_drop = function(bonus=1) {
        var output = List();

        for (var i = 0, c = self.drops.count(); i < c; i++) {
            var drop = self.drops.get(i);

            //
            if chance_percent((drop.chance + ARI.perk_value(Perk.PerfectPick) * drop.perfect_pick_chance) * bonus) || TEST_SUITE {
                output.push(drop);
            }
        }

        //
        for (var i = 0, c = self.exclusive_drops.count(); i < c; i++) {
            var drop_list = self.exclusive_drops.get(i);

            if chance_percent(drop_list.first().chance) || TEST_SUITE {
                output.push(drop_list.choose_random());
                break;
            }
        }

        var real_output = List();
        for (var i = 0; i < output.count(); i++) {
            var drop = output.get(i);

            var r = irandom_range(drop.count_range[0], drop.count_range[1]);
            repeat r {
                var o;
                if self.functor != undefined {
                    o = self.functor(drop.item_id);
                } else {
                    o = new LiveItem(drop.item_id);
                }
                real_output.push(o);
            }
        }

        return real_output;
    }
}

//
//
//
//
//
function ItemDrop(chance, exclusive, item_id, count_range, perfect_pick_chance) constructor {
    self.chance = chance;
    self.is_exclusive = exclusive;
    self.item_id = item_id;
    self.count_range = count_range;
    self.perfect_pick_chance = perfect_pick_chance;
}
