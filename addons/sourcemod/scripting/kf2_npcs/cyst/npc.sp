static int npc_walk_anim = -1;
static int npc_run_anim = -1;
static int npc_idle_anim = -1;
static int npc_jump_anim = -1;

static int npc_melee_anims[3] = {-1, ...};

#include "behavior.sp"

static int npc_health = 300;

void kf2_cyst_init()
{
	register_robot_nextbot_factory("npc_kf2_cyst", "KF2Cyst");

	CustomPopulationSpawnerEntry spawner = register_popspawner("KF2Cyst");
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
	return npc_pop_spawn_single("npc_kf2_cyst", spawner, pos, result);
}

void kf2_cyst_precache(int entity)
{
	PrecacheModel("models/linux55/kf2/zeds/cyst_kf2.mdl");
	SetEntityModel(entity, "models/linux55/kf2/zeds/cyst_kf2.mdl");

	npc_walk_anim = AnimatingLookupSequence(entity, "walk");
	npc_run_anim = AnimatingLookupSequence(entity, "run");
	npc_idle_anim = AnimatingLookupSequence(entity, "idle");
	npc_jump_anim = AnimatingLookupSequence(entity, "jump");

	npc_melee_anims[0] = AnimatingLookupSequence(entity, "attack1");
	npc_melee_anims[1] = AnimatingLookupSequence(entity, "attack2");
	npc_melee_anims[2] = AnimatingLookupSequence(entity, "attack3");
}

void kf2_cyst_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
	SDKHook(entity, SDKHook_ThinkPost, npc_think);
}

static void npc_think(int entity)
{
	npc_fire_animevent(entity);

	INextBot bot = INextBot(entity);
	ILocomotion locomotion = bot.LocomotionInterface;
	IBody body = bot.BodyInterface;

	npc_hull_debug(bot, body, locomotion, entity);

	npc_resolve_collisions(entity);

	handle_playbackrate(entity, locomotion, body);
}

static void npc_fire_animevent(int entity)
{
	int anim_idx = -1;

	int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");
	for(int i = 0; i < sizeof(npc_melee_anims); ++i) {
		if(sequence == npc_melee_anims[i]) {
			anim_idx = i;
			break;
		}
	}

	if(anim_idx == -1) {
		return;
	}

	int frame = AnimatingSequenceFrame(entity);

	bool do_event = false;

	switch(anim_idx) {
		case 0: {
			switch(frame) {
				case 10, 18:
				do_event = true;
			}
		}
		case 1: {
			switch(frame) {
				case 16, 28:
				do_event = true;
			}
		}
		case 2: {
			switch(frame) {
				case 5, 11, 21, 27, 39, 45:
				do_event = true;
			}
		}
	}

	if(do_event && GetEntPropFloat(entity, Prop_Send, "m_flNextAttack") < GetGameTime()) {
		animevent_t event;
		event.event = AE_NPC_ATTACK_BROADCAST;
		AnimatingHandleAnimEvent(entity, event);
		SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", GetGameTime() + 0.1);
	}
}

static Action npc_handle_animevent(int entity, animevent_t event)
{
	if(event.event == AE_NPC_ATTACK_BROADCAST) {
		CombatCharacterHullAttackRange(entity, MELEE_RANGE, MELEE_MINS, MELEE_MAXS, 10, DMG_SLASH|DMG_CLUB, 1.0, true);
	}

	return Plugin_Continue;
}

static int npc_select_animation(IBodyCustom body, int entity, Activity act)
{
	switch(act) {
		case ACT_IDLE: return npc_idle_anim;
		case ACT_RUN: return npc_run_anim;
		case ACT_WALK: return npc_walk_anim;
		case ACT_JUMP: return npc_jump_anim;
		case ACT_MELEE_ATTACK1: {
			return npc_melee_anims[GetRandomInt(0, sizeof(npc_melee_anims)-1)];
		}
	}

	return -1;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/linux55/kf2/zeds/cyst_kf2.mdl");
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.5);
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Cyst");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health, view_as<float>({20.0, 20.0, 82.0}), 100.0, 160.0);

	bot.AllocateCustomIntention(kf2_cyst_behavior, "KF2CystBehavior");

	IBodyCustom body = view_as<IBodyCustom>(bot.BodyInterface);
	body.set_function("SelectAnimationSequence", npc_select_animation);
}