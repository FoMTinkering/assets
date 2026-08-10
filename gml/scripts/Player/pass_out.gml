function pass_out(faint=false) {
    obj_ari.receiver.status = set_flag(obj_ari.receiver.status, ReceiverStatus.UntimedInvulnerable);
    ARI.set_stamina(0);
    end_day();
    if ARI.held_animal_id != undefined {
        var animal = find_animal(ARI.held_animal_id);
        if animal.instance == undefined {
            //
            ARI.held_animal_id = undefined;
        } else {
            animal.instance.put_down();
        }
        obj_ari.par.unset_modifier(AnimationName.Pickup);
    }
    if faint {
        game_stats_increment(GAME_STATS, "faints");
        create_notification("misc_local/two_am_alert");

        if DUNGEON_RUNNER != undefined {
            DUNGEON_RUNNER.exit_mines_stats_condition = "faint";
        }
    }
    TANGO.play("SoundEffects/Ari/Faint");
}
