#macro HELD_ITEM_ANIMATIONS global.__hia_par
global.__hia_par = setup_held_item_animations();

enum AnimatorOutput {
    FrameComplete,
    AnimationComplete,
}

enum PlayerAnimationEndBehavior {
    Normal,
    Loop,
    HoldLastFrame,

    LEN,
}

enum AnimationSlot {
    BaseArmLeft,
    BaseArmRight,
    BaseChest,
    BaseHead,
    BaseLegs,
    SleeveRight,
    SleeveLeft,
    Tool,
    ToolEffect,
    HairMid,
    HairBack,
    HeldItem,
    Eyes,
    Feet,
    Legs,
    Torso,
    Waist,
    BaseEffect,
    FaceGear,
    Face,
    FacialHair,
    HeadGear,
    BackGear,
    HairFront,
    HeadGearBack,
    LegsTop,
    BabyBack,

    LEN
}

enum AnimationName {
    Idle,
    Blink,
    Walk,
    Run,
    Pickup,
    Throw,
    Jump,
    Combo1,
    Combo2,
    Combo3,
    DownAttack,
    SpellcastStart,
    SpellcastLoop,
    SpellcastEnd,
    Hurt,
    HurtBlink,
    EyesClosed,
    Water,
    Axe,
    ChargeHoe,
    Till,
    Sow,
    Shovel,
    Net,
    Saw,
    FishCast,
    FishBite,
    FishReel,
    Action,
    SwimIdle,
    Swim,
    Submerge,
    Emerge,
    SwimCelebrate,
    Celebrate,
    Eat,
    Identify,
    Kiss,
    Sneeze,
    Sweat,
    Tired,
    Cold,
    SleepStart,
    SleepLoop,
    SleepEnd,
    Sit,
    SitCelebrate,
    Ride,
    RideWalk,
    RideRun,
    RideJump,
    Faint,

    LEN
}

enum ToolEffect {
    None,
    Critical,

    //
    Fire,
    Ice,
    Venom,
}

enum Attachment {
    Tool,
    ToolEffect,
    ToolEffectCritical,
    ToolEffectFire,
    ToolEffectFireOutline,
    ToolEffectIce,
    ToolEffectIceOutline,
    ToolEffectVenom,
    ToolEffectVenomOutline,

    LEN
}

//
enum BroadcastMessage {
    EMPTY                   = 0,
    EMIT_FOOTSTEP_SOUND     = 1,
    PUSH_FORWARD            = 1 << 1,
    CREATE_TARBALL          = 1 << 2,
    START_ACTION            = 1 << 3,
    FINISH_ACTION           = 1 << 4,
    CHARGE_FRAME            = 1 << 5,
}

function setup_held_item_animations() {
    var held_item_animations = array_bool(AnimationName.LEN);

    held_item_animations[AnimationName.Pickup] = true;
    held_item_animations[AnimationName.Throw] = true;
    held_item_animations[AnimationName.Sow] = true;
    held_item_animations[AnimationName.Eat] = true;
    held_item_animations[AnimationName.Identify] = true;
    held_item_animations[AnimationName.Celebrate] = true;
    held_item_animations[AnimationName.SwimCelebrate] = true;

    return held_item_animations;
}

function multiple_player_animation_runtimes() {
    return instance_exists(obj_void_ari)
        || ANCHOR.get_menu(Menu.Customization) != undefined
        || ANCHOR.get_menu(Menu.Load) != undefined;
}
