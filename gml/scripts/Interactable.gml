#macro INTERACTABLES global.__interactables
INTERACTABLES = List();

function register_interactable(inst) {
    for (var i = 0; i < INTERACTABLES.count(); i++) {
        if INTERACTABLES.get(i) == undefined {
            INTERACTABLES.set(i, inst);
            return;
        }
    }

    INTERACTABLES.push(inst);
}

function find_nearest_interactable(list, owner) {
    //
    ds_list_clear(list);

    var ari_x = owner.x;
    var ari_y = owner.y;

    //
    switch owner.cardinal {
        case Cardinal.East:
            ari_x += owner.interact_nudge_distance;
            break;
        case Cardinal.West:
            ari_x -= owner.interact_nudge_distance;
            break;
        case Cardinal.South:
            ari_y += owner.interact_nudge_distance;
            break;
        case Cardinal.North:
            ari_y -= owner.interact_nudge_distance;
            break;
        default: impossible("unexpected cardinal {}", owner.cardinal);
    }

    //
    var len = collision_rectangle_list(
        ari_x - owner.interact_detection_radius,
        ari_y - owner.interact_detection_radius,
        ari_x + owner.interact_detection_radius,
        ari_y + owner.interact_detection_radius,
        INTERACTABLES.__buffer,
        list,
    );

    var selection = undefined;
    var selection_value = -1;
    var selection_priority = 0;

    for (var i = 0; i < len; i++) {
        var interactable = list[| i];
        if interactable.has_potential_interactions() == false {
            continue;
        }

        var distance;
        switch interactable.interactable_mode {
            case InteractableMode.Circle:
                var xx = interactable.x;
                var yy = interactable.y;

                if interactable.offset_with_cardinal {
                    switch interactable.animator.cardinality {
                        case Cardinal.East:
                            xx += interactable.interact_nudge_distance;
                            break;
                        case Cardinal.West:
                            xx -= interactable.interact_nudge_distance;
                            break;
                        case Cardinal.South:
                            yy += interactable.interact_nudge_distance;
                            break;
                        case Cardinal.North:
                            yy -= interactable.interact_nudge_distance;
                            break;
                    }
                }

                distance = point_distance(xx, yy, ari_x, ari_y) - interactable.circle_size;
                break;
            case InteractableMode.Bbox:
                with interactable {
                    var stash = undefined;
                    if self.override_mask != undefined {
                        stash = self.mask_index;
                        self.mask_index = self.override_mask;
                    }
                    distance = distance_to_point(ari_x, ari_y);
                    if self.override_mask != undefined {
                        self.mask_index = stash;
                    }
                }
                break;
            case InteractableMode.Box:
                var dx = max(abs(ari_x - interactable.interaction_center.x) - interactable.interaction_half_size.x, 0);
                var dy = max(abs(ari_y - interactable.interaction_center.y) - interactable.interaction_half_size.y, 0);

                distance = sqrt(dx * dx + dy * dy);
                break;
            default: impossible("unexpected interactable_mode: {}", interactable.interactable_mode);
        }

        //
        if distance > owner.interact_max_radius {
            continue;
        }

        //
        distance -= owner.interact_max_radius;
        distance *= -1;

        var this_priority = interactable["selection_priority"] ?? 0;

        if (this_priority > selection_priority)
            || (distance > selection_value)
            || (distance == selection_value
                && (selection == undefined || instance_ids_compare_age(interactable.id, selection.id) == 1))
        {
            selection_priority = this_priority;
            selection = interactable;
            selection_value = distance;
        }
    }

    //
    return selection;
}
