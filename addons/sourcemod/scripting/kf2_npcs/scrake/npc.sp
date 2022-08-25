static int kf2_scrake_walk_anim = -1;
static int kf2_scrake_run_anim = -1;
static int kf2_scrake_idle_anim = -1;
static int kf2_scrake_jump_anim = -1;

static int kf2_scrake_melee_anims[5] = {-1, ...};

#include "behavior.sp"

void kf2_scrake_init()
{
	register_robot_nextbot_factory("npc_kf2_scrake", "KF2Scrake");

	CustomPopulationSpawnerEntry spawner = register_popspawner("KF2Scrake");
	spawner.Parse = npc_pop_parse;
	spawner.Spawn = kf2_scrake_pop_spawner;
	spawner.GetClass = kf2_scrake_pop_class;
	spawner.HasAttribute = npc_pop_attrs;
	spawner.GetHealth = kf2_scrake_pop_health;
}

static TFClassType kf2_scrake_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Soldier;
}

static int kf2_scrake_pop_health(CustomPopulationSpawner spawner, int num)
{
	return 1000;
}

static bool kf2_scrake_pop_spawner(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	int entity = CreateEntityByName("npc_kf2_scrake");
	TeleportEntity(entity, pos);
	DispatchSpawn(entity);

	if(result) {
		result.Push(entity);
	}

	if(!npc_pop_spawn(spawner, pos, result)) {
		return false;
	}

	return true;
}

void kf2_scrake_precache(int entity)
{
	PrecacheModel("models/linux55/kf2/zeds/scrake_kf2.mdl");
	SetEntityModel(entity, "models/linux55/kf2/zeds/scrake_kf2.mdl");

	kf2_scrake_walk_anim = AnimatingLookupSequence(entity, "walk");
	kf2_scrake_run_anim = AnimatingLookupSequence(entity, "run");
	kf2_scrake_idle_anim = AnimatingLookupSequence(entity, "idle");
	kf2_scrake_jump_anim = AnimatingLookupSequence(entity, "jump");

	kf2_scrake_melee_anims[0] = AnimatingLookupSequence(entity, "attack1");
	kf2_scrake_melee_anims[1] = AnimatingLookupSequence(entity, "attack2");
	kf2_scrake_melee_anims[2] = AnimatingLookupSequence(entity, "attack3");
	kf2_scrake_melee_anims[3] = AnimatingLookupSequence(entity, "attack4");
	kf2_scrake_melee_anims[4] = AnimatingLookupSequence(entity, "attack5");
}

void kf2_scrake_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, kf2_scrake_spawn);
	SDKHook(entity, SDKHook_ThinkPost, npc_think);
	SDKHook(entity, SDKHook_ThinkPost, kf2_scrake_fire_animevent);
}

static void kf2_scrake_fire_animevent(int entity)
{
	int anim_idx = -1;

	int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");
	for(int i = 0; i < sizeof(kf2_scrake_melee_anims); ++i) {
		if(sequence == kf2_scrake_melee_anims[i]) {
			anim_idx = i;
			break;
		}
	}

	if(anim_idx == -1) {
		return;
	}

	int frame = AnimatingSequenceFrame(entity);

	animevent_t event;
	event.event = AE_NPC_ATTACK_BROADCAST;

	switch(anim_idx) {
		case 0: {
			if(frame >= 3 && frame <= 6 ||
				frame >= 12 && frame <= 15 ||
				frame >= 21 && frame <= 24 ||
				frame >= 34 && frame <= 36) {
				AnimatingHandleAnimEvent(entity, event);
			}
		}
		case 1: {
			if(frame >= 3 && frame <= 6 ||
				frame >= 11 && frame <= 13 ||
				frame >= 19 && frame <= 21 ||
				frame >= 28 && frame <= 30) {
				AnimatingHandleAnimEvent(entity, event);
			}
		}
		case 2: {
			if(frame >= 2 && frame <= 5 ||
				frame >= 9 && frame <= 11) {
				AnimatingHandleAnimEvent(entity, event);
			}
		}
		case 3: {
			if(frame >= 12 && frame <= 14 ||
				frame >= 18 && frame <= 22) {
				AnimatingHandleAnimEvent(entity, event);
			}
		}
		case 4: {
			if(frame >= 2 && frame <= 6 ||
				frame >= 11 && frame <= 14) {
				AnimatingHandleAnimEvent(entity, event);
			}
		}
	}
}

static Action kf2_scrake_handle_animevent(int entity, animevent_t event)
{
	if(event.event == AE_NPC_ATTACK_BROADCAST) {
		
	}

	return Plugin_Continue;
}

static int kf2_scrake_select_animation(IBodyCustom body, int entity, Activity act)
{
	switch(act) {
		case ACT_IDLE: return kf2_scrake_idle_anim;
		case ACT_RUN: return kf2_scrake_run_anim;
		case ACT_WALK: return kf2_scrake_walk_anim;
		case ACT_JUMP: return kf2_scrake_jump_anim;
		case ACT_MELEE_ATTACK1: {
			return kf2_scrake_melee_anims[GetRandomInt(0, sizeof(kf2_scrake_melee_anims)-1)];
		}
	}

	return -1;
}

static void kf2_scrake_spawn(int entity)
{
	SetEntityModel(entity, "models/linux55/kf2/zeds/scrake_kf2.mdl");
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.5);
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);

	SetEntPropString(entity, Prop_Data, "m_iName", "Scrake");

	AnimatingHookHandleAnimEvent(entity, kf2_scrake_handle_animevent);

	int health = 1000;

	INextBot bot = INextBot(entity);

	shared_npc_spawn(bot, entity, health, view_as<float>({22.0, 23.0, 180.0}), 100.0, 300.0);

	bot.AllocateCustomIntention(kf2_scrake_behavior, "KF2ScrakeBehavior");

	IBodyCustom body = view_as<IBodyCustom>(bot.BodyInterface);
	body.set_function("SelectAnimationSequence", kf2_scrake_select_animation);
}