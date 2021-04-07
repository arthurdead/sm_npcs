#include <sourcemod>
#include <moreinfected>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#include "base/shared.sp"

#include "base/re_npcs/classic_zombies.sp"
#include "base/re_npcs/tyrant.sp"

public void OnPluginStart()
{
	base_npc_init();

	classiczombie_init();
	tyrant_init();

	RegConsoleCmd("testre", cmd);

	CustomSendtable table = null;
	CustomEntityFactory factory = register_infected_factory("testinfected", table);
	table.set_name("DT_TestInfected");
	table.set_network_name("CTestInfected");
	//table.override_with("NextBotCombatCharacter");
}

Action cmd(int client, int args)
{
	float end[3];
	end[0] = 1842.788208;
	end[1] = 2050.267578;
	end[2] = 68.982697;

	if(client != 0) {
		float origin[3];
		GetClientEyePosition(client, origin);

		float angles[3];
		GetClientEyeAngles(client, angles);

		Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntity, client);

		TR_GetEndPosition(end, trace);

		delete trace;
	}

	moreinfected_data data;
	re_tyrant_precache(data);

	int entity = entity = CreateEntityByName("testinfected");
	PrintToServer("%i", entity);
	DispatchSpawn(entity);

	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderFx(entity, RENDERFX_HOLOGRAM);
	SetEntityRenderColor(entity, 255, 0, 0);

	PrecacheModel("models/re2/re2zombie_officer.mdl");
	SetEntityModel(entity, "models/re2/re2zombie_officer.mdl");

	TeleportEntity(entity, end);

	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "npc_re_classiczombie")) {
		SDKHook(entity, SDKHook_Think, classiczombie_think);
		SDKHook(entity, SDKHook_Spawn, classiczombie_spawn);
	} else if(StrEqual(classname, "npc_re_tyrant")) {
		SDKHook(entity, SDKHook_Think, tyrant_think);
		SDKHook(entity, SDKHook_Spawn, tyrant_spawn);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "npc_re_classiczombie") ||
		StrEqual(classname, "npc_re_tyrant")) {
		base_npc_deleted(entity);
	}
}

public void OnPluginEnd()
{
	classiczombie_removeall();
	tyrant_removeall();
}