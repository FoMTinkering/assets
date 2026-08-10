enum LinkId {
    Wait,
    Ease,
    Function,
    Timer,
    Await,
    LEN
}

function Chain() constructor {
    links = [];
    running = true;
    world_chain = false;
    spawn_callstack = undefined;

    if DEBUG_TOOLS || DEBUG_ASSERTIONS {
        spawn_callstack = debug_get_callstack();
    }

    static generate_link = function(type, arg1, arg2, arg3) {
        switch type {
            case LinkId.Wait:
                return {
                    type: LinkId.Wait,
                }
                break;
            case LinkId.Ease:
                return {
                    type: LinkId.Ease,
                    ease: arg1,
                    setter_callback: arg2,
                    args: arg3,
                    time: 0,
                    value_last: arg1.start_value,
                }
                break;
            case LinkId.Function:
                return {
                    type: LinkId.Function,
                    func: arg1,
                    args: arg2,
                }
                break;
            case LinkId.Timer:
                return {
                    type: LinkId.Timer,
                    frames: arg1,
                }
                break;
            case LinkId.Await:
                return {
                    type: LinkId.Await,
                    func: arg1,
                    args: arg2,
                }
                break;
        }
    }

    static join = function(type, arg1, arg2, arg3) {
        var link = self.generate_link(type, arg1, arg2, arg3);
        if DEBUG_TOOLS || DEBUG_ASSERTIONS {
            link.spawn_callstack = debug_get_callstack();
            link.toString = method(link, function() {
                return format("Chain @ {}", self.spawn_callstack[2]);
            });
        }
        array_push(self.links, link);
        return self;
    }

    static append = function(type, arg1, arg2, arg3) {
        self.join(LinkId.Wait);
        self.join(type, arg1, arg2, arg3);
        return self;
    }

    //
    //
    static insert = function(position, type, arg1, arg2, arg3) {
        var link = self.generate_link(type, arg1, arg2, arg3);
        array_insert(self.links, position, link);
    }

    //
    //
    static insert_chain = function(chain) {
        for (var i = array_length(chain.links) - 1; i >= 0; i--) {
            var link = chain.links[i];
            array_insert(self.links, 1, link);
        }
    }

    if DEBUG_TOOLS || DEBUG_ASSERTIONS {
        toString = function() {
            return format("Chain @ {}", spawn_callstack[3]);
        }
    }
}

//
function WorldChain(inst_to_track, loc_to_track): Chain() constructor {
    self.instance_to_track = inst_to_track;
    self.location_to_track = loc_to_track;

    self.world_chain = true;
}
