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
#include "base/hl2_npcs/shared.sp"
#include "base/hl2_npcs/classic_zombie.sp"

public void OnPluginStart()
{
	base_npc_init();

	classiczombie_init();
	
	RegConsoleCmd("testzm", cmd);
}

bool TraceEntityFilter_DontHitEntity(int entity, int mask, any data)
{
	return entity != data;
}

Action cmd(int client, int args)
{
	int entity = create_base_npc("npc_classiczombie");

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

	classiczombie_precache(entity, anim);

	RemoveEntity(entity);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "npc_classiczombie")) {
		SDKHook(entity, SDKHook_Think, OnClassicZombieThink);
		SDKHook(entity, SDKHook_SpawnPost, OnClassicZombieSpawn);
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnNPCTakeDamage);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "npc_classiczombie")) {
		base_npc_deleted(entity);
	}
}

public void OnPluginEnd()
{
	ClassicZombieRemoveAll();
}