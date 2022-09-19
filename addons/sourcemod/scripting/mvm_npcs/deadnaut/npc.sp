#include "behavior.sp"

static int AE_DEADNAUT_KICK = -1;
static int AE_DEADNAUT_SMASH = -1;

static int npc_idle_anim = -1;
static int npc_walk_anim = -1;
static int npc_run_anim = -1;
static int npc_kick_anim = -1;
static int npc_smash_anim = -1;

static ConVar npc_health_cvar;

static void npc_datamap_init(CustomDatamap datamap)
{
	
}

void mvm_deadnaut_init()
{
	npc_health_cvar = CreateConVar("tf_deadnaut_health", "125");

	CustomEntityFactory factory = null;
	npc_datamap_init(register_nextbot_factory("npc_mvm_deadnaut", "MVMDeadnaut", _, _, factory));

	npc_datamap_init(register_robot_nextbot_factory("npc_mvm_deadnaut_robothealthbar", "MVMDeadnaut"));
	npc_datamap_init(register_tankboss_nextbot_factory("npc_mvm_deadnaut_tankhealthbar", "MVMDeadnaut"));

	CustomPopulationSpawnerEntry spawner = register_popspawner("MVMDeadnaut");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "deadnaut");
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
	return npc_pop_spawn_single("npc_mvm_deadnaut", spawner, pos, result);
}

void mvm_deadnaut_precache(int entity)
{
	PrecacheModel("models/deadnaut/deadnaut_heavy_anim.mdl");

	AddModelToDownloadsTable("models/deadnaut/deadnaut_heavy_anim.mdl");

	SetEntityModel(entity, "models/deadnaut/deadnaut_heavy_anim.mdl");

	npc_idle_anim = AnimatingLookupSequence(entity, "Stance");
	npc_walk_anim = AnimatingLookupSequence(entity, "Walk");
	npc_run_anim = AnimatingLookupSequence(entity, "Run_urgent");
	npc_kick_anim = AnimatingLookupSequence(entity, "Kick");
	npc_smash_anim = AnimatingLookupSequence(entity, "Smash");

	AE_DEADNAUT_KICK = EventList_RegisterPrivateEvent("AE_DEADNAUT_KICK");
	AE_DEADNAUT_SMASH = EventList_RegisterPrivateEvent("AE_DEADNAUT_SMASH");
}

void mvm_deadnaut_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
}

static void fire_animevents(int entity)
{
	int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");

	int frame = AnimatingSequenceFrame(entity);

	int event_idx = -1;

	if(sequence == npc_kick_anim) {
		if(frame == 11) {
			event_idx = AE_DEADNAUT_KICK;
		}
	} else if(sequence == npc_smash_anim) {
		if(frame == 18) {
			event_idx = AE_DEADNAUT_SMASH;
		}
	}

	if(event_idx != -1 && GetEntPropFloat(entity, Prop_Send, "m_flNextAttack") < GetGameTime()) {
		animevent_t event;
		event.event = event_idx;
		AnimatingHandleAnimEvent(entity, event);
		SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", GetGameTime()+0.1);
	}
}

static Action npc_think(int entity)
{
	INextBot bot = INextBot(entity);
	ILocomotion locomotion = bot.LocomotionInterface;
	IBody body = bot.BodyInterface;

	npc_hull_debug(bot, body, locomotion, entity);

	npc_resolve_collisions(entity);

	//handle_playbackrate(entity, locomotion, body);

	fire_animevents(entity);

	return Plugin_Continue;
}

static Action npc_handle_animevent(int entity, animevent_t event)
{
	if(event.event == AE_DEADNAUT_KICK) {
		int hit = CombatCharacterHullAttackRange(entity, 70.0 + MELEE_RANGE, MELEE_MINS, MELEE_MAXS, 10, DMG_CLUB, 1.0, true);
		if(hit != -1) {
			float my_center[3];
			EntityWorldSpaceCenter(entity, my_center);

			float victim_center[3];
			EntityWorldSpaceCenter(hit, victim_center);

			float dir[3];
			SubtractVectors(victim_center, my_center, dir);

			dir[2] = 0.0;
			NormalizeVector(dir, dir);
			dir[2] = 1.0;

			ScaleVector(dir, 500.0);

			ApplyAbsVelocityImpulse(hit, dir);
		}
	} else if(event.event == AE_DEADNAUT_SMASH) {
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

		TE_SetupTFParticleEffect("bomibomicon_ring", pos, NULL_VECTOR, NULL_VECTOR, entity, PATTACH_ABSORIGIN, -1, false);
		TE_SendToAll();

		ArrayList players = new ArrayList();
		PushAllPlayersAway(pos, 200.0, 500.0, TF_TEAM_PVE_DEFENDERS, players);

		float my_center[3];
		EntityWorldSpaceCenter(entity, my_center);

		int len = players.Length;
		for(int i = 0; i < len; ++i) {
			int victim = players.Get(i);

			float victim_center[3];
			EntityWorldSpaceCenter(victim, victim_center);

			float dir[3];
			SubtractVectors(victim_center, my_center, dir);
			NormalizeVector(dir, dir);

			CTakeDamageInfo dmg_info;
			dmg_info.Init(entity, entity, 10.0, DMG_CLUB, 0);
			CalculateMeleeDamageForce(dmg_info, dir, my_center, 5.0);
			EntityTakeDamage(victim, dmg_info);
		}

		delete players;
	}

	return Plugin_Continue;
}

static int npc_select_animation(IBodyCustom body, int entity, Activity act)
{
	switch(act) {
		case ACT_IDLE_AGITATED: {
			return npc_idle_anim;
		}
		case ACT_IDLE_STIMULATED: {
			return npc_idle_anim;
		}
		case ACT_IDLE_RELAXED: {
			return npc_idle_anim;
		}

		case ACT_RUN_AGITATED: {
			return npc_run_anim;
		}
		case ACT_RUN_STIMULATED: {
			return npc_run_anim;
		}
		case ACT_RUN_RELAXED: {
			return npc_run_anim;
		}

		case ACT_WALK_AGITATED: {
			return npc_walk_anim;
		}
		case ACT_WALK_STIMULATED: {
			return npc_walk_anim;
		}
		case ACT_WALK_RELAXED: {
			return npc_walk_anim;
		}

		case ACT_MELEE_ATTACK1: {
			//return ((GetURandomInt() % 2) ? npc_smash_anim : npc_kick_anim);
			return npc_kick_anim;
		}
	}

	return -1;
}

static Action npc_takedmg(int entity, CTakeDamageInfo info, int &result)
{
	return Plugin_Continue;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/deadnaut/deadnaut_heavy_anim.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);
	SetEntPropString(entity, Prop_Data, "m_iName", "Deadnaut");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, NULL_VECTOR, 45.0, 150.0);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(mvm_deadnaut_behavior, "MVMDeadnautBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("SelectAnimationSequence", npc_select_animation);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);
}