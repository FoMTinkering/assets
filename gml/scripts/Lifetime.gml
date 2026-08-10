function execute_at_end_of_frame() {
    var next_room = TAXI.depart();

    if instance_exists(Game) && Game.go_to_main_menu {
        next_room = rm_menu;
        Game.execute_return_to_menu();
    }

    if DUNGEON_RUNNER != undefined && next_room != undefined && is_dungeon_room(next_room) == false {
        on_dungeon_exit();
    }

    STENCIL_VALUE = 0;
}
