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

public void OnPluginStart()
{
	base_npc_init();

	CustomEntityFactory factory = register_baseobject_factory("obj_doom3_sentrybot");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);

	g_SentryBoyInfo = CObjectInfoCustom.CloneByName("OBJ_SENTRYGUN");
	g_SentryBoyInfo.SetString("m_pObjectName", "OBJ_DOOM3_SENTRYBOT");
	g_SentryBoyInfo.SetString("m_pClassName", "obj_doom3_sentrybot");
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

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "model", "models/error.mdl");
	DispatchSpawn(entity);

	BaseAnimating anim = BaseAnimating(entity);

	PrecacheModel("models/cpthazama/doom3/sentrybot.mdl");

	RemoveEntity(entity);
}

void SentryBotSpawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);

	SetEntityModel(entity, "models/cpthazama/doom3/sentrybot.mdl");

	base_npc_set_hull(entity, 20.0, 50.0);

	SDKUnhook(entity, SDKHook_SpawnPost, SentryBotSpawn);
	SDKHook(entity, SDKHook_SpawnPost, SentryBotCarried);
}

void SentryBotCarried(int entity)
{
	PrintToServer("SentryBotCarried");
}

void SentryBotThink(int entity, const char[] context, any data)
{
	INextBot bot = INextBot(entity);

	SetEntityNextThinkContext(entity, GetGameTime() + 0.05);

	if(GetEntProp(entity, Prop_Send, "m_bBuilding") ||
		GetEntProp(entity, Prop_Send, "m_bPlacing") ||
		GetEntProp(entity, Prop_Send, "m_bCarried") ||
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

	float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed == 0.0) {
		m_flGroundSpeed = 999.0;
	}

	locomotion.RunSpeed = m_flGroundSpeed;
	locomotion.WalkSpeed = m_flGroundSpeed;

	path.Update(bot);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "obj_doom3_sentrybot")) {
		SetEntProp(entity, Prop_Send, "m_iObjectType", g_SentryBoyInfo.Index);

		SDKHook(entity, SDKHook_SpawnPost, SentryBotSpawn);

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