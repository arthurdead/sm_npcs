#include "behavior.sp"

static Activity ACT_ZOM_RELEASECRAB = ACT_INVALID;

static int AE_ZOMBIE_ATTACK_RIGHT = -1;
static int AE_ZOMBIE_ATTACK_LEFT = -1;
static int AE_ZOMBIE_ATTACK_BOTH = -1;

static int npc_move_yaw = -1;

static int npc_health = 300;

void hl2_zombie_init()
{
	register_robot_nextbot_factory("npc_hl2_zombie", "HL2Zombie");

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Zombie");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Scout;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health);
}

static bool npc_pop_spawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_hl2_zombie", spawner, pos, result);
}

void hl2_zombie_precache(int entity)
{
	PrecacheModel("models/zombie/classic.mdl");
	SetEntityModel(entity, "models/zombie/classic.mdl");

	ACT_ZOM_RELEASECRAB = ActivityList_RegisterPrivateActivity("ACT_ZOM_RELEASECRAB");

	AE_ZOMBIE_ATTACK_RIGHT = EventList_RegisterPrivateEvent("AE_ZOMBIE_ATTACK_RIGHT");
	AE_ZOMBIE_ATTACK_LEFT = EventList_RegisterPrivateEvent("AE_ZOMBIE_ATTACK_LEFT");
	AE_ZOMBIE_ATTACK_BOTH = EventList_RegisterPrivateEvent("AE_ZOMBIE_ATTACK_BOTH");

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");
}

void hl2_zombie_created(int entity)
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
	handle_move_yaw(entity, npc_move_yaw, locomotion);
}

static Action npc_handle_animevent(int entity, animevent_t event)
{
	if(event.event == AE_ZOMBIE_ATTACK_RIGHT ||
		event.event == AE_ZOMBIE_ATTACK_LEFT ||
		event.event == AE_ZOMBIE_ATTACK_BOTH) {
		CombatCharacterHullAttackRange(entity, MELEE_RANGE, MELEE_MINS, MELEE_MAXS, 10, DMG_SLASH|DMG_CLUB, 1.0, true);
	}

	return Plugin_Continue;
}

static Activity npc_translate_act(IBodyCustom body, Activity act)
{
	switch(act) {
		case ACT_RUN: return ACT_WALK;
	}

	return act;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/zombie/classic.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_GREEN);
	switch(GetURandomInt() % 2) {
		case 1: SetEntProp(entity, Prop_Send, "m_nBody", 1);
	}
	SetEntPropString(entity, Prop_Data, "m_iName", "Classic Zombie");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health, NULL_VECTOR, 45.0, 45.0);

	bot.AllocateCustomIntention(hl2_zombie_behavior, "HL2ZombieBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("TranslateActivity", npc_translate_act);
}