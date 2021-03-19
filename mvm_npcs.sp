#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <datamaps>
#include <nextbot>
#include <animhelpers>
#include <popspawner>

#include "base/shared.sp"

#include "base/mvm_npcs/shared.sp"
#include "base/mvm_npcs/deadnaut.sp"
#include "base/mvm_npcs/bulltank.sp"

public void OnPluginStart()
{
	PrintToServer("on plugin loadddddddddddddddddddddddd!!!!!!!!!!!");

	//override_serverclass_name("player", "CTFPlayer", "CHeadlessHatman");

	base_npc_init();

	bulltank_init();
	deadnaut_init();

	RegConsoleCmd("testmvm", cmd);
	RegConsoleCmd("testmvm2", cmd2);
	RegConsoleCmd("testmvm3", cmd3);
	RegConsoleCmd("testmvm4", cmd4);
	RegConsoleCmd("testmvm5", cmd5);
	RegConsoleCmd("testmvm6", cmd6);
}

Action cmd3(int client, int args)
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_bulltank")) != -1) {
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

		TeleportEntity(client, pos);

		break;
	}

	return Plugin_Handled;
}

Action cmd2(int client, int args)
{
	float origin[3];
	GetClientEyePosition(client, origin);

	float angles[3];
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntity, client);

	float end[3];
	TR_GetEndPosition(end, trace);

	delete trace;

	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_bulltank")) != -1) {
		TeleportEntity(entity, end);
	}

	return Plugin_Handled;
}

Action cmd6(int client, int args)
{
	int entity = CreateDeadnaut();

	SetEntProp(entity, Prop_Send, "m_bGlowEnabled", 1);

	PrintToServer("%i", entity);

	float origin[3];
	GetClientEyePosition(client, origin);

	float angles[3];
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntity, client);

	float end[3];
	TR_GetEndPosition(end, trace);

	delete trace;

	TeleportEntity(entity, end);

	return Plugin_Handled;
}

Action cmd(int client, int args)
{
	int entity = create_base_npc("npc_bulltank", TFTeam_Blue);

	SetEntProp(entity, Prop_Send, "m_bGlowEnabled", 1);

	PrintToServer("%i", entity);

	float origin[3];
	GetClientEyePosition(client, origin);

	float angles[3];
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntity, client);

	float end[3];
	TR_GetEndPosition(end, trace);

	delete trace;

	TeleportEntity(entity, end);

	return Plugin_Handled;
}

Action cmd5(int client, int args)
{
	if(client != 0) {
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
	}

	int table = FindStringTable("instancebaseline");
	int num = GetStringTableNumStrings(table);
	for(int i = 0; i < num; ++i) {
		char str[50];
		ReadStringTable(table, i, str, sizeof(str));
		PrintToServer("%s", str);
	}
	return Plugin_Handled;
}

Action cmd4(int client, int args)
{
	int entity = CreateEntityByName("tank_boss");
	DispatchSpawn(entity);

	SetEntProp(entity, Prop_Send, "m_bGlowEnabled", 1);

	PrintToServer("%i", entity);

	float origin[3];
	GetClientEyePosition(client, origin);

	float angles[3];
	GetClientEyeAngles(client, angles);

	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntity, client);

	float end[3];
	TR_GetEndPosition(end, trace);

	delete trace;

	TeleportEntity(entity, end);

	return Plugin_Handled;
}

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "model", "models/error.mdl");
	DispatchSpawn(entity);

	BaseAnimating anim = BaseAnimating(entity);

	bulltank_precache(entity, anim);
	deadnaut_precache(entity, anim);

	RemoveEntity(entity);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "npc_deadnaut")) {
		SDKHook(entity, SDKHook_Think, OnDeadnautThink);
		SDKHook(entity, SDKHook_Spawn, OnDeadnautSpawn);
	} else if(StrEqual(classname, "npc_bulltank")) {
		SDKHook(entity, SDKHook_Think, OnBulltankThink);
		SDKHook(entity, SDKHook_Spawn, OnBulltankSpawn);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "npc_bulltank") ||
		StrEqual(classname, "npc_deadnaut")) {
		base_npc_deleted(entity);
	}
}

public void OnPluginEnd()
{
	BulltankRemoveAll();
	DeadnautRemoveAll();
}