#macro DAYCARE global.__daycare
DAYCARE = undefined;

function daycare_new_day() {
    //
}

function serialize_daycare() {
    var a = DAYCARE.to_array();
    for (var i = 0; i < array_length(a); i++) {
        a[i] = a[i].serialize();
    }
    return a;
}

function deserialize_daycare(animals) {
    var list = ListFromArray(animals);
    list.map(function(animal) {
        var a = new PlayerAnimal(
            string_to_animal_kind(animal.kind),
            animal.variant,
            string_to_sex(animal.sex),
            true,
        );
        a.deserialize(animal);
        return a;
    });
    return list;
}

