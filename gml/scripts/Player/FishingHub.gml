//
//
//
#macro FISHING global.__fishing

enum FishingEvent {
    Bite,
    Nibble,
    Caught,
    Missed,
    None,
    LEN
}

function __FishHub() constructor {

    self.interested_fish = undefined;
    self.bite_timer = 0;
    self.nibbled_times = 0;
    self.fishing_grid_position = Vec2();
    self.fishing_grid_position_start = Vec2();
    self.fish_subs = Map();

    function subscribe(key) {
        self.fish_subs.set(key, {
            kind: FishingEvent.None,
            value: undefined
        });
    }

    //
    function notify(kind, value) {
        var names = fish_subs.keys();
        for (var i = 0, c = array_length(names); i < c; i++) {
            self.fish_subs.set(names[i], {
                kind: kind,
                value: value
            });
        }
    }

    function get_subscriber(key) {
        return self.fish_subs.get(key);
    }

    function set_fish(fish) {
        self.interested_fish = fish;
        self.nibbled_times = 0;
        self.bite_timer = 0;
    }

    function try_bite() {
        var chance;
        switch(self.nibbled_times) {
            case 0: chance = 0.2; break;
            case 1: chance = 0.55; break;
            case 2: chance = 0.75; break;
            default: chance = 1; break;
        }
        self.nibbled_times++;
        //
        var bite = random_range(0, 0.999) < chance;
        if bite {
            self.notify(FishingEvent.Bite, self.interested_fish);
            self.nibbled_times = 0;

            set_rumble(RumbleKind.FishingStrong);
        } else {
            self.notify(FishingEvent.Nibble, self.interested_fish);
            set_rumble(RumbleKind.FishingWeak);
        }
    }

    function step() {
        if self.bite_timer > 0 {
            self.bite_timer--;
            if self.bite_timer == 0 {
                self.notify(FishingEvent.Missed,self.interested_fish);
            }
        }
    }
}

function FishHub() {
    return new __FishHub();
}

//
enum FishingState {
    Windup,
    Cast,
    Wait,
    Reel,
    LEN
}
