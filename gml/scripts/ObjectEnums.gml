enum MushroomState {
    Idle,
    Acknowledgment,
    Walk,
    WindupSlide,
    Windup,
    Attack,
    Tired,
    Shell,
    Wiggle,
    WiggleExit,
    Dying,
    Explode,

    LEN
}

enum RockclodState {
    Idle,
    Acknowledgment,
    Walk,
    Windup,
    Attack,
    Tired,
    Hurt,
    Dying,
    Flying,

    LEN
}

enum SaplingState {
    Idle,
    Acknowledgment,
    Walk,
    Windup,
    Attack,
    Tired,
    Hurt,
    Dying,
    Splitting,
    LEN
}

enum EnchanternState {
    Idle,
    Acknowledgment,
    FlickerOn,
    Charge,
    Flee,
    GoHome,
    Hurt,
    Dying,

    LEN
}

enum ElectrocuteKind {
    Yellow,
    Blue,
}

enum MiteState {
    Idle,
    Walk,
    Windup,
    Attack,
    Tired,
    Flee,
    Hurt,
    Dying,

    LEN
}

enum BatState {
    Idle,
    Acknowledgment,
    Walk,
    Windup,
    Attack,
    Hurt,
    Dying,
    Flee,

    LEN
}

enum MimicState {
    Idle,
    Attack,
    Hurt,
    Gobble,
    Dying,
    Fade,

    LEN
}

enum SpiritState {
    Idle,
    Teleport,
    Windup,
    Attack,
    Tired,
    Hurt,
    Dying,
    Acknowledgment,
    Recovery,

    LEN
}

enum CatState {
    Idle,
    Acknowledgment,
    Walk,
    Windup,
    Attack,
    Tired,
    Petrified,
    Hurt,
    Dying,
    LEN
}

enum RockStackState {
    Idle,
    Acknowledgment,
    Walk,
    Windup,
    Hurt,
    Launching,
    Catching,
    Dying,
    Hopping,

    LEN
}

enum BirdState {
    Idle,
    Fly,
    Animate,

    LEN
}

enum BirdAction {
    Fly,
    Look,
    Sleep,

    LEN
}

enum Shrine {
    Health,
    Stamina,
    Essence,

    LEN
}

enum BobberState {
    Cast,
    InWater,
    Reel,
    LEN
}

enum BugStateId {
    Idle,
    Move,
    CanopySpawn,
    Flee,
}

enum DamageNumber {
    Damage,
    Health,
    Stamina,
}

enum OpenStateId {
    Closed,
    Opening,
    Open,
    Closing,
    LEN,
}

enum MimicAttackState {
    Init,
    Main,
    Done,
}

enum EnchanternProjectileState {
    Start,
    Main,
    Impact,
    Fizzle,
}

enum RockStackPosition {
    Top,
    Bottom
}

enum WindupState {
    Start,
    Hold,
    LastFrame,
}

enum StarsState {
    FadeIn,
    Normal,
    FadeOut,
}

enum MorselState {
    Init,
    Settle,
    Chase,

    LEN,
}

enum PetState {
    Idle,
    Wander,
    Animate,
    Pathfinding,
    Held,
    MoveDirected,
    UsingToy,
    Cutscene,

    LEN,
}

enum ShootingStarState {
    Start,
    Loop,
    End,
}

enum Daytime {
    Day,
    Dusk,
    Night,
    Weather,
    LEN
}

enum TileCursorState {
    Hidden,
    Idle,
    Selected,
}

enum InteractableMode {
    Circle,
    Bbox,
    Box,
}

enum LadderState {
    Spawned,
    Unspawned,
    TrapdoorClosed,
    TrapdoorOpening,
    LEN
}

enum NpcState {
    Default,
    Pathfinding,
    Dummy,
    LEN
}

enum DummyExitConditionId {
    Timer,
    Position,
    Never,
}

enum StatueState {
    Acknowledgment,
    Idle,
    Chase,
    Tumbling,
    Dying,

    LEN,
}

enum TomeState {
    Acknowledgment,
    Stunned,
    Idle,
    Windup,
    StunAttack,
    Flying,
    Hurt,
    Dying,
    GentleStun,
    LEN
}

enum PerpetualSoupStatus {
    Used = -1,
    NoItem = 0,
    Ready = 1,
}
