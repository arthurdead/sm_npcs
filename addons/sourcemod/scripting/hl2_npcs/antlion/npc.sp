Activity ACT_ANTLION_BURROW_OUT = ACT_INVALID;

static int AE_ANTLION_MELEE_HIT1 = -1;
static int AE_ANTLION_MELEE_HIT2 = -1;
static int AE_ANTLION_MELEE_POUNCE = -1;

#include "behavior.sp"

static int npc_move_yaw = -1;

static int npc_health = 300;

void hl2_antlion_init()
{
	register_robot_nextbot_factory("npc_hl2_antlion", "HL2Antlion");

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Antlion");
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

static bool npc_pop_spawn(CustomPopulationSpawner spawner, const float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_hl2_antlion", spawner, pos, result);
}

void hl2_antlion_precache(int entity)
{
	PrecacheModel("models/antlion.mdl");
	SetEntityModel(entity, "models/antlion.mdl");

	ACT_ANTLION_BURROW_OUT = ActivityList_RegisterPrivateActivity("ACT_ANTLION_BURROW_OUT");

	AE_ANTLION_MELEE_HIT1 = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE_HIT1");
	AE_ANTLION_MELEE_HIT2 = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE_HIT2");
	AE_ANTLION_MELEE_POUNCE = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE_POUNCE");

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");
}

void hl2_antlion_created(int entity)
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
	if(event.event == AE_ANTLION_MELEE_HIT1 ||
		event.event == AE_ANTLION_MELEE_HIT2 ||
		event.event == AE_ANTLION_MELEE_POUNCE) {
		CombatCharacterHullAttackRange(entity, MELEE_RANGE, MELEE_MINS, MELEE_MAXS, 10, DMG_SLASH|DMG_CLUB, 1.0, true);
	}

	return Plugin_Continue;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/antlion.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_GREEN);
	SetEntProp(entity, Prop_Send, "m_nSkin", GetURandomInt() % 4);
	SetEntPropString(entity, Prop_Data, "m_iName", "Antlion");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health, NULL_VECTOR, 195.0, 354.90);

	bot.AllocateCustomIntention(hl2_antlion_behavior, "HL2AntlionBehavior");
}