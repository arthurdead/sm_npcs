#include "behavior.sp"

static int npc_idle_anim = -1;

static int npc_rudder = -1;

static int npc_health = 300;

void hl2_helicopter_init()
{
	register_robot_nextbot_factory("npc_hl2_helicopter", "HL2Helicopter");

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Helicopter");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Sniper;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health);
}

static bool npc_pop_spawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_hl2_helicopter", spawner, pos, result);
}

void hl2_helicopter_precache(int entity)
{
	PrecacheModel("models/combine_helicopter.mdl");
	SetEntityModel(entity, "models/combine_helicopter.mdl");

	npc_idle_anim = AnimatingLookupSequence(entity, "idle");

	npc_rudder = AnimatingLookupPoseParameter(entity, "rudder");
}

void hl2_helicopter_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
	SDKHook(entity, SDKHook_ThinkPost, npc_think);
}

static void npc_think(int entity)
{
	INextBot bot = INextBot(entity);
	ILocomotion locomotion = bot.LocomotionInterface;
	IBody body = bot.BodyInterface;

	npc_hull_debug(bot, body, locomotion, entity);

	npc_resolve_collisions(entity);

	handle_playbackrate(entity, locomotion, body);
}

static int npc_select_animation(IBodyCustom body, int entity, Activity act)
{
	return npc_idle_anim;
}

static void npc_spawn(int entity)
{
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.5);
	SetEntityModel(entity, "models/combine_helicopter.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);
	SetEntPropString(entity, Prop_Data, "m_iName", "Helicopter");

	INextBot bot = INextBot(entity);
	flying_npc_spawn(bot, entity, npc_health, view_as<float>({38.0, 38.0, 38.0}), 100.0, 500.0);

	bot.AllocateCustomIntention(hl2_helicopter_behavior, "HL2HelicopterBehavior");

	IBodyCustom body = view_as<IBodyCustom>(bot.BodyInterface);
	body.set_function("SelectAnimationSequence", npc_select_animation);
}