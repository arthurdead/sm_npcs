int tf2_shooting_star_muzzle = -1;
int dxhr_sniper_rail_red = INVALID_STRING_INDEX;
int dxhr_sniper_rail_blue = INVALID_STRING_INDEX;

ConVar sk_tf2i_alien_commando_dmg;

#include "behavior.sp"

static int npc_move_yaw = -1;

static ConVar npc_health_cvar;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_hWeaponModel", custom_prop_ehandle);
}

void tf2i_alien_commando_init()
{
	npc_health_cvar = CreateConVar("sk_tf2i_alien_health", "125");

	sk_tf2i_alien_commando_dmg = CreateConVar("sk_tf2i_alien_commando_dmg", "50");

	CustomEntityFactory factory = null;
	npc_datamap_init(register_nextbot_factory("npc_tf2i_alien_commando", "TF2IAlienCommando", _, _, factory));

	npc_datamap_init(register_robot_nextbot_factory("npc_tf2i_alien_commando_robothealthbar", "TF2IAlienCommando"));
	npc_datamap_init(register_tankboss_nextbot_factory("npc_tf2i_alien_commando_tankhealthbar", "TF2IAlienCommando"));

	CustomPopulationSpawnerEntry spawner = register_popspawner("TF2IAlienCommando");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "tf2i_alien_commando");
	return true;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Soldier;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health_cvar.IntValue);
}

static bool npc_pop_spawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_tf2i_alien_commando", spawner, pos, result);
}

#define TF2I_ALIEN_COMMANDO_MODEL "models/player/alien_commando.mdl"

void tf2i_alien_commando_precache(int entity)
{
	PrecacheModel(TF2I_ALIEN_COMMANDO_MODEL);
	SetEntityModel(entity, TF2I_ALIEN_COMMANDO_MODEL);

	AddModelToDownloadsTable(TF2I_ALIEN_COMMANDO_MODEL);

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");

	PrecacheModel("models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");
	SetEntityModel(entity, "models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");

	tf2_shooting_star_muzzle = AnimatingLookupAttachment(entity, "muzzle");

	dxhr_sniper_rail_red = find_particle("dxhr_sniper_rail_red");
	dxhr_sniper_rail_blue = find_particle("dxhr_sniper_rail_blue");

	PrecacheScriptSound("Weapon_ShootingStar.SingleCharged");
}

void tf2i_alien_commando_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
}

static Action npc_think(int entity)
{
	INextBot bot = INextBot(entity);
	ILocomotion locomotion = bot.LocomotionInterface;
	IBody body = bot.BodyInterface;

	npc_hull_debug(bot, body, locomotion, entity);

	npc_resolve_collisions(entity);

	handle_playbackrate(entity, locomotion, body);
	handle_move_yaw(entity, npc_move_yaw, locomotion);

	return Plugin_Continue;
}

static Action npc_handle_animevent(int entity, animevent_t event)
{
	

	return Plugin_Continue;
}

static Activity npc_translate_act(IBodyCustom body, Activity act)
{
	switch(act) {
		case ACT_JUMP: {
			return ACT_HOP;
		}

		case ACT_IDLE_AGITATED: {
			return ACT_IDLE;
		}
		case ACT_IDLE_STIMULATED: {
			return ACT_IDLE;
		}
		case ACT_IDLE_RELAXED: {
			return ACT_IDLE;
		}

		case ACT_RUN_AGITATED: {
			return ACT_RUN;
		}
		case ACT_RUN_STIMULATED: {
			return ACT_RUN;
		}
		case ACT_RUN_RELAXED: {
			return ACT_RUN;
		}

		case ACT_WALK_AGITATED: {
			return ACT_RUN;
		}
		case ACT_WALK_STIMULATED: {
			return ACT_RUN;
		}
		case ACT_WALK_RELAXED: {
			return ACT_RUN;
		}

		case ACT_RANGE_ATTACK1: {
			return ACT_RANGE_ATTACK_PISTOL;
		}
	}

	return act;
}

static Action npc_takedmg(int entity, CTakeDamageInfo info, int &result)
{
	return Plugin_Continue;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, TF2I_ALIEN_COMMANDO_MODEL);
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_GREEN);
	SetEntPropString(entity, Prop_Data, "m_iName", "Alien Commando");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, NULL_VECTOR, 175.0, 175.0);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(tf2i_alien_commando_behavior, "TF2IAlienCommandoBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);

	int weapon = create_attach_model(entity, "models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl", "0");
	SetEntPropVector(weapon, Prop_Send, "m_angRotation", view_as<float>({-90.0, -90.0, 0.0}));
	SetEntPropVector(weapon, Prop_Send, "m_vecOrigin", view_as<float>({0.0, 0.0, 20.0}));
	SetEntProp(weapon, Prop_Send, "m_nSkin", 1);
	SetEntPropEnt(entity, Prop_Data, "m_hWeaponModel", weapon);
}