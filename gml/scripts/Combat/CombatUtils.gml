//
enum CombatTarget {
    //
    Player          = 1 << 0,

    //
    Enemy           = 1 << 1,
}

//
//
enum CombatFlag {
    //
    Empty = 0,

    //
    ShieldBreak = 1 << 0,

    //
    InAir = 1 << 1,

    //
    Electric = 1 << 2,

    //
    Acid = 1 << 3,

    //
    Fire = 1 << 4,

    //
    Rockstack = 1 << 5,
}

//
//
enum TarballCollision {
    //
    BuiltIn,

    //
    RectInRect,

    //
    Circle,
}

//
//
//
enum ReceiverStatus {
    //
    Normal,

    //
    Blocking,

    //
    UntimedInvulnerable,

    //
    //
    Aerial,

    //
    DamageOnAttack,
}

enum DamageFlag {
    NONE = 0,

    HEAVY = 1 << 0,

    CRITICAL = 1 << 1,

    WEAK = 1 << 2,
}

function spawn_damage_numbers(originator, offset, dmg, dmg_flag, color_override=undefined, delay=10) {
    //
    if has_flag(dmg_flag, DamageFlag.HEAVY) {
        delay += 10;
    }

    new_chain()
        .append(LinkId.Timer, delay)
        .append(LinkId.Function, function(originator, xx, yy, offset, dmg, dmg_flag, color_override) {
            if instance_exists(originator) {
                xx = originator.x;
                yy = originator.y;
            }

            yy += offset;

            var i = instance_create_depth(xx, yy, 0, obj_damage_number, {
                damage: dmg,
                damage_flag: dmg_flag,
                kind: DamageNumber.Damage,
            });

            if dmg != 0 && color_override != undefined {
                i.image_blend = color_override;
            }
        }, [originator, originator.x, originator.y, offset, dmg, dmg_flag, color_override]);
}

function spawn_health_numbers(originator, offset, dmg, kind, delay=10) {
    new_chain()
        .append(LinkId.Timer, delay)
        .append(LinkId.Function, function(originator, xx, yy, offset, dmg, kind) {
            if instance_exists(originator) {
                xx = originator.x;
                yy = originator.y;
            }
            yy += offset;

            instance_create_depth(xx, yy, 0, obj_damage_number, {
                damage: dmg,
                kind,
                damage_flag: DamageFlag.NONE,
            });
        }, [originator, originator.x, originator.y, offset, dmg, kind]);
}
