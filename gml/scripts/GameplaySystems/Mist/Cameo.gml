#macro CAMEO_PROTOTYPES global.__cameo_prototypes
CAMEO_PROTOTYPES = undefined;

enum CameoId {
    Linnet,
    Wiscar,
    GreatBird,
    Darren,
    Wynne,
    LEN
}

function load_cameo_prototypes() {
    var cameos = array_create(CameoId.LEN, undefined);

    for (var i = 0; i < CameoId.LEN; i++) {
        var cameo_string = cameo_id_to_string(i);
        var data = fiddle_get("cameos/" + cameo_string);
        var wardrobe_outfits = parse_wardrobe(data, cameo_string);

        cameos[i] = {
            id: i,
            name: data.name,
            wardrobe_outfits,
            offsets: data.offsets,
            voice: data.voice,
            portrait_sound_overrides: data[$ "portrait_sound_overrides"] ?? {},
        };
    }

    return cameos;
}

function Cameo(idx, brain) constructor {
    self.id = idx;
    self.brain = brain;
    self.brain.blackboard.set("me", self);
    self.prototype = CAMEO_PROTOTYPES[idx];
    self.location_position = undefined;
    self.brain_dead = true;
    self.animation = "idle";
    self.cardinality = Cardinal.South;
    self.itinerary = undefined;
    self.wardrobe = new Wardrobe(self.prototype.wardrobe_outfits, undefined);
    self.wardrobe.set_outfit("spring");

    function set_animation(animation_name) {
        self.animation = animation_name;
        with cameo_id_to_gm_obj_id(self.id) {
            self.update_animation();
        }
    }

    function set_cardinality(cardinal) {
        self.cardinality = cardinal;
        with cameo_id_to_gm_obj_id(self.id) {
            self.update_cardinality();
        }
    }

    function complete_pathfind() {
        var output = self.brain.blackboard.try_take("on_arrived_at_next_location");
        if output != undefined {
            output(self.brain.blackboard);
        }

        if self.activity_handler.activity != undefined {
            var trellis_point = TP.location_position_to_tp(self.location_position);

            var zone = undefined;
            if trellis_point != undefined {
                zone = T2R.tp_to_zone(trellis_point.name);
            }

            if zone == undefined {
                zone = format("personal/{NpcId}", self.id);
            }

            T2R.write(format("{NpcId}_zone", self.id), zone);
        }

        self.itinerary = undefined;
        self.simulated_distance_traveled = 0;
    }

}
