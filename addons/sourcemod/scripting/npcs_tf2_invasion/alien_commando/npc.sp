int tf2_shooting_star_muzzle = -1;
int tf2_cow_mangler_muzzle = -1;

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

	create_npc_factories("npc_tf2i_alien_commando", "TF2IAlienCommando", npc_datamap_init);

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

void tf2i_alien_commando_precache(int entity)
{
	PrecacheModel("models/tf2_invasion/alien_commando_v2.mdl");
	AddModelToDownloadsTable("models/tf2_invasion/alien_commando_v2.mdl");

	SetEntityModel(entity, "models/tf2_invasion/alien_commando_v2.mdl");

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");

	PrecacheModel("models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");
	SetEntityModel(entity, "models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");

	tf2_shooting_star_muzzle = AnimatingLookupAttachment(entity, "muzzle");

	PrecacheModel("models/workshop/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl");
	SetEntityModel(entity, "models/workshop/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl");

	tf2_cow_mangler_muzzle = AnimatingLookupAttachment(entity, "muzzle");

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

	//npc_hull_debug(bot, body, locomotion, entity);

	npc_resolve_collisions(bot, entity);

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
	}

	return act;
}

static Action npc_takedmg(int entity, CTakeDamageInfo info, int &result)
{
	float dir[3];
	TE_SetupBloodSprite2(info.m_vecDamagePosition, dir, BLOOD_COLOR_GREEN, 5);
	TE_SendToAll();

	return Plugin_Continue;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/tf2_invasion/alien_commando_v2.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Alien Commando");

	SetEntProp(entity, Prop_Data, "m_takedamage", 1);

	SetEntProp(entity, Prop_Send, "m_nSkin", GetURandomInt() % 3);
	SetEntProp(entity, Prop_Send, "m_nBody", GetURandomInt() % 2);

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, 175.0, 175.0);
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

void tf2i_alien_commando_destroyed(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
	if(weapon != -1) {
		RemoveEntity(weapon);
	}
}