Activity ACT_ANTLION_BURROW_OUT = ACT_INVALID;

static int AE_ANTLION_BURROW_OUT = -1;
static int AE_ANTLION_MELEE1_SOUND = -1;
static int AE_ANTLION_MELEE2_SOUND = -1;

static int AE_ANTLION_FOOTSTEP_SOFT = -1;
static int AE_ANTLION_FOOTSTEP_HEAVY = -1;
static int AE_ANTLION_WALK_FOOTSTEP = -1;

static int AE_ANTLION_MELEE_HIT1 = -1;
static int AE_ANTLION_MELEE_HIT2 = -1;
static int AE_ANTLION_MELEE_POUNCE = -1;

#include "behavior.sp"

static int npc_move_yaw = -1;

static int npc_health = 300;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_flIdleDelay", custom_prop_time);
}

void hl2_antlion_init()
{
	CustomEntityFactory factory = null;
	npc_datamap_init(register_nextbot_factory("npc_hl2_antlion", "HL2Antlion", _, _, factory));
	factory.add_alias("npc_hl2_antlion_bosshealthbar");

	npc_datamap_init(register_robot_nextbot_factory("npc_hl2_antlion_healthbar", "HL2Antlion"));
	npc_datamap_init(register_tankboss_nextbot_factory("npc_hl2_antlion_tankhealthbar", "HL2Antlion"));

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Antlion");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "hl2_antlion");
	return true;
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

	AE_ANTLION_BURROW_OUT = EventList_RegisterPrivateEvent("AE_ANTLION_BURROW_OUT");
	AE_ANTLION_MELEE1_SOUND = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE1_SOUND");
	AE_ANTLION_MELEE2_SOUND = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE2_SOUND");

	AE_ANTLION_FOOTSTEP_SOFT = EventList_RegisterPrivateEvent("AE_ANTLION_FOOTSTEP_SOFT");
	AE_ANTLION_FOOTSTEP_HEAVY = EventList_RegisterPrivateEvent("AE_ANTLION_FOOTSTEP_HEAVY");
	AE_ANTLION_WALK_FOOTSTEP = EventList_RegisterPrivateEvent("AE_ANTLION_WALK_FOOTSTEP");

	AE_ANTLION_MELEE_HIT1 = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE_HIT1");
	AE_ANTLION_MELEE_HIT2 = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE_HIT2");
	AE_ANTLION_MELEE_POUNCE = EventList_RegisterPrivateEvent("AE_ANTLION_MELEE_POUNCE");

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");

	LoadSoundScript("scripts/npc_sounds_antlion.txt");

	PrecacheScriptSound("NPC_Antlion.BurrowOut");

	PrecacheScriptSound("NPC_Antlion.MeleeAttack");
	PrecacheScriptSound("NPC_Antlion.MeleeAttackSingle");
	PrecacheScriptSound("NPC_Antlion.MeleeAttackDouble");

	PrecacheScriptSound("NPC_Antlion.Idle");

	PrecacheScriptSound("NPC_Antlion.FootstepSoft");
	PrecacheScriptSound("NPC_Antlion.FootstepHeavy");
	PrecacheScriptSound("NPC_Antlion.Footstep");

	PrecacheScriptSound("NPC_Antlion.Pain");
}

void hl2_antlion_created(int entity)
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
	if(event.event == AE_ANTLION_BURROW_OUT) {
		EmitGameSoundToAll("NPC_Antlion.BurrowOut", entity);
	} else if(event.event == AE_ANTLION_MELEE1_SOUND) {
		EmitGameSoundToAll("NPC_Antlion.MeleeAttackSingle", entity);
	} else if(event.event == AE_ANTLION_MELEE2_SOUND) {
		EmitGameSoundToAll("NPC_Antlion.MeleeAttackDouble", entity);
	} else if(event.event == AE_ANTLION_FOOTSTEP_SOFT) {
		EmitGameSoundToAll("NPC_Antlion.FootstepSoft", entity);
	} else if(event.event == AE_ANTLION_FOOTSTEP_HEAVY) {
		EmitGameSoundToAll("NPC_Antlion.FootstepHeavy", entity);
	} else if(event.event == AE_ANTLION_WALK_FOOTSTEP) {
		EmitGameSoundToAll("NPC_Antlion.Footstep", entity);
	} else if(event.event == AE_ANTLION_MELEE_HIT1 ||
		event.event == AE_ANTLION_MELEE_HIT2 ||
		event.event == AE_ANTLION_MELEE_POUNCE) {
		int hit = CombatCharacterHullAttackRange(entity, MELEE_RANGE, MELEE_MINS, MELEE_MAXS, 10, DMG_SLASH|DMG_CLUB, 1.0, true);
		if(hit != -1) {
			EmitGameSoundToAll("NPC_Antlion.MeleeAttack", entity);
		}
	}

	return Plugin_Continue;
}

static Activity npc_translate_act(IBodyCustom body, Activity act)
{
	switch(act) {
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
			return ACT_WALK;
		}
		case ACT_RUN_STIMULATED: {
			return ACT_WALK;
		}
		case ACT_RUN_RELAXED: {
			return ACT_WALK;
		}

		case ACT_WALK_AGITATED: {
			return ACT_WALK;
		}
		case ACT_WALK_STIMULATED: {
			return ACT_WALK;
		}
		case ACT_WALK_RELAXED: {
			return ACT_WALK;
		}
	}

	return act;
}

static Action npc_takedmg(int entity, CTakeDamageInfo info, int &result)
{
	EmitGameSoundToAll("NPC_Antlion.Pain", entity);
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
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(hl2_antlion_behavior, "HL2AntlionBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);
}