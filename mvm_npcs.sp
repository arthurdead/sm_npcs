#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <datamaps>
#include <nextbot>
#include <animhelpers>
#include <popspawner>

#include "tf2_npcs/shared.sp"

#include "mvm_npcs/shared.sp"
#include "mvm_npcs/deadnaut.sp"
#include "mvm_npcs/bulltank.sp"

public void OnPluginStart()
{
	mvm_npcs_init();

	RegConsoleCmd("testmvm", cmd);
}

bool TraceEntityFilter_DontHitEntity(int entity, int mask, any data)
{
	return entity != data;
}

Action cmd(int client, int args)
{
	int entity = CreateDeadnaut();

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
	mvm_npcs_precache();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "npc_deadnaut")) {
		SDKHook(entity, SDKHook_Think, OnDeadnautThink);
		SDKHook(entity, SDKHook_SpawnPost, OnDeadnautSpawn);
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	} else if(StrEqual(classname, "npc_bulltank")) {
		SDKHook(entity, SDKHook_Think, OnBulltankThink);
		SDKHook(entity, SDKHook_SpawnPost, OnBulltankSpawn);
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamage);
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
		StrEqual(classname, "npc_deadnaut") ||
		StrEqual(classname, "npc_slasher")) {
		base_npc_deleted(entity);
	}
}

public void OnPluginEnd()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_bulltank")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
	entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_deadnaut")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
	entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_slasher")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}