#include "behavior.sp"

static int npc_idle_anim = -1;

static ConVar npc_health_cvar;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_hIdleSoundTimer", custom_prop_int);
}

void tf2_saucer_init()
{
	npc_health_cvar = CreateConVar("tf_saucer_health", "1000");

	CustomEntityFactory factory = null;
	npc_datamap_init(register_nextbot_factory("npc_tf2_saucer", "TF2Saucer", _, _, factory));

	npc_datamap_init(register_robot_nextbot_factory("npc_tf2_saucer_robothealthbar", "TF2Saucer"));
	npc_datamap_init(register_tankboss_nextbot_factory("npc_tf2_saucer_tankhealthbar", "TF2Saucer"));

	CustomPopulationSpawnerEntry spawner = register_popspawner("TF2Saucer");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "saucer_lite");
	return true;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Spy;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health_cvar.IntValue);
}

static bool npc_pop_spawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_tf2_saucer", spawner, pos, result);
}

#define TF2_SAUCER_MODEL "models/props_teaser/saucer.mdl"

void tf2_saucer_precache(int entity)
{
	PrecacheModel(TF2_SAUCER_MODEL);

	//AddModelToDownloadsTable(TF2_SAUCER_MODEL);

	SetEntityModel(entity, TF2_SAUCER_MODEL);

	npc_idle_anim = AnimatingLookupSequence(entity, "idle");

	PrecacheScriptSound("Weapon_Capper.Single");

	PrecacheSound("UFO_1_short.wav");
	PrecacheSound("e_o_mvm.wav");
	PrecacheSound("e_o_mvm_2.wav");
}

void tf2_saucer_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
}

static void fire_animevents(int entity)
{
	int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");

	int frame = AnimatingSequenceFrame(entity);

	int event_idx = -1;

	

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

	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 2.0);

	fire_animevents(entity);

	return Plugin_Continue;
}

static Action npc_handle_animevent(int entity, animevent_t event)
{
	

	return Plugin_Continue;
}

static int npc_select_animation(IBodyCustom body, int entity, Activity act)
{
	return npc_idle_anim;
}

static Activity npc_translate_act(IBodyCustom body, Activity act)
{
	return ACT_IDLE;
}

static Action npc_takedmg(int entity, CTakeDamageInfo info, int &result)
{
	return Plugin_Continue;
}

static void npc_spawn(int entity)
{
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 2.0);
	SetEntityModel(entity, TF2_SAUCER_MODEL);
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_GREEN);
	SetEntPropString(entity, Prop_Data, "m_iName", "Saucer");

	AnimatingHookHandleAnimEvent(entity, npc_handle_animevent);

	INextBot bot = INextBot(entity);
	flying_npc_spawn(bot, entity, npc_health_cvar.IntValue, NULL_VECTOR, 135.0, 500.0);
	HookEntityThink(entity, npc_think);

	NextBotFlyingLocomotion custom_locomotion = view_as<NextBotFlyingLocomotion>(bot.LocomotionInterface);
	custom_locomotion.AllowFacing = false;

	bot.AllocateCustomIntention(tf2_saucer_behavior, "TF2SaucerBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("SelectAnimationSequence", npc_select_animation);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);

	EmitSoundToAll("e_o_mvm_2.wav", entity, SNDCHAN_BODY, SNDLEVEL_AIRCRAFT);
	SetEntProp(entity, Prop_Data, "m_hIdleSoundTimer", CreateTimer(1.0, timer_npc_idlesound, EntIndexToEntRef(entity), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE));
}

static Action timer_npc_idlesound(Handle timer, int entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity == -1) {
		return Plugin_Stop;
	}

	EmitSoundToAll("e_o_mvm_2.wav", entity, SNDCHAN_BODY, SNDLEVEL_AIRCRAFT);
	return Plugin_Continue;
}

void tf2_saucer_destroyed(int entity)
{
	Handle timer = GetEntProp(entity, Prop_Data, "m_hIdleSoundTimer");
	if(timer != null) {
		KillTimer(timer);
	}

	StopSound(entity, SNDCHAN_BODY, "e_o_mvm_2.wav");
}