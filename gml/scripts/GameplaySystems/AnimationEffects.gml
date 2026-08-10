function create_animation_effect(_xx, _yy, _depth, _spr, live_on_anim_end=false) {
    var _inst = instance_create_depth(_xx, _yy, _depth, obj_animation_effect);
    _inst.sprite_index = _spr;
    _inst.live_on_anim_end = live_on_anim_end;

    return _inst;
}

function create_animation_effect_on_object(_object, _spr, _relative_depth, _y_offset=0, _x_offset=0, _lifetime_frames=undefined) {
    var _inst = instance_create_depth(_object.x, _object.y, _object.depth + _relative_depth, obj_animation_effect);
    _inst.sprite_index = _spr;
    _inst.following_object = _object;
    _inst.relative_depth = _relative_depth;
    _inst.x_offset = _x_offset;
    _inst.y_offset = _y_offset;
    _inst.lifetime_frames = _lifetime_frames;
    return _inst;
}

function create_debris(_x, _y, _depth, _sprite, _properties) {
    var _inst = instance_create_depth(
        _x + _properties.get_x_offset(),
        _y + _properties.get_y_offset(),
        _depth,
        obj_debris
    );
    with _inst {
        sprite_index = _sprite;
        image_index = irandom(image_number - 1);

        //
        image_speed = _properties.animate;

        image_angle = random_range(_properties.start_angle[0], _properties.start_angle[1]);
        angle_inc = choose(_properties.rot_spd, -_properties.rot_spd);
        lifetime = random_range(_properties.lifetime[0], _properties.lifetime[1]) * 60;
        dir = random_range(_properties.dir[0], _properties.dir[1]);
        if _properties.image_angle_equal_dir {
            image_angle = dir;
        }
        var scalar = random_range(_properties.rand_range[0], _properties.rand_range[1]);
        spd = _properties.spd * scalar;
        grav = _properties.grav * scalar;
        spd_inc = _properties.spd_inc * scalar;
        grav_inc = _properties.grav_inc * scalar;
        image_alpha = _properties.init_alpha;
        start_alpha_fadeout = _properties.start_alpha_fadeout;
        angle_lock = _properties.angle_lock;

        follow_obj = _properties.follow_obj;
        sway = _properties.sway;
        ydir = _properties.ydir;

        if _properties.on_floor {
            self.depth = get_floor_depth();
        }
    }
    return _inst;
}

//
function ParticleBundle() constructor {
    //
    animate = false;

    start_angle = [0, 0];
    rand_range = [0.5, 1];
    lifetime = [0.7, 1];
    init_alpha = 1;
    start_alpha_fadeout = 4/5;
    fadeout_after_one_loop = false;
    image_angle_equal_dir = false;

    x_offset = 0;
    y_offset = 0;
    spawn_rectangle = {
        x1: -2,
        x2: 2,
        y1: -2,
        y2: 2
    }

    instances = [3, 4];
    angle_lock = 45;

    spd = 2;
    grav = 0.08;
    spd_inc = -0.02;
    grav_inc = 0.066;

    dir = [60, 120];
    rot_spd = 10;
    size_inc = 0.00;

    follow_obj = undefined;
    sway = false;
    ydir = 270; //
    on_floor = false;

    //
    static get_instances = function() {
        return irandom_range(instances[0], instances[1]);
    }
    static get_x_offset = function() {
        return x_offset + random_range(spawn_rectangle.x1, spawn_rectangle.x2);
    }
    static get_y_offset = function() {
        return y_offset + random_range(spawn_rectangle.y1, spawn_rectangle.y2);
    }

    //
    static set_offset = function(_x, _y) {
        x_offset = _x;
        y_offset = _y;
        return self;
    }

    //
    static set_spawn_rectangle = function(x1, x2, y1, y2) {
        spawn_rectangle.x1 = x1;
        spawn_rectangle.x2 = x2;
        spawn_rectangle.y1 = y1;
        spawn_rectangle.y2 = y2;
        return self;
    }

    //
    static set_instances_range = function(_lower, _upper) {
        instances[0] = _lower;
        instances[1] = _upper;
        return self;
    }
    //
    static set_depth_on_floor = function() {
        on_floor = true;
        return self;
    }

    //
    static set_alpha_info = function(_init_alpha, _start_alpha_fadeout){
        init_alpha = _init_alpha;
        start_alpha_fadeout = _start_alpha_fadeout;
        return self;
    }
    //
    static set_animate = function(_bool) {
        animate = _bool;
        return self;
    }
    //
    static set_rand_range = function(_lower, _upper) {
        assert(_lower >= 0 && _lower <= 1 && _upper >= 0 && _upper <= 1, "lower and upper rand_range must be a scalar between 0-1");
        rand_range[0] = _lower;
        rand_range[1] = _upper;
        return self;
    }
    //
    static set_direction_range = function(_lower, _upper) {
        assert(_lower >= 0 && _lower <= 360 && _upper >= 0 && _upper <= 360, "dir range lower and upper are angles and must be between 0-360");
        dir[0] = _lower;
        dir[1] = _upper;
        return self;
    }
    //
    static set_starting_angle_range = function(_lower, _upper) {
        assert(_lower >= 0 && _lower <= 360 && _upper >= 0 && _upper <= 360, "dir range lower and upper are angles and must be between 0-360");
        start_angle[0] = _lower;
        start_angle[1] = _upper;
        return self;
    }
    //
    static set_lifetime_range = function(_lower, _upper) {
        lifetime[0] = _lower;
        lifetime[1] = _upper;
        return self;
    }

    //
    static set_speed = function(_val) {
        spd = _val;
        return self;
    }
    static set_gravity = function(_val) {
        grav = _val;
        return self;
    }
    static set_rotation_speed = function(_val) {
        rot_spd = _val;
        return self;
    }
    static set_image_angle_equal_dir = function() {
        image_angle_equal_dir = true;
        return self;
    }

    //
    static set_speed_increase = function(_val) {
        spd_inc = _val;
        return self;
    }
    static set_gravity_increase = function(_val) {
        grav_inc = _val;
        return self;
    }
    static set_size_increase = function(_val) {
        size_inc = _val;
        return self;
    }

    //
    static set_follow_object = function(_val) {
        follow_obj = _val;
        return self;
    }

    //
    static set_sway = function(_val) {
        sway = _val;
        return self;
    }
    //
    static set_sway_dir = function(_val) {
        ydir = _val;
        return self;
    }
    //
    static set_angle_lock = function(_val) {
        angle_lock = _val;
        return self;
    }
}

function ParticleFloatingBundle() : ParticleBundle() constructor {
    set_lifetime_range(1.5, 2.5);
    set_speed(0.3);
    set_speed_increase(-0.01);
    set_gravity(0.002);
    set_gravity_increase(0);
    set_animate(true);
    set_direction_range(0, 360);
    set_sway(true);
    set_sway_dir(270);
    set_rotation_speed(0);
    set_starting_angle_range(0, 360);
    set_angle_lock(90); //
}

function ParticleSmokeBundle() : ParticleBundle() constructor {
    set_lifetime_range(0.5, 1.25);
    set_speed(0.2);
    set_speed_increase(-0.01);
    set_gravity(0.002);
    set_gravity_increase(-0.01);
    set_animate(true);
    set_direction_range(0, 360);
    set_sway(true);
    set_sway_dir(0);
    set_rotation_speed(5);
    set_starting_angle_range(0, 360);
    set_animation_end_kill(true);
}

function ParticleRockBundle() : ParticleBundle() constructor {
    set_rotation_speed(18);
    set_speed_increase(-0.01);
    set_gravity(0.08);
    set_gravity_increase(0.07);
    set_angle_lock(90);
}

function ParticleDustBundle() : ParticleBundle() constructor {
    set_lifetime_range(0.7, 0.8);
    set_animate(false);
    set_rotation_speed(3);
    set_speed(0.7);
    set_speed_increase(-0.01);
    set_gravity(0.008);
    set_gravity_increase(0.02);
    set_direction_range(50, 130);
    set_instances_range(1, 2);
    set_size_increase(-0.01)
    set_alpha_info(0.9, 0.5);
    set_angle_lock(undefined);
}

function ParticleGrassBundle() : ParticleBundle() constructor {
    set_rotation_speed(0);
    set_animate(1);
    set_speed_increase(-0.02);
    set_gravity(0.08);
    set_gravity_increase(0.04);
    set_direction_range(60, 120);
    set_instances_range(1, 1);
}

function ParticleGrassExplosionBundle() : ParticleBundle() constructor {
    set_animate(true);
    set_speed_increase(-0.01);
    set_gravity(0.08);
    set_gravity_increase(0.04);
    set_direction_range(60, 120);
    set_starting_angle_range(0, 360);
    set_rotation_speed(0);
    set_angle_lock(90);
}

function ParticleBasicBundle() : ParticleBundle() constructor {
    set_offset(0, 0);
    set_spawn_rectangle(0, 0, 0, 0);
    set_instances_range(1, 1);
    set_animate(false);
    set_rand_range(1, 1);
    set_direction_range(0, 0);
    set_lifetime_range(1, 1);
    set_speed(0);
    set_gravity(0);
    set_rotation_speed(0);
    set_speed_increase(0);
    set_gravity_increase(0);
    set_size_increase(0);
}

//
function CoralDebris() : ParticleBundle() constructor {
    set_rand_range = [0.5, 1];
    set_lifetime = [0.7, 1];
    set_init_alpha = 1;
    set_start_alpha_fadeout = 4/5;
    set_lifetime_range(0.4, 0.7);
    set_instances_range(1, 1);
    set_rotation_speed(0);
}

function spawn_particle_rockclod_bundle(xx, yy, set_depth, spr) {
    static DEBRIS = new ParticleBundle()
        .set_lifetime_range(0.5, 0.75)
        .set_rotation_speed(9)
        .set_speed_increase(-0.005)
        .set_gravity(0.08)
        .set_gravity_increase(0.07)
        .set_angle_lock(90)
        .set_alpha_info(0.9, 0.0);

    var _rep = DEBRIS.get_instances();

    repeat _rep {
        create_debris(
            xx,
            yy,
            set_depth - 16,
            spr,
            DEBRIS,
        )
    }
}

function spawn_particle_blood(xx, yy, set_depth, spr) {
    static DEBRIS = new ParticleBundle()
        .set_lifetime_range(0.25, 0.3)
        .set_gravity(0.08)
        .set_angle_lock(90)
        .set_instances_range(1, 2)
        .set_direction_range(0, 360)
        .set_alpha_info(0.9, 0.0);

    var _rep = DEBRIS.get_instances();

    repeat _rep {
        create_debris(
            xx,
            yy,
            set_depth - 16,
            spr,
            DEBRIS,
        )
    }
}

function spawn_wood_debris(xx, yy, set_depth, spr) {
    static DEBRIS = new ParticleBundle()
        .set_instances_range(1, 2);
    var _rep = DEBRIS.get_instances();

    repeat _rep {
        create_debris(
            xx,
            yy,
            set_depth,
            spr,
            DEBRIS,
        )
    }
}

function spawn_cool_debris(xx, yy, set_depth, spr) {
    static DEBRIS = new ParticleBundle()
        .set_rotation_speed(0)
        .set_speed(3)
        .set_rand_range(1, 1)
        .set_spawn_rectangle(0, 0, 0, 0)
        .set_gravity(0.04)
        .set_animate(true);

    create_debris(
        xx,
        yy,
        set_depth,
        spr,
        DEBRIS,
    );
}


function spawn_critical_debris(xx, yy, set_depth, spr) {
    static DEBRIS = new ParticleBundle()
        .set_speed(1)
        .set_gravity(0.02)
        .set_angle_lock(90)
        .set_lifetime_range(0.25, 0.3)
        .set_rand_range(0.8, 1.0)
        .set_direction_range(0, 360)
        .set_animate(true);

    var i = create_debris(
        xx,
        yy,
        set_depth,
        spr,
        DEBRIS,
    );
    i.image_index = 0;
}
