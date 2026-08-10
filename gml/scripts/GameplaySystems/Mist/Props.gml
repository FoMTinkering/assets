#macro PROP_PROTOTYPES global.__prop_prototypes
global.__prop_prototypes = undefined;

#macro PROPS global.__props
global.__props = undefined;

//
function create_prop_prototypes() {
    var prop_map = Map();

    var f_props = fiddle_get("props");
    var prop_names = struct_get_names(f_props);

    for (var i = 0, c = array_length(prop_names); i < c; i++) {
        var prop_name = prop_names[i];
        var member = f_props[$ prop_name];
        var z = member[$ "z"] ?? 0;

        var mist_prop;
        if member[$ "sprite"] != undefined {

            //
            mist_prop = MistProp.Sprite(string_to_asset(member.sprite), z, member[$ "seasonal"] ?? false);

            //
        } else if member[$ "item"] != undefined {
            //
            var item_id = string_to_item_id(member.item);
            var item = ITEM_PROTOTYPES[item_id];
            mist_prop = MistProp.Item(item.icon_sprite, z);

        } else if member[$ "artifact"] != undefined {
            mist_prop = MistProp.Digsite(member[$ "artifact"], z);
        } else {
            crash("prop {} was not set up properly", prop_name);
        }

        prop_map.insert(prop_name, mist_prop);
    }

    return prop_map;
}

//
function PropMaster() constructor {
    world = array_create_ext(LocationId.LEN, EmptyList);
    spawned = Map();

    //
    function on_room_start() {
        var prop_loc = self.world[CURRENT_LOCATION_ID];

        for (var i = 0; i < prop_loc.count(); i++) {
            var prop = prop_loc.get(i);

            self.spawn_prop(prop);
        }
    }

    //
    function create_prop(point_name, location_id) {
        if location_id == CURRENT_LOCATION_ID {
            self.spawn_prop(point_name);
        }

        self.world[location_id].push(point_name);
    }

    //
    function spawn_prop(tp_name) {
        //
        var pt = trellis_point_find_by_name(
            location_id_to_gm_room(CURRENT_LOCATION_ID),
            tp_name,
            TrellisPointDataRequest.OBJECT_INDEX | TrellisPointDataRequest.PROP_NAME
        );
        assert_defined(pt, "failed to find prop trellis point");
        assert_eq(pt.object_index, obj_trellis_point_prop, "trellis point was a `{GmObject}`. needed `obj_trellis_point_prop`", pt.object_index);

        var xx = pt.x;
        var yy = pt.y;

        var prop_data = fiddle_get(format("props/{}", pt.prop_name));
        var residual = undefined;

        var prop_prototype = PROP_PROTOTYPES.get_unwrap(pt.prop_name);
        switch prop_prototype.type {
            case MistPropType.Item:
                var item_sprite = ITEM_PROTOTYPES[string_to_item_id(prop_data.item)].icon_sprite;

                var inst = instance_create_layer(
                    xx,
                    yy,
                    "Instances",
                    obj_assetobject,
                    {
                        sprite_index: item_sprite,
                        z: prop_prototype.z,
                    }
                );
                residual = PropResidual.Instance(inst);
                break;
            case MistPropType.Sprite:
                var inst = instance_create_layer(
                    xx,
                    yy,
                    "Instances",
                    obj_assetobject,
                    {
                        sprite_index: prop_prototype.sprite_id,
                        z: prop_prototype.z,
                        seasonal: prop_prototype.seasonal
                    }
                );
                residual = PropResidual.Instance(inst);
                break;
            case MistPropType.Digsite:
                var success = GRID.write_node(xx div 8,yy div 8, ObjectId.DigSite, string_to_item_id(prop_prototype.artifact_name));
                assert(success, "we failed to write a dig site to {}x{}", xx div 8, yy div 8);

                residual = PropResidual.GridCoordinate(Vec2(xx div 8, yy div 8));
            break;
            default: impossible("unexpected mist prop type");
        }

        self.spawned.insert(tp_name, residual);
    }

    //
    function destroy_prop(tp_name, location) {
        //
        var prop_loc = self.world[location];

        for (var i = 0; i < prop_loc.count(); i++) {
            var prop = prop_loc.get(i);
            if prop == tp_name {
                prop_loc.remove(i);
                break;
            }
        }

        return self.despawn_prop(tp_name);
    }

    //
    //
    function despawn_prop(tp_name) {
        var output = self.spawned.remove(tp_name);
        if output == undefined {
            return false;
        }

        switch output.type {
            case PropResidualType.Instance:
                if instance_exists(output.inst) {
                    instance_destroy(output.inst);
                }
                break;

            case PropResidualType.GridCoordinate:
                erase_object_node(GRID.node_index_for_cell(output.grid_coord.x, output.grid_coord.y));
                break;

            default: impossible("unknown prop map residual: {}", output.type);
        }

        return true;
    }

    //
    //
    function clear_all_current_props() {
        var keys = self.spawned.keys();
        for (var i = 0; i < array_length(keys); i++) {
            var key = keys[i];
            self.despawn_prop(key);
        }

        self.spawned.clear();
    }
}

function MistPropFactory() constructor {
    static Item = function(item_id, z) {
        return {
            type: MistPropType.Item,
            item_id: item_id,
            z: z,
        }
    }

    static Sprite = function(sprite_id, z, seasonal) {
        return {
            type: MistPropType.Sprite,
            sprite_id: sprite_id,
            z: z,
            seasonal
        }
    }
    static Digsite = function(artifact, z) {
        return {
            type: MistPropType.Digsite,
            artifact_name: artifact,
            z: z,
        }
    }
}

enum MistPropType {
    Item,
    Sprite,
    Digsite
}

global.mist_prop_factory = new MistPropFactory();
#macro MistProp global.mist_prop_factory

function PropResidualFactory() constructor {
    static Instance = function(instance_id) {
        return {
            type: PropResidualType.Instance,
            inst: instance_id,
        }
    }

    static GridCoordinate = function(grid_coord) {
        return {
            type: PropResidualType.GridCoordinate,
            grid_coord: grid_coord,
        }
    }
}

enum PropResidualType {
    Instance,
    GridCoordinate,
}

global.prop_residual_factory = new PropResidualFactory();
#macro PropResidual global.prop_residual_factory
