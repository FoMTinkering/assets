#macro NON_PLAYER_ANIMAL_PROTOTYPES global.__non_player_animal_prototypes
NON_PLAYER_ANIMAL_PROTOTYPES = undefined;

#macro NON_PLAYER_ANIMALS global.__non_player_animals
NON_PLAYER_ANIMALS = undefined;

enum NpaState {
    Idle,
    Wander,
    Animate,
    LEN,
}

function load_npa_prototypes() {
    var data = fiddle_get("ranching/npas");
    var output = array_create(LocationId.LEN, undefined);

    for (var i = 0; i < LocationId.LEN; i++) {
        var npas = data[$ location_id_to_string(i)] ?? [];
        for (var j = 0; j < array_length(npas); j++) {
            var npa = npas[j];
            npa.kind = string_to_animal_kind(npa.kind);
            npa.sex = string_to_sex(npa.sex);
            npa.require_player_unlocked = npa[$ "require_player_unlocked"] ?? false;
        }
        output[i] = npas;
    }
    return output;
}

function npas_new_day() {
    NON_PLAYER_ANIMALS = List();

    for (var i = 0; i < LocationId.LEN; i++) {
        var points = array_shuffle(LOCATIONS[i].npa_spawn_points);
        var animals = NON_PLAYER_ANIMAL_PROTOTYPES[i];

        for (var j = 0; j < array_length(animals); j++) {
            var animal = animals[j];
            if animal.require_player_unlocked && !animal_is_unlocked(animal.kind) {
                continue;
            }

            var npa = new NonPlayerAnimal(animal.kind, animal.variant, animal.sex);
            npa.days_old = animal.days_old;
            npa.location_position = trellis_point_location_position(format("{LocationId}/{}", i, array_pop(points)));

            NON_PLAYER_ANIMALS.push(npa);
        }
    }
}

function npas_room_start() {
    if WEATHER.is_inclement() || CLOCK.time >= NIGHT_TIME || MIST.is_running() {
        return;
    }

    NON_PLAYER_ANIMALS.for_each(function(animal) {
        if animal.is_present() {
            animal.instance = instance_create_layer(
                animal.location_position.pos.x,
                animal.location_position.pos.y,
                "Instances",
                obj_npa,
                {
                    me: animal,
                }
            );
        }
    });

    with obj_festival_npa_spawner {
        self.spawn_npa();
    }
}
