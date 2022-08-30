ConVar zombie_moanfreq;

#include "behavior.sp"

static Activity ACT_ZOM_RELEASECRAB = ACT_INVALID;

static int AE_ZOMBIE_ATTACK_RIGHT = -1;
static int AE_ZOMBIE_ATTACK_LEFT = -1;
static int AE_ZOMBIE_ATTACK_BOTH = -1;

static int AE_ZOMBIE_STEP_LEFT = -1;
static int AE_ZOMBIE_STEP_RIGHT = -1;
static int AE_ZOMBIE_SCUFF_LEFT = -1;
static int AE_ZOMBIE_SCUFF_RIGHT = -1;

static int npc_move_yaw = -1;

static ConVar npc_health_cvar;

static ConVar sk_zombie_dmg_one_slash;
static ConVar sk_zombie_dmg_both_slash;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_flNextMoanSound", custom_prop_time);
}

void hl2_zombie_init()
{
	npc_health_cvar = CreateConVar("sk_zombie_health", "1000");

	sk_zombie_dmg_one_slash = CreateConVar("sk_zombie_dmg_one_slash", "10");
	sk_zombie_dmg_both_slash = CreateConVar("sk_zombie_dmg_both_slash", "25");

	zombie_moanfreq = CreateConVar("zombie_moanfreq", "4");

	CustomEntityFactory factory = null;
	npc_datamap_init(register_nextbot_factory("npc_hl2_zombie", "HL2Zombie", _, _, factory));
	factory.add_alias("npc_hl2_zombie_bosshealthbar");

	npc_datamap_init(register_robot_nextbot_factory("npc_hl2_zombie_healthbar", "HL2Zombie"));
	npc_datamap_init(register_tankboss_nextbot_factory("npc_hl2_zombie_tankhealthbar", "HL2Zombie"));

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Zombie");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "hl2_zombie");
	return true;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Scout;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health_cvar.IntValue);
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

	AE_ZOMBIE_STEP_LEFT = EventList_RegisterPrivateEvent("AE_ZOMBIE_STEP_LEFT");
	AE_ZOMBIE_STEP_RIGHT = EventList_RegisterPrivateEvent("AE_ZOMBIE_STEP_RIGHT");
	AE_ZOMBIE_SCUFF_LEFT = EventList_RegisterPrivateEvent("AE_ZOMBIE_SCUFF_LEFT");
	AE_ZOMBIE_SCUFF_RIGHT = EventList_RegisterPrivateEvent("AE_ZOMBIE_SCUFF_RIGHT");

	npc_move_yaw = AnimatingLookupPoseParameter(entity, "move_yaw");

	LoadSoundScript("scripts/npc_sounds_zombie.txt");

	PrecacheScriptSound("Zombie.Idle");
	PrecacheScriptSound("Zombie.Die");

	PrecacheScriptSound("Zombie.Attack");
	PrecacheScriptSound("Zombie.AttackHit");
	PrecacheScriptSound("Zombie.AttackMiss");

	PrecacheScriptSound("NPC_BaseZombie.Moan1");
	PrecacheScriptSound("NPC_BaseZombie.Moan2");
	PrecacheScriptSound("NPC_BaseZombie.Moan3");
	PrecacheScriptSound("NPC_BaseZombie.Moan4");

	PrecacheScriptSound("Zombie.FootstepRight");
	PrecacheScriptSound("Zombie.FootstepLeft");
	PrecacheScriptSound("Zombie.ScuffRight");
	PrecacheScriptSound("Zombie.ScuffLeft");

	PrecacheScriptSound("Zombie.Pain");
}

void hl2_zombie_created(int entity)
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
	if(event.event == AE_ZOMBIE_STEP_LEFT) {
		EmitGameSoundToAll("Zombie.FootstepLeft", entity);
	} else if(event.event == AE_ZOMBIE_STEP_RIGHT) {
		EmitGameSoundToAll("Zombie.FootstepRight", entity);
	} else if(event.event == AE_ZOMBIE_SCUFF_LEFT) {
		EmitGameSoundToAll("Zombie.ScuffLeft", entity);
	} else if(event.event == AE_ZOMBIE_SCUFF_RIGHT) {
		EmitGameSoundToAll("Zombie.ScuffRight", entity);
	} else if(event.event == AE_ZOMBIE_ATTACK_RIGHT ||
				event.event == AE_ZOMBIE_ATTACK_LEFT ||
				event.event == AE_ZOMBIE_ATTACK_BOTH) {
		int damage = (event.event == AE_ZOMBIE_ATTACK_BOTH) ? sk_zombie_dmg_both_slash.IntValue : sk_zombie_dmg_one_slash.IntValue;

		int hit = CombatCharacterHullAttackRange(entity, MELEE_RANGE, MELEE_MINS, MELEE_MAXS, damage, DMG_SLASH|DMG_CLUB, 1.0, true);
		if(hit != -1) {
			EmitGameSoundToAll("Zombie.AttackHit", entity);
		} else {
			EmitGameSoundToAll("Zombie.AttackMiss", entity);
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
	EmitGameSoundToAll("Zombie.Pain", entity);
	return Plugin_Continue;
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
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, NULL_VECTOR, 45.0, 45.0);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(hl2_zombie_behavior, "HL2ZombieBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);
}