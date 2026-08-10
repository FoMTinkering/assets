enum NpcId {
    Adeline,
    Balor,
    Caldarus,
    Celine,
    Darcy,
    Dell,
    Dozy,
    Eiland,
    Elsie,
    Errol,
    Hayden,
    Hemlock,
    Henrietta,
    Holt,
    Josephine,
    Juniper,
    Landen,
    Louis,
    Luc,
    Maple,
    March,
    Merri,
    Nora,
    Olric,
    Reina,
    Ryis,
    Seridia,
    Stillwell,
    Taliferro,
    Terithia,
    Valen,
    Vera,
    Wheedle,
    Zorel,
    LEN,
}

//
function npc_id_to_gm_obj_id(npc_id) {
    switch (npc_id) {
        case NpcId.Adeline: return obj_adeline;
        case NpcId.Balor: return obj_balor;
        case NpcId.Caldarus: return obj_caldarus;
        case NpcId.Celine: return obj_celine;
        case NpcId.Darcy: return obj_darcy;
        case NpcId.Dell: return obj_dell;
        case NpcId.Dozy: return obj_dozy;
        case NpcId.Eiland: return obj_eiland;
        case NpcId.Elsie: return obj_elsie;
        case NpcId.Errol: return obj_errol;
        case NpcId.Hayden: return obj_hayden;
        case NpcId.Hemlock: return obj_hemlock;
        case NpcId.Henrietta: return obj_henrietta;
        case NpcId.Holt: return obj_holt;
        case NpcId.Josephine: return obj_josephine;
        case NpcId.Juniper: return obj_juniper;
        case NpcId.Landen: return obj_landen;
        case NpcId.Louis: return obj_louis;
        case NpcId.Luc: return obj_luc;
        case NpcId.Maple: return obj_maple;
        case NpcId.March: return obj_march;
        case NpcId.Merri: return obj_merri;
        case NpcId.Nora: return obj_nora;
        case NpcId.Olric: return obj_olric;
        case NpcId.Reina: return obj_reina;
        case NpcId.Ryis: return obj_ryis;
        case NpcId.Seridia: return obj_seridia;
        case NpcId.Stillwell: return obj_stillwell;
        case NpcId.Taliferro: return obj_taliferro;
        case NpcId.Terithia: return obj_terithia;
        case NpcId.Valen: return obj_valen;
        case NpcId.Vera: return obj_vera;
        case NpcId.Wheedle: return obj_wheedle;
        case NpcId.Zorel: return obj_zorel;
        default: impossible("Unexpected NpcId: {}", npc_id);
    }
}

//
//
function gm_obj_id_to_npc_id(obj_id) {
    switch (obj_id) {
        case obj_adeline: return NpcId.Adeline;
        case obj_balor: return NpcId.Balor;
        case obj_caldarus: return NpcId.Caldarus;
        case obj_celine: return NpcId.Celine;
        case obj_darcy: return NpcId.Darcy;
        case obj_dell: return NpcId.Dell;
        case obj_dozy: return NpcId.Dozy;
        case obj_eiland: return NpcId.Eiland;
        case obj_elsie: return NpcId.Elsie;
        case obj_errol: return NpcId.Errol;
        case obj_hayden: return NpcId.Hayden;
        case obj_hemlock: return NpcId.Hemlock;
        case obj_henrietta: return NpcId.Henrietta;
        case obj_holt: return NpcId.Holt;
        case obj_josephine: return NpcId.Josephine;
        case obj_juniper: return NpcId.Juniper;
        case obj_landen: return NpcId.Landen;
        case obj_louis: return NpcId.Louis;
        case obj_luc: return NpcId.Luc;
        case obj_maple: return NpcId.Maple;
        case obj_march: return NpcId.March;
        case obj_merri: return NpcId.Merri;
        case obj_nora: return NpcId.Nora;
        case obj_olric: return NpcId.Olric;
        case obj_reina: return NpcId.Reina;
        case obj_ryis: return NpcId.Ryis;
        case obj_seridia: return NpcId.Seridia;
        case obj_stillwell: return NpcId.Stillwell;
        case obj_taliferro: return NpcId.Taliferro;
        case obj_terithia: return NpcId.Terithia;
        case obj_valen: return NpcId.Valen;
        case obj_vera: return NpcId.Vera;
        case obj_zorel: return NpcId.Zorel;
        case obj_wheedle: return NpcId.Wheedle;
        default: return undefined;
    }
}
