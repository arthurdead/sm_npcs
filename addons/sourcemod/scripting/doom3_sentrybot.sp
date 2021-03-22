#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <clsobj_hack>
#include <datamaps>
#include <animhelpers>
#include <nextbot>

#include "base/shared.sp"

CObjectInfoCustom g_SentryBoyInfo = null;
DynamicHook GetConstructionMultiplierDetour = null;

public void OnPluginStart()
{
	base_npc_init();

	GameData gamedata = new GameData("doom3_sentrybot");

	GetConstructionMultiplierDetour = DynamicHook.FromConf(gamedata, "CBaseObject::GetConstructionMultiplier");

	delete gamedata;

	CustomEntityFactory factory = register_baseobject_factory("obj_doom3_sentrybot");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);
	datamap.add_prop("m_flLastStep", custom_prop_float);

	g_SentryBoyInfo = CObjectInfoCustom.CloneByName("OBJ_SENTRYGUN");
	g_SentryBoyInfo.SetString("m_pObjectName", "OBJ_DOOM3_SENTRYBOT");
	g_SentryBoyInfo.SetString("m_pClassName", "obj_doom3_sentrybot");
	g_SentryBoyInfo.SetFloat("m_flUpgradeDuration", 0.0);
	g_SentryBoyInfo.SetInt("m_MaxUpgradeLevel", 1);
	g_SentryBoyInfo.SetInt("m_UpgradeCost", 0);

	HookEvent("player_builtobject", player_builtobject);
	HookEvent("object_destroyed", object_destroyed);
	HookEvent("object_detonated", object_destroyed);
}

public Action ClassCanBuildObject(int client, int class, int type, bool &can)
{
	if(g_SentryBoyInfo != null && type == g_SentryBoyInfo.Index) {
		can = true;
		return Plugin_Changed;
	} else if(type == view_as<int>(TFObject_Sentry)) {
		can = false;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

static const char stepstounds[4][PLATFORM_MAX_PATH] =
{
	"cpt_doom3/sentrybot/sentry_sstep_01.wav",
	"cpt_doom3/sentrybot/sentry_sstep_02.wav",
	"cpt_doom3/sentrybot/sentry_sstep_03.wav",
	"cpt_doom3/sentrybot/sentry_sstep_04.wav",
};

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "model", "models/error.mdl");
	DispatchSpawn(entity);

	BaseAnimating anim = BaseAnimating(entity);

	PrecacheModel("models/cpthazama/doom3/sentrybot.mdl");

	SetEntityModel(entity, "models/cpthazama/doom3/sentrybot.mdl");

	g_SentryBoyInfo.SetFloat("m_flBuildTime", anim.SequenceDuration("unfold") * 1.8);

	RemoveEntity(entity);

	PrecacheSound("cpt_doom3/sentrybot/sentry_destroyed_01.wav");
	PrecacheSound("cpt_doom3/sentrybot/sentry_activate_01.wav");
	PrecacheSound("cpt_doom3/sentrybot/sentry_shutdown_01.wav");
	for(int i = 0; i < 4; ++i) {
		PrecacheSound(stepstounds[i]);
	}
}

void SentryBotSpawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);

	SetEntityModel(entity, "models/cpthazama/doom3/sentrybot.mdl");

	base_npc_set_hull(entity, 20.0, 50.0);

	SDKUnhook(entity, SDKHook_SpawnPost, SentryBotSpawn);
	SDKHook(entity, SDKHook_SpawnPost, SentryBotCarried);

	SentryBotCarried(entity);
}

void SentryBotCarried(int entity)
{
	float origin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);

	EmitSoundToAll("cpt_doom3/sentrybot/sentry_shutdown_01.wav", entity, SNDCHAN_VOICE, _, _, _, _, _, origin, NULL_VECTOR);
}

Action object_destroyed(Event event, const char[] name, bool dontBroadcast)
{
	int type = event.GetInt("objecttype");

	if(type == g_SentryBoyInfo.Index) {
		int entity = event.GetInt("index");

		float origin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);

		EmitSoundToAll("cpt_doom3/sentrybot/sentry_destroyed_01.wav", entity, SNDCHAN_VOICE, _, _, _, _, _, origin, NULL_VECTOR);
	}

	return Plugin_Continue;
}

Action player_builtobject(Event event, const char[] name, bool dontBroadcast)
{
	int type = event.GetInt("object");

	if(type == g_SentryBoyInfo.Index) {
		int entity = event.GetInt("index");

		float origin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);

		EmitSoundToAll("cpt_doom3/sentrybot/sentry_activate_01.wav", entity, SNDCHAN_VOICE, _, _, _, _, _, origin, NULL_VECTOR);
	}

	return Plugin_Continue;
}

void SentryBotThink(int entity, const char[] context, any data)
{
	INextBot bot = INextBot(entity);

	SetEntityNextThinkContext(entity, GetGameTime() + 0.05);

	BaseAnimating anim = BaseAnimating(entity);

	if(GetEntProp(entity, Prop_Send, "m_bBuilding")) {
		int sequence = anim.SelectWeightedSequenceEx(ACT_STAND);
		anim.ResetSequenceEx(sequence);
		return;
	}

	if(GetEntProp(entity, Prop_Send, "m_bPlacing")) {
		int sequence = anim.SelectWeightedSequenceEx(ACT_CROUCHIDLE);
		anim.ResetSequenceEx(sequence);
		return;
	}

	if(GetEntProp(entity, Prop_Send, "m_bCarried") ||
		GetEntProp(entity, Prop_Send, "m_bPlasmaDisable") ||
		GetEntProp(entity, Prop_Send, "m_bDisabled") ||
		GetEntProp(entity, Prop_Send, "m_bCarryDeploy")) {
		return;
	}

	bot.DoThink(entity);

	base_npc_think(entity);

	int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	if(builder == -1) {
		return;
	}

	PathFollower path = get_npc_path(entity);
	NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

	if(GetEntPropFloat(entity, Prop_Data, "m_flRepathTime") <= GetGameTime()) {
		path.ComputeEntity(bot, builder, baseline_path_cost, cost_flags_mod);
		SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
	}

	int sequence = anim.SelectWeightedSequenceEx(ACT_IDLE);
	float speed = locomotion.GroundSpeed;
	if(speed > 1.0) {
		if(GetEntPropFloat(entity, Prop_Data, "m_flLastStep") <= GetGameTime()) {
			float origin[3];
			GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);

			EmitSoundToAll(stepstounds[GetRandomInt(0, sizeof(stepstounds)-1)], entity, SNDCHAN_VOICE, _, _, _, _, _, origin, NULL_VECTOR);

			SetEntPropFloat(entity, Prop_Data, "m_flLastStep", GetGameTime() + 0.1);
		}

		sequence = anim.SelectWeightedSequenceEx(ACT_WALK);
	}

	anim.ResetSequenceEx(sequence);

	float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed == 0.0) {
		m_flGroundSpeed = 999.0;
	}

	locomotion.RunSpeed = m_flGroundSpeed;
	locomotion.WalkSpeed = m_flGroundSpeed;

	path.Update(bot);
}

MRESReturn GetConstructionMultiplierPost(int pThis, DHookReturn hReturn)
{
	view_as<float>(hReturn.Value) *= 2.0;
	return MRES_Supercede;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "obj_doom3_sentrybot")) {
		SetEntProp(entity, Prop_Send, "m_iObjectType", g_SentryBoyInfo.Index);

		SDKHook(entity, SDKHook_SpawnPost, SentryBotSpawn);

		GetConstructionMultiplierDetour.HookEntity(Hook_Post, entity, GetConstructionMultiplierPost);

		SetEntityContextThink(entity, SentryBotThink, GetGameTime() + 0.05, "SentrybotContext");

		MakeEntityNextBot(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "obj_doom3_sentrybot")) {
		base_npc_deleted(entity);
	}
}

void SentryBotRemoveAll()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "obj_doom3_sentrybot")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}

public void OnPluginEnd()
{
	SentryBotRemoveAll();
}