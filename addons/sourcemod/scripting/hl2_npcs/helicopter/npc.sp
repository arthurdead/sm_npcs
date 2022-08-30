int hl2_helicopter_muzzle = -1;

#include "behavior.sp"

static int npc_idle_anim = -1;

static int npc_rudder = -1;

static ConVar npc_health_cvar;

void hl2_helicopter_init()
{
	npc_health_cvar = CreateConVar("sk_helicopter_health", "1000");

	CustomEntityFactory factory = null;
	register_nextbot_factory("npc_hl2_helicopter", "HL2Helicopter", _, _, factory);
	factory.add_alias("npc_hl2_helicopter_bosshealthbar");

	register_robot_nextbot_factory("npc_hl2_helicopter_healthbar", "HL2Helicopter");
	register_tankboss_nextbot_factory("npc_hl2_helicopter_tankhealthbar", "HL2Helicopter");

	CustomPopulationSpawnerEntry spawner = register_popspawner("HL2Helicopter");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "hl2_helicopter");
	return true;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Sniper;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health_cvar.IntValue);
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

	hl2_helicopter_muzzle = AnimatingLookupAttachment(entity, "Muzzle");

	LoadSoundScript("scripts/npc_sounds_attackheli.txt");

	PrecacheScriptSound("NPC_AttackHelicopter.Rotors");
	PrecacheScriptSound("NPC_AttackHelicopter.RotorBlast");
	PrecacheScriptSound("NPC_AttackHelicopter.FireGun");
}

void hl2_helicopter_created(int entity)
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

	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);

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

static void npc_spawn(int entity)
{
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.5);
	SetEntityModel(entity, "models/combine_helicopter.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);
	SetEntPropString(entity, Prop_Data, "m_iName", "Helicopter");

	INextBot bot = INextBot(entity);
	flying_npc_spawn(bot, entity, npc_health_cvar.IntValue, view_as<float>({38.0, 38.0, 38.0}), 100.0, 500.0);
	HookEntityThink(entity, npc_think);

	NextBotFlyingLocomotion custom_locomotion = view_as<NextBotFlyingLocomotion>(bot.LocomotionInterface);
	custom_locomotion.DesiredAltitude = 100.0;

	bot.AllocateCustomIntention(hl2_helicopter_behavior, "HL2HelicopterBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("SelectAnimationSequence", npc_select_animation);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	EmitGameSoundToAll("NPC_AttackHelicopter.Rotors", entity);
	EmitGameSoundToAll("NPC_AttackHelicopter.RotorBlast", entity);
}

void hl2_helicopter_destroyed(int entity)
{
	StopGameSound(entity, "NPC_AttackHelicopter.Rotors");
	StopGameSound(entity, "NPC_AttackHelicopter.RotorBlast");
}