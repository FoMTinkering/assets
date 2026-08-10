#macro MEMORY_FIVE_MINUTES      18000

#macro MEMORY_USED global.__memory_level
global.__memory_level = 0;

#macro MEMORY_EMERGENCY_TIMER global.__memory_emergency_timer
MEMORY_EMERGENCY_TIMER = MEMORY_FIVE_MINUTES;

function manual_gc_check() {
    MEMORY_EMERGENCY_TIMER -= 1;

    if MEMORY_EMERGENCY_TIMER <= 0 {
        manual_gc_cycle();
        MEMORY_EMERGENCY_TIMER = MEMORY_FIVE_MINUTES;
    }
}

function manual_gc_cycle() {
    //
    gc_collect();

    //
    //
    MEMORY_EMERGENCY_TIMER = MEMORY_FIVE_MINUTES;
}
