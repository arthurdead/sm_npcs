int hl2_pistol_muzzle = -1;

#include "behavior.sp"

static int npc_move_yaw = -1;

static ConVar npc_health_cvar;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_hWeaponModel", custom_prop_ehandle);
}

void hl2_combine_init()
{
	npc_health_cvar = CreateConVar("sk_combine_health", "1000");

	CustomEntityFactory factory = null;
	npc_datamap_init(register_nextbot_factory("npc_hl2_combine", "HL2Combine", _, _, factory));

	npc_datamap_init(register_robot_nextbot_factory("npc_hl2_combine_robothealthbar", "HL2Combine"));
	npc_datamap_init(register_tankboss_nextbot_factory("npc_hl2_combine_tankhealthbar", "HL2Combine"));

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Combine");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "hl2_combine");
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
	return npc_pop_spawn_single("npc_hl2_combine", spawner, pos, result);
}

void hl2_combine_precache(int entity)
{
	PrecacheModel("models/police.mdl");
	SetEntityModel(entity, "models/police.mdl");

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");

	PrecacheModel("models/weapons/w_pistol.mdl");
	SetEntityModel(entity, "models/weapons/w_pistol.mdl");

	hl2_pistol_muzzle = AnimatingLookupAttachment(entity, "muzzle");
}

void hl2_combine_created(int entity)
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
		case ACT_IDLE_AGITATED: {
			return ACT_IDLE_ANGRY_PISTOL;
		}
		case ACT_IDLE_STIMULATED: {
			return ACT_IDLE_PISTOL;
		}
		case ACT_IDLE_RELAXED: {
			return ACT_IDLE_PISTOL;
		}

		case ACT_RUN_AGITATED: {
			return ACT_RUN_AIM_PISTOL;
		}
		case ACT_RUN_STIMULATED: {
			return ACT_RUN_PISTOL;
		}
		case ACT_RUN_RELAXED: {
			return ACT_RUN_PISTOL;
		}

		case ACT_WALK_AGITATED: {
			return ACT_WALK_AIM_PISTOL;
		}
		case ACT_WALK_STIMULATED: {
			return ACT_WALK_PISTOL;
		}
		case ACT_WALK_RELAXED: {
			return ACT_WALK_PISTOL;
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
	SetEntityModel(entity, "models/police.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Combine");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, NULL_VECTOR, 57.68, 184.56);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(hl2_combine_behavior, "HL2CombineBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);

	int weapon = create_bonemerge_model(entity, "models/weapons/w_pistol.mdl", "anim_attachment_LH");
	SetEntPropEnt(entity, Prop_Data, "m_hWeaponModel", weapon);
}