//
//
//
//
//
//
//
//
//
//
function TarballBuilder(xx, yy, w, h, dmg, target=CombatTarget.Player) {
    return {
        position: Vec2(xx, yy),
        target: target,
        dimensions: Vec2(w, h),
        offset: undefined,
        persists: false,
        //
        notify_on_destroy_grid_objects: false,
        //
        notify_on_pick_grid_objects: false,
        pick_object_notifee: undefined,
        grid_object_notifee: undefined,
        //
        //
        can_destroy_grid_objects: true,

        //
        can_pick_grid_objects: false,

        //
        can_chop_grid_objects: false,

        //
        heavy: false,

        //
        critical: false,

        //
        flags: CombatFlag.Empty,

        //
        damage: dmg,

        //
        mask_idx: undefined,

        //
        circle: false,

        //
        parent_id: undefined,

        //
        //
        provenance: undefined,

        //
        stats_entry: undefined,

        //
        destruction_timer: undefined,

        //
        can_hit_count: undefined,

        //
        //
        //
        //
        override_offset: Vec2Zero(),

        //
        knockback: false,

        //
        //
        knockback_force: undefined,

        //
        knockback_radius: 0,

        //
        //
        //
        push_force_mask: undefined,

        //
        trauma: 0.0,

        //
        notifee: undefined,

        //
        //
        hit_notify_only: false,

        //
        electrocute_kind: undefined,

        venomous: false,
        frozen: false,
        fire_oil: false,
        instant_kill: false,

        //
        set_venomous: function(val) {
            self.venomous = val;
            return self;
        },

        set_frozen: function(val) {
            self.frozen = val;
            return self;
        },

        set_fire_oil: function(val) {
            self.fire_oil = val;
            return self;
        },

        set_instant_kill: function(val) {
            self.instant_kill = val;
            return self;
        },

        //
        //
        set_shield_break: function() {
            self.flags |= CombatFlag.ShieldBreak;
            return self;
        },

        //
        set_fire: function() {
            self.flags |= CombatFlag.Fire;
            return self;
        },

        //
        set_in_air: function() {
            self.flags |= CombatFlag.InAir;
            return self;
        },

        //
        set_electric: function(electrocute_kind) {
            self.flags |= CombatFlag.Electric;
            self.electrocute_kind = electrocute_kind;
            return self;
        },

        //
        set_acid: function() {
            self.flags |= CombatFlag.Acid;
            return self;
        },

        //
        set_rockstack: function() {
            self.flags |= CombatFlag.Rockstack;
            return self;
        },

        //
        set_parent: function(_parent_id) {
            self.parent_id = _parent_id;
            return self;
        },

        //
        notify: function(obj) {
            self.notifee = obj;
            return self;
        },

        //
        //
        set_mask_index: function(_mask_idx) {
            self.mask_idx = _mask_idx;
            return self;
        },

        set_circle: function() {
            self.circle = true;
            return self;
        },

        set_can_destroy_grid_objects: function(val, notify=false, notifee=undefined) {
            self.can_destroy_grid_objects = val;
            self.notify_on_destroy_grid_objects = notify;
            self.grid_object_notifee = notifee;
            return self;
        },

        set_can_pick_grid_objects: function(val, notify=false, notifee=undefined) {
            self.can_pick_grid_objects = val;
            self.notify_on_pick_grid_objects = notify;
            self.pick_object_notifee = notifee;
            return self;
        },

        set_can_chop_grid_objects: function(val) {
            self.can_chop_grid_objects = val;
            return self;
        },

        set_timer: function(_time) {
            self.destruction_timer = _time;
            return self;
        },

        set_trauma: function(_trauma) {
            self.trauma = _trauma;
            return self;
        },

        set_offset: function(xx, yy) {
            self.offset = Vec2(xx, yy);

            return self;
        },

        //
        set_override_pos_offset: function(_offset_x, _offset_y) {
            self.override_offset = Vec2(_offset_x, _offset_y);
            return self;
        },

        //
        set_knockback: function(lhs, rhs, knockback_radius) {
            self.knockback = true;
            self.knockback_force = Vec2(lhs, rhs);
            self.knockback_radius = knockback_radius;
            //
            if self.push_force_mask == undefined {
                self.push_force_mask = Vec2(1.0, 1.0);
            }
            return self;
        },

        //
        //
        set_push_force_mask: function(_push_x, _push_y) {
            self.push_force_mask = Vec2(_push_x, _push_y);

            return self;
        },

        //
        //
        destroy_on_hit: function() {
            return self.set_hit_count(1);
        },

        //
        set_heavy: function(is_heavy) {
            self.heavy = is_heavy;

            return self;
        },

        //
        set_critical: function(is_critical) {
            self.critical = is_critical;

            return self;
        },

        set_hit_count: function(_count) {
            self.can_hit_count = _count;
            return self;
        },

        set_provenance: function(_provenance, _stats_entry) {
            self.provenance = _provenance;
            self.stats_entry = _stats_entry;
            return self;
        },

        set_hit_notify_only: function(boo) {
            self.hit_notify_only = boo;
            return self;
        },

        set_persists: function() {
            self.persists = true;
            return self;
        },

        //
        gen: function() {
            var tarball_handle = instance_create_depth(self.position.x, self.position.y, 0, obj_damage_tarball);
            tarball_handle.persists = self.persists;
            tarball_handle.target = self.target;
            tarball_handle.flags = self.flags;
            tarball_handle.damage = self.instant_kill ? 999 : self.damage;
            tarball_handle.provenance = self.provenance;
            tarball_handle.stats_entry = self.stats_entry;
            tarball_handle.notifee = self.notifee;
            tarball_handle.hit_notify_only = self.hit_notify_only;
            tarball_handle.notify_on_destroy_grid_objects = self.notify_on_destroy_grid_objects;
            tarball_handle.notify_on_pick_grid_objects = self.notify_on_pick_grid_objects;
            tarball_handle.pick_object_notifee = self.pick_object_notifee;
            tarball_handle.grid_object_notifee = self.grid_object_notifee;

            tarball_handle.x = self.position.x;
            tarball_handle.y = self.position.y;
            tarball_handle.dimensions = self.dimensions;
            tarball_handle.offset = self.offset;

            if self.offset != undefined {
                tarball_handle.x += self.offset.x;
                tarball_handle.y += self.offset.y;
            }

            tarball_handle.override_offset = self.override_offset;
            tarball_handle.push_force_mask = self.push_force_mask;
            tarball_handle.knockback = self.knockback;
            tarball_handle.knockback_force = self.knockback_force;
            tarball_handle.knockback_radius = self.knockback_radius;

            tarball_handle.destruction_timer = self.destruction_timer;
            tarball_handle.can_hit_count = self.can_hit_count;
            tarball_handle.can_destroy_grid_objects = self.can_destroy_grid_objects;
            tarball_handle.can_pick_grid_objects = self.can_pick_grid_objects;
            tarball_handle.can_chop_grid_objects = self.can_chop_grid_objects;

            //
            if self.mask_idx != undefined {
                tarball_handle.mask_index = self.mask_idx;
                tarball_handle.collision_mode = TarballCollision.BuiltIn;

                //
                tarball_handle.dimensions.x = tarball_handle.bbox_right - tarball_handle.bbox_left;
                tarball_handle.dimensions.y = tarball_handle.bbox_bottom - tarball_handle.bbox_top;
            }

            if self.circle {
                tarball_handle.collision_mode = TarballCollision.Circle;
            }

            //
            tarball_handle.parent_id = self.parent_id;
            tarball_handle.heavy = self.heavy;
            tarball_handle.critical = self.critical;
            tarball_handle.electrocute_kind = self.electrocute_kind;
            tarball_handle.venomous = self.venomous;
            tarball_handle.frozen = self.frozen;
            tarball_handle.fire_oil = self.fire_oil;
            tarball_handle.instant_kill = self.instant_kill;

            //
            return tarball_handle;
        }
    };
}

//
function create_receiver(xx, yy, mask_idx, parent_id, data) {
    var dmg_rcvr = instance_create_depth(xx, yy, 0, obj_damage_receiver);

    dmg_rcvr.target = data[$ "target"] ?? CombatTarget.Enemy;
    dmg_rcvr.mask_index = mask_idx;

    if data[$ "offset"] != undefined {
        dmg_rcvr.x = xx + data.offset.x;
        dmg_rcvr.y = yy + data.offset.y;
        dmg_rcvr.offset = data.offset;
    }

    dmg_rcvr.parent_id = parent_id;
    dmg_rcvr.iframes = data[$ "iframes"] ?? 0;

    //
    return dmg_rcvr;
}
