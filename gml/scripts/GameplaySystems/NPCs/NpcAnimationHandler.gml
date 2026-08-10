
function NpcAnimationHandler(owner) constructor {
    self.sprite_pack_collection = undefined;
    self.loops_requested = I32_MAX;
    self.loop_count = 0;
    self.complex_index = 0;
    self.animation_is_over = false;
    self.hold_last_frame_flag = false;
    self.cardinality = Cardinal.South;
    self.current = undefined;
    self.tango_instance = undefined;
    self.owner = owner;

    //
    function set_animation(collection) {
        if self.sprite_pack_collection != collection {
            self.set_animation_raw(collection);
        }
    }

    //
    function set_animation_raw(collection) {
        self.sprite_pack_collection = collection;
        self.loop_count = 0;
        self.loops_requested = I32_MAX;
        self.complex_index = 0;
        self.animation_is_over = false;
        self.hold_last_frame_flag = false;
        self.update_sprite();
    }

    //
    function update_sprite() {
        if self.complex_index == 0 {
            self.trigger_sound();
        }
        var sprite = self.retrieve_sprite();
        self.current = {
            index: 0,
            frame: 0,
            sprite: sprite,
            info: sprite_get_info(sprite),
        };
    }

    //
    function trigger_sound() {
        self.stop_sound();
        if self.sprite_pack_collection.sound != undefined {
            var sound = TANGO.play(self.sprite_pack_collection.sound, self.owner.x, self.owner.y);
            if self.sprite_pack_collection.detach_sound == false {
                self.tango_instance = sound;
            }

        }
    }

    //
    function stop_sound() {
        if self.tango_instance != undefined {
            if TANGO.instance_alive(self.tango_instance) {
                TANGO.force_stop(self.tango_instance);
            }
            self.tango_instance = undefined;
        }
    }

    //
    function set_cardinality(cardinality) {
        self.cardinality = cardinality;
        if self.current != undefined {
            self.current.sprite = self.retrieve_sprite();
            self.current.info = sprite_get_info(self.current.sprite);
            //
            //
            self.current.index = min(self.current.index, self.current.info.num_subimages - 1);
        }
    }

    //
    function set_index(index) {
        self.current.index = index;
        self.current.frame = self.current.info.frame_info[index].frame;
    }

    //
    function retrieve_pack() {
        switch self.sprite_pack_collection.type {
            case SpritePackCollectionType.Single:
                return self.sprite_pack_collection.pack;
            case SpritePackCollectionType.Multi:
                switch self.cardinality {
                    case Cardinal.North:
                        return self.sprite_pack_collection.north_pack;
                    case Cardinal.South:
                        return self.sprite_pack_collection.south_pack;
                    case Cardinal.East:
                    case Cardinal.West:
                        return self.sprite_pack_collection.horz_pack;
                    default: impossible("got cardinality {}, which was unexpected", self.cardinality);
                }
            default: impossible("got sprite pack collection type {}, which was unexpected", self.sprite_pack_collection.type);
        }
    }

    //
    function retrieve_sprite() {
        var pack = self.retrieve_pack();
        switch pack.type {
            case SpritePackType.Linear:
                return pack.sprite;
            case SpritePackType.Complex:
                switch self.complex_index {
                    case 0:
                        return pack.start;
                    case 1:
                        return pack.loop;
                    case 2:
                        return pack.stop;
                    default: impossible();
                }
                break;
            default: impossible();
        }
    }

    //
    function set_loop_infinite() {
        self.loops_requested = I32_MAX;
    }

    //
    function set_loop_x_times(xx) {
        self.loops_requested = xx;
    }

    function next_tick_values(speed) {
        static RET = {
            next_frame: undefined,
            next_index: undefined,
            completed: undefined,
        };
        var images = self.current.info.num_subimages;
        var infos = self.current.info.frame_info;

        var next_keyframe;
        if self.current.index + 1 == self.current.info.num_subimages {
            next_keyframe = self.sprite_pack_collection.last_frame_hold != undefined
                ? irandom_range(self.sprite_pack_collection.last_frame_hold[0], self.sprite_pack_collection.last_frame_hold[1])
                : infos[images - 1].frame + infos[images - 1].duration;
        } else {
            next_keyframe = infos[self.current.index + 1].frame;
        }

        RET.next_index = self.current.index;
        RET.next_frame = self.current.frame + speed * (40 / 60); //
        if (RET.next_frame >= next_keyframe) {
            RET.next_index += 1;
        }

        RET.completed = RET.next_index >= images;

        return RET;
    }

    function animate(speed) {
        if self.tango_instance != undefined {
            TANGO.update_instance_position(self.tango_instance, self.owner.x, self.owner.y);
        }
        if speed != 0 && !self.animation_is_over {
            var info = self.next_tick_values(speed);
            self.current.frame = info.next_frame;
            self.current.index = info.next_index;

            if info.completed {
                self.loop_count += 1;

                //
                switch self.retrieve_pack().type {
                    case SpritePackType.Linear:
                        self.animation_is_over = self.loop_count >= self.loops_requested;
                        if self.animation_is_over && self.hold_last_frame_flag {
                            //
                            self.current.index -= 1;
                        } else {
                            self.update_sprite();
                        }
                        break;
                    case SpritePackType.Complex:
                        switch self.complex_index {
                            case 0:
                                self.complex_index = 1;
                                break;
                            case 1:
                                if self.loop_count >= self.loops_requested {
                                    self.complex_index = 2;
                                }
                                break;
                            case 2:
                                self.animation_is_over = true;
                                self.complex_index = 0;
                                break;
                            default: impossible();
                        }
                        self.update_sprite();
                        break;
                }
            }
        }
    }

    function sprite() {
        return self.current.sprite;
    }

    function index() {
        return self.current.index;
    }
}


enum SpritePackCollectionType {
    Single,
    Multi,
}

function SpritePackCollectionFactory() constructor {
    static Single = function(pack) {
        return {
            type: SpritePackCollectionType.Single,
            is_seated: false,
            can_talk: true,
            sound: undefined,
            last_frame_hold: undefined,
            pack: pack,
            pack_type: function() {
                return self.pack.type;
            },
        };
    }
    static Multi = function(north_pack, south_pack, horz_pack) {
        return {
            type: SpritePackCollectionType.Multi,
            is_seated: false,
            can_talk: true,
            sound: undefined,
            last_frame_hold: undefined,
            north_pack: north_pack,
            south_pack: south_pack,
            horz_pack: horz_pack,
            pack_type: function() {
                return self.north_pack.pack_type; //
            },
        };
    }
}

global.__sprite_pack_collection_factory = new SpritePackCollectionFactory();
#macro SpritePackCollection global.__sprite_pack_collection_factory

enum SpritePackType {
    Linear,
    Complex,
}

function SpritePackFactory() constructor {
    static Linear = function(sprite) {
        return {
            type: SpritePackType.Linear,
            sprite: sprite,
            toString: function() {
                return fmt("SpritePack.Linear({})", asset_to_string(sprite));
            }
        };
    }
    static Complex = function(start, loop, stop) {
        return {
            type: SpritePackType.Complex,
            start: start,
            loop: loop,
            stop: stop,
            toString: function() {
                return fmt("SpritePack.Complex({}, {}, {})", asset_to_string(start), asset_to_string(loop), asset_to_string(stop));
            }
        };
    }
}

global.__sprite_pack_factory = new SpritePackFactory();
#macro SpritePack global.__sprite_pack_factory
