#macro CHAINS global.__chains
CHAINS = undefined;

function ChainManager() constructor {
    self.chains = [];
    self.pending_removals = [];

    //
    //
    function new_chain() {
        var chain = new Chain();
        array_push(self.chains, chain);
        return chain;
    }

    //
    //
    function new_world_chain(inst_to_track, loc_to_track) {
        var world_chain = new WorldChain(inst_to_track, loc_to_track);
        array_push(self.chains, world_chain);
        return world_chain;
    }

    //
    //
    function cancel_chain(chain) {
        chain.running = false;
    }

    function clear_pending_chains() {
        while !array_is_empty(self.pending_removals) {
            var chain = array_pop(self.pending_removals);
            var pos = array_index(self.chains, chain);
            assert_neq(pos, undefined, "Tried to cancel a chain that does not exist!");
            array_delete(self.chains, pos, 1);
        }
    }

    function on_begin_step() {
        if DEBUG_TOOLS {
            var span = profile_span_start("ChainManager::on_begin_step");
        }
        self.clear_pending_chains();
        for (var i = 0; i < array_length(self.chains); i++) {
            var chain = self.chains[i];

            if !chain.running || run_chain(chain) {
                chain.running = false;
                array_push(self.pending_removals, chain);
            }
        }
        self.clear_pending_chains();

        if DEBUG_TOOLS {
            profile_span_stop(span);
        }
    }
}

//
function new_chain() {
    return CHAINS.new_chain()
}

//
//
function new_world_chain(inst_to_track, loc_to_track) {
    return CHAINS.new_world_chain(inst_to_track, loc_to_track)
}

//
function run_chain(chain) {
    if chain.world_chain {
        if chain.instance_to_track != undefined && instance_exists(chain.instance_to_track) == false {
            //
            return true;
        }

        //
        if non_cutscene_pause() {
            return false;
        }
    }


    for (var j = 0; j < array_length(chain.links); j++) {
        var blocked = false;
        var completed = false;
        var link = chain.links[j];

        if is_struct(link) == false {
            error("Link is: {}", link);

            crash("unexpected `link` type!");
        }

        switch link.type {
            case LinkId.Wait:
                if j == 0 {
                    completed = true;
                    break;
                }
                blocked = true;
                break;
            case LinkId.Ease:
                ++link.time;
                var abs_val = link.ease.calculate_value(link.time);
                var delta_val = abs_val - link.value_last;
                var args = link.args == undefined ? [] : link.args;
                switch array_length(args) {
                    case 0:  link.setter_callback(delta_val, abs_val); break;
                    case 1:  link.setter_callback(delta_val, abs_val, args[0]); break;
                    case 2:  link.setter_callback(delta_val, abs_val, args[0], args[1]); break;
                    case 3:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2]); break;
                    case 4:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3]); break;
                    case 5:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4]); break;
                    case 6:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5]); break;
                    case 7:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6]); break;
                    case 8:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]); break;
                    case 9:  link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]); break;
                    case 10: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]); break;
                    case 11: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]); break;
                    case 12: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]); break;
                    case 13: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12]); break;
                    case 14: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13]); break;
                    case 15: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14]); break;
                    case 16: link.setter_callback(delta_val, abs_val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15]); break;
                }
                link.value_last = abs_val;
                if link.time >= link.ease.duration { //
                    completed = true;
                }
                break;
            case LinkId.Function:
                var args = link.args == undefined ? [] : link.args;
                switch array_length(args) {
                    case 0:  link.func(); break;
                    case 1:  link.func(args[0]); break;
                    case 2:  link.func(args[0], args[1]); break;
                    case 3:  link.func(args[0], args[1], args[2]); break;
                    case 4:  link.func(args[0], args[1], args[2], args[3]); break;
                    case 5:  link.func(args[0], args[1], args[2], args[3], args[4]); break;
                    case 6:  link.func(args[0], args[1], args[2], args[3], args[4], args[5]); break;
                    case 7:  link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]); break;
                    case 8:  link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]); break;
                    case 9:  link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]); break;
                    case 10: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]); break;
                    case 11: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]); break;
                    case 12: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]); break;
                    case 13: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12]); break;
                    case 14: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13]); break;
                    case 15: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14]); break;
                    case 16: link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15]); break;
                }
                completed = true;
                break;
            case LinkId.Timer:
                --link.frames;
                if link.frames == -1 {
                    completed = true;
                }
                break;
            case LinkId.Await:
                var args = link.args == undefined ? [] : link.args;
                switch array_length(args) {
                    case 0:  completed = link.func(); break;
                    case 1:  completed = link.func(args[0]); break;
                    case 2:  completed = link.func(args[0], args[1]); break;
                    case 3:  completed = link.func(args[0], args[1], args[2]); break;
                    case 4:  completed = link.func(args[0], args[1], args[2], args[3]); break;
                    case 5:  completed = link.func(args[0], args[1], args[2], args[3], args[4]); break;
                    case 6:  completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5]); break;
                    case 7:  completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]); break;
                    case 8:  completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]); break;
                    case 9:  completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]); break;
                    case 10: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]); break;
                    case 11: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]); break;
                    case 12: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]); break;
                    case 13: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12]); break;
                    case 14: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13]); break;
                    case 15: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14]); break;
                    case 16: completed = link.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], args[12], args[13], args[14], args[15]); break;
                }
                if DEBUG_ASSERTIONS {
                    assert(completed == false || completed == true, "Link did not return a bool: `{}` / `{}`", link, typeof(link));
                }
                break;
            default: impossible("unexpected link_type: {}", link);
        }

        if blocked {
            break;
        }
        if completed {
            array_delete(chain.links, j, 1);
            j -= 1;
        }
    }

    return array_length(chain.links) == 0;
}

function world_chain_clean_locations(chain_array, new_location_id) {
    var chain;
    for (var i = 0; i < array_length(chain_array); i++) {
        chain = chain_array[i];

        if chain.world_chain
            && chain.location_to_track != undefined
            && chain.location_to_track != new_location_id
        {
            array_delete(chain_array, i, 1);
            chain.running = false;

            i -= 1;
        }
    }
}
